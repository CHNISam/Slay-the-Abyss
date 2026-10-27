local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
local Controller = require('abyss_controller')
local focus, enabled = nil, true
local api = {events={Confirm='confirm',Cancel='cancel',Focus='focus'},
    directions={Left='left',Right='right'},modes={Specified='specified',NearestControl='nearest'},
    getFocus=function()return focus end,setFocus=function(value)assert(value,'official focus setter requires a control');focus=value end,
    isController=function()return enabled end}
local function control(parent)
    local c={visible=true,raycastTarget=true,parent=parent,listeners={},links={}}
    function c:AddNavigationEventListener(e,fn) NativeContract.listener(e,fn);assert(not self.listeners[e]);self.listeners[e]=fn end
    function c:SetControllerNavigation(d,m,target)self.links[d]={m,target}end
    return c
end
local manager=Controller.new(api)
local count,cancelled=0,0
local page,modal=control(),control()
local a,b,c,close=control(page),control(page),control(page),control(modal)
local empty=control(page)
Controller.bind(manager,empty,'main',function()error('empty action executed')end,function()return nil end)
Controller.bind(manager,a,'main',function()count=count+1 end,nil,1,'cards')
Controller.bind(manager,b,'main',function()count=count+1 end,nil,2,'cards')
Controller.bind(manager,c,'main',function()count=count+1 end,nil,3,'cards')
Controller.bind(manager,close,'modal',function()end)
manager:sync('main',function()cancelled=cancelled+1 end)
assert(empty.canControllerFocus==false,'native focus setters require an explicit boolean when no dynamic action exists')
assert(focus==a and a.canControllerFocus and not close.canControllerFocus)
assert(a.links.left[2]==c and c.links.right[2]==a,'card navigation must wrap')
a.listeners.confirm();a.listeners.confirm();assert(count==1,'one physical event cannot execute twice in one update')
manager:tick();a.listeners.cancel();assert(cancelled==1)
focus=b;manager:sync('main');manager:sync('modal')
assert(focus==close and not a.canControllerFocus,'modal owns all focus')
manager:tick();a.listeners.confirm();assert(count==1,'old-page callbacks cannot run behind a modal')
manager:sync('main');assert(focus==b,'closing a modal restores the previous focus')
b.raycastTarget=false;manager:sync('main');assert(focus~=b and not b.canControllerFocus)
assert(a.links.right[2]==c,'disabled items are omitted from navigation')
c.visible=false;manager:sync('main');assert(focus==a and a.links.right[2]==a)
page.visible=false;manager:sync('main');assert(not focus.canControllerFocus,'no hidden ancestor may remain navigable')
enabled=false;page.visible=true;manager:sync('main');assert(focus==a,'mouse/touch mode must not have focus forced')
enabled=true;manager:sync('main');assert(focus==a,'hot-plug restores a usable focus')
manager:disable();manager:tick();a.listeners.confirm();assert(count==1 and not a.canControllerFocus)
print('controller: default, wrap, repeat, modal, restore, disabled, hidden, device switch and shutdown passed')
