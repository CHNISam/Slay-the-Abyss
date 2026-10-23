local F = dofile('tests/lua/support/game_ui_fixture.lua')
local cursor = {CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='endDrag'}
local total, failed = 0, 0
local function test(name, fn)
    total = total + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and 'ok ' or 'not ok ') .. total .. ' - ' .. name .. (ok and '' or ': ' .. tostring(reason)))
end
local function fire(hit, event, id)
    local fn = hit.listeners and hit.listeners[event]
    if fn then return fn(id ~= nil and {touchId=id} or nil) end
end
local function fixture(kind, callback)
    local calls = 0
    local ui, root = F.fixture(nil, function(victory)
        calls=calls+1
        if callback then return callback(calls,victory) end
        return true
    end, nil, cursor)
    if kind ~= 'menu' then assert(ui:start()); ui.run.phase='defeat'; ui:refresh() end
    local hit = root:GetChild('menuPanel'):GetChild(kind=='settle' and 'settle' or 'start'):GetChild('hit')
    return ui,hit,function() return calls end
end
local function gesture(hit,id) fire(hit,'down',id); fire(hit,'up',id) end
for _,kind in ipairs({'menu','restart','settle'}) do
    test(kind .. ' rejects orphan touch Click',function()
        local ui,hit,calls=fixture(kind); local run=ui.run
        fire(hit,'click',1)
        assert(ui.run==run and calls()==0,'orphan touch executed command')
    end)
    test(kind .. ' expires touch across exit cancellation then permits a fresh tap',function()
        local ui,hit,calls=fixture(kind); local run=ui.run
        gesture(hit,1); assert(ui:openExit()); assert(ui:closeExit()); fire(hit,'click',1)
        assert(ui.run==run and calls()==0,'stale touch executed after exit cancellation')
        gesture(hit,2); assert(fire(hit,'click',2)); assert(kind=='settle' and calls()==1 or kind~='settle' and ui.run~=run)
    end)
    test(kind .. ' expires touch on viewport resize',function()
        local ui,hit,calls=fixture(kind); local run=ui.run
        fire(hit,'down',1); ui:resize(720,1280); fire(hit,'up',1); fire(hit,'click',1)
        assert(ui.run==run and calls()==0,'resize revived touch')
    end)
    test(kind .. ' foreign pointer cannot steal or cancel owner',function()
        local ui,hit,calls=fixture(kind); local run=ui.run
        fire(hit,'down',1); fire(hit,'down',2); fire(hit,'up',2); fire(hit,'exit',2); fire(hit,'click',2)
        assert(ui.run==run and calls()==0,'foreign pointer executed command')
        fire(hit,'up',1); assert(fire(hit,'click',1),'owner was lost')
    end)
    test(kind .. ' cancelled drag does not click',function()
        local ui,hit,calls=fixture(kind); local run=ui.run
        gesture(hit,1); fire(hit,'endDrag',1); fire(hit,'click',1)
        assert(ui.run==run and calls()==0,'cancelled gesture executed command')
    end)
end
test('failed settlement requires a new gesture before retry',function()
    local ui,hit,calls=fixture('settle',function(n) return n>1 end)
    gesture(hit,1); assert(not fire(hit,'click',1) and calls()==1)
    fire(hit,'click',1); assert(calls()==1,'duplicate touch retried platform request')
    gesture(hit,2); assert(fire(hit,'click',2) and calls()==2)
end)
test('restart gesture cannot be reused on a different run result',function()
    local ui,hit=fixture('restart'); gesture(hit,1); assert(ui:start()); ui.run.phase='defeat'; ui:refresh()
    local run=ui.run; fire(hit,'click',1); assert(ui.run==run,'previous run gesture restarted new result')
end)
test('result gesture expires after leaving and returning to the same result',function()
    local ui,hit=fixture('restart'); gesture(hit,1); ui.run.phase='map'; ui:refresh(); ui.run.phase='defeat'; ui:refresh()
    local run=ui.run; fire(hit,'click',1); assert(ui.run==run,'hidden interval revived result gesture')
end)
test('mouse down/up without touch ID works, but repeated result Click does not retry',function()
    local ui,hit,calls=fixture('settle',function() return false end)
    gesture(hit); fire(hit,'click'); fire(hit,'click'); assert(calls()==1,'mouse click replayed')
end)
test('click-only platform preserves start, restart and settlement',function()
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end)
    local panel=root:GetChild('menuPanel'); assert(panel:GetChild('start'):GetChild('hit').click())
    ui.run.phase='defeat'; ui:refresh(); assert(panel:GetChild('start'):GetChild('hit').click())
    ui.run.phase='defeat'; ui:refresh(); assert(panel:GetChild('settle'):GetChild('hit').click()); assert(calls==1)
end)
print('LUA_GAME_UI_RESULT_GESTURES '..(total-failed)..'/'..total)
assert(failed==0,tostring(failed)..' result gesture regressions')
