-- Explicit chapter/arithmetic fixtures, not a natural three-act playthrough.
local Run,C,D,Q,R,A,W,ER=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
 require('abyss_encounter_queue'),require('abyss_sts_random'),require('abyss_actor'),
 require('abyss_writhing_mass'),require('abyss_enemy_random')
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function intent(e)return e.intents[e.intentIndex].id end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;e.writhingLast=id;return end end;error(id)end
local function battle(deck,ids,data)
 local streams={};for _,k in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[k]=R.fromSeed('42')end
 return C.new(data or D,{enemies=ids or {'writhing_mass'},deck=deck or {},roomSeed='42',roomStreams=streams})
end
local function stage()
 local r=Run.new(D,'34',{campaign=true,experimental=true});r.act,r.floor,r.encounters=3,35,Q.new('34',3)
 for _=1,2 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
 return r
end
test('formal source queue opens the original single160HP encounter without pool resampling',function()
 local r=stage();eq(Q.peek(r.encounters,'normal'),'Writhing Mass')
 local old,deck,uid=r.encounters,#r.deck,r.nextDeckUid
 assert(Run.startRoomCombat(r,'normal'));local s,e=r.combat,r.combat.enemies[1]
 eq(r.encounterSource,'Writhing Mass');eq(#s.enemies,1);eq(e.definitionId,'writhing_mass')
 eq(e.sourceId,'WrithingMass');eq(e.hp,160);eq(e.maxHp,160)
 eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1);eq(r.miscRng.counter,0)
 eq(e.statuses.malleable,3);eq(e.statuses.reactive,1);eq(#r.deck,deck);eq(s.nextMasterDeckUid,uid)
 eq(#r.encounters.normal,#old.normal-1);eq(#old.normal,13);eq(s.player.hp,80)
end)
test('late formal construction restores source queue and every resource owner',function()
 local r=stage();local before=C.copy(r);local queue,card=r.encounters,r.cardRng;local make=C.new
 C.new=function(...)make(...);error('LATE_WRITHING_CONSTRUCTOR')end
 local called,ok,why=pcall(Run.startRoomCombat,r,'normal');C.new=make
 assert(called);eq(ok,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,queue);eq(r.cardRng,card)
end)
test('opening thresholds consume one primary roll and cannot choose big hit or Implant',function()
 for _,v in ipairs({{0,'multi_hit'},{32,'multi_hit'},{33,'attack_block'},{65,'attack_block'},{66,'attack_debuff'},{99,'attack_debuff'}})do
  local e=C.copy(W.enemy);local calls=0
  W.initialize({},e,function(_,maximum)eq(maximum,100);calls=calls+1;return v[1]+1 end)
  eq(intent(e),v[2]);eq(e.writhingLast,v[2]);eq(e.writhingFirst,false);eq(e.writhingUsedImplant,false);eq(calls,1)
 end
end)
local function scripted(last,used,integers,floats,expected)
 local e=C.copy(W.enemy);e.writhingFirst=false;e.writhingLast=last;e.writhingUsedImplant=used
 local i,f,old=0,0,ER.float
 ER.float=function()f=f+1;assert(floats[f]~=nil,'extra float');return floats[f]end
 local ok,why=pcall(W.advance,{},e,function(_,maximum)
  i=i+1;local row=assert(integers[i],'extra integer');eq(maximum,row[1]);return row[2]
 end)
 ER.float=old;assert(ok,why);eq(i,#integers);eq(f,#floats);eq(intent(e),expected);eq(e.writhingLast,expected)
end
test('source post-opening10/20/40/70 thresholds retain exact secondary intervals',function()
 for _,v in ipairs({{9,'big_hit'},{10,'implant'},{19,'implant'},{20,'attack_debuff'},
  {39,'attack_debuff'},{40,'multi_hit'},{69,'multi_hit'},{70,'attack_block'},{99,'attack_block'}})do
  scripted(nil,false,{{100,v[1]+1}},{},v[2])
 end
 scripted('big_hit',false,{{100,10},{90,11}},{},'attack_debuff')
 scripted('attack_block',false,{{100,71},{70,21}},{},'attack_debuff')
end)
test('binary32 chance boundaries preserve .1 .4 .3 float draws and recursive paths',function()
 scripted('implant',false,{{100,11}},{0},'big_hit')
 scripted('implant',true,{{100,20},{80,1}},{R.float32(.1)},'attack_debuff')
 scripted('attack_debuff',false,{{100,21},{20,10}},{0},'big_hit')
 scripted('attack_debuff',false,{{100,40},{60,1}},{R.float32(.4)},'multi_hit')
 scripted('multi_hit',false,{{100,41}},{0},'attack_block')
 scripted('multi_hit',false,{{100,70},{40,1}},{R.float32(.3)},'big_hit')
 scripted('multi_hit',true,{{100,51},{40,11},{80,21}},{.9,.9,0},'attack_block')
end)
test('independent96 selected-move vectors lock every actual integer float and RNG state',function()
 local vectors=dofile('tests/fixtures/act3-writhing-mass-vectors.lua')
 for _,v in ipairs(vectors)do
  local s={aiRng=R.fromSeed(v.seed)};local e=C.copy(W.enemy);local hp=R.fromSeed(v.seed)
  eq(160+R.randomInt(hp,0),v.hp);same(R.snapshot(hp),v.hpRng)
  W.initialize(s,e,ER.legacyInteger);eq(intent(e),v.opening);same(R.snapshot(s.aiRng),v.openingRng)
  for _,step in ipairs(v.steps)do
   if step.executed then W.beforeAction(e,e.intents[e.intentIndex])end
   eq(e.writhingUsedImplant,step.used);local from=s.aiRng.counter
   W.advance(s,e,ER.legacyInteger);eq(intent(e),step.next)
   eq(s.aiRng.counter-from,#step.draws);same(R.snapshot(s.aiRng),step.rng)
  end
 end
end)
test('Malleable blocks and Reactive rerolls queue after all real TwinStrike hits and disposal',function()
 for _,experimental in ipairs({false,true})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle({'twin_strike'},nil,data);local e=s.enemies[1];local from=#s.events+1;local counter=s.aiRng.counter
  assert(C.play(s,s.hand[1].uid,1));eq(e.hp,150);eq(e.block,7);eq(e.statuses.malleable,5)
  local damage,blocks,rolls,lastHit,firstBlock={},0,0
  for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='damage'and ev.detail.target==e.id then damage[#damage+1]=ev.detail.amount;lastHit=i
   elseif ev.kind=='block'and ev.detail.target==e.id then blocks=blocks+1;firstBlock=firstBlock or i
   elseif ev.kind=='enemy_interrupt'and ev.detail.enemy==e.id then rolls=rolls+1;eq(blocks,rolls)end
  end
  same(damage,{5,5});eq(blocks,2);eq(rolls,2);assert(firstBlock>lastHit);eq(#s.discard,1)
  assert(s.aiRng.counter>=counter+2);eq(s.cardRandomRng.counter,0)
  force(e,'big_hit');assert(C.endTurn(s));eq(e.statuses.malleable,3)
 end
end)
test('zero blocked lethal fixed null-owner poison and Thorns cannot trigger either Power',function()
 for _,kind in ipairs({'zero','blocked','lethal','fixed','null','thorns','hp_loss'})do
  local s=battle();local e=s.enemies[1];local ai=s.aiRng.counter
  if kind=='blocked'then e.block=10 end
  if kind=='thorns'then C.retaliate(s,s.player,e,1)
  elseif kind=='hp_loss'then A.loseHp(s,e,1)
  else local source=s.player;if kind=='null'then source=nil end
   C.damage(s,source,e,kind=='zero'and 0 or kind=='lethal'and 160 or 1,kind=='fixed',nil,kind=='null'and 1 or nil)end
  eq(e.statuses.malleable,3);eq(s.aiRng.counter,ai);eq(e.block,kind=='blocked'and 9 or 0)
 end
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'poison',1,s.player);local ai=s.aiRng.counter
 force(e,'big_hit');assert(C.endTurn(s));eq(e.statuses.malleable,3)
 assert(s.aiRng.counter>=ai+1) -- only takeTurn's ordinary RollMove
end)
test('queued Reactive rolls dead owners only with living allies and cancels on final victory',function()
 for _,ally in ipairs({false,true})do
  local s=battle(nil,ally and {'writhing_mass','cultist'}or nil);local e=s.enemies[1];local ai=s.aiRng.counter
  s.resolvingEffects=true;C.damage(s,s.player,e,1);C.damage(s,s.player,e,999,true);s.resolvingEffects=nil
  eq(e.hp,0);eq(e.statuses.malleable,4);eq(e.block,0)
  require('abyss_card_actions').drain(C,s);eq(e.block,0)
  if ally then assert(s.aiRng.counter>ai)else eq(s.aiRng.counter,ai)end
 end
end)
test('native and advanced late reactive failure restore every original RNG actor and pile alias',function()
 for _,experimental in ipairs({false,true})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle({'twin_strike'},nil,data);local e,ai,primitive,hand=s.enemies[1],s.aiRng,s.aiRng.primitive,s.hand
  local before=C.copy(s);local roll=W.roll;local fired=false
  W.roll=function(...)roll(...);fired=true;error('LATE_REACTIVE_ROLL')end
  local ok=pcall(C.play,s,s.hand[1].uid,1);W.roll=roll
  assert(not ok and fired);same(s,before);eq(s.enemies[1],e);eq(s.aiRng,ai);eq(ai.primitive,primitive);eq(s.hand,hand)
 end
end)
print('ACT3_WRITHING_MASS '..passed..' passed; '..failed..' failed');assert(failed==0)
