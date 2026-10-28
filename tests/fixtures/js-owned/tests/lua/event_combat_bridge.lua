local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
local Run,Nodes,C,R=F.Run,F.Nodes,F.C,F.R
assert(type(Run.prepareEventEncounter)=='function','missing real event constructor boundary')
assert(type(Run.startEventCombat)=='function','missing real EventRoom combat entry')
local function fixture(id)
 local run,map,nodeId=F.fixture()
 for _,node in ipairs(map.nodes)do if node.id==nodeId then node.eventId=id end end
 -- A controlled late-run queue: preceding rare identities have been spent.
 -- Keep the original source catalog and use the real queue selector.
 run.relicPool.queues.rare={'TungstenRod'}
 return run,map,nodeId
end
local function enter(id)
 local run,map,nodeId=fixture(id)
 assert(Nodes.enter(run,map,nodeId));return run,map
end
local function sphere()
 local run,map=enter('mysterious_sphere')
 assert(Nodes.chooseEvent(run,'open'));return run,map
end
local function finish(run)
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 assert(Run.finishCombat(run));assert(run.phase=='reward')
end
local function owned(run,id)for _,held in ipairs(run.relics)do if held==id then return true end end;return false end

do
 local run,map=enter('mysterious_sphere')
 local prepared=run.nodeFlow.event.preparedCombat
 assert(prepared.source=='2 Orb Walkers' and prepared.floor==35)
 assert(prepared.prepared.monsterHpRng.counter==4)
 assert(#prepared.prepared.actors==2 and not run.combat)
 assert(prepared.prepared.actors[1].intentRoll==nil)
 assert(Nodes.chooseEvent(run,'leave'));assert(run.phase=='node')
 assert(Nodes.chooseEvent(run,'leave'));assert(run.phase=='map' and run.nodeFlow.complete)
 assert(run.nodeFlow.event.preparedCombat.prepared.monsterHpRng.counter==4)
 assert(#Nodes.available(run,map)>0)
end
do
 local run,map=sphere();local queue=F.Q.snapshot(run.encounters)
 local misc=R.cloneState(run.miscRng);local gold=R.randomIntBetween(misc,45,55)
 local heldGold=run.gold;local heldRelics=#run.relics
 local card=R.snapshot(run.cardRng);local potion=run.shopRng and R.snapshot(run.shopRng.potion)
 assert(Nodes.chooseEvent(run,'fight'))
 assert(run.phase=='combat' and run.nodeFlow.type=='event' and run.nodeFlow.eventCombat)
 assert(run.combat.monsterHpRng.counter==4 and #run.combat.enemies==2)
 assert(run.encounterTier=='normal' and run.encounterSource=='2 Orb Walkers')
 assert(run.gold==heldGold and #run.relics==heldRelics and #run.relicPool.queues.rare==0)
 F.same(R.snapshot(run.miscRng),R.snapshot(misc));F.same(F.Q.snapshot(run.encounters),queue)
 F.same(R.snapshot(run.cardRng),card);F.same(run.shopRng and R.snapshot(run.shopRng.potion),potion)
 local wrong,why=Nodes.chooseEvent(run,'fight');assert(not wrong and why=='wrong_node_type')
 local Gold=require('abyss_gold_rewards');local oldGold=Gold.prepare
 Gold.prepare=function()error('event may not roll ordinary combat gold')end
 local Potion,Card=require('abyss_potion_rewards'),require('abyss_card_pool')
 local oldPotion,oldCard=Potion.prepare,Card.prepareRewards;local order={}
 Potion.prepare=function(...)order[#order+1]='potion';return oldPotion(...)end
 Card.prepareRewards=function(...)order[#order+1]='cards';return oldCard(...)end
 finish(run);Gold.prepare=oldGold;Potion.prepare=oldPotion;Card.prepareRewards=oldCard
 assert(table.concat(order,',')=='potion,cards')
 assert(run.rewards.gold==gold and #run.rewards.relics==1 and #run.rewards.cards==3)
 assert(run.gold==heldGold and not owned(run,'tungsten_rod'))
 assert(Run.claimGoldReward(run));assert(run.gold==heldGold+gold)
 assert(Run.claimRelicReward(run,1));assert(owned(run,'tungsten_rod'))
 assert(not Run.claimRelicReward(run,1))
 assert(Run.claimCardReward(run,0));assert(Run.leaveCombatRewards(run))
 assert(Nodes.completeCombat(run,map));assert(run.nodeFlow.complete and run.nodeFlow.result=='victory')
 assert(run.phase=='map' and not run.pendingAct and not Nodes.completeCombat(run,map))
 local nextId=F.Map.available(map)[1].id
 for _,node in ipairs(map.nodes)do if node.id==nextId then node.type,node.eventId='combat',nil end end
 assert(Nodes.enter(run,map,nextId));assert(not run.eventCombat,'normal room must replace the prior event owner')
 finish(run);assert(run.rewards.cards and run.victories==2)
end
do
 local run,map=sphere();local snapshot=C.copy(run,{[run.data]=run.data})
 local flow,deck,prepared=run.nodeFlow,run.deck,run.nodeFlow.event.preparedCombat
 local original,reached=C.new,false
 C.new=function(...)original(...);reached=true;error('late event battle setup fault')end
 local ok=Nodes.chooseEvent(run,'fight');C.new=original
 assert(not ok and reached);F.same(run,snapshot)
 assert(run.nodeFlow==flow and run.deck==deck and run.nodeFlow.event.preparedCombat==prepared)
 assert(Nodes.chooseEvent(run,'fight'));assert(run.combat.monsterHpRng.counter==4)
 assert(not Nodes.completeCombat(run,map))
end
do
 local run=enter('mind_bloom');local queue=F.Q.snapshot(run.encounters)
 assert(Nodes.chooseEvent(run,'fight'))
 assert(run.phase=='combat' and run.nodeFlow.type=='event' and run.encounterTier=='normal')
 assert(run.encounterSource=='The Guardian' or run.encounterSource=='Hexaghost' or run.encounterSource=='Slime Boss')
 F.same(F.Q.snapshot(run.encounters),queue)
 finish(run);assert(run.rewards.gold==50 and #run.rewards.relics==1)
end
do
 local run=sphere();assert(Nodes.chooseEvent(run,'fight'))
 local snapshot=C.copy(run,{[run.data]=run.data})
 local Potion=require('abyss_potion_rewards');local old=Potion.prepare
 Potion.prepare=function()error('late event reward fault')end
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 snapshot=C.copy(run,{[run.data]=run.data})
 local called,ok=pcall(Run.finishCombat,run);Potion.prepare=old
 assert(not called or not ok);F.same(run,snapshot)
 assert(Run.finishCombat(run))
end
do
 local run=sphere();assert(Nodes.chooseEvent(run,'fight'))
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 local card,battle=run.deck[1],run.combat
 battle.masterDeckChanges={[card.uid]=C.copy(card)}
 battle.masterDeckChanges[card.uid].upgraded=true
 local snapshot=C.copy(run,{[run.data]=run.data})
 local W=require('abyss_writhing_mass');local old=W.syncMaster
 W.syncMaster=function()error('late permanent sync fault')end
 local called,ok=pcall(Run.finishCombat,run);W.syncMaster=old
 assert(not called or not ok);F.same(run,snapshot)
 assert(run.deck[1]==card and run.combat==battle)
 assert(Run.finishCombat(run)and card.upgraded)
end
do
 local run,map=sphere();run.hp=30;run.potions[1]='smoke_bomb'
 assert(Nodes.chooseEvent(run,'fight'))
 local gold,victories,card=run.gold,run.victories,R.snapshot(run.cardRng)
 local Potion,Card=require('abyss_potion_rewards'),require('abyss_card_pool')
 local oldPotion,oldCard=Potion.prepare,Card.prepareRewards;local calls=0
 Potion.prepare=function(owner,count,context)
  calls=calls+1;assert(count==2 and context.allEscaped==false)
  return oldPotion(owner,count,context)
 end
 Card.prepareRewards=function()error('smoke must not create event card rewards')end
 local used,why=Run.usePotion(run,1);Potion.prepare=oldPotion;Card.prepareRewards=oldCard
 assert(used,why)
 assert(run.hp==36,'event smoke must run combat-end healing')
 assert(calls==1 and run.shopRng and run.potionChanceModifier~=0)
 F.same(R.snapshot(run.cardRng),card)
 assert(run.gold==gold and run.victories==victories and #run.relicPool.queues.rare==0)
 assert(run.phase=='map'and not run.rewards and not run.pendingCombatRewards and run.lastResult.outcome=='escaped')
 assert(not run.eventCombat,'escape must release the completed event combat owner')
 assert(not Run.claimGoldReward(run)and not Run.claimRelicReward(run,1))
 assert(Nodes.completeCombat(run,map));assert(run.nodeFlow.result=='escaped')
end
do
 local run=enter('mind_bloom');run.potions[1]='smoke_bomb';assert(Nodes.chooseEvent(run,'fight'))
 local used,why=Run.usePotion(run,1)
 assert(not used and why=='smoke_not_allowed'and run.potions[1]=='smoke_bomb')
end
do
 local run=sphere();assert(Run.obtainRelic(run,'golden_idol'))
 local misc=R.cloneState(run.miscRng);local base=R.randomIntBetween(misc,45,55)
 assert(Nodes.chooseEvent(run,'fight'))
 local frozen=base+math.floor(base*.25+.5);assert(run.eventCombat.gold==frozen)
 for i,id in ipairs(run.relics)do if id=='golden_idol'then table.remove(run.relics,i);break end end
 finish(run);local gold=run.gold;assert(run.rewards.gold==frozen)
 assert(Run.claimGoldReward(run));assert(run.gold==gold+frozen)
end
do
 local run=sphere();run.hp=30;run.potions[1]='smoke_bomb';assert(Nodes.chooseEvent(run,'fight'))
 local snapshot=C.copy(run,{[run.data]=run.data});local battle,flow=run.combat,run.nodeFlow
 local Potion=require('abyss_potion_rewards');local old=Potion.prepare
 Potion.prepare=function()error('late smoke potion fault')end
 local ok,why=Run.usePotion(run,1);Potion.prepare=old
 assert(not ok and why=='potion_effect_failed');F.same(run,snapshot)
 assert(run.combat==battle and run.nodeFlow==flow);assert(Run.usePotion(run,1))
end
do
 local run,map=fixture('cleric');run.hp=30;assert(Run.obtainRelic(run,'mark_of_bloom'))
 assert(Nodes.enter(run,map,'not-an-event-node')==false) -- invalid command stays rejected
 local id=F.Map.available(map)[1].id;assert(Nodes.enter(run,map,id))
 local view=Nodes.view(run,map);assert(view.node.event.heal==0)
 local options=Nodes.eventOptions(run,run.nodeFlow);assert(options[1].description:find('回复 0',1,true))
 local gold=run.gold;assert(Nodes.chooseEvent(run,'heal'));assert(run.hp==30 and run.gold<gold)
end
do
 local run,map=enter('mind_bloom');run.hp=30;assert(Nodes.chooseEvent(run,'awake'))
 assert(owned(run,'mark_of_bloom')and Run.heal(run,80)==0)
 assert(Nodes.chooseEvent(run,'leave'))
 local nextId=F.Map.available(map)[1].id
 for _,node in ipairs(map.nodes)do if node.id==nextId then node.type,node.eventId='event','mysterious_sphere'end end
 assert(Nodes.enter(run,map,nextId));assert(Nodes.chooseEvent(run,'open'));assert(Nodes.chooseEvent(run,'fight'))
 finish(run);assert(run.hp==30,'Mark must also block combat-end relic healing')
end
print('EVENT_COMBAT_BRIDGE_PASS constructor ownership, EventRoom rewards, rollback, smoke and Mark healing')
