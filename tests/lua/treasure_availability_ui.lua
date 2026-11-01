-- Real generated NodeUI/Nodes entries; source checkpoints are component fixtures,
-- never naturally earned route/probability evidence.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local UI,Run,Map=require('abyss_node_ui'),require('abyss_run'),require('abyss_map')
local Source=dofile('tests/lua/support/sapphire_source_fixture.lua')
local route=Map.generate(F.Data,'42',1)
local target
while not target do
 for _,node in ipairs(Map.available(route))do if node.type=='treasure' then target=node;break end end
 if not target then assert(Map.choose(route,Map.available(route)[1].id))end
end
local function setup(list,options)
 local run,map=Run.new(F.Data,'42'),F.Combat.copy(route)
 Source.stage(run,options)
 if options.missing then
  run.data=F.Combat.copy(run.data)
  for i=#run.data.relics.relics,1,-1 do
   if run.data.relics.relics[i].sourceId=='Strawberry' then table.remove(run.data.relics.relics,i)end
  end
 end
 assert(F.Nodes.enter(run,map,target.id))
 local host=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local root=host:GetChild('nodePanel')
 local ui=UI.new(root,run,map,F.Presentation,'click',nil,{enhancedRooms=list})
 ui:setVisible(true);assert(ui:press('treasureView/chest'));ui:update(2)
 return run,map,ui,root:GetChild('treasureView')
end
local function same(a,b)
 assert(type(a)==type(b),'state type changed')
 if type(a)~='table' then assert(a==b,'state value changed');return end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil,'state field removed')end
end
local count=0
for _,list in ipairs({true,false})do
 for _,case in ipairs({
  {name='single unavailable',missing=true,others=false},
  {name='other gold',missing=true,gold='42',others=true},
  {name='other relic',missing=true,extra=true,others=true},
  {name='normal claim',others=false},
 })do
  local run,map,ui,panel=setup(list,case)
  local index,item
  for i,reward in ipairs(run.nodeFlow.reward.items)do
   if reward.sourceId=='Strawberry' then index,item=i,reward;break end
  end
  assert(item and item.available==not case.missing,'real source reward availability')
  if not list then ui.treasureChoice=index;ui:render()end
  local row=panel:GetChild(list and ('rewardItem'..index) or 'reward')
  local command=list and ('treasureView/rewardItem'..index) or 'treasureView/take'
  local description=row:GetChild('description').text
  if case.missing then
   assert(description:find('内容缺失',1,true),case.name..': must explain missing content: '..description)
   assert(description:find('离开',1,true),'must offer an available next action')
   assert((description:find('其他奖励',1,true)~=nil)==case.others,'other rewards hint must match live availability: '..description)
   if not case.others then assert(#run.nodeFlow.reward.items==1)end
   local before,mapBefore=F.Combat.copy(run),F.Combat.copy(map)
   assert(not ui.actions[command].enabled and not ui:press(command))
   same(run,before);same(map,mapBefore)
   local ok,why=F.Nodes.claimTreasureReward(run,assert(F.Nodes.treasureRewardSource(run,item.slot)))
   assert(not ok and why=='relic_content_unavailable')
   same(run,before);same(map,mapBefore) -- includes RNG, pools, resources and reward owners
   if case.others then
    local other
    for i,reward in ipairs(run.nodeFlow.reward.items)do if reward.kind~='relic' or reward.available then other=i;break end end
    assert(other and other~=index)
    if not list then ui.treasureChoice=other;ui:render()end
    assert(ui:press(list and ('treasureView/rewardItem'..other) or 'treasureView/take'))
    if not list then ui.treasureChoice=1;ui:render()end
    local remaining=panel:GetChild(list and 'rewardItem1' or 'reward'):GetChild('description').text
    assert(not remaining:find('其他奖励',1,true),'claimed alternatives must disappear from hint')
   end
   assert(ui:press('back'))
  else
   assert(not description:find('内容缺失',1,true) and ui.actions[command].enabled)
   assert(ui:press(command) and run.relics[#run.relics]=='strawberry')
  end
  count=count+1;print('ok treasure availability '..count..' - '..case.name..(list and ' list' or ' fallback'))
 end
end
print('TREASURE_AVAILABILITY_UI_PASS '..count)
