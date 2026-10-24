import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-encounter-runtime-vectors.json','utf8'));
test('room construction vectors preserve independently authored source interpretation',()=>{
 assert.equal(createHash('sha256').update(readFileSync('tools/oracles/sts1_encounter_runtime.py')).digest('hex'),vectors.generatorSha256);
 assert.equal(vectors.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(vectors.cases.length,126);
});
test('all seventeen bindings and Guardian match independent HP/Bite/AI/CurlUp and interleaved stream vectors',()=>{
 const dir=mkdtempSync(join(tmpdir(),'abyss-room-vectors-'));
 try{
  const file=join(dir,'vectors.lua');
  writeFileSync(file,`local Run,C,R,Bindings=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_room_encounters')
local Data=require('abyss_data')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
for _,v in ipairs(${toLua(vectors.cases)})do
 local run=Run.new(Data,v.seed);local streams=Run.roomStreams(run,v.floor)
 assert(streams.seed==v.roomSeed)
 local tier=v.source=='Gremlin Nob' or v.source=='Lagavulin' or v.source=='3 Sentries'
 local binding=v.source=='The Guardian' and {enemies={'guardian'}} or assert(Bindings.resolve(v.source,tier and 'elite' or 'normal'))
 local options={deck={},seed=1,roomSeed=streams.seed,roomStreams=streams,enemies=binding.enemies,sourceEncounter=binding.sourceEncounter}
 options.encounterBoundary={misc={boolean=function()return R.randomBoolean(streams.miscRng)end,
 integer=function(lo,hi)return R.randomIntBetween(streams.miscRng,lo,hi)end},visualFloat=function()return 0 end}
 local trace={};local int,boolean=R.randomInt,R.randomBoolean
 R.randomInt=function(s,max)
  local value=int(s,max);local name=s==streams.miscRng and 'misc' or nil
  -- Combat clones source HP/AI streams; their initial identity is separate.
  if not name then name=max==99 and 'ai' or 'hp' end
  trace[#trace+1]={stream=name,operation='integer',args={0,max},value=value,after=R.snapshot(s)}
  return value
 end
 local between=R.randomIntBetween
 R.randomIntBetween=function(s,lo,hi)
  local value=between(s,lo,hi)
  trace[#trace+1]={stream='misc',operation='integer',args={lo,hi},value=value,after=R.snapshot(s)}
  return value
 end
 R.randomBoolean=function(s)
  local value=boolean(s);trace[#trace+1]={stream=s==streams.miscRng and 'misc' or 'ai',operation='boolean',args={},value=value,after=R.snapshot(s)}
  return value
 end
 local ok,battle=pcall(C.new,Data,options)
 R.randomInt,R.randomIntBetween,R.randomBoolean=int,between,boolean
 assert(ok,battle)
 local actors={}
 for i,e in ipairs(battle.enemies)do
  local a={id=e.definitionId,hp=e.hp,intent=e.intents[e.intentIndex].id}
  if e.ai.kind=='louse'then a.bite=e.intents[1].effects[1].value;a.curlUp=e.statuses.curl_up end
  actors[i]=a
 end
 same(actors,v.actors,v.source..' '..v.seed)
 same(R.snapshot(battle.monsterHpRng),v.hp,'hp '..v.source)
 same(R.snapshot(battle.aiRng),v.ai,'ai '..v.source)
 same(R.snapshot(streams.miscRng),v.misc,'misc '..v.source)
 -- HP adapter uses zero-based bounded draws plus source minimum; normalize
 -- the independent range/value representation before comparing each state.
 local expected={}
 for i,event in ipairs(v.trace)do
  expected[i]=C.copy(event)
  if event.stream=='hp'then expected[i].value=event.value-event.args[1];expected[i].args={0,event.args[2]-event.args[1]}end
 end
 same(trace,expected,'interleaving '..v.source..' '..v.seed)
 assert(battle.shuffleRng.counter==1 and battle.cardRandomRng.counter==0,'empty initializeDeck shuffles once; cardRandom remains unmigrated')
end
print('SOURCE_ROOM_VECTORS_PASS 126')`);
  const result=runLua(file,{timeout:60000});assert.equal(result.status,0,result.stderr||result.stdout);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('actual Nodes entries preserve source queue ownership and transaction boundaries',()=>{
 const result=runLua('tests/lua/encounter_runtime.lua');assert.equal(result.status,0,result.stderr||result.stdout);
});
