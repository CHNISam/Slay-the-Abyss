local Run,N,Map,D,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data'),require('abyss_combat')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local F=dofile('tests/lua/support/event_combat_route_fixture.lua')
-- Real EventRoom combat path; controlled room identity, not a natural route claim.
local r,map=F.event('42','colosseum');eq(r.scoreStats.mysteryRooms,1)
assert(not N.enter(r,map,map.currentNodeId));eq(r.scoreStats.mysteryRooms,1)
assert(Run.obtainPotion(r,'smoke_bomb'));assert(N.chooseEvent(r,'continue'));assert(N.chooseEvent(r,'fight'))
assert(Run.usePotion(r,1));eq(r.scoreStats.normalWins,0);eq(r.scoreStats.eliteWins[2],0);eq(r.scoreStats.champion,0)
assert(N.chooseEvent(r,'fight'));for _,e in ipairs(r.combat.enemies)do e.hp=0 end
assert(Run.finishCombat(r));eq(r.scoreStats.normalWins,0);eq(r.scoreStats.eliteWins[2],0);eq(r.scoreStats.champion,0)
-- Direct supported acquisitions use common gainGold, rather than inferring wallet.
r=Run.new(D,'42');assert(Run.obtainRelic(r,'Old Coin'));eq(r.scoreStats.goldGained,300)
assert(Run.obtainRelic(r,'CeramicFish'));assert(Run.obtainCard(r,'anger'));eq(r.scoreStats.goldGained,309)
-- A resolved original ? combat still counts a visit; normal non-? entry does not.
local seen=false
for seed=1,30 do
 r=Run.new(D,tostring(seed));map=Map.generate(D,tostring(seed));local id=N.available(r,map)[1].id;local node;for _,v in ipairs(map.nodes)do if v.id==id then node=v end end;node.type='event';node.eventId=nil
 if N.enter(r,map,node.id)then
  eq(r.scoreStats.mysteryRooms,1)
  if r.nodeFlow.type~='event'then seen=true;break end
 end
end
assert(seen,'fixture must exercise a resolved original question room')
r=Run.new(D,'42');map=Map.generate(D,'42');local id=N.available(r,map)[1].id;local node;for _,v in ipairs(map.nodes)do if v.id==id then node=v end end;node.type='event';node.eventId='invalid_event'
assert(not N.enter(r,map,node.id));eq(r.scoreStats.mysteryRooms,0)
-- Existing chapter API, controlled completed chapter boundary.
r=Run.new(D,'3',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
r.phase='act_transition';r.pendingAct=2;r.floor=17
r.nodeFlow={floor=17,complete=true,roomKind='boss_treasure',result='boss_treasure_complete'}
r.scoreStats.goldGained=1001;r.scoreStats.normalWins=9;r.scoreStats.mysteryRooms=5
local before=C.copy(r.scoreStats);assert(Run.advanceAct(r));F.same(r.scoreStats,before)
r.floor=24;assert(Run.startRoomCombat(r,'elite'));for _,e in ipairs(r.combat.enemies)do e.hp=0 end
assert(Run.finishCombat(r));eq(r.scoreStats.eliteWins[1],0);eq(r.scoreStats.eliteWins[2],1)
r.phase='map';r.floor=33;assert(Run.startRoomCombat(r,'boss'));for _,e in ipairs(r.combat.enemies)do e.hp=0 end
assert(Run.finishCombat(r));eq(r.scoreStats.bosses,1);eq(r.scoreStats.perfect,1);assert(not Run.finishCombat(r));eq(r.scoreStats.bosses,1)
print('PASS score original question/event combat/gold acquisitions/cross-act/boss')
