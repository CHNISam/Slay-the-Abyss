package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Map,Nodes,Pool=require('abyss_run'),require('abyss_combat'),require('abyss_map'),require('abyss_nodes'),require('abyss_relic_pool')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
do
 local r=Run.new(Data,'5');eq(r.relicPool.queues.rare[1],'TungstenRod')
 local queue,first=r.relicPool.queues.rare,Pool.snapshot(r.relicPool)
 local offer,nextPool=Run.prepareRelic(r,{tier='rare'});assert(offer,nextPool)
 eq(offer.id,'tungsten_rod');eq(offer.sourceId,'TungstenRod');eq(#offer.trace,1)
 eq(#nextPool.queues.rare,#queue-1);eq(r.relicPool.queues.rare,queue);eq(queue[1],'TungstenRod')
 eq(Pool.snapshot(r.relicPool).rng.counter,first.rng.counter)
 assert(Run.obtainRelic(r,offer.id));eq(r.relics[#r.relics],'tungsten_rod')
 print('PASS seed5 complete source Rare queue selects exact first candidate once, no reroll/filter or premature mutation')
end
do
 local r,m=Run.new(Data,54),Map.generate(Data,54);local first=Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='treasure'end end
 assert(Nodes.enter(r,m,first.id));eq(r.nodeFlow.reward.relicId,'tungsten_rod');assert(Nodes.claimTreasure(r))
 eq(r.relics[#r.relics],'tungsten_rod');eq(r.phase,'map')
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;local hp=s.player.hp
 eq(C.damage(s,s.enemies[1],s.player,1,false),0);eq(s.player.hp,hp)
 print('PASS seed54 actual ordinary treasure chooses/claims Rare Rod and binds actual same-Run battle hook')
end
do
 local r,m=Run.new(Data,1),Map.generate(Data,1);local first=Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='shop'end end
 Run.gainGold(r,300);assert(Nodes.enter(r,m,first.id));local offer=r.nodeFlow.relics[2]
 eq(offer.id,'tungsten_rod');eq(offer.rarity,'rare');eq(offer.price,290);assert(not offer.unavailable)
 local gold=r.gold;assert(Nodes.buyRelic(r,'tungsten_rod'));eq(r.gold,gold-290);eq(r.relics[#r.relics],'tungsten_rod');assert(r.nodeFlow.relics[2].sold)
 print('PASS seed1 ordinary shop Rare shelf quote/purchase adds the actual relic; gold is an explicit purchase boundary')
end
print('TUNGSTEN_ROD_CHANNELS_PASS 3; source queue tier choice is explicit component evidence, treasure/shop are real acquire paths')
