package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local S=dofile('tests/lua/support/ending_proceed_fixture.lua')
local cursor={CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag',CursorEnter='enter',CursorExit='exit'}
local count=0
local function test(fn)fn();count=count+1;print('PASS ending Proceed UI '..count)end
local function get(root,path)
 local c=root;for part in path:gmatch('[^/]+')do c=assert(c:GetChild(part),path)end;return c
end
local function fixture()
 local focus;local settled=0
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
  modes={Specified='specified',NearestControl='nearest'},isController=function()return true end,
  getFocus=function()return focus end,setFocus=function(c)assert(c);focus=c end}
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,prologue=false,campaign=true,
  cursorEvents=cursor,controllerApi=api,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
  settle=function()settled=settled+1;return true end})
 root.ui=host;assert(host:start());local map=S.stage(host.run)
 host.map,host.mapUI.map,host.nodeUI.map=map,map,map
 S.finish(host.run);host:refresh()
 return host,root,host.run,map,function()return settled end
end
test(function()
 local host,root,run,map,settled=fixture()
 assert(host.mode=='node'and run.phase=='ending_proceed'and not run.rewards)
 assert(get(root,'nodePanel/eventView').visible and not get(root,'battlePanel').visible)
 assert(get(root,'nodePanel/eventView/name').text=='腐化之心已击败')
 assert(get(root,'nodePanel/eventView/body').text:find('继续进入真结局',1,true))
 assert(get(root,'nodePanel/confirm/label').text=='继续'and get(root,'nodePanel/confirm').visible)
 for i=1,#F.Theme.layout.nativeNode.event.options.rows do assert(not get(root,'nodePanel/eventView/option'..i).visible)end
 for _,name in ipairs({'hpIcon','hp','goldIcon','gold','deckIcon','deck','relics','potions'})do
  assert(not get(root,'nodePanel/'..name).visible,name)
 end
 assert(not get(root,'deckEntry').visible and not get(root,'potionEntry').visible)
 assert(not get(root,'menuPanel/result').visible and not host.settlementRequested and settled()==0)
 assert(run.nodeFlow.type=='boss'and map.nodes[#map.nodes].type=='boss')
 local hit=get(root,'nodePanel/confirm/hit')
 assert(host.controller:focus(hit));assert(hit.canControllerFocus)
 hit.navigationListeners.confirm()
 assert(run.phase=='victory'and run.ending=='true_victory'and host.mode=='victory')
 assert(get(root,'menuPanel/title').text:find('真结局',1,true)and settled()==0)
 assert(F.statValue(root,'floor')=='55 / 55')
 assert(not get(root,'nodePanel').visible and not run.rewards)
 run.ending='normal_victory';host:refresh()
 assert(get(root,'menuPanel/title').text=='深渊已被封印','normal ending copy must remain unchanged')
end)
test(function()
 local host,root,run=fixture();local hit=get(root,'nodePanel/confirm/hit');local owner=run.endingProceed
 local stale=host.nodeUI.actions.confirm.handler
 hit.listeners.down({touchId=1});run.endingProceed=S.C.copy(owner)
 host.nodeUI:update(0);run.endingProceed=owner
 hit.listeners.up({touchId=1});hit.listeners.click({touchId=1})
 assert(run.phase=='ending_proceed'and not stale(),'invalidated owner cannot revive after repair')
 host.nodeUI:render();host:syncController();host:update(0)
 assert(host.controller:focus(hit));hit.navigationListeners.confirm()
 assert(run.phase=='victory'and not run.endingProceed)
end)
test(function()
 local host,root,run=fixture();local stale=host.nodeUI.actions.confirm.handler
 assert(host:openExit());assert(not stale());assert(run.phase=='ending_proceed')
 assert(host:closeExit());assert(not stale(),'old hidden-page closure cannot revive')
 local old=host.nodeUI.actions.confirm.handler
 local replacement=S.Run.new(F.Data,'43',{experimental=true,campaign=true})
 host.nodeUI.run=replacement;assert(not old());assert(run.phase=='ending_proceed'and replacement.phase=='map')
end)
print('ENDING_PROCEED_UI 3 groups; 0 failed; native/natural NOT_RUN')
