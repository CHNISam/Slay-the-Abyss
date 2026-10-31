local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
-- Real generated controls and Map/GameUI commands; only native UI objects are doubled.
local F = dofile('tests/lua/support/game_ui_fixture.lua')
local Map, MapUI = require('abyss_map'), require('abyss_map_ui')
local passed, failed = 0, 0
local cursor = {CursorDown='down', CursorUp='up', CursorDrag='drag', CursorExit='exit', CursorEndDrag='endDrag'}
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(why)))
end
local function pointer(touch, y) return {touchId=touch, GetUIPos=function() return 640, y or 200 end} end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function setup(events, callback, controller)
    local root = F.control({children=require('abyss_map_controls').controls})
    local panel = root:GetChild('stage'):GetChild('mapPanel')
    local map, calls, ui = Map.generate(F.Data, 42), {}, nil
    local activeCursor = events
    if events == nil then activeCursor = cursor elseif events == false then activeCursor = nil end
    ui = MapUI.new(root, map, function(node)
        calls[#calls+1] = node.id
        if callback then return callback(ui, node) end
        return Map.choose(ui.map, node.id)
    end, 'click', {imageSource='static', cursor=activeCursor,controller=controller,
        color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end})
    local function hit(slot)
        return F.mapControl(panel, type(slot)=='number' and ('node'..slot) or slot):GetChild('hit')
    end
    local function emit(slot, kind, touch, y)
        local control = slot == 'dragArea' and F.mapControl(panel, 'dragArea') or hit(slot)
        return assert(control.listeners[kind], kind)(pointer(touch, y))
    end
    local function tap(slot, touch) emit(slot,'down',touch); emit(slot,'up',touch); return emit(slot,'click',touch) end
    return ui, map, calls, emit, tap, hit
end
local function unchanged(ui, before, calls)
    assert(same(ui.map, before), 'rejected gesture changed map/path/RNG')
    assert(#calls == 0, 'rejected gesture called the coordinator')
end

test('actual exit cancel cannot revive old map input after a newer touch begins', function()
    local ui, root = F.fixture(nil, function() return true end, nil, cursor)
    assert(testStart(ui))
    local function hit(slot) return F.mapControl(root:GetChild('mapPanel'),'node'..slot):GetChild('hit') end
    local beforeRun, beforeMap = F.Combat.copy(ui.run), Map.snapshot(ui.map)
    hit(1).listeners.down(pointer(11))
    assert(ui:openExit() and not ui.mapUI.visible)
    assert(ui:closeExit() and ui.mapUI.visible)
    hit(2).listeners.down(pointer(22))
    hit(1).listeners.up(pointer(11))
    assert(not hit(1).click(pointer(11)), 'cancelled touch entered battle')
    assert(same(ui.run,beforeRun) and same(ui.map,beforeMap) and ui.mode=='map')
    hit(2).listeners.up(pointer(22))
    assert(hit(2).click(pointer(22)) and ui.mode=='battle' and ui.map.currentNodeId==ui.map.nodes[2].id)
end)

test('second finger cannot choose a node or consume the original owner', function()
    local ui,map,calls,emit = setup()
    local before = Map.snapshot(map)
    emit(1,'down',11); emit(2,'down',22); emit(2,'up',22)
    assert(not emit(2,'click',22)); unchanged(ui,before,calls)
    emit(1,'up',11); assert(emit(1,'click',11))
    assert(#calls==1 and map.currentNodeId==map.nodes[1].id)
end)

test('foreign release and click cannot consume the owners completed tap', function()
    local ui,map,calls,emit = setup()
    local before = Map.snapshot(map)
    emit(1,'down',11); emit(1,'up',22)
    assert(not emit(1,'click',22)); unchanged(ui,before,calls)
    emit(1,'up',11)
    assert(not emit(1,'click',22)); unchanged(ui,before,calls)
    assert(emit(1,'click',11) and map.floor==1 and #calls==1)
end)

for _, boundary in ipairs({'overlay','resize','replacement','navigation'}) do
    test(boundary .. ' cannot revive old input when a newer touch starts', function()
        local ui,map,calls,emit = setup()
        emit(1,'down',11)
        if boundary=='overlay' then ui:setVisible(false); ui:setVisible(true)
        elseif boundary=='resize' then assert(ui:resize(1600,900))
        elseif boundary=='replacement' then ui.map=Map.generate(F.Data,43); ui:render()
        else ui:setNavigationEnabled(false); ui:setNavigationEnabled(true) end
        local before=Map.snapshot(ui.map)
        emit(2,'down',22); emit(1,'up',11)
        assert(not emit(1,'click',11)); unchanged(ui,before,calls)
        emit(2,'up',22); assert(emit(2,'click',22))
        assert(#calls==1 and ui.map.currentNodeId==ui.map.nodes[2].id)
    end)
end

test('a completed tap is invalid after hide and reshow even without another down', function()
    local ui,map,calls,emit = setup()
    local before=Map.snapshot(map)
    emit(1,'down',11); emit(1,'up',11)
    ui:setVisible(false); ui:setVisible(true)
    assert(not emit(1,'click',11)); unchanged(ui,before,calls)
end)

test('hidden down cannot arm a tap after the map returns', function()
    local ui,map,calls,emit,tap = setup()
    local before=Map.snapshot(map)
    ui:setVisible(false); emit(1,'down',11); ui:setVisible(true)
    emit(1,'up',11); assert(not emit(1,'click',11)); unchanged(ui,before,calls)
    assert(tap(1,22) and #calls==1)
end)

test('an orphan touch click cannot borrow click-only compatibility', function()
    local ui,map,calls,emit = setup()
    local before=Map.snapshot(map)
    assert(not emit(1,'click',11)); unchanged(ui,before,calls)
end)

test('normal same-ID taps can choose successive nodes once each', function()
    local ui,map,calls,emit,tap = setup()
    assert(tap(1,11) and map.floor==1)
    ui:setNavigationEnabled(true)
    assert(not emit(1,'click',11) and map.floor==1 and #calls==1)
    local nextId=Map.available(map)[1].id
    local slot
    for i,node in ipairs(map.nodes) do if node.id==nextId then slot=i end end
    assert(tap(slot,11) and map.floor==2 and #calls==2)
end)

test('a completed scroll cannot choose on either its first or duplicate click', function()
    local ui,map,calls,emit,tap = setup()
    emit(1,'down',11,200); emit(1,'drag',11,150); emit(1,'up',11,150)
    assert(ui.scroll==50)
    ui:setScroll(0)
    local before=Map.snapshot(map)
    assert(not emit(1,'click',11)); assert(not emit(1,'click',11)); unchanged(ui,before,calls)
    assert(tap(1,22) and #calls==1)
end)

for _, afterUp in ipairs({false,true}) do
    test('EndDrag cancels a tap ' .. (afterUp and 'after' or 'before') .. ' release', function()
        local ui,map,calls,emit,tap = setup()
        local before=Map.snapshot(map)
        emit(1,'down',11)
        if afterUp then emit(1,'up',11) end
        emit(1,'endDrag',11)
        if not afterUp then emit(1,'up',11) end
        assert(not emit(1,'click',11)); unchanged(ui,before,calls)
        assert(tap(1,22) and #calls==1)
    end)
end

test('foreign cancellation does not destroy an owners tap', function()
    local ui,map,calls,emit = setup()
    emit(1,'down',11); emit(1,'exit',22); emit(1,'endDrag',22)
    emit(1,'up',11); assert(emit(1,'click',11) and #calls==1 and map.floor==1)
end)

test('owned cursor exit cancels the tap but preserves later fresh input', function()
    local ui,map,calls,emit,tap = setup()
    local before=Map.snapshot(map)
    emit(1,'down',11); emit(1,'exit',11); emit(1,'up',11)
    assert(not emit(1,'click',11)); unchanged(ui,before,calls)
    assert(tap(1,22) and #calls==1)
end)

test('a release on another node cannot finish or consume the original tap', function()
    local ui,map,calls,emit,tap = setup()
    local before=Map.snapshot(map)
    emit(1,'down',11); emit(2,'up',11)
    assert(not emit(2,'click',11)); assert(not emit(1,'click',11)); unchanged(ui,before,calls)
    emit(1,'up',11); assert(emit(1,'click',11) and map.currentNodeId==map.nodes[1].id and #calls==1)
end)

test('Down and Up ownership does not require optional drag events', function()
    local ui,map,calls,emit,tap = setup({CursorDown='down',CursorUp='up'})
    local before=Map.snapshot(map)
    emit(1,'down',11); ui:setVisible(false); ui:setVisible(true)
    emit(2,'down',22); emit(1,'up',11)
    assert(not emit(1,'click',11)); unchanged(ui,before,calls)
    emit(2,'up',22); assert(emit(2,'click',22) and #calls==1)
end)

test('anonymous complete pointer sequences remain supported', function()
    local ui,map,calls,emit,tap = setup()
    assert(tap(1,nil) and map.floor==1 and #calls==1)
end)

test('click-only hosts retain their first intentional map click', function()
    for _,events in ipairs({false,{CursorDown='down'},cursor}) do
        local ui,map,calls,emit,tap,hit = setup(events)
        assert(hit(1).click() and map.floor==1 and #calls==1)
    end
end)

test('an ordinary render does not cancel a pending valid tap', function()
    local ui,map,calls,emit = setup()
    emit(1,'down',11); ui:render(); ui:setNavigationEnabled(true)
    emit(1,'up',11); assert(emit(1,'click',11) and #calls==1 and map.floor==1)
end)

test('programmatic scroll invalidates a held node even if it scrolls back', function()
    local ui,map,calls,emit,tap = setup()
    local before=Map.snapshot(map)
    emit(1,'down',11); ui:setScroll(100); ui:setScroll(0)
    emit(1,'up',11); assert(not emit(1,'click',11)); unchanged(ui,before,calls)
    assert(tap(1,22) and #calls==1)
end)

test('rejected coordinator calls require a fresh gesture but can be retried', function()
    local accept=false
    local ui,map,calls,emit,tap = setup(nil,function(current,node)
        if not accept then return false,'fixture_rejection' end
        return Map.choose(current.map,node.id)
    end)
    assert(not tap(1,11) and map.floor==0 and #calls==1)
    accept=true
    assert(not emit(1,'click',11) and #calls==1 and map.floor==0)
    assert(tap(1,11) and map.floor==1 and #calls==2)
end)

test('old control release cannot consume a newer gesture with a reused touch ID', function()
    local ui,map,calls,emit = setup()
    emit(1,'down',11); ui:setVisible(false); ui:setVisible(true)
    emit(2,'down',11); emit(1,'up',11)
    assert(not emit(1,'click',11) and map.floor==0 and #calls==0)
    emit(2,'up',11); assert(emit(2,'click',11) and map.currentNodeId==map.nodes[2].id and #calls==1)
end)

for _,afterUp in ipairs({false,true}) do
    test('foreign control cancellation preserves new same-ID input '..(afterUp and 'after' or 'before')..' release',function()
        local ui,map,calls,emit = setup()
        emit(1,'down',11); ui:setVisible(false); ui:setVisible(true)
        emit(2,'down',11)
        if afterUp then emit(2,'up',11) end
        emit(1,'exit',11); emit(1,'endDrag',11)
        if not afterUp then emit(2,'up',11) end
        assert(emit(2,'click',11) and map.currentNodeId==map.nodes[2].id and #calls==1)
    end)
end

test('old control drag cannot scroll or consume a newer same-ID node gesture', function()
    local ui,map,calls,emit = setup()
    emit(1,'down',11); ui:setVisible(false); ui:setVisible(true)
    emit(2,'down',11)
    emit(1,'drag',11,100)
    assert(ui.scroll==0 and #calls==0)
    emit(2,'up',11); assert(emit(2,'click',11) and map.currentNodeId==map.nodes[2].id)
end)

test('a second control Down cannot replace the active same-ID owner', function()
    local ui,map,calls,emit = setup()
    emit(1,'down',11); emit(2,'down',11); emit(2,'up',11)
    assert(not emit(2,'click',11) and map.floor==0 and #calls==0)
    emit(1,'up',11); assert(emit(1,'click',11) and map.currentNodeId==map.nodes[1].id)
end)

for _, boundary in ipairs({'exit','scroll'}) do
    test('duplicate owner Down cannot rearm a cancelled '..boundary..' selection', function()
        local ui,map,calls,emit,tap = setup()
        local before=Map.snapshot(map)
        emit(1,'down',11,200)
        if boundary=='exit' then emit(1,'exit',11)
        else emit(1,'drag',11,150); ui:setScroll(0) end
        emit(1,'down',11,200); emit(1,'up',11,200)
        assert(not emit(1,'click',11), 'duplicate Down revived cancelled selection')
        unchanged(ui,before,calls)
        assert(tap(1,11) and #calls==1, 'post-Up same-ID tap must remain valid')
    end)
end

test('duplicate owner Down preserves the original movement threshold', function()
    local ui,map,calls,emit = setup()
    emit(1,'down',11,200); emit(1,'down',11,400); emit(1,'up',11,200)
    assert(emit(1,'click',11) and map.floor==1 and #calls==1,
        'duplicate Down must not reset the original tap position')
end)

for _,boundary in ipairs({'replacement','advance'}) do
    for _,event in ipairs({'drag','up'}) do
        test('unrendered map '..boundary..' safely cancels old '..event, function()
            local ui,map,calls,emit,tap = setup()
            emit(1,'down',11,200)
            if boundary=='replacement' then ui.map=Map.generate(F.Data,43)
            else assert(Map.choose(map,Map.available(map)[1].id)) end
            local before=Map.snapshot(ui.map)
            emit(1,event,11,100)
            if event=='drag' then emit(1,'up',11,100) end
            assert(not emit(1,'click',11)); unchanged(ui,before,calls)
            assert(ui.observedMap==ui.map and ui.observedFloor==ui.map.floor)
            if boundary=='replacement' then
                assert(tap(1,11) and #calls==1, 'fresh replacement-map tap must remain valid')
            else assert(not ui.navigationEnabled, 'external advance must retain its navigation gate') end
        end)
    end
end

test('explicit focus recovers lost node release for same, new and mouse pointers without moving state',function()
    for _,spec in ipairs({{old=11,new=11},{old=11,new=22},{}})do
        local ui,map,calls,emit,tap,hit=setup()
        local before=Map.snapshot(map)
        assert(F.mapControl(ui.panel,'focus').visible,'focus recovery must be reachable without a controller')
        emit(1,'down',spec.old)
        assert(tap('focus',spec.new),'complete focus tap must be accepted')
        unchanged(ui,before,calls)
        emit(1,'up',spec.old);assert(not emit(1,'click',spec.old),'old node release survived focus')
        assert(tap(2,spec.new) and #calls==1 and map.currentNodeId==map.nodes[2].id)
        assert(not emit(2,'click',spec.new) and #calls==1,'duplicate node click committed twice')
    end
end)

test('incomplete focus click cannot steal a held node owner',function()
    local ui,map,calls,emit,tap=setup()
    local before=Map.snapshot(map)
    emit(1,'down',11);emit('focus','down',22)
    assert(not emit('focus','click',22),'focus requires a complete tap')
    unchanged(ui,before,calls)
    emit(1,'up',11);assert(emit(1,'click',11) and #calls==1)
end)

test('old focus release after a visibility boundary cannot cancel a fresh node',function()
    local ui,map,calls,emit,tap=setup()
    emit('focus','down',11);emit('focus','up',11)
    ui:setVisible(false);ui:setVisible(true)
    emit(2,'down',22)
    assert(not emit('focus','click',11),'stale focus click must be rejected')
    emit(2,'up',22);assert(emit(2,'click',22) and #calls==1)
end)

test('controller focus confirmation remains available after pointer observation',function()
    local focus,device=nil,false
    local api={events={Confirm='confirm',Cancel='cancel'},directions={Left='left',Right='right'},modes={Specified='specified'},
        getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return device end}
    local manager=require('abyss_controller').new(api)
    local ui,map,calls,emit,tap,hit=setup(nil,nil,manager)
    emit('focus','down',11);emit('focus','up',11)
    ui:setVisible(false);ui:setVisible(true)
    emit(1,'down',11)
    device=true;ui:update(0);manager:sync('map')
    focus=hit('focus');assert(focus.canControllerFocus)
    assert(focus.navigationListeners.confirm(),'controller confirm borrowed stale pointer requirements')
    device=false;manager:sync('map')
    emit(1,'up',11);assert(not emit(1,'click',11))
    assert(tap(2,22) and #calls==1)
end)

print('LUA_MAP_GESTURE_OWNERSHIP '..passed..' passed; '..failed..' failed')
assert(failed==0,'map gesture ownership regressions failed')
