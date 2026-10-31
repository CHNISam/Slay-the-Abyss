-- Current host tree: unlike frozen historical fixtures, these exercise today's
-- native menu admission, layered pointer routing and controller ownership.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function hit(box,name)return box:GetChild(name):GetChild('hit')end
local function panels(root)
 return root:GetChild('runMenu'),root:GetChild('exitPanel'):GetChild('guide')
end
local cases=0
local function test(name,fn)fn();cases=cases+1;print('ok menu boundary '..cases..' - '..name)end
test('pointer catches preserve modal; outside consumes and returns one layer only',function()
 local calls=0
 local ui,root=F.fixture(nil,function()calls=calls+1;return true end)
 assert(F.start(ui));local run,map=ui.run,ui.map
 local floor=map.floor
 local menu,guide=panels(root)
 assert(menu.disableCursorEventPassthrough and root:GetChild('exitPanel').disableCursorEventPassthrough)
 assert(ui:openMenu());assert(menu:GetChild('catch').click()==true and ui.menuOpen)
 assert(not ui.mapUI:choose(F.Nodes.available(run,map)[1].id),'background route must stay blocked')
 assert(hit(menu,'help').click() and ui.controlsOpen and guide.visible)
 assert(guide:GetChild('catch').click()==true and ui.controlsOpen)
 assert(menu:GetChild('blocker').click()==true and ui.controlsOpen,'hidden menu blocker must not dismiss guide')
 assert(guide:GetChild('blocker').click()==true and not ui.controlsOpen and ui.menuOpen and ui.exitOpen)
 assert(menu.visible and not guide.visible)
 assert(menu:GetChild('blocker').click()==true and not ui.menuOpen and not ui.exitOpen)
 assert(guide:GetChild('blocker').click()==true and menu:GetChild('blocker').click()==true)
 assert(ui.run==run and ui.map==map and map.floor==floor and calls==0,'dismissal must not advance or settle the run')
 assert(ui:openMenu() and hit(menu,'abandon').click())
 local why=root:GetChild('exitPanel'):GetChild('whyText')
 assert(why.visible and why.text=='存档功能需作者达到创作者 4 级后开放，喜欢的话欢迎点赞支持。帮助作者提升等级。')
 assert(ui:closeExit() and calls==0)
 ui:disable()
end)
test('controller owns same-frame pointer echoes and hidden map never receives focus',function()
 local focus
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus',LostFocus='blur'},
  directions={Left='left',Right='right'},modes={Specified='specified'},
  getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
 local ui,root=F.fixture(nil,nil,nil,nil,false,nil,nil,api)
 local menu,guide=panels(root)
 local function press(control,event)
  ui:update(.01);ui:syncController();assert(control.canControllerFocus)
  api.setFocus(control);return control.navigationListeners[event or 'confirm']()
 end
 assert(press(focus,'cancel') and ui.menuOpen)
 assert(not menu:GetChild('map').visible and not hit(menu,'map').canControllerFocus)
 assert(menu:GetChild('blocker').click()==true and ui.menuOpen,'controller-open pointer echo must not close menu')
 assert(press(hit(menu,'help')) and ui.controlsOpen)
 assert(guide:GetChild('blocker').click()==true and ui.controlsOpen,'controller-confirm pointer echo must not close guide')
 assert(press(focus,'cancel') and not ui.controlsOpen and ui.menuOpen)
 assert(menu:GetChild('blocker').click()==true and ui.menuOpen,'controller-back pointer echo must not close parent')
 assert(press(focus,'cancel') and not ui.exitOpen)
 assert(ui.run==nil and ui.controller.scope=='menu')
 ui:disable()
end)
test('settlement busy and requested states swallow stale outside and controller input',function()
 local ui,root,calls,focus
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus',LostFocus='blur'},
  directions={Left='left',Right='right'},modes={Specified='specified'},
  getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
 calls=0
 ui,root=F.fixture(nil,function()
  calls=calls+1
  local menu,guide=panels(root)
  assert(ui.settlementBusy and not ui:closeExit())
  assert(menu:GetChild('blocker').click()==true and guide:GetChild('blocker').click()==true)
  assert(ui.exitOpen,'outside events must not dismiss during settlement callback')
  return true
 end,nil,nil,false,nil,nil,api)
 local menu,guide=panels(root)
 assert(ui:openMenu());assert(hit(menu,'help').click())
 ui.settlementBusy=true
 assert(guide:GetChild('blocker').click()==true and ui.controlsOpen)
 ui.settlementBusy=false;assert(ui:closeExit())
 ui.settlementBusy=true
 assert(menu:GetChild('blocker').click()==true and ui.menuOpen)
 ui.settlementBusy=false
 assert(hit(menu,'abandon').click() and not ui.menuOpen and ui.exitOpen)
 local oldCancel=focus.navigationListeners.cancel
 assert(hit(root:GetChild('exitPanel'),'confirm').click() and ui.settlementRequested and calls==1)
 assert(menu:GetChild('blocker').click()==true and guide:GetChild('blocker').click()==true)
 ui:update(.01);assert(ui.controller.scope=='blocked')
 assert(not oldCancel() and not focus.canControllerFocus,'settlement must revoke controller ownership')
 assert(not ui:closeExit() and not ui:openMenu() and not ui:confirmExit() and calls==1)
 ui:disable()
end)
print('MENU_INPUT_BOUNDARIES_CURRENT_PASS '..cases)
