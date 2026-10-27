-- Controlled production-entry integration; not natural-acquisition evidence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C,Data=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_data')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('PASS permanent_nodes '..count..' '..name)end
local function fixture(kind,eventId)
 local r,m=Run.new(Data,42),Map.generate(Data,42);r.gold=500
 local first=Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type=kind;node.eventId=eventId end end
 assert(Nodes.enter(r,m,first.id));return r,m
end
test('card reward uses acquisition hooks and preserves its independent potion offer',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'CeramicFish'))
 r.phase='reward';r.rewards={cards={'strike'},cardResolved=false,potion={resolved=false}}
 local gold,n=r.gold,#r.deck;assert(Run.claimCardReward(r,1))
 eq(r.gold,gold+9);eq(#r.deck,n+1);eq(r.rewards.cardResolved,true);eq(r.rewards.potion.resolved,false)
 eq(Run.claimCardReward(r,1),false)
end)
test('Ectoplasm suppresses both gold reward types while resolving their offers',function()
 local r=Run.new(Data,42);r.relics[#r.relics+1]='ectoplasm'
 r.phase='reward';r.rewards={gold=25,goldClaimed=false,manualContinue=true,
  stolenGold={type='STOLEN_GOLD',amount=50,claimed=false}}
 local gold=r.gold;assert(Run.claimGoldReward(r));assert(Run.claimStolenGoldReward(r))
 eq(r.gold,gold);eq(r.rewards.goldClaimed,true);eq(r.rewards.stolenGold.claimed,true)
end)
test('a real shop purchase invokes card hooks after spending',function()
 local r=fixture('shop');assert(Run.obtainRelic(r,'CeramicFish'))
 local offer=r.nodeFlow.cards[1];offer.id='strike';offer.price=20;offer.unavailable=false
 local gold,n=r.gold,#r.deck;assert(Nodes.buyCardSlot(r,1))
 eq(r.gold,gold-20+9);eq(#r.deck,n+1);eq(r.nodeFlow.cards[1].sold,true)
end)
test('shop removal invokes Parasite and shop-spending hooks once',function()
 local r=fixture('shop');assert(Run.obtainRelic(r,'MawBank'))
 local ok,uid=Run.obtainCard(r,'parasite');assert(ok)
 assert(Nodes.removeCard(r,uid));eq(r.maxHp,77);eq(r.relicCounters.maw_bank,-2)
 local gold=r.gold;eq(Nodes.removeCard(r,uid),false);eq(r.gold,gold);eq(r.maxHp,77)
end)
test('shop and treasure relic grants initialize acquisition counters',function()
 local shop=fixture('shop');local offer=shop.nodeFlow.relics[1]
 offer.id='omamori';offer.price=20;offer.unavailable=false
 assert(Nodes.buyRelic(shop,'omamori'));eq(shop.relicCounters.omamori,2)
 local chest=fixture('treasure');assert(Nodes.openTreasure(chest))
 -- This acquisition-hook fixture explicitly adds an Omamori offer AFTER the
 -- real source chest has opened. Preserve every original identity and queue;
 -- the added test offer is not a claim of natural Omamori acquisition.
 local items,slot=chest.nodeFlow.reward.items,0
 for _,item in ipairs(items)do slot=math.max(slot,item.slot)end
 slot=slot+1
 items[#items+1]={slot=slot,kind='relic',id='omamori',sourceId='Omamori',available=true,origin='fixture'}
 local counter=chest.relicPool.rng.counter
 local token=assert(Nodes.treasureRewardSource(chest,slot))
 assert(Nodes.claimTreasureReward(chest,token));eq(chest.relicCounters.omamori,2)
 eq(chest.relicPool.rng.counter,counter)
 local uid=chest.nextDeckUid;assert(Run.obtainCard(chest,'regret'));eq(chest.nextDeckUid,uid)
end)
test('purification invokes the same permanent removal hook',function()
 local r=fixture('event','purifier');local ok,uid=Run.obtainCard(r,'parasite');assert(ok)
 assert(Nodes.chooseEvent(r,'pray',uid));eq(r.maxHp,77);eq(r.phase,'map')
end)
test('Golden Shrine freezes Omamori and resolves gold without allocating a blocked curse',function()
 local r=fixture('event','golden_shrine');assert(Run.obtainRelic(r,'Omamori'))
 local uid,gold=r.nextDeckUid,r.gold;assert(Nodes.chooseEvent(r,'desecrate'))
 eq(r.nextDeckUid,uid);eq(r.relicCounters.omamori,1)
 eq(r.gold,gold+r.data.rules.events.golden_shrine.curseGold);eq(r.nodeFlow.event.cursePrevented,true)
end)
test('failed acquisition rolls back the complete shop command',function()
 local r=fixture('shop');local offer=r.nodeFlow.cards[1]
 offer.id='missing_card';offer.price=20;offer.unavailable=false
 local gold,deck,flow=r.gold,r.deck,r.nodeFlow
 local ok=Nodes.buyCardSlot(r,1);eq(ok,false);eq(r.gold,gold);eq(r.deck,deck);eq(r.nodeFlow,flow)
end)
print('PERMANENT_NODE_HOOKS '..count..' passed')
