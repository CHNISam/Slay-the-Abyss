-- Notify actual player HP loss once, irrespective of attack/payment/status.
-- Damage provenance stays explicit: unknown/null owners cannot trigger Rupture.
local M={}
function M.notify(state,owner,target,amount)
    if target~=state.player or amount<=0 then return end
    if state.originalV4 then require('abyss_original_v4_health').hpEvent(state,amount) end
    require('abyss_warrior_status_cards').onHpLost(state,amount)
    require('abyss_silent_final_cards').onHpLost(state)
    if state.player.hp<=0 then
        require('abyss_potion_fairy').fatal(state)
        return
    end
    local plan=require('abyss_warrior_strength_cards').planHpLost(state,owner,amount)
    if state.actionQueue then
        local queue=require('abyss_action_queue')
        for _,action in ipairs(plan.top) do queue.pushTop(state,action) end
    else
        for _,action in ipairs(plan.top) do
            require('abyss_actor').applyPower(state,state.player,action.effect.status,action.effect.value,state.player)
        end
    end
end
return M
