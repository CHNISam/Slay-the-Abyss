-- Controlled public event entry, unmodified starting inventory and rules.
-- This proves driver selection commands, not natural event selection/campaign.
local Run,Nodes,Map,D=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data')
local Policy=dofile('scripts/warrior75-autoplay-policy.lua')
local Select=dofile('scripts/m3-event-card-policy.lua')
local function fixture(id)
 local run=Run.new(D,'3',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
 local map=Map.generate(run.data,run.runSeed,1)
 local first=Nodes.available(run,map)[1]
 for _,node in ipairs(map.nodes)do if node.id==first.id then node.type,node.eventId='event',id end end
 assert(Nodes.enter(run,map,first.id));return run,map
end
local function option(run,choice)
 for _,row in ipairs(Nodes.eventOptions(run,run.nodeFlow))do if row.choice==choice then return row end end
 error('missing public option '..choice)
end
local function step(run,map,name)
 local row=option(run,name)
 assert(row.picker==nil,'regression requires real no-picker public option')
 local uid=Select.uid(run,map,row,Policy.scoreCard)
 local selecting=run.nodeFlow.event.stage=='choose_card'
 assert((uid~=nil)==selecting,'driver must supply UID exactly at public choose_card stage: '..run.nodeFlow.event.id)
 local ok,why=Nodes.chooseEvent(run,row.choice,uid);assert(ok,tostring(why));return uid
end
for _,case in ipairs({{id='bonfire',intro={'approach','offer'},selection='offer'},
 {id='accursed_blacksmith',intro={'forge'},selection='forge'},
 {id='transmogrifier',intro={'change'},selection='change'}})do
 local run,map=fixture(case.id)
 for _,choice in ipairs(case.intro)do step(run,map,choice)end
 assert(run.nodeFlow.event.stage=='choose_card')
 local uid=step(run,map,case.selection)
 assert(type(uid)=='number'and run.nodeFlow.event.stage=='result')
 if case.id=='accursed_blacksmith'then
  local found;for _,card in ipairs(run.deck)do if card.uid==uid then found=card.upgraded end end;assert(found)
 else for _,card in ipairs(run.deck)do assert(card.uid~=uid,'selected permanent card must be removed/transformed')end end
 step(run,map,'leave');assert(run.phase=='map'and run.nodeFlow.complete)
 print('PASS driver public no-picker '..case.id)
end
print('M3_DRIVER_EVENT_CARDS_PASS 3')
