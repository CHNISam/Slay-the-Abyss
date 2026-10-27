local F=dofile('tests/lua/support/golden_idol_fixture.lua')
local fixture,eq,same,Run,Map,Nodes,C,R,P,D=F.fixture,F.eq,F.same,F.Run,F.Map,F.Nodes,F.C,F.R,F.P,F.D
local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));assert(Nodes.chooseEvent(r,'max_hp'));assert(Nodes.chooseEvent(r,'leave'))
local target;for _,node in ipairs(Map.available(m))do if node.type=='combat'then target=node;break end end;assert(target,'seed42 next source combat unavailable')
local G=require('abyss_gold_rewards');local raw,key,nextRng=G.prepare('normal',r);local previous=R.snapshot(r.treasureRng)
assert(Nodes.enter(r,m,target.id));assert(r.combat.roomSeed and r.encounterTier=='normal')
-- Actual starter deck, source enemies/HP/energy and normal commands; no kill fixture.
for _=1,30 do
 if r.phase~='combat'then break end
 for _=1,15 do
  if r.phase~='combat'then break end
  local uid;for _,card in ipairs(r.combat.hand)do if C.canPlay(r.combat,card.uid,1)then uid=card.uid;break end end
  if not uid then break end;assert(Run.play(r,uid,1))
 end
 if r.phase=='combat'then assert(Run.endTurn(r))end
end
eq(r.phase,'reward');local total=raw+math.floor(raw*.25+.5);eq(r.rewards.gold,total);eq(r.gold,99);same(R.snapshot(r.treasureRng),R.snapshot(nextRng));eq(r.treasureRng.counter,previous.counter+1)
local gold=r.gold;assert(Run.claimGoldReward(r));eq(r.gold,gold+total);eq(Run.claimGoldReward(r),false)
if r.rewards.potion and not r.rewards.potion.resolved then assert(Run.skipPotionReward(r))end
assert(Run.claimCardReward(r,0));assert(Run.leaveCombatRewards(r));assert(Nodes.completeCombat(r,m));eq(r.phase,'map')
-- Boundary jump isolates the already implemented Act3 event; same actual Idol
-- owner is carried, never obtained/injected again. This is not a full-campaign run.
local owned=r.relics;local cards=C.copy(r.deck);r.act,r.floor=3,34;r.nodeFlow=nil;r.path={};r.encounters=require('abyss_encounter_queue').new(r.runSeed,3);r.unknown.pools=P.new('full',false,3)
local act3=Map.generate(D,'42',3);local node=Map.available(act3)[1]
for _,v in ipairs(act3.nodes)do if v.id==node.id then v.type='event';v.eventId='moai_head'end end
local before=r.gold;assert(Nodes.enter(r,act3,node.id));assert(Nodes.view(r,act3).node.event.options[2].enabled);assert(Nodes.chooseEvent(r,'give_idol'));eq(r.gold,before+333)
for _,id in ipairs(r.relics)do assert(id~='golden_idol')end;same(r.deck,cards);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
print('GOLDEN_IDOL_CHANNELS_PASS actual event acquire -> real starter source battle/unchanged gold RNG/claim -> same-owner Moai333 sacrifice (Act3 boundary, not whole campaign)')
