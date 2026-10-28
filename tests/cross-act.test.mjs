import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { toLua } from '../scripts/build-lua-data.mjs';

test('real chapter maps, source RNG boundaries, resource migration and ending gates', () => {
  const result=runLua('tests/fixtures/js-owned/tests/lua/cross_act.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/CROSS_ACT_PASS 12/);
});

test('chapter queues and boss shuffle retain independent pinned-source input and generator hashes', () => {
  const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-chapter-queues.json','utf8'));
  const source=JSON.parse(readFileSync('tests/fixtures/cross-act-source-lock.json','utf8'));
  assert.equal(vectors.sourceCommit,source.sourceCommit);
  assert.equal(createHash('sha256').update(readFileSync('tools/oracles/sts1_chapter_queues.py')).digest('hex'),vectors.generatorSha256);
  for (const [path,hash] of Object.entries(vectors.inputHashes)) assert.equal(hash,source.files[path]);
});

test('consecutive chapter queues, full-unlock boss shuffles and card counter states match independent integer vectors', () => {
  const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-chapter-queues.json','utf8'));
  const dir=mkdtempSync(join(tmpdir(),'abyss-chapter-vectors-'));
  try {
    const file=join(dir,'check.lua');
    writeFileSync(file,`local Q=require('abyss_encounter_queue')
local R=require('abyss_sts_random')
local Run=require('abyss_run')
local Data=require('abyss_data')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
for _,v in ipairs(${toLua(vectors.cases)})do
 local prior=Q.new(v.seed)
 for _,a in ipairs(v.acts)do
  same(R.snapshot(prior.monsterRng),a.before)
  local q=Q.new(v.seed,a.act,prior.monsterRng)
  same(q.normal,a.normal);same(q.elite,a.elite);same(R.snapshot(q.monsterRng),a.afterQueues)
  local seen=v.allLaterBossesSeen and {CHAMP=true,AUTOMATON=true,COLLECTOR=true,CROW=true,DONUT=true,WIZARD=true} or {}
  local boss,nextQ=Q.initializeBoss(q,seen)
  same(boss.bossList,a.bosses);same(R.snapshot(nextQ.monsterRng),a.afterBoss)
  same(R.snapshot(q.monsterRng),a.afterQueues,'staging consumed source queue')
  prior=nextQ
 end
end
for _,v in ipairs(${toLua(vectors.cardBoundaries)})do
 local run=Run.new(Data,'42',{experimental=true,campaign=true})
 run.cardRng=R.restore(v.before)
 run.phase,run.pendingAct,run.floor='act_transition',2,17
 run.nodeFlow={floor=17,complete=true,roomKind='boss_treasure',result='boss_treasure_complete'}
 assert(Run.advanceAct(run));same(R.snapshot(run.cardRng),v.after)
end
local fixed=${toLua(vectors.fixedEnding)}
local rng=R.fromSeed('42');R.randomBoolean(rng)
local ending=Q.new('42',4,rng)
same(ending.normal,fixed.normal);same(ending.elite,fixed.elite)
same(R.snapshot(ending.monsterRng),R.snapshot(rng),'fixed ending consumed monster RNG')
local boss,nextEnding=Q.initializeBoss(ending)
same(boss.bossList,fixed.bosses);same(Q.snapshot(nextEnding),Q.snapshot(ending))
print('CROSS_ACT_INDEPENDENT_PASS 14 11')`);
    const result=runLua(file);
    assert.equal(result.status,0,result.stderr||result.stdout);
    assert.match(result.stdout,/CROSS_ACT_INDEPENDENT_PASS 14 11/);
  } finally { rmSync(dir,{recursive:true,force:true}); }
});
