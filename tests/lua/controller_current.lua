-- Current source-card ownership and chapter context remain authoritative when
-- native controller events are added. These use the real generated host tree.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local function setup(combat)
    local focus
    local api={events={Confirm='confirm',Cancel='cancel',Focus='focus',LostFocus='blur'},
        directions={Left='left',Right='right'},modes={Specified='specified'},
        getFocus=function()return focus end,isController=function()return true end}
    api.setFocus=function(control)
        if focus and focus.navigationListeners and focus.navigationListeners.blur then focus.navigationListeners.blur()end
        focus=control
        if control.navigationListeners and control.navigationListeners.focus then control.navigationListeners.focus()end
    end
    local cursor={CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag'}
    local host,root=F.fixture(nil,nil,nil,cursor,false,nil,{keyEvents={KeyboardSprintKeyDown='right'}},api)
    assert(host.run==nil and host.mapUI.map==nil and host.nodeUI.run==nil,
        'controller title construction must not create preview owners')
    assert(host:start())
    if combat then
        assert(Run.startCombat(host.run,'cultist_solo'))
        host.run.combat=F.Combat.new(F.Data,{deck={'strike'},enemies={'cultist','jaw_worm'}})
        host:resize(1280,720);host:refresh()
    end
    local panel=root:GetChild('battlePanel')
    local function hit(name)
        local box=panel:GetChild(name)
        return box:GetChild('hit') or box
    end
    local function pointer(name,kind,touch,x,y)
        return assert(hit(name).listeners[kind])({touchId=touch,
            GetUIPos=function()return 640+(x or 0),360+(y or 0)end})
    end
    local function press(control,kind)
        host:update(.01);host:syncController();assert(control.canControllerFocus)
        api.setFocus(control)
        return assert(control.navigationListeners[kind or 'confirm'])()
    end
    return host,root,hit,pointer,press,api
end
local host,root,hit,pointer,press,api=setup(true)
local ui,battle=host.battleUI,host.run.combat
local energy,hp=battle.energy,battle.enemies[2].hp
pointer('card1','down',7,-60,-280);pointer('card1','drag',7,-285,0)
pointer('dragLayer','up',7,-285,0)
assert(ui.carry and ui.selected and ui.carry.aiming)
host:syncController();press(api.getFocus(),'cancel')
assert(ui.carry==nil and ui.selected==nil and battle.energy==energy and battle.enemies[2].hp==hp)
pointer('card1','up',7,-285,0);pointer('card1','click',7)
assert(ui.selected==nil,'late pointer release cannot reclaim controller-cancelled card ownership')
press(hit('card1'));assert(ui.selected==battle.hand[1].uid)
assert(root:GetChild('battlePanel').keyListeners.right())
assert(ui.selected==nil and ui.carry==nil and battle.energy==energy,
    'current right-click keyboard cancellation must stay separate and harmless')
host:disable()
print('controller current: ownerless title, source carry cancel, stale pointer and right-click passed')

host,root,hit,pointer,press,api=setup(true)
ui,battle=host.battleUI,host.run.combat
battle.enemies[1].hp=0
host:refresh()
local living=battle.enemies[2]
hp=living.hp
-- Navigate the visible live actor after this deliberate out-of-command HP edit.
-- Its Focus callback, not a numeric core slot assumption, owns the target.
api.setFocus(hit('enemy1'));assert(ui.target==2)
press(hit('card1'))
assert(api.getFocus()==hit('enemy1'),'first visible screen slot must represent the active second core enemy')
press(api.getFocus())
for _=1,400 do if not ui.busy then break end;host:update(.05)end
assert(battle.energy==2 and living.hp==hp-6 and battle.enemies[1].hp==0,
    'controller screen slots must issue commands to their live core indices')
host:disable()
print('controller current: dynamic enemy screen-slot/core-index targeting passed')

host,root,hit,pointer,press,api=setup(false)
local oldFocus=api.getFocus()
assert(oldFocus and oldFocus.parent.name:match('^node'))
local beforeFloor=host.map.floor
-- Same table, same floor/node IDs, different map identity signature: no render
-- or update has acknowledged it, so an old focused route must fail closed.
host.map.sourceSignature=host.map.sourceSignature..':replacement'
local ok=oldFocus.navigationListeners.confirm()
assert(not ok and host.map.floor==beforeFloor and host.run.phase=='map',
    'stale controller focus must not cross a replacement chapter context')
host:disable()
print('controller current: stale map focus cannot enter a replacement context')
