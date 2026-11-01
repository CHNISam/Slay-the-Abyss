local F=dofile('tests/lua/support/game_ui_fixture.lua')
-- Returning to raw clock formatting would expose unverified host time or throw
-- on invalid state before the existing restart/settlement actions can be used.
local ui,root=F.fixture(nil,function()return true end)
assert(F.start(ui))
ui:update(62.25)
assert(ui.run.elapsedSeconds==62.25)
for _,dt in ipairs({-1,math.huge,-math.huge,0/0,'1',false})do
    local ok,reason=ui:update(dt)
    assert(not ok and reason=='invalid_delta' and ui.run.elapsedSeconds==62.25)
end
for _,case in ipairs({{0},{62.25},{3074457345},{-1},{math.huge},{-math.huge},{0/0},{'bad'},{false},{}})do
    local value=case[1]
    ui.run.elapsedSeconds=value
    for _,phase in ipairs({'defeat','victory'})do
        ui.run.phase=phase
        ui.run.nodeFlow=phase=='victory' and {complete=true,result='boss_treasure_complete'} or nil
        ui:refresh()
        assert(F.statValue(root,'time')=='暂不可用','unverified duration leaked into '..phase)
        assert(ui.run.elapsedSeconds==value or value~=value and ui.run.elapsedSeconds~=ui.run.elapsedSeconds,
            'presentation must preserve time used by score and event rules')
        local menu=root:GetChild('menuPanel')
        assert(menu:GetChild('start').visible and menu:GetChild('settle').visible)
    end
end
-- Restart creates a fresh run; elapsed values do not leak into the new run.
assert(F.start(ui) and ui.run.elapsedSeconds==0)
ui.run.phase='defeat';ui:refresh()
assert(F.statValue(root,'time')=='暂不可用')
assert(ui:settle() and ui.settlementRequested)
-- Voluntary departure still submits the existing non-victory result.
local departed=false
local exit=F.fixture(nil,function(victory)assert(not victory);departed=true;return true end)
assert(F.start(exit));exit:update(3074457345)
assert(exit:openExit() and exit:confirmExit() and departed)
print('RESULT_DURATION_UNAVAILABLE_PASS')
