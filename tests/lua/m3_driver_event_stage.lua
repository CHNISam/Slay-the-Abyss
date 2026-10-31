-- Controlled real Nodes entry; inventory preconditions use permanent public APIs.
-- These event protocol tests do not claim natural event selection/acquisition.
local Run,Nodes,Map,D,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data'),require('abyss_combat')
local Policy=dofile('scripts/warrior75-autoplay-policy.lua')
local Select=dofile('scripts/m3-event-card-policy.lua')
local function same(a,b)
 assert(type(a)==type(b),'state type');if type(a)~='table'then assert(a==b,'state value');return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'state extra')end
end
local function fixture()
 local run=Run.new(D,'17',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
 local map=Map.generate(run.data,run.runSeed,1)
 local first=Nodes.available(run,map)[1]
 for _,node in ipairs(map.nodes)do if node.id==first.id then node.type,node.eventId='event','living_wall' end end
 assert(Nodes.enter(run,map,first.id));assert(run.nodeFlow.event.stage==nil)
 return run,map
end
local function option(run,name)
 for _,row in ipairs(Nodes.eventOptions(run,run.nodeFlow))do if row.choice==name then return row end end
 error('missing public option '..name)
end
local function uid(run,map,row)
 local before=C.copy({run=run,map=map});local result=Select.uid(run,map,row,Policy.scoreCard)
 same({run=run,map=map},before);return result
end
local function has(cards,selected)
 for _,card in ipairs(cards)do if card.uid==selected then return true end end;return false
end
local function reject(run,map,choice,selected,expected)
 local before=C.copy({run=run,map=map});local ok,why=Nodes.chooseEvent(run,choice,selected)
 assert(not ok and why==expected,tostring(why));same({run=run,map=map},before)
end
local function selectStage(run,map,name)
 local row=option(run,name)
 assert(row.picker=='living_'..name,'real public staged-picker descriptor')
 assert(uid(run,map,row)==nil,'initial staged picker must not submit UID before choose_card: '..name)
 assert(Nodes.chooseEvent(run,row.choice))
 assert(run.nodeFlow.event.stage=='choose_card'and run.nodeFlow.event.choice==name)
 return option(run,name)
end
for _,name in ipairs({'forget','change','grow'})do
 local run,map=fixture()
 if name=='grow'then
  -- Purge candidates include already-upgraded strikes; upgrade candidates do not.
  for _,card in ipairs(run.deck)do if card.cardId=='strike'then assert(Run.upgradeCard(run,card.uid))end end
 end
 local row=selectStage(run,map,name)
 local selected=uid(run,map,row);assert(type(selected)=='number')
 local view=Nodes.view(run,map).node
 assert(has(name=='grow'and view.upgradeCards or view.event.purgeCards,selected),'UID must come from the operation-specific public candidate group')
 local count,nextUid=#run.deck,run.nextDeckUid
 assert(Nodes.chooseEvent(run,name,selected))
 assert(run.nodeFlow.complete and run.phase=='map')
 if name=='grow'then
  assert(#run.deck==count);local found
  for _,card in ipairs(run.deck)do if card.uid==selected then found=card.upgraded end end;assert(found)
 elseif name=='forget'then assert(#run.deck==count-1 and not has(run.deck,selected))
 else assert(#run.deck==count and not has(run.deck,selected)and run.nextDeckUid==nextUid+1)end
 reject(run,map,name,selected,'no_pending_node')
 print('PASS driver staged public '..name)
end
local run,map=fixture()
local copy=C.copy(run.deck);for _,card in ipairs(copy)do assert(Run.removeCard(run,card.uid))end
assert(#run.deck==0)
local row=option(run,'forget');assert(not row.picker and uid(run,map,row)==nil)
assert(Nodes.chooseEvent(run,'forget'));assert(run.nodeFlow.complete and run.nodeFlow.event.empty)
print('PASS driver staged empty purge group completes without phantom UID')

local run,map=fixture()
assert(Run.obtainRelic(run,'Bottled Flame'))
local Pending=require('abyss_relic_pending');local view=assert(Pending.view(run));local bottle=view.rows[1].token
assert(Pending.resolve(run,bottle));local protected=bottle.uid
local row=selectStage(run,map,'forget')
local candidates=Nodes.view(run,map).node.event.purgeCards;assert(not has(candidates,protected))
local selected=uid(run,map,row);assert(selected and selected~=protected and has(candidates,selected))
reject(run,map,'forget',protected,'card_not_purgeable')
assert(Nodes.chooseEvent(run,'forget',selected));assert(has(run.deck,protected))
print('PASS driver staged purge excludes actual bottled UID and rejects stale selection atomically')

local run,map=fixture()
for _,card in ipairs(run.deck)do assert(Run.upgradeCard(run,card.uid))end
local row=option(run,'grow');assert(not row.enabled and #Nodes.view(run,map).node.upgradeCards==0)
assert(uid(run,map,row)==nil);reject(run,map,'grow',nil,'card_not_upgradeable')
print('PASS driver staged grow cannot fabricate an upgradeable UID')

local run,map=fixture()
local first=Nodes.view(run,map).node.event.purgeCards[1].uid
reject(run,map,'forget',first,'invalid_event_choice')
local row=selectStage(run,map,'forget');local selected=uid(run,map,row)
reject(run,map,'change',selected,'invalid_event_choice')
assert(Nodes.chooseEvent(run,'forget',selected))
print('PASS driver initial UID and mismatched staged operation reject without resource or RNG change')
print('M3_DRIVER_EVENT_STAGE_PASS 7')
