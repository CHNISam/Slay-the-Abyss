-- Opt-in class plans share a data continuation ABI. Combat owns transactions.
local M={}
local modules={require('abyss_warrior_status_cards'),require('abyss_defect_engine_cards'),
    require('abyss_watcher_flow_cards'),require('abyss_silent_tactics_cards')}
local internal={engineRandomRounds=modules[2],engineChannelRounds=modules[2],
    engineEvokeRounds=modules[2],engineSunderRefund=modules[2],recallFlowCard=modules[3]}
M.ops={}
for _,module in ipairs(modules) do for op in pairs(module.ops or {}) do
    assert(not M.ops[op],'duplicate class action');M.ops[op]=module
end end
local function copyInto(target,source)
    for key in pairs(target) do if source[key]==nil then target[key]=nil end end
    for key,value in pairs(source) do
        if type(value)=='table' then
            if type(target[key])~='table' then target[key]={} end
            copyInto(target[key],value)
        else target[key]=value end
    end
end
function M.commitRng(state,after)
    if not after then return end
    require('abyss_sts_random').snapshot(after)
    assert(state.cardRandomRng,'missing card random state')
    copyInto(state.cardRandomRng,after)
end
function M.prepare(state,effect,target,context)
    local module=M.ops[effect.op]
    if not module then return effect end
    local prepared,after=module.prepareEffect(state,effect,target,context)
    M.commitRng(state,after)
    return prepared
end
function M.plan(state,effect,context)
    local module=M.ops[effect.op] or internal[effect.op]
    if not module then return nil end
    return module.planEffect(state,effect,context)
end
function M.instance(state,uid)
    local found
    for _,name in ipairs({'hand','draw','discard','exhaust'}) do
        for _,card in ipairs(state[name]) do if card.uid==uid then assert(not found,'duplicate instance UID');found=card end end
    end
    if state.cardInUse and state.cardInUse.uid==uid then assert(not found,'duplicate in-use UID');found=state.cardInUse end
    return assert(found,'missing planned card instance')
end
local fields={engineClawBonus=true,engineBlockLoss=true,combatCost=true,turnCost=true}
local function action(value)
    if value.kind then return value end
    return {kind='effect',effect=value}
end
function M.enqueue(state,plan,queue)
    local changes={}
    for _,entry in ipairs(plan.instanceChanges or {}) do
        local card=M.instance(state,entry.uid)
        for key,value in pairs(entry.changes) do
            assert(fields[key] and type(value)=='number' and value%1==0 and value>=0 and value<=2147483647,'invalid instance change')
        end
        changes[#changes+1]={card=card,values=entry.changes}
    end
    for _,entry in ipairs(changes) do for key,value in pairs(entry.values) do entry.card[key]=value end end
    M.commitRng(state,plan.cardRandomRng)
    if plan.consumeAllEnergy and not (state.pendingPlay and state.pendingPlay.freeToPlayOnce)then state.energy=0 end
    if plan.move then
        local move=plan.move
        assert(move.from=='discard' and move.to=='hand' and move.handHook==false,'unsupported planned movement')
        if #state.hand<state.rules.player.maxHand then
            for i,card in ipairs(state.discard) do if card.uid==move.uid then
                assert(card.cardId==move.cardId,'stale planned movement')
                table.remove(state.discard,i);state.hand[#state.hand+1]=card;break
            end end
        end
    end
    for i=#(plan.top or {}),1,-1 do queue.pushTop(state,action(plan.top[i])) end
    for _,value in ipairs(plan.bottom or {}) do queue.pushBottom(state,action(value)) end
end
return M
