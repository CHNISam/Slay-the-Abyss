import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';

test('agent-pack room buckets, pool boundaries and eligibility vectors execute against production modules',()=>{
  const read=name=>JSON.parse(readFileSync(`tests/fixtures/unknown-events/${name}.json`,'utf8'),(_key,value)=>value===null?undefined:value);
  mkdirSync('build/lua',{recursive:true});
  const path='build/lua/unknown-pack-test.lua';
  writeFileSync(path,`local U=require('abyss_unknown')
local P=require('abyss_event_pool');local R=require('abyss_sts_random')
for _,case in ipairs(${toLua(read('room-roll-vectors').cases)}) do
 for _,v in ipairs(case.steps or {case}) do
  local s=U.newPc()
  for k,n in pairs(v.before) do s[k]=R.float32(n/100.0) end
  assert(U.advancePc(s,v.bucket/100.0,{})==v.expected,case.name)
  for k,n in pairs(v.after) do assert(math.abs(s[k]-n/100.0)<0.000001,case.name..k) end
 end
end
for _,v in ipairs(${toLua(read('eligibility-vectors').cases)}) do
 assert(P.isEligible(v.id,{act=1,floor=v.floor,gold=v.gold or 0,cursed=v.isCursed,hp=80,relicCount=1,elapsedSeconds=0})==v.eligible,v.id)
end
for _,v in ipairs(${toLua(read('event-pool-vectors').cases)}) do
 local p={mode='full',act=v.act_available and {'The Cleric'} or {},shrine=v.rare_available and {'Purifier'} or {},once={}}
 local id,kind=P.draw(p,{act=1,floor=7,gold=35},R.fromSeed('1'),v.roll)
 local expected=v.expected_pool
 if expected==nil then assert(id==nil) else
  assert((kind=='act' and 'act1_regular' or 'shrine_and_eligible_one_time')==expected,v.name)
 end
end
print('UNKNOWN_PACK_FIXTURES_PASS')`);
  const result=runLua(path);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/UNKNOWN_PACK_FIXTURES_PASS/);
});
