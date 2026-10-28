package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Controller=require('abyss_controller')
local function rejects(fn,needle)
 local ok,why=pcall(fn);assert(not ok and tostring(why):find(needle,1,true),tostring(why))
end
local cursor=F.control({name='strict-cursor',kind='cursorArea'})
rejects(function()return cursor.interactable end,'CursorArea')
rejects(function()cursor.interactable=false end,'CursorArea')
assert(cursor.activeInHierarchy==true,'documented native hierarchy state must be readable')
rejects(function()cursor.activeInHierarchy=false end,'read-only')
cursor.raycastTarget=false;assert(cursor.raycastTarget==false)
local preset=F.control({name='strict-button',kind='presetButton'})
preset.interactable=false;assert(preset.interactable==false)
assert(preset.activeInHierarchy==true)
rejects(function()preset.activeInHierarchy=false end,'read-only')

-- The generated host startup must exercise the real BattleUI constructor.
local host,root=F.fixture()
assert(host.mode=='menu' and host.run==nil and not host.battleUI.active)
local pile=root:GetChild('battlePanel'):GetChild('drawIcon'):GetChild('hit')
assert(pile.kind=='cursorArea' and pile.raycastTarget==false)
local endTurn=root:GetChild('battlePanel'):GetChild('endTurn')
assert(endTurn.kind=='presetButton' and endTurn.interactable==false and endTurn.raycastTarget==false)

-- Both native controls use the same visibility and engine-hierarchy focus gate.
local focus,calls=nil,0
local api={events={Confirm='confirm',Cancel='cancel'},directions={Left='left',Right='right'},modes={Specified='specified'},
 getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
local page=F.control({name='page',kind='container'})
local a=F.control({name='cursor',kind='cursorArea'},page)
local b=F.control({name='button',kind='presetButton'},page)
local manager=Controller.new(api)
Controller.bind(manager,a,'test',function()calls=calls+1 end,nil,1)
Controller.bind(manager,b,'test',function()calls=calls+1 end,nil,2)
manager:sync('test');assert(focus==a and a.canControllerFocus and b.canControllerFocus)
a.raycastTarget=false;manager:sync('test');assert(focus==b and not a.canControllerFocus)
a.navigationListeners.confirm();assert(calls==0,'disabled native target must reject stale Confirm')
manager:tick();b.navigationListeners.confirm();b.navigationListeners.confirm();assert(calls==1,'one frame cannot double activate')
page.visible=false;manager:sync('test');assert(not a.canControllerFocus and not b.canControllerFocus)
manager:tick();b.navigationListeners.confirm();assert(calls==1,'hidden ancestor must block old Confirm')
page.visible=true;b.raycastTarget=false;manager:sync('test');assert(not b.canControllerFocus)

-- Queue native listeners while focused, then change only engine activation.
-- Visible, alive, attached and raycast-enabled controls must not dispatch either
-- old event when they or an ancestor become inactive, for either native kind.
for _,kind in ipairs({'cursorArea','presetButton'})do
 for _,event in ipairs({'confirm','cancel'})do
  for _,target in ipairs({'control','ancestor'})do
   local ancestor=F.control({name='active-page',kind='container'})
   local item=F.control({name='active-item',kind=kind},ancestor)
   ancestor.alive,item.alive=true,true
   local accepted=0
   local current=Controller.new(api)
   local function action()accepted=accepted+1;return true end
   Controller.bind(current,item,'active',action)
   current:sync('active',action)
   assert(focus==item and current:eligible(current.byControl[item]))
   local queued=item.navigationListeners[event]
   F.setEngineActive(target=='control' and item or ancestor,false)
   assert(item.alive and ancestor.alive and item.visible and ancestor.visible
    and item.parent==ancestor and item.raycastTarget and item.activeInHierarchy==false)
   current:tick()
   assert(queued()==false and accepted==0,kind..' inactive '..target..' must reject queued '..event)
   assert(not current:eligible(current.byControl[item]))
   current:sync('active',action);assert(not item.canControllerFocus)
   F.setEngineActive(target=='control' and item or ancestor,true)
   current:sync('active',action);current:tick()
   assert(queued()==true and accepted==1,'reactivated native control must accept '..event)
  end
 end
end

-- This uses the generated menu and real GameUI Start action. No Run may be
-- created from its old Confirm while the Start control or menu is inactive.
for _,target in ipairs({'control','ancestor'})do
 local generated,tree=F.fixture(nil,nil,nil,nil,false,nil,nil,api)
 local menu=tree:GetChild('menuPanel')
 local start=menu:GetChild('start'):GetChild('hit')
 assert(generated.mode=='menu' and generated.run==nil and focus==start and start.kind=='cursorArea')
 local queued=start.navigationListeners.confirm
 F.setEngineActive(target=='control' and start or menu,false)
 assert(start.visible and menu.visible and start.parent~=nil and start.raycastTarget and not start.activeInHierarchy)
 generated.controller:tick()
 assert(queued()==false and generated.mode=='menu' and generated.run==nil,'inactive generated Start must not create a Run')
 F.setEngineActive(target=='control' and start or menu,true)
 generated.controller:tick()
 assert(queued()==true and generated.mode=='map' and generated.run~=nil,'reactivated generated Start must still create a Run')
end
print('NATIVE_CURSOR_FIELDS_PASS strict fields, generated startup, shared focus and stale-input gates')
