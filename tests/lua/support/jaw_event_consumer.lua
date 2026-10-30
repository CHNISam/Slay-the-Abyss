-- The battle UI releases a completed event batch in-place (abyss_battle_ui).
-- This headless AI fixture observes every emitted frame before acknowledging it.
local M={}
function M.consume(state)
    assert(state.phase=='player','consume only a completed enemy turn')
    local events=state.events
    for _,event in ipairs(events)do
        assert(type(event.kind)=='string' and type(event.frame)=='table','complete event required')
        assert(event.frame.player and event.frame.enemies,'detached actor frame required')
    end
    local count=#events
    for i=count,1,-1 do events[i]=nil end
    assert(state.events==events,'consumer preserves the event table')
    return count
end
return M
