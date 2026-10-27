local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua');local eq,same,Run,Nodes,C=F.eq,F.same,F.Run,F.Nodes,F.C
local A=require('abyss_actor')
local function acquire(bagFirst,seed)
 local r,m,n=F.fixture(0,seed)
 if bagFirst==true then assert(Run.obtainRelic(r,'bag_of_marbles'))end
 assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'pay'));assert(Nodes.chooseEvent(r,'leave'))
 if bagFirst==false then assert(Run.obtainRelic(r,'bag_of_marbles'))end
 return r,m
end
local function nextBattle(r,m)
 local n=F.Map.available(m)[1];assert(n)
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='combat';v.eventId=nil;v.roomKind=nil end end
 assert(Nodes.enter(r,m,n.id));return r.combat
end
for _,bagFirst in ipairs({false,true})do
 local r,m=acquire(bagFirst);local control,cm=C.copy(r),C.copy(m)
 -- Negative control removes only the tested relic; same legal source room,
 -- permanent deck and streams. This is not another acquisition claim.
 for i,id in ipairs(control.relics)do if id=='red_mask'then table.remove(control.relics,i);break end end
 local original=C.new
 C.new=function(...)
  local s=original(...);A.applyPower(s,s.enemies[1],'artifact',1,s.enemies[1]);return s
 end
 local called,s=pcall(nextBattle,r,m);local calledControl,t=pcall(nextBattle,control,cm);C.new=original
 assert(called,s);assert(calledControl,t);eq(s.enemies[1].definitionId,'orb_walker')
 local e=s.enemies[1];eq(e.statuses.artifact,0)
 if bagFirst then eq(e.statuses.weak,1);eq(e.statuses.vulnerable,nil)
 else eq(e.statuses.weak,nil);eq(e.statuses.vulnerable,1)end
 same(s.hand,t.hand)
 for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng','miscRng'})do same(F.R.snapshot(s[key]),F.R.snapshot(t[key]))end
 local opened,weak,vulnerable=0
 for i,event in ipairs(s.events)do
  if event.kind=='player_turn'then opened=i end
  if event.kind=='status'and event.detail.target==e.id then
   if event.detail.status=='weak'then weak=i elseif event.detail.status=='vulnerable'then vulnerable=i end
  end
 end
 local applied=weak or vulnerable
 assert(opened>0 and applied>opened,'BOTTOM applications must follow ordinary opening draw/player-turn frame')
 eq(#s.events[applied].frame.hand,s.rules.player.drawPerTurn)
 if weak then eq(e.weakJustApplied,nil)end
 print('PASS actual Tomb obtain/BOTTOM held order/Artifact/ordinary draw and independent stream invariance bagFirst='..tostring(bagFirst))
end
do
 local r,m=acquire(nil,'9');local s=nextBattle(r,m);local e=s.enemies[1];eq(e.definitionId,'orb_walker');eq(e.statuses.weak,1)
 local base;for _,effect in ipairs(e.intents[e.intentIndex].effects)do if effect.op=='damage'then base=effect.value end end;assert(base)
 local hp=s.player.hp;assert(Run.endTurn(r));eq(s.player.hp,hp-math.floor(base*.75));eq(e.statuses.weak or 0,0)
 e.hp=1;assert(Run.obtainPotion(r,'fire_potion'));assert(Run.usePotion(r,1,1));eq(r.phase,'reward')
 assert(Run.leaveCombatRewards(r));assert(Nodes.completeCombat(r,m))
 local t=nextBattle(r,m);assert(t~=s);eq(#t.enemies,3)
 for _,enemy in ipairs(t.enemies)do eq(enemy.statuses.weak,1);eq(enemy.weakJustApplied,nil)end
 print('PASS same event-acquired mask weakens first real attack then expires, persists through rewards and weakens every second-room enemy')
end
print('TOMB_RED_MASK_OPENING_PASS 3; enemy Artifact and terminal HP are explicit effect boundaries, not natural campaign evidence')
