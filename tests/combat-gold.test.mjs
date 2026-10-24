import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-combat-gold-vectors.json','utf8'));
test('combat gold vectors keep their independent canonical-LF generator identity',()=>{
 const generator=readFileSync('tools/oracles/sts1_combat_gold.py','utf8').replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(generator).digest('hex'),vectors.generatorSha256);
 assert.equal(vectors.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(vectors.cases.length,7);assert.equal(vectors.cases.flatMap(v=>v.steps).length,42);
});
test('actual formal battle completion uses continuous treasure gold and room misc boss gold vectors',()=>{
 const dir=mkdtempSync(join(tmpdir(),'abyss-gold-'));
 try{
  const file=join(dir,'vectors.lua');
  writeFileSync(file,`local Run,C,R=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random')
local Data=require('abyss_data')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path..' type')
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
for _,v in ipairs(${toLua(vectors.cases)})do
 local run=Run.new(Data,v.seed)
 for _,step in ipairs(v.steps)do
  run.phase,run.floor='map',step.floor
  assert(Run.startRoomCombat(run,step.tier));assert(run.combat.roomSeed==step.roomSeed)
  -- Terminal ledger fixture only; no natural battle victory or gameplay claim.
  for _,e in ipairs(run.combat.enemies)do e.hp=0;e.escaped=step.allEscaped end
  local before=C.copy(run);local gold=run.gold
  local trace={};local integer=R.randomIntBetween
  R.randomIntBetween=function(s,lo,hi)
   local result=integer(s,lo,hi);trace[#trace+1]={low=lo,high=hi,value=result,after=R.snapshot(s)};return result
  end
  local ok,result=pcall(Run.finishCombat,run)
  R.randomIntBetween=integer;assert(ok and result)
  assert(run.rewards.gold==step.gold,'source gold '..v.seed..' '..step.tier..': '..tostring(run.rewards.gold)..' ~= '..step.gold)
  assert(run.gold==gold,'victory must not auto-claim gold')
  same(R.snapshot(run.treasureRng),step.treasure,'treasure '..v.seed..' '..step.tier)
  if step.tier=='boss'then same(R.snapshot(run.miscRng),step.bossMisc,'boss room misc')
  else same(run.miscRng,before.miscRng,'non-boss misc must not be spent by gold')end
  same(run.combat.monsterHpRng,before.combat.monsterHpRng,'HP untouched')
  same(run.combat.aiRng,before.combat.aiRng,'AI untouched');same(run.combat.shuffleRng,before.combat.shuffleRng,'shuffle untouched')
  same(run.combat.cardRandomRng,before.combat.cardRandomRng,'cardRandom untouched')
  assert(#trace==(step.owner and 1 or 0),'one exact source range draw or none on escape')
  if step.owner then
   assert(trace[1].low==step.bounds[1] and trace[1].high==step.bounds[2],'source draw range')
   local snapshot=R.snapshot(run[step.owner]);same(trace[1].after,snapshot,'selected owner commits once')
  end
  local after=C.copy(run.treasureRng);local misc=C.copy(run.miscRng)
  assert(not Run.finishCombat(run));same(run.treasureRng,after);same(run.miscRng,misc)
  if step.gold>0 then assert(Run.claimGoldReward(run));assert(run.gold==gold+step.gold)
  else assert(run.rewards.goldClaimed and not Run.claimGoldReward(run))end
  local claimed=run.gold;assert(not Run.claimGoldReward(run));assert(run.gold==claimed)
  same(run.treasureRng,after);same(run.miscRng,misc)
 end
end
print('SOURCE_COMBAT_GOLD_VECTORS_PASS 42')`);
  const result=runLua(file,{timeout:60000});assert.equal(result.status,0,result.stderr||result.stdout);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('combat gold bounds, escape, explicit ownership and atomic failure guards',()=>{
 const result=runLua('tests/lua/combat_gold.lua');assert.equal(result.status,0,result.stderr||result.stdout);
});
