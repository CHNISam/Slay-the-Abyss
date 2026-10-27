-- Notify actual player HP loss once, irrespective of attack/payment/status.
-- Damage provenance stays explicit: unknown/null owners cannot trigger Rupture.
local M={}
-- These callbacks can insert TOP actions while a card effect is running.
-- Keep source action boundaries until the one-shot relic has been consumed;
-- ordinary cards and a used Puzzle retain the existing batching fast path.
function M.requiresQueue(state)
    local combat=state.relicCombat
    return (state.player.statuses.rupture or 0)>0 or combat~=nil and not combat.centennialUsed
        and require('abyss_relic_hooks').owns(state,'centennial_puzzle')
end
function M.notify(state,owner,target,amount)
    if target~=state.player or amount<=0 then return end
    if state.originalV4 then require('abyss_original_v4_health').hpEvent(state,amount) end
    require('abyss_warrior_status_cards').onHpLost(state,amount)
    if state.player.hp<=0 then
        require('abyss_potion_fairy').fatal(state)
        return
    end
    local plan=require('abyss_warrior_strength_cards').planHpLost(state,owner,amount)
    -- Powers dispatch before relics. Both callbacks insert TOP actions, so
    -- a later Puzzle Draw must run before Rupture's ApplyPower, on either owner.
    for _,action in ipairs(plan.top) do
        require('abyss_card_actions').enqueueReaction(state,action.effect,true)
    end
end
return M
