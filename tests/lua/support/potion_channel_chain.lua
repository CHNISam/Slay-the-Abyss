-- Source-oracle composition. Shop positions and terminal enemy HP are controlled;
-- every stream commit, purchase, rejection, refill and potion use is production.
local Run,C,D,R,Shop,Nodes=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_shop'),require('abyss_nodes')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function checkPotion(run,item,record)
 eq(item.id,SOURCE_POTION_IDS[record.result.sourceId]);if item.sourceId then eq(item.sourceId,record.result.sourceId)end
 local rarity=item.rarity
 if not rarity then for _,d in ipairs(run.data.potions.potions)do if d.id==item.id then rarity=d.rarity end end end
 eq(rarity,record.result.rarity);eq(item.unavailable,false)
end
local function shop(run,records,offset)
 local stock=Shop.prepare(run)
 for i=1,3 do checkPotion(run,stock.potions[i],records[offset+i-1])end
 same(R.snapshot(stock.shopRng.potion),records[offset+2].after)
 stock.type='shop';run.phase='node';run.nodeFlow=stock
 run.shopRng,run.relicPool=stock.shopRng,stock.relicPool
 return stock
end
local function finish(run,record)
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 assert(Run.finishCombat(run))
 local p=run.rewards.potion;eq(p~=nil,record.result.dropped)
 if p then checkPotion(run,p,{result=record.result.potion});assert(Run.skipPotionReward(run))end
 same(R.snapshot(run.shopRng.potion),record.after);eq(run.potionChanceModifier,record.modifier)
 assert(Run.claimCardReward(run,0));dofile('tests/lua/support/finish_combat_rewards.lua')(run)
end
return function(case)
 local records=case.records
 local run=Run.new(D,case.seed,{experimental=true,campaign=true,campaignProfile='competition-two-act',character='ironclad'})
 assert(Run.obtainRelic(run,'The Courier'));run.gold=10000
 local flow=shop(run,records,1)
 -- Full belt failure must restore every owner, price, queue and resource before
 -- the same legal purchase performs exactly one Courier replacement sample.
 for _=1,3 do assert(Run.obtainPotion(run,'block_potion'))end
 local before=C.copy(run);eq(Nodes.buyPotion(run,1),false);same(run,before)
 assert(Run.discardPotion(run,2));local acquired=flow.potions[1].id
 assert(Nodes.buyPotion(run,1));eq(run.potions[2],acquired)
 checkPotion(run,run.nodeFlow.potions[1],records[4]);same(R.snapshot(run.shopRng.potion),records[4].after)
 assert(Nodes.leaveShop(run));for slot=1,3 do assert(Run.discardPotion(run,slot))end
 assert(Run.startRoomCombat(run,'normal'));finish(run,records[5])
 assert(Run.obtainPotion(run,'entropic_brew'));assert(Run.startCombat(run,'cultist_solo'))
 local card=R.snapshot(run.cardRng);local merchant=R.snapshot(run.shopRng.merchant)
 local beforeView=C.copy(run);Run.potionView(run);same(run,beforeView)
 assert(Run.usePotion(run,1));eq(Run.potionCount(run),3)
 for i=1,3 do checkPotion(run,run.lastPotionGeneration[i],records[5+i])end
 same(R.snapshot(run.shopRng.potion),records[8].after)
 same(R.snapshot(run.cardRng),card);same(R.snapshot(run.shopRng.merchant),merchant)
 -- Complete this controlled battle without another reward draw: Smoke escape
 -- has no potion-drop preparation, so the following merchant continues Entropic.
 for slot=1,3 do assert(Run.discardPotion(run,slot))end
 assert(Run.obtainPotion(run,'smoke_bomb'));assert(Run.usePotion(run,1));eq(run.phase,'map')
 same(R.snapshot(run.shopRng.potion),records[8].after)
 shop(run,records,9);assert(Nodes.leaveShop(run))
 assert(Run.startRoomCombat(run,'elite'));finish(run,records[12])
 print('POTION_CHANNEL_CHAIN_PASS '..case.seed)
end
