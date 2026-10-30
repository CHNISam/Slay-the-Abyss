-- Detached, bounded-size presentation frames. No callbacks, RNG or rule writes.
local M = {}
local function detached(value)
    if type(value)~='table'then return value end
    local result={}
    for k,v in pairs(value)do result[k]=detached(v)end
    return result
end
local function originalView(value)
    if type(value)~='table'then return value end
    local result={}
    for k,v in pairs(value)do if k~='commands' and k~='enemyAction'then result[k]=originalView(v)end end
    return result
end
local function actor(a)
    local result = {}
    for k, v in pairs(a) do result[k] = v end
    result.statuses = {}
    for k, v in pairs(a.statuses) do result.statuses[k] = v end
    -- Book/Hexaghost mutate move effects when choosing later moves. Earlier
    -- presentation boundaries must retain their own selected move payload.
    if a.intents then result.intents=detached(a.intents)end
    if a.definitionId and a.powerOrder then
        result.powerOrder={}
        for i,id in ipairs(a.powerOrder)do result.powerOrder[i]=id end
    end
    if a.originalV4 then result.originalV4=originalView(a.originalV4)end
    if a.v4Bloom then result.v4Bloom=originalView(a.v4Bloom)end
    if a.v4Directive then result.v4Directive=originalView(a.v4Directive)end
    return result
end
function M.frame(state)
    local result = { player = actor(state.player), enemies = {}, phase = state.phase,
        turn = state.turn, energy = state.energy }
    if state.spirePair then result.spirePair={facingLeft=state.spirePair.facingLeft}end
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
    if state.originalV4 then result.originalV4=originalView(state.originalV4);result.player.originalV4=result.originalV4 end
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
-- Explicit AbstractDungeon.onModifyPower provenance. Existing action events
-- retain kind/detail/order; eventless actions receive one detached boundary.
function M.onModifyPower(state, origin, before, timing)
    assert(type(origin)=='string' and origin~='', 'missing source Power callback origin')
    assert(type(before)=='number' and before%1==0 and before>=0 and before<=#state.events,
        'invalid source Power callback event boundary')
    local entry
    if #state.events>before then entry=state.events[#state.events]
    else entry=M.emit(state,'source_intent_powers',{}) end
    assert(entry.frame and not entry.sourceIntentPowers, 'duplicate/missing source Power callback frame')
    entry.sourceIntentPowers={origin=origin,scope='all-monsters',timing=timing or 'action-boundary'}
    return entry
end
return M
