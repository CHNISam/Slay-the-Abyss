import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';

const vectors = JSON.parse(readFileSync('tests/fixtures/sts1-encounter-queue-vectors.json', 'utf8'));
test('encounter vectors retain their independent generator and fixed source identity', () => {
  assert.equal(createHash('sha256').update(readFileSync('tools/oracles/sts1_encounter_queue.py')).digest('hex'), vectors.generatorSha256);
  assert.equal(vectors.sourceCommit, '319009d5df0a82d9fb0f23cc22322286c6a87ec0');
});
test('real source-name queues, every RNG draw and elite refill match independent integer vectors', () => {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-encounter-queue-'));
  try {
    const script = join(directory, 'vectors.lua');
    writeFileSync(script, `local Q=require('abyss_encounter_queue')
local R=require('abyss_sts_random')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
for _,v in ipairs(${toLua(vectors.cases)})do
 local draw,trace=R.randomFloat,{}
 R.randomFloat=function(s)local n=draw(s);trace[#trace+1]={value=n,after=R.snapshot(s)};return n end
 local s=Q.new(v.seed)
 R.randomFloat=draw
 same(trace,v.draws,'draws '..v.seed)
 local snap=Q.snapshot(s)
 same(snap.normal,v.normal);same(snap.elite,v.elite);same(snap.monsterRng,v.afterInitial)
 assert(snap.rawSeed==v.seed)
 for _,name in ipairs(v.normal)do
  assert(Q.peek(s,'normal')==name)
  local got,nextState=Q.consume(s,'normal');assert(got==name);s=nextState
 end
 local before=Q.snapshot(s)
 local no,nextState,reason=Q.consume(s,'normal')
 assert(no==nil and nextState==nil and reason=='normal_queue_exhausted')
 same(Q.snapshot(s),before)
 for _,name in ipairs(v.elite)do local got,n=Q.consume(s,'elite');assert(got==name);s=n end
 assert(Q.peek(s,'elite')==v.eliteRefill[1]);same(Q.snapshot(s).monsterRng,v.afterInitial)
 local got,nextState=Q.consume(s,'elite');assert(got==v.eliteRefill[1]);s=nextState
 same(Q.snapshot(s).monsterRng,v.afterEliteRefill)
 for i=2,10 do local name,n=Q.consume(s,'elite');assert(name==v.eliteRefill[i]);s=n end
end
print('ENCOUNTER_QUEUE_VECTORS_PASS 9')`);
    const result = runLua(script);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /ENCOUNTER_QUEUE_VECTORS_PASS 9/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
test('all seventeen source pool entries retain explicit bindings or blockers without renormalizing missing content', () => {
  const audit = JSON.parse(readFileSync('docs/rules/evidence/sts1-encounter-bindings.json', 'utf8'));
  const data = JSON.parse(readFileSync('data/enemies.json', 'utf8'));
  assert.equal(audit.productionQueueWired, false);
  assert.equal(audit.contentBindingsComplete, false);
  assert.equal(audit.bindings.length, 17);
  assert.equal(new Set(audit.bindings.map(row => row.source)).size, 17);
  assert.deepEqual(audit.bindings.filter(row => row.status === 'blocked').map(row => row.source).sort(),
    ['2 Louse', '3 Louse', 'Large Slime', 'Lots of Slimes', 'Exordium Thugs', 'Exordium Wildlife'].sort());
  for (const binding of audit.bindings) {
    for (const id of binding.ids) assert(data.encounters.some(row => row.id === id), id);
    if (binding.status !== 'bound') { assert(binding.reason); continue; }
    assert.equal(binding.ids.length, 1);
    const entry = data.encounters.find(row => row.id === binding.ids[0]);
    for (const key of ['enemies', 'enemiesOnTrue', 'gremlinPool', 'gremlinCount'])
      assert.deepEqual(entry[key], binding[key], `${binding.source} ${key}`);
  }
  const directory = mkdtempSync(join(tmpdir(), 'abyss-encounter-bindings-'));
  try {
    const script = join(directory, 'bindings.lua');
    writeFileSync(script, `local Q=require('abyss_encounter_queue')
local binding={};for _,row in ipairs(${toLua(audit.bindings)})do binding[row.source]=true end
local names={};local total=0
for _,kind in ipairs({'weak','strong','elite'})do for _,item in ipairs(Q.rules()[kind])do
 assert(binding[item[1]],'unreported source name '..item[1]);names[item[1]]=true;total=total+1
end end
assert(total==17);for name in pairs(binding)do assert(names[name],name)end`);
    const result = runLua(script);
    assert.equal(result.status, 0, result.stderr || result.stdout);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
