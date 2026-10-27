package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Map,Nodes,Pool=require('abyss_run'),require('abyss_combat'),require('abyss_map'),require('abyss_nodes'),require('abyss_relic_pool')
local Data=require('abyss_data')
local R=require('abyss_sts_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function rodQueue(run,fromTail)
 -- Full-source component snapshot: no support filtering, pool exhaustion or
 -- natural-seed claim. Every other Rare identity stays in the same order.
 local snapshot=Pool.snapshot(run.relicPool);local before=snapshot.queues.rare
 local queue,found={},false
 for _,id in ipairs(before)do
  if id=='TungstenRod'then assert(not found);found=true else queue[#queue+1]=id end
 end
 assert(found and #queue==#before-1)
 if fromTail then queue[#queue+1]='TungstenRod'else table.insert(queue,1,'TungstenRod')end
 eq(#queue,#before);snapshot.queues.rare=queue
 run.relicPool=Pool.restore(snapshot,run.relicPool.catalog)
end
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
 local r,m=Run.new(Data,91),Map.generate(Data,91);local first=Map.available(m)[1]
 rodQueue(r,false)
 -- Keep run/map/stream seed91. Independent source oracle checkpoint58 gives
 -- constructor rolls52/93: Medium/Rare with no gold. This isolates the Rare
 -- obtain channel; seed91's first chest is Small/Uncommon (40/93).
 r.treasureRng=R.atCounter(r.eventSeed,58)
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='treasure'end end
 assert(Nodes.enter(r,m,first.id));eq(r.nodeFlow.chest.opened,false);eq(r.nodeFlow.reward.relicId,nil)
 eq(r.treasureRng.counter,60);assert(Nodes.openTreasure(r));eq(r.treasureRng.counter,60)
 eq(r.nodeFlow.chest.kindRoll,52);eq(r.nodeFlow.chest.rewardRoll,93)
 eq(r.nodeFlow.chest.relicTier,'rare');eq(r.nodeFlow.reward.relicId,'tungsten_rod');assert(Nodes.claimTreasure(r))
 eq(r.relics[#r.relics],'tungsten_rod');eq(r.phase,'map')
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;local hp=s.player.hp
 eq(C.damage(s,s.enemies[1],s.player,1,false),0);eq(s.player.hp,hp)
 print('PASS seed91 fixed source checkpoint actual ordinary treasure claims Rare Rod and binds same-Run battle hook')
end
do
 local r,m=Run.new(Data,2),Map.generate(Data,2);local first=Map.available(m)[1]
 rodQueue(r,true)
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='shop'end end
 Run.gainGold(r,300);assert(Nodes.enter(r,m,first.id));local offer=r.nodeFlow.relics[1]
 -- Independent merchant seed2: seven card-price floats, sale3, tier97;
 -- price multiplier .9998730421066284 gives round(float32(300*m))=300.
 -- The removed supported-pool index draw must not survive as an old302 quote.
 eq(offer.id,'tungsten_rod');eq(offer.rarity,'rare');eq(offer.price,300);assert(not offer.unavailable)
 local gold=r.gold;assert(Nodes.buyRelic(r,'tungsten_rod'));eq(r.gold,gold-300);eq(r.relics[#r.relics],'tungsten_rod');assert(r.nodeFlow.relics[1].sold)
 print('PASS seed2 ordinary shop Rare shelf quote/purchase adds the actual relic; gold is an explicit purchase boundary')
end
print('TUNGSTEN_ROD_CHANNELS_PASS 3; source queue tier choice is explicit component evidence, treasure/shop are real acquire paths')
