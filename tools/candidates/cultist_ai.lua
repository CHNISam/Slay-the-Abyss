-- Isolated A0 Cultist behavior candidate. NOT loaded by the game runtime.
-- Independent reducer from behavioral facts; provenance and scope in
-- docs/reviews/TASK-15-cultist-ai-candidate.md. No RNG or damage resolution.
local M = {}

local function copy(state)
    local nextState = {}
    for key, value in pairs(state) do nextState[key] = value end
    return nextState
end

function M.new(hp)
    assert(type(hp) == 'number' and hp >= 0 and hp % 1 == 0, 'invalid supplied HP')
    return { hp = hp, phase = 'opening', ritual = 0, strength = 0,
        skipRitualRound = false, awaitingRound = false }
end

-- The caller resolves the returned action, including attack modifiers, block,
-- retaliation and death. It must not call endRound until ALL enemies finish.
function M.act(state)
    local result = copy(state)
    if state.hp <= 0 then return result, { kind = 'none' } end
    assert(not state.awaitingRound, 'round boundary required before another action')
    result.awaitingRound = true
    if state.phase == 'opening' then
        result.phase = 'attacking'
        result.ritual = 3
        result.skipRitualRound = true
        return result, { kind = 'buff', status = 'ritual', amount = 3 }
    end
    assert(state.phase == 'attacking', 'invalid Cultist phase')
    return result, { kind = 'attack', baseDamage = 6 }
end

function M.endRound(state)
    local result = copy(state)
    if state.hp <= 0 then return result end
    assert(state.awaitingRound, 'no resolved action for this round')
    result.awaitingRound = false
    if state.skipRitualRound then
        result.skipRitualRound = false
    else
        result.strength = state.strength + state.ritual
    end
    return result
end

return M
