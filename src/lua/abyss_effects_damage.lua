-- Synchronous damage operations. No continuation-queue ownership is transferred here.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local M={}
function M.damage(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local target=context.target
    local op=context.effect.op
    local value=context.effect.value
    local targets=context.targets
    local dealt=context.dealt
    local selected = op == "damageAll" and targets(state, source) or { target }
    for _ = 1, effect.times or 1 do
        local retaliation = op == "damageAll" and {} or nil
        for _, victim in ipairs(selected) do
            -- Both callers capture NORMAL output; retain the older
            -- per-target resolved ABI alongside class queue snapshots.
            local snapshot=effect.normalAmount
            if snapshot==nil and effect.normalAmounts then snapshot=effect.normalAmounts[victim.id] end
            if snapshot==nil and effect.resolved then snapshot=effect.resolved[victim.id] end
            dealt = dealt + combat.damage(state, source, victim, value, effect.fixed, retaliation,snapshot)
        end
        -- Angry, Thorns and death powers add reactions to the top:
        -- finish this area hit, then resolve in reverse target order.
        if retaliation then
            Actors.resolveDamageReactions(state, retaliation, combat.retaliate)
        end
        if combat.outcome(state) then break end
    end
    return dealt
end
M.damageAll=M.damage

function M.damageEqualToBlock(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local target=context.target
    local dealt=context.dealt
    -- Current block is the attack base, not a payment or fixed damage.
    dealt = dealt + combat.damage(state, source, target, source.block,nil,nil,effect.resolved and effect.resolved[target.id])
    return dealt
end

function M.conditional(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local target=context.target
    local playedCard=context.playedCard
    local dealt=context.dealt
    -- Damage leaves the target's statuses intact, even on a lethal hit.
    -- The outer source-alive guard still stops thorns-killed attackers.
    assert(effect["if"] == "target_vulnerable" or effect['if']=='target_poison', "unsupported condition")
    local status=effect['if']=='target_poison' and 'poison' or 'vulnerable'
    if target and (target.statuses[status] or 0) > 0 then
        dealt = dealt + context.interpreter.apply(combat, state, effect["then"], source, target, playedCard)
    end
    return dealt
end

function M.loseHp(context)
    local state=context.state
    local source=context.source
    local value=context.effect.value
    -- HP payment is not an attack or a status tick. The next effect's
    -- source-alive guard stops the card when this payment is lethal.
    local before = source.hp
    if (source.statuses.intangible or 0)>0 then value=math.min(value,1) end
    value=require('abyss_defect_final_cards').incoming(state,source,value)
    if source==state.player then value=require('abyss_relic_hooks').onLoseHpLast(state,value) end
    source.hp = math.max(0, source.hp - value)
    Events.emit(state, "hp_loss", {source = source.id, target = source.id, amount = before - source.hp, blocked = 0})
    -- Actor owns the single HP-loss notification for either queue.
    Actors.hpLostFromCard(state,source,before-source.hp)
    require('abyss_relic_hooks').hpChanged(state,source,before)
end

return M
