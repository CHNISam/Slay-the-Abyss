package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Actions=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions')
local Data=require('abyss_warrior_strength_cards').withCards(require('abyss_data'))
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function fresh(advanced,burn)
 local s=C.new(Data,{deck={'combust'},enemies={'cultist'},seed=42})
 -- The same real definitions exercise both production dispatchers; this is a
 -- controlled host selection, not a natural class acquisition claim.
 s.experimentalMechanics=advanced
 assert(C.play(s,s.hand[1].uid));if burn then Actions.toHand(s,Actions.fresh(C,s,'burn'))end
 return s
end
for _,advanced in ipairs({false,true})do
 test('automatic Burn death precedes ordinary Combust '..tostring(advanced),function()
  local s=fresh(advanced,true);local hp=s.enemies[1].hp;s.player.hp=2
  assert(C.endTurn(s));eq(C.outcome(s),'defeat');eq(s.enemies[1].hp,hp)
  eq(s.cardInUse.cardId,'burn')
 end)
 test('Regen TOP action precedes queued Combust loss '..tostring(advanced),function()
  local s=fresh(advanced,false);s.player.hp=1;A.applyPower(s,s.player,'regen',3,s.player)
  assert(C.endTurn(s));eq(C.outcome(s),nil);eq(s.player.hp,3);eq(s.player.statuses.regen,2)
 end)
 test('real native Rage cleanup keeps its owning registration '..tostring(advanced),function()
  local s=C.new(Data,{deck={'rage'},enemies={'cultist'},seed=42});s.experimentalMechanics=advanced
  assert(C.play(s,s.hand[1].uid));assert(C.endTurn(s));eq(s.player.statuses.rage,nil)
 end)
end
test('lethal queued real Strike still executes useCard disposal',function()
 local s=C.new(Data,{deck={'strike'},enemies={'cultist'},seed=42,enableStances=true})
 local card=s.hand[1];s.enemies[1].hp=1
 assert(C.play(s,card.uid,1));eq(C.outcome(s),'victory');eq(s.discard[1].uid,card.uid)
 eq(s.cardInUse,nil);eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
end)
print('OWNER_END_ORDER '..passed..' passed; '..failed..' failed');assert(failed==0,'source owner-end phase mismatch')
