package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local S=dofile('tests/lua/support/emerald_run_fixture.lua')
local Run,Nodes,Map=S.Run,S.Nodes,S.Map
local cursor={CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag',CursorMove='move',CursorEnter='enter',CursorExit='exit'}
local count=0
local function test(fn)fn();count=count+1;print('PASS emerald UI '..count)end
local function get(root,path)
 local c=root;for part in path:gmatch('[^/]+')do c=assert(c:GetChild(part),path)end;return c
end
local function fixture()
 local focus
 local controller={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
  modes={Specified='specified',NearestControl='nearest'},isController=function()return true end,
  getFocus=function()return focus end,setFocus=function(c)assert(c);focus=c end}
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,S.data(true),F.Presentation,'click',{
  seed=42,prologue=false,campaign=true,imageSource='static',cursorEvents=cursor,controllerApi=controller,
  color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
  readEndingHistory=function()return{version=1,wins={ironclad=true,silent=true,defect=true}}end})
 root.ui=host;assert(host:start());local run,map=host.run,host.map
 assert(run.mapBirthContext.endingUnlocked and map.emeraldSelection)
 run.relics[#run.relics+1]='black_star';S.queues(run);run.potionChanceModifier=60
 local id=S.beforeSelected(map);run.floor=map.floor
 host.mapUI:focusCurrent(false);host:refresh()
 local index;for i,node in ipairs(map.nodes)do if node.id==id then index=i end end
 local box=F.mapControl(get(root,'mapPanel'),'node'..assert(index))
 assert(box:GetChild('emeraldLabel').text=='绿钥匙'and box:GetChild('emeraldLabel').visible)
 assert(host.mapUI:choose(id));S.victory(run);host:refresh()
 assert(host.mode=='battle'and #run.rewards.relics==2 and run.rewards.potion and run.rewards.emeraldKey)
 return host,root,run,map
end
local function control(root,name)
 local path=name:match('^relicReward')or name=='emeraldKeyReward'
 return get(root,'battlePanel/'..(path and 'potionHelp/'or '')..name)
end
local function tap(c,id)
 assert(c.visible and c.interactable)
 c.listeners.down({touchId=id});c.listeners.up({touchId=id});c.listeners.click({touchId=id})
end
test(function()
 local host,root,run=fixture()
 local names={'goldReward','relicReward1','relicReward2','emeraldKeyReward','claimPotion','cardReward'}
 local previous
 for _,name in ipairs(names)do
  local c=control(root,name);assert(c.visible and c.interactable and c.canControllerFocus)
  if previous then assert(previous.y-c.y>=64,'reward hit rows overlap')end;previous=c
 end
 local held=#run.relics;local gold=run.gold
 for i,name in ipairs(names)do
  local c=control(root,name);host:update(0);assert(host.controller:focus(c));assert(c.canControllerFocus)
  if i%2==0 then c.navigationListeners.confirm()else tap(c,100+i)end
  if name=='cardReward'then
   host:update(0);tap(control(root,'skip'),200)
   assert(not run.rewards.cardResolved and host.battleUI.rewardScreen=='list','source Skip only closes the picker')
   tap(control(root,'cardReward'),201);host:update(0)
   local card=get(root,'battlePanel/card1/hit');assert(host.controller:focus(card));card.navigationListeners.confirm()
  end
 end
 assert(run.keys.emerald and #run.relics==held+2 and run.gold>gold)
 assert(run.rewards.emeraldKey.claimed and run.rewards.relics[1].claimed and run.rewards.relics[2].claimed)
 assert(run.rewards.potion.resolved,'potion row did not resolve: '..tostring(host.battleUI.rewardNotice))
 assert(run.rewards.cardResolved,'card obtain did not resolve: '..tostring(host.battleUI.rewardScreen))
 host:update(0);local proceed=control(root,'continue');assert(host.controller:focus(proceed))
 proceed.navigationListeners.confirm();assert(run.phase=='map'and host.mode=='map')
end)
test(function()
 local host,root,run=fixture();local key=control(root,'emeraldKeyReward')
 key.listeners.down({touchId=1});local original=run.rewards.emeraldKey
 run.rewards.emeraldKey=S.C.copy(original)
 key.listeners.up({touchId=1});key.listeners.click({touchId=1});assert(not run.keys.emerald)
 host:refresh();tap(key,2);assert(run.keys.emerald)
 local state=run.rewards.emeraldKey
 key.listeners.click({touchId=2});assert(run.rewards.emeraldKey==state and state.claimed)
end)
test(function()
 local host,root,run,map=fixture();local offer=run.rewards.emeraldKey
 tap(control(root,'continue'),1);assert(run.phase=='map'and run.pendingCombatRewards)
 F.click(root,'combatRewards','');assert(run.phase=='reward'and run.rewards.emeraldKey==offer)
 assert(control(root,'emeraldKeyReward').visible)
 tap(control(root,'continue'),2)
 local id=assert(Nodes.available(run,map)[1]).id
 assert(host.mapUI:choose(id));assert(not run.pendingCombatRewards)
 assert(not Run.reopenCombatRewards(run)and not Run.claimEmeraldKey(run))
end)
print('EMERALD_KEY_UI 3 groups; 0 failed; native/natural NOT_RUN')
