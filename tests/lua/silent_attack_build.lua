package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat,Silent,Actors=require("abyss_combat"),require("abyss_silent"),require("abyss_actor")
local Cards=require("abyss_silent_attack_cards")
local data=require("abyss_data")
local count=0
local function eq(a,b,label)assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b))end
local function test(name,fn)fn();count=count+1;print("ok silent attack build "..count.." - "..name)end
local function fresh(id,upgraded,extra,two)
 local d=Cards.withCardDefinitions(Silent.withFoundationCards(data))
 local deck={{cardId=id,upgraded=upgraded}}
 for _,c in ipairs(extra or {})do deck[#deck+1]=c end
 local s=Combat.new(d,{deck=deck,enemies=two and {"jaw_worm","jaw_worm"}or{"jaw_worm"},seed=42})
 for _,e in ipairs(s.enemies)do e.hp,e.maxHp=300,300 end
 local card
 for _,pile in ipairs({s.hand,s.draw})do
  for i,c in ipairs(pile)do
   if c.cardId==id then
    card=c
    if pile==s.draw then s.draw[i],s.hand[1]=s.hand[1],c end
    break
   end
  end
  if card then break end
 end
 return s,assert(card)
end
local function damageHits(s)
 local n=0
 for _,e in ipairs(s.events)do if e.kind=="damage"and e.detail.source==s.player.id then n=n+1 end end
 return n
end
for _,upgraded in ipairs({false,true})do
 for _,case in ipairs({{"slice",0,6,9},{"riddle_with_holes",2,15,20},{"backstab",0,11,15}})do
  test(case[1].." real damage/payment/lifecycle "..tostring(upgraded),function()
   local s,card=fresh(case[1],upgraded)
   assert(Combat.play(s,card.uid,1));eq(s.energy,3-case[2]);eq(s.enemies[1].hp,300-(upgraded and case[4]or case[3]))
   eq(damageHits(s),case[1]=="riddle_with_holes"and 5 or 1)
   eq(#s.exhaust,case[1]=="backstab"and 1 or 0)
   if case[1]=="backstab"then eq(Combat.cardDefinition(s,card).innate,true)end
  end)
 end
 test("Sucker Punch damage then Weak "..tostring(upgraded),function()
  local s,card=fresh("sucker_punch",upgraded)
  assert(Combat.play(s,card.uid,1));eq(s.energy,2);eq(s.enemies[1].hp,300-(upgraded and 9 or 7))
  eq(s.enemies[1].statuses.weak,upgraded and 2 or 1)
 end)
 test("Poisoned Stab damage then Poison "..tostring(upgraded),function()
  local s,card=fresh("poisoned_stab",upgraded)
  assert(Combat.play(s,card.uid,1));eq(s.energy,2);eq(s.enemies[1].hp,300-(upgraded and 8 or 6))
  eq(s.enemies[1].statuses.poison,upgraded and 4 or 3)
 end)
 test("Adrenaline gains energy then draws two and exhausts "..tostring(upgraded),function()
  local extra={};for _=1,8 do extra[#extra+1]="defend"end
  local s,card=fresh("adrenaline",upgraded,extra)
  local draw=#s.draw;assert(Combat.play(s,card.uid));eq(s.energy,upgraded and 5 or 4)
  eq(#s.hand,6);eq(#s.draw,draw-2);eq(#s.exhaust,1);eq(s.exhaust[1],card)
 end)
 test("Deflect has zero cost and exact block "..tostring(upgraded),function()
  local s,card=fresh("deflect",upgraded);assert(Combat.play(s,card.uid))
  eq(s.energy,3);eq(s.player.block,upgraded and 7 or 4)
 end)
 test("Caltrops power leaves piles and retaliates through actual enemy attack "..tostring(upgraded),function()
  local s,card=fresh("caltrops",upgraded);assert(Combat.play(s,card.uid));eq(s.energy,2)
  eq(s.player.statuses.thorns,upgraded and 5 or 3);eq(#s.discard,0);eq(#s.exhaust,0)
  assert(Combat.endTurn(s));eq(s.enemies[1].hp,300-(upgraded and 5 or 3))
 end)
end
test("Artifact blocks Poisoned Stab status after damage",function()
 local s,card=fresh("poisoned_stab",false);Actors.addStatus(s.enemies[1],"artifact",1)
 assert(Combat.play(s,card.uid,1));eq(s.enemies[1].hp,294);eq(s.enemies[1].statuses.poison or 0,0)
 eq(s.enemies[1].statuses.artifact,0)
end)
test("Caltrops still retaliates when enemy damage is fully blocked",function()
 local s,card=fresh("caltrops",false);assert(Combat.play(s,card.uid))
 s.player.block=30;local hp=s.player.hp;assert(Combat.endTurn(s))
 eq(s.player.hp,hp);eq(s.enemies[1].hp,297)
end)
test("next energy is capped and waits for recharge; removal is separate",function()
 local s=fresh("slice",false)
 assert(Cards.applyNextEnergy(s,2));eq(s.energy,3);eq(s.player.statuses.energized,2)
 assert(Cards.onEnergyRecharge(s));eq(s.energy,5);eq(s.player.statuses.energized,2)
 assert(Cards.removeNextEnergy(s));eq(s.player.statuses.energized,nil)
 assert(Cards.applyNextEnergy(s,10000));eq(s.player.statuses.energized,999)
 assert(Cards.applyNextEnergy(s,3));eq(s.player.statuses.energized,999)
end)
test("next block uses a captured fixed amount, not new Dexterity/Frail",function()
 local s=fresh("slice",false)
 assert(Cards.applyNextBlock(s,6));Actors.addStatus(s.player,"dexterity",20);Actors.addStatus(s.player,"frail",1)
 assert(Cards.preDrawBlock(s,Combat));eq(s.player.block,6);eq(s.player.statuses.next_turn_block,nil)
 assert(Cards.applyNextBlock(s,0));assert(Cards.preDrawBlock(s,Combat));eq(s.player.statuses.next_turn_block,nil)
end)

-- Real shared conditional/turn/guard regressions. The initial pre-integration
-- run was explicitly red; no mock supplies missing mechanics.
for _,upgraded in ipairs({false,true})do
 test("Bane has one hit without poison and two with poison "..tostring(upgraded),function()
  for _,poison in ipairs({false,true})do
   local s,card=fresh("bane",upgraded)
   if poison then Actors.addStatus(s.enemies[1],"poison",1)end
   assert(Combat.play(s,card.uid,1),"shared target_poison ABI required")
   eq(s.energy,2);eq(s.enemies[1].hp,300-(upgraded and 10 or 7)*(poison and 2 or 1))
   eq(damageHits(s),poison and 2 or 1)
  end
 end)
 test("Heel Hook has a pre-hit weak conditional with energy then draw "..tostring(upgraded),function()
  for _,weak in ipairs({false,true})do
   local extra={};for _=1,8 do extra[#extra+1]="defend"end
   local s,card=fresh("heel_hook",upgraded,extra)
   if weak then Actors.addStatus(s.enemies[1],"weak",1)end
   local draw=#s.draw;assert(Combat.play(s,card.uid,1))
   eq(s.energy,weak and 3 or 2);eq(s.enemies[1].hp,300-(upgraded and 8 or 5))
   eq(#s.draw,draw-(weak and 1 or 0));eq(#s.hand,weak and 5 or 4)
  end
 end)
 test("Flying Knee delays one energy until actual next player turn "..tostring(upgraded),function()
  local s,card=fresh("flying_knee",upgraded);assert(Combat.play(s,card.uid,1))
  eq(s.energy,2);eq(s.enemies[1].hp,300-(upgraded and 11 or 8));eq(s.player.statuses.energized,1)
  assert(Combat.endTurn(s));eq(s.energy,4);eq(s.player.statuses.energized,nil)
  assert(Combat.endTurn(s));eq(s.energy,3)
 end)
 test("Outmaneuver delays base/upgraded energy once "..tostring(upgraded),function()
  local s,card=fresh("outmaneuver",upgraded);assert(Combat.play(s,card.uid));eq(s.energy,2)
  assert(Combat.endTurn(s));eq(s.energy,upgraded and 6 or 5);eq(s.player.statuses.energized,nil)
  assert(Combat.endTurn(s));eq(s.energy,3)
 end)
 test("Dodge and Roll captures original modified block for next turn "..tostring(upgraded),function()
  local s,card=fresh("dodge_and_roll",upgraded,{{cardId="footwork",upgraded=true}})
  Actors.addStatus(s.player,"dexterity",2)
  assert(Combat.play(s,card.uid));eq(s.player.block,upgraded and 8 or 6)
  local footwork;for _,c in ipairs(s.hand)do if c.cardId=="footwork"then footwork=c end end
  assert(Combat.play(s,footwork.uid));eq(s.player.statuses.dexterity,5)
  assert(Combat.endTurn(s));eq(s.player.block,upgraded and 8 or 6)
  eq(s.player.statuses.next_turn_block,nil)
  assert(Combat.endTurn(s));eq(s.player.block,0)
 end)
 test("Grand Finale uses empty draw pile, independently of nonempty discard "..tostring(upgraded),function()
  local s,card=fresh("grand_finale",upgraded,{"defend"},true)
  local defend;for _,c in ipairs(s.hand)do if c.cardId=="defend"then defend=c end end
  assert(require("abyss_discard").manualDiscard(s,defend.uid,Combat));eq(#s.draw,0);eq(#s.discard,1)
  assert(Combat.play(s,card.uid));eq(s.energy,3)
  for _,e in ipairs(s.enemies)do eq(e.hp,300-(upgraded and 60 or 50))end
 end)
end
test("Grand Finale with a nonempty draw pile is rejected before mutation",function()
 local extra={};for _=1,8 do extra[#extra+1]="defend"end
 local s,card=fresh("grand_finale",false,extra);assert(#s.draw>0)
 local seed,energy,events=s.seed,s.energy,#s.events
 local ok,reason=Combat.canPlay(s,card.uid);eq(ok,false);eq(reason,"requires_empty_draw_pile")
 ok,reason=Combat.play(s,card.uid);eq(ok,false);eq(reason,"requires_empty_draw_pile")
 eq(s.seed,seed);eq(s.energy,energy);eq(#s.events,events);eq(#s.hand,5)
end)
test("final killing Heel Hook cancels both energy and draw tails",function()
 local extra={};for _=1,8 do extra[#extra+1]="defend"end
 local s,card=fresh("heel_hook",false,extra);s.enemies[1].hp=5;Actors.addStatus(s.enemies[1],"weak",1)
 local draw=#s.draw;assert(Combat.play(s,card.uid,1));eq(s.phase,"victory");eq(s.energy,2);eq(#s.draw,draw)
end)
test("final killing Flying Knee does not leave an Energized buff",function()
 local s,card=fresh("flying_knee",false);s.enemies[1].hp=8
 assert(Combat.play(s,card.uid,1));eq(s.phase,"victory");eq(s.player.statuses.energized,nil)
end)
test("Heel Hook energy refund remains with NoDraw while draw is blocked",function()
 local extra={};for _=1,8 do extra[#extra+1]="defend"end
 local s,card=fresh("heel_hook",false,extra);s.player.noDraw=true;Actors.addStatus(s.enemies[1],"weak",1)
 local draw=#s.draw;assert(Combat.play(s,card.uid,1));eq(s.energy,3);eq(#s.draw,draw)
end)
for _,mode in ipairs({"normal","artifact","blocked"})do
 test("Bane checks poison after the first real Envenom hit: "..mode,function()
  local d=Cards.withCardDefinitions(require("abyss_card_triggers").withCards(Silent.withFoundationCards(data),"silent"))
  local s=Combat.new(d,{deck={{cardId="envenom",upgraded=true},"bane"},enemies={"jaw_worm"},seed=42})
  s.enemies[1].hp,s.enemies[1].maxHp=300,300
  local envenom,bane
  for _,c in ipairs(s.hand)do if c.cardId=="envenom"then envenom=c else bane=c end end
  assert(Combat.play(s,envenom.uid));eq(s.enemies[1].statuses.poison or 0,0)
  if mode=="artifact"then Actors.addStatus(s.enemies[1],"artifact",1)
  elseif mode=="blocked"then s.enemies[1].block=7 end
  assert(Combat.play(s,bane.uid,1))
  if mode=="normal"then eq(s.enemies[1].hp,286);eq(s.enemies[1].statuses.poison,2);eq(damageHits(s),2)
  elseif mode=="artifact"then eq(s.enemies[1].hp,293);eq(s.enemies[1].statuses.poison or 0,0)
   eq(s.enemies[1].statuses.artifact,0);eq(damageHits(s),1)
  else eq(s.enemies[1].hp,300);eq(s.enemies[1].statuses.poison or 0,0);eq(damageHits(s),1)end
 end)
end
print("SILENT_ATTACK_BUILD_PASS "..count)
