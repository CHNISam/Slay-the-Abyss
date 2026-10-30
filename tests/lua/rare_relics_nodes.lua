local Run,Nodes,Map,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local D=require('abyss_data')
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS rare node '..name)end
local function fixture(ids)
 local r,m=Run.new(D,42),Map.generate(D,42)
 for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id))end
 local first=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='camp'end end
 assert(Nodes.enter(r,m,first.id));return r,m
end
test('Girya uses one camp action and grants its accumulated battle strength',function()
 local r,m=fixture({'Girya'});assert(Nodes.lift(r));assert(r.relicCounters.girya==1 and r.phase=='map')
 assert(not Nodes.rest(r));assert(not Nodes.lift(r));assert(Run.startCombat(r,'cultist_solo'))
 assert(r.combat.player.statuses.strength==1)
end)
test('Peace Pipe removes a chosen permanent UID and excludes bottled cards',function()
 local r=fixture({'Peace Pipe'});local uid=r.deck[1].uid;local n=#r.deck
 r.deck[1].inBottleFlame=true
 assert(not Nodes.toke(r,uid));assert(not Nodes.toke(r,-1));assert(#r.deck==n)
 r.deck[1].inBottleFlame=nil;assert(Nodes.toke(r,uid));assert(#r.deck==n-1 and r.phase=='map')
 assert(not Nodes.toke(r,r.deck[1].uid))
end)
test('Shovel consumes one source rarity draw and offers an actual optional relic',function()
 local r=fixture({'Shovel'});local n=#r.relics
 assert(Nodes.dig(r));local offer=assert(r.nodeFlow.digReward);assert(offer.sourceId and offer.trace)
 assert(not Nodes.dig(r));assert(not Nodes.rest(r));assert(#r.relics==n)
 assert(Nodes.claimDigReward(r,true));assert(#r.relics==n+1 and r.relics[#r.relics]==offer.id)
 assert(not Nodes.claimDigReward(r,true))
 local skip=fixture({'Shovel'});assert(Nodes.dig(skip));local total=#skip.relics
 assert(Nodes.claimDigReward(skip,false));assert(#skip.relics==total and skip.phase=='map')
end)
test('Winged Greaves advertises next row and consumes only committed off-path entry',function()
 local r,m=fixture({'WingedGreaves'});assert(Nodes.rest(r));local normal={}
 for _,node in ipairs(Map.available(m))do normal[node.id]=true end
 local off
 for _,node in ipairs(Nodes.available(r,m))do if not normal[node.id]then off=node;break end end
 assert(off,'source seed needs an off-path next-row node')
 local before=r.relicCounters.winged_greaves
 Nodes.view(r,m);Nodes.available(r,m);assert(r.relicCounters.winged_greaves==before)
 assert(not Nodes.enter(r,m,'invalid'));assert(r.relicCounters.winged_greaves==before)
 for _,node in ipairs(m.nodes)do if node.id==off.id then node.type='camp'end end
 assert(Nodes.enter(r,m,off.id));assert(r.relicCounters.winged_greaves==before-1)
 assert(m.wingedJumps and m.wingedJumps[1]==2)
end)
test('Map restoration replays a legal Winged Greaves path without inventory mutation',function()
 local m=Map.generate(D,42);assert(Map.choose(m,Map.available(m)[1].id))
 local normal={};for _,n in ipairs(Map.available(m))do normal[n.id]=true end
 local target;for _,n in ipairs(Map.available(m,true))do if not normal[n.id]then target=n.id;break end end
 assert(target and Map.choose(m,target,true));local restored,why=Map.restore(D,Map.snapshot(m));assert(restored,why)
 assert(restored.currentNodeId==target and restored.wingedJumps[1]==2)
 local invalid=C.copy(m);invalid.wingedJumps={1};assert(not Map.restore(D,invalid))
end)
print('RARE_RELICS_NODES_PASS '..passed)
