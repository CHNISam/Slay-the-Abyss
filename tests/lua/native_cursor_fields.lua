package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Controller=require('abyss_controller')
local function rejects(fn,needle)
 local ok,why=pcall(fn);assert(not ok and tostring(why):find(needle,1,true),tostring(why))
end
local cursor=F.control({name='strict-cursor',kind='cursorArea'})
rejects(function()return cursor.interactable end,'CursorArea')
rejects(function()cursor.interactable=false end,'CursorArea')
rejects(function()return cursor.activeInHierarchy end,'activeInHierarchy')
rejects(function()cursor.activeInHierarchy=false end,'activeInHierarchy')
cursor.raycastTarget=false;assert(cursor.raycastTarget==false)
local preset=F.control({name='strict-button',kind='presetButton'})
preset.interactable=false;assert(preset.interactable==false)
rejects(function()return preset.activeInHierarchy end,'activeInHierarchy')

-- The generated host startup must exercise the real BattleUI constructor.
local host,root=F.fixture()
assert(host.mode=='menu' and host.run==nil and not host.battleUI.active)
local pile=root:GetChild('battlePanel'):GetChild('drawIcon'):GetChild('hit')
assert(pile.kind=='cursorArea' and pile.raycastTarget==false)
local endTurn=root:GetChild('battlePanel'):GetChild('endTurn')
assert(endTurn.kind=='presetButton' and endTurn.interactable==false and endTurn.raycastTarget==false)

-- Both supported native controls use the same focus gate, with a visible parent
-- chain and native field restrictions rather than synthetic hierarchy aliases.
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
print('NATIVE_CURSOR_FIELDS_PASS strict fields, generated startup, shared focus and stale-input gates')
