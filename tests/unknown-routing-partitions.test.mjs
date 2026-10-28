import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua,shardLuaScripts} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {originalLuaRunner} from './helpers/ci-lua-runner-inverse.mjs';

const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const digest=s=>createHash('sha256').update(s).digest('hex');
const matrixPath='tests/lua/support/unknown_event_routing_matrix.lua';
const coverage="    assert(types.combat and types.shop and types.treasure and types.event)\n    local count=0;for _ in pairs(events) do count=count+1 end;assert(count==7,'all seven events must be reachable across seeds')\n";
const verify='local function verify(types,events)\n'+coverage+'end\n\n';
const observation="        print('ROUTING_SEED '..seed..' '..kind..' '..(kind=='event' and run.nodeFlow.event.id or '-'))\n";
const footer='    return types,events\nend\n\nreturn {run=run,verify=verify}\n';
const parts=[
 ['tests/lua/unknown_event_routing.lua',1,55],
 ['tests/lua/unknown_event_routing_lower_2.lua',56,110],
 ['tests/lua/unknown_event_routing_upper.lua',111,165],
 ['tests/lua/unknown_event_routing_upper_2.lua',166,220],
];
const wrapper=([,first,last])=>`dofile('${matrixPath}').run(${first},${last})\nprint('ROUTING_SLICE ${first} ${last}')\n`;
function original(source){
 assert.equal(source.split(verify).length,2,'exact original coverage assertions');
 assert.equal(source.split(observation).length,2,'one post-assertion observation per seed');
 assert.ok(source.endsWith(footer),'complete run and verifier exports');
 let restored=source.replace(verify,'').replace('local function run(firstSeed,lastSeed)','return function(firstSeed,lastSeed)').replace(observation,'');
 restored=restored.slice(0,-footer.length)+coverage+'end\n';
 assert.equal(digest(restored),'a4d67d6a178274d83c813c241ee8b30a19d524ed8a3a6b423113621bf29f4c70','exact original full matrix');
 return restored;
}
function observations(stdout,first,last){
 const lines=stdout.trim().split(/\r?\n/);
 assert.equal(lines.pop(),`ROUTING_SLICE ${first} ${last}`,'completed whole slice');
 const rows=lines.map(line=>{
  const m=/^ROUTING_SEED (\d+) (combat|shop|treasure|event) ([a-zA-Z0-9_-]+)$/.exec(line);
  assert.ok(m,'real completed seed observation');
  assert.equal(m[2]==='event',m[3]!=='-');
  return {seed:Number(m[1]),kind:m[2],event:m[3]};
 });
 assert.deepEqual(rows.map(r=>r.seed),Array.from({length:last-first+1},(_,i)=>first+i),'all original seeds exactly once and in order');
 return rows;
}

test('routing partitions preserve exact original assertions, topology and deadlines',()=>{
 original(read(matrixPath));
 assert.equal(digest(read('tests/lua/support/unknown_event_routing_map.lua')),'dbbaf362af2e2d5eafe42584be7844f1fdee1835f1ec5c0e5872ef77477e5d3b');
 assert.equal(digest(originalLuaRunner(read('scripts/test-lua.mjs'))),'63ec149511d52b9e362f2c9210d092e4d97bd815c5b8c16e7009ade146d5d55b');
 for(const part of parts)assert.equal(read(part[0]),wrapper(part));
 const discovered=readdirSync('tests/lua').filter(n=>n.endsWith('.lua')).map(n=>'tests/lua/'+n);
 const selected=Array.from({length:8},(_,i)=>shardLuaScripts(discovered,`${i+1}/8`)).flat();
 for(const [path]of parts)assert.equal(selected.filter(p=>p===path).length,1);
});

test('routing guards reject weakened bodies, aggregate assertions, missing and duplicated seeds',()=>{
 const source=read(matrixPath);
 for(const mutant of [source.replace('assert(not Nodes.enter(run,map,id))','assert(true)'),
  source.replace('Nodes.view(run,map);Nodes.view(run,map)','Nodes.view(run,map)'),
  source.replace("count==7,'all seven", "count==6,'all seven"),
  source.replace('for seed=firstSeed,lastSeed do','for seed=firstSeed,lastSeed-1 do'),
  source.replace(observation,'')])assert.throws(()=>original(mutant),{code:'ERR_ASSERTION'});
 const good='ROUTING_SEED 1 combat -\nROUTING_SEED 2 event purifier\nROUTING_SLICE 1 2\n';
 observations(good,1,2);
 for(const mutant of [good.replace('ROUTING_SEED 1 combat -\n',''),good.replace('SEED 2','SEED 1'),good.replace('SLICE 1 2','SLICE 1 1')])
  assert.throws(()=>observations(mutant,1,2),{code:'ERR_ASSERTION'});
});

test('all 220 real Run seeds retain every per-seed assertion and both original 110-seed coverage checks',t=>{
 const rows=[];
 for(const [path,first,last]of parts){
  const started=performance.now(),result=runLua(path);
  t.diagnostic(`${path}: ${Math.round(performance.now()-started)}ms, original 30000ms budget`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  rows.push(...observations(result.stdout,first,last));
 }
 assert.deepEqual(rows.map(r=>r.seed),Array.from({length:220},(_,i)=>i+1));
 const groups=[rows.slice(0,110),rows.slice(110)].map(group=>({
  types:Object.fromEntries(group.map(r=>[r.kind,true])),
  events:Object.fromEntries(group.filter(r=>r.kind==='event').map(r=>[r.event,true])),
 }));
 mkdirSync('build/lua',{recursive:true});
 const path='build/lua/unknown_routing_aggregate.lua';
 const verifyGroups=values=>{
  writeFileSync(path,`local verify=dofile('${matrixPath}').verify\nfor _,g in ipairs(${toLua(values)})do verify(g.types,g.events)end\nprint('ROUTING_ORIGINAL_AGGREGATES_PASS 2')\n`);
  return runLua(path);
 };
 const result=verifyGroups(groups);assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ROUTING_ORIGINAL_AGGREGATES_PASS 2/);
 const noRoute=structuredClone(groups);delete noRoute[0].types.treasure;
 assert.notEqual(verifyGroups(noRoute).status,0,'actual original Lua rejects missing route');
 const noEvent=structuredClone(groups);delete noEvent[1].events[Object.keys(noEvent[1].events)[0]];
 assert.notEqual(verifyGroups(noEvent).status,0,'actual original Lua rejects missing event');
});
