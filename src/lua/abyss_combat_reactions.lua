-- Combat admission only. The caller owns draining and transaction boundaries.
local M={}
function M.enqueue(state, effect, source, target, instance, top)
    state.cardActions = state.cardActions or {}
    local item = {effect=effect, source=source or state.player, target=target, instance=instance}
    if top then table.insert(state.cardActions, 1, item) else state.cardActions[#state.cardActions+1] = item end
end

-- Damage/HP-loss callbacks join the queue that already owns the action.
-- This enqueues an effect, never a second action manager or a continuation.
function M.enqueueReaction(state,effect,top)
    if state.actionQueue then
        local queue=require('abyss_action_queue')
        local action={kind='effect',effect=effect}
        if top then queue.pushTop(state,action)else queue.pushBottom(state,action)end
    else M.enqueue(state,effect,nil,nil,nil,top)end
end
return M
