-- Continuation-owned choice operations. Return values preserve pause and early exits.
local Handlers={}
function Handlers.pileChoice(c)
    local state=c.state
    local effect=c.effect
    local result,why=require('abyss_pile_choice').begin(state,effect.mode,effect.value,state.combatGeneration or 0)
    assert(result,why);return result
end

function Handlers.requestDiscard(c)
    local state=c.state
    local effect=c.effect
    local ok,reason=require('abyss_discard').begin(state,effect.value)
    assert(ok,reason)
    return state.pendingDiscard and 'pause' or true
end

function Handlers.scry(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    return require("abyss_scry").begin(state,effect.value,queue)
end

function Handlers.handChoice(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local result, reason=require("abyss_hand_choice").begin(state,effect.mode,effect.value,queue)
    assert(result,reason)
    return result
end

function Handlers.effectBatch(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local queueCurlUp=c.helpers.queueCurlUp
    local queueStanceGains=c.helpers.queueStanceGains
    local context=assert(state.pendingPlay,"missing pending batch play")
    local target
    for _,enemy in ipairs(state.enemies) do if enemy.id==context.targetId then target=enemy;break end end
    M.applyEffects(state,effect.effects,state.player,target,state.cardInUse)
    queueCurlUp(state,queue);queueStanceGains(state,queue)
    return state.pendingDiscard and 'pause' or true
end

return Handlers
