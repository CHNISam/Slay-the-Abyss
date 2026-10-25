-- Detached, bounded-size presentation frames. No callbacks, RNG or rule writes.
local M = {}
local function actor(a)
    local result = {}
    for k, v in pairs(a) do result[k] = v end
    result.statuses = {}
    for k, v in pairs(a.statuses) do result.statuses[k] = v end
    return result
end
function M.frame(state)
    local result = { player = actor(state.player), enemies = {}, phase = state.phase,
        turn = state.turn, energy = state.energy }
    if state.discardedThisTurn~=nil then result.discardedThisTurn=state.discardedThisTurn end
    for i, a in ipairs(state.enemies) do result.enemies[i] = actor(a) end
    for _, name in ipairs({"hand", "draw", "discard", "exhaust"}) do
        result[name] = {}
        for i, card in ipairs(state[name]) do
            local entry = {}
            for k, v in pairs(card) do entry[k] = v end
            result[name][i] = entry
        end
    end
    if state.orbs then
        local o=state.orbs
        result.orbs={slots=o.slots,focus=o.focus,balls={}}
        for i,ball in ipairs(o.balls) do
            local entry={};for k,v in pairs(ball) do entry[k]=v end
            result.orbs.balls[i]=entry
        end
    end
    return result
end
function M.emit(state, kind, detail)
    local entry = { kind = kind, detail = detail, frame = M.frame(state) }
    state.events[#state.events + 1] = entry
    return entry
end
return M
