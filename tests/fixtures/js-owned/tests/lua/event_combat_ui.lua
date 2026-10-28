package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
-- Controlled chapter/event IDs, a late rare queue and explicit zero enemy HP
-- isolate native host wiring. This is not a natural route or live UI evidence.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map=require('abyss_run'),require('abyss_map')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS event combat UI '..count..' - '..name)end
local function get(root,path)
 local control=root;for part in path:gmatch('[^/]+')do control=assert(control:GetChild(part),path)end;return control
end
local function fixture(id)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{
  seed=42,prologue=false,campaign=true,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
 root.ui=host;assert(host:start())
 local run=host.run
 -- Stage only completed prior chapters; the public transition owns source
 -- queues and map-birth context. This remains controlled, not natural play.
 while run.act<3 do
  local floor=run.act*17
  run.phase,run.pendingAct,run.floor='act_transition',run.act+1,floor
  run.nodeFlow={floor=floor,complete=true,roomKind='boss_treasure',result='boss_treasure_complete'}
  assert(Run.advanceAct(run))
 end
 run.relicPool.queues.rare={'TungstenRod'} -- controlled source queue; no identity reroll.
 -- Existing explicit event-content input isolates UI behavior. Never change a
 -- generated node's type/id to manufacture the requested room.
 assert(run.data~=F.Data and run.data.rules~=F.Data.rules and run.data.rules.events~=F.Data.rules.events,
  'controlled event selection requires a private Run data owner')
 local originalEvent=F.Data.rules.events.encounterId
 run.data.rules.events.encounterId=id
 assert(F.Data.rules.events.encounterId==originalEvent,'event fixture must not change shared source data')
 local map=Map.generate(run.data,run.runSeed,3,assert(Run.mapContext(run)))
 local first
 while not first do
  local available=Map.available(map);assert(#available>0,'canonical event route missing')
  for _,node in ipairs(available)do if node.type=='event' then first=node;break end end
  if not first then assert(Map.choose(map,available[1].id))end
 end
 run.floor=map.floor
 assert(F.Nodes.restoreMap(run,map),'event UI must retain the canonical chapter map')
 host.map,host.mapUI.map,host.nodeUI.map=map,map,map
 host:refresh();assert(host.mode=='map'and get(root,'mapPanel').visible)
 assert(host.mapUI:choose(first.id))
 assert(host.mode=='node'and run.phase=='node'and get(root,'nodePanel/eventView').visible)
 assert(run.nodeFlow.id==first.id and run.nodeFlow.type=='event' and run.nodeFlow.event.id==id)
 return host,root,run,map
end
local function option(root,index)return get(root,'nodePanel/eventView/option'..index)end
local function tapOption(root,index)return F.click(root,'nodePanel','eventView/option'..index)end
local function owns(run,id)for _,held in ipairs(run.relics)do if held==id then return true end end;return false end

test('Sphere enters real host two-stage controls and reward buttons return to the same map',function()
 local host,root,run,map=fixture('mysterious_sphere')
 assert(get(root,'nodePanel/eventView/name').text=='神秘球体')
 assert(get(option(root,1),'title').text:find('打开容器',1,true))
 assert(get(option(root,2),'title').text:find('离开',1,true))
 assert(not get(root,'battlePanel').visible and not run.combat)
 local originalPrepared=run.nodeFlow.event.preparedCombat
 assert(originalPrepared.prepared.monsterHpRng.counter==4)
 local stale=host.nodeUI.actions['eventView/option1'].handler
 assert(tapOption(root,1));assert(run.nodeFlow.event.stage=='pre_combat'and host.mode=='node')
 assert(get(option(root,1),'title').text:find('战斗',1,true));assert(not option(root,2).visible)
 local preparedBeforeExit=run.nodeFlow.event.preparedCombat
 assert(preparedBeforeExit.prepared.monsterHpRng.counter==4)
 for i,actor in ipairs(originalPrepared.prepared.actors)do
  assert(preparedBeforeExit.prepared.actors[i].hp==actor.hp,'opening the Sphere must retain constructor HP')
 end
 assert(not stale(),'retired Open callback must not start combat')
 assert(host:openExit());assert(not host.nodeUI:press('eventView/option1'))
 assert(not run.combat and run.nodeFlow.event.preparedCombat==preparedBeforeExit)
 assert(host:closeExit());assert(tapOption(root,1))
 assert(run.phase=='combat'and host.mode=='battle'and host.battleUI.active)
 assert(get(root,'battlePanel').visible and not get(root,'nodePanel').visible)
 assert(#run.combat.enemies==2 and run.combat.monsterHpRng.counter==4)
 assert(host.battleUI.run==run and host.nodeUI.run==run)
 local deck,gold,relics=#run.deck,run.gold,#run.relics
 -- Controlled lethal boundary; use the real bound End Turn command to publish
 -- victory and the real reward view rather than fabricating a reward table.
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 F.click(root,'battlePanel','endTurn')
 assert(run.phase=='reward'and host.mode=='battle'and not host.battleUI.busy)
 assert(host.battleUI.rewardScreen=='list'and get(root,'battlePanel/rewardList').visible)
 assert(get(root,'battlePanel/goldReward').visible)
 assert(get(root,'battlePanel/potionHelp/relicReward1').visible)
 local rewardGold=run.rewards.gold
 F.click(root,'battlePanel','goldReward');assert(run.rewards.goldClaimed and run.gold==gold+rewardGold)
 F.click(root,'battlePanel','potionHelp/relicReward1')
 assert(run.rewards.relics[1].claimed and #run.relics==relics+1 and owns(run,'tungsten_rod'))
 assert(not get(root,'battlePanel/potionHelp/relicReward1').visible)
 F.click(root,'battlePanel','cardReward')
 assert(host.battleUI.rewardScreen=='cards'and get(root,'battlePanel/rewardStage').visible)
 F.click(root,'battlePanel','card1')
 assert(run.rewards.cardResolved and #run.deck==deck+1 and host.battleUI.rewardScreen=='list')
 F.click(root,'battlePanel','continue')
 assert(run.phase=='map'and host.mode=='map'and run.nodeFlow.complete and run.nodeFlow.result=='victory')
 assert(host.map==map and host.mapUI.map==map and get(root,'mapPanel').visible)
 assert(not get(root,'battlePanel').visible and not get(root,'nodePanel').visible)
 assert(#Map.available(map)>0 and not run.pendingAct,'event Boss actors cannot trigger chapter completion')
end)

test('MindBloom Awake shows real Mark result and a single Leave returns to map',function()
 local host,root,run,map=fixture('mind_bloom')
 assert(get(root,'nodePanel/eventView/name').text=='心灵绽放')
 assert(get(option(root,1),'title').text:find('挑战首领',1,true))
 assert(get(option(root,2),'title').text:find('全部升级',1,true))
 assert(option(root,3).visible and not run.combat)
 local deck=#run.deck;local uids={};for _,card in ipairs(run.deck)do uids[#uids+1]=card.uid end
 assert(tapOption(root,2));assert(host.mode=='node'and run.phase=='node'and run.nodeFlow.event.stage=='result')
 assert(#run.deck==deck and owns(run,'mark_of_bloom'))
 for i,card in ipairs(run.deck)do assert(card.uid==uids[i]and card.upgraded and card.upgrades==1)end
 local markName;for _,relic in ipairs(run.data.relics.relics)do if relic.id=='mark_of_bloom'then markName=relic.name end end
 assert(markName and get(root,'nodePanel/eventView/body').text:find(markName,1,true))
 assert(get(root,'nodePanel/eventView/body').text:find('获得遗物',1,true))
 assert(get(option(root,1),'title').text:find('离开',1,true))
 assert(not option(root,2).visible and not option(root,3).visible)
 local hp=run.hp;assert(Run.heal(run,80)==0 and run.hp==hp)
 assert(tapOption(root,1));assert(host.mode=='map'and run.phase=='map'and run.nodeFlow.complete)
 assert(host.map==map and get(root,'mapPanel').visible and not get(root,'nodePanel').visible)
end)

test('MindBloom Fight switches directly to a live Boss battle without another event menu',function()
 local host,root,run=fixture('mind_bloom')
 local old=host.nodeUI.actions['eventView/option1'].handler
 assert(tapOption(root,1))
 assert(run.phase=='combat'and host.mode=='battle'and host.battleUI.active)
 assert(get(root,'battlePanel').visible and not get(root,'nodePanel').visible)
 assert(run.encounterTier=='normal'and run.eventCombat.eventId=='mind_bloom')
 assert(run.combat.catalog.enemies[run.combat.enemies[1].definitionId].tier=='boss')
 assert(host.nodeUI.run==run and host.battleUI.run==run)
 assert(not old(),'retired event Fight callback must not duplicate the encounter')
 assert(#run.relicPool.queues.rare==0 and not run.rewards)
end)
print('EVENT_COMBAT_UI_PASS '..count..' real host/native controls; controlled chapter/queue/lethal fixtures, not natural or live acceptance')
