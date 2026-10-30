-- Source-derived stance semantics; shared combat owns damage and turn ordering.
local Events = require("abyss_events")
local M = {}
local valid = {Neutral=true, Wrath=true, Calm=true, Divinity=true}
local amounts = {violet_lotus=1, calm_exit=2, divinity_enter=3}
local powerKinds = {rushdown="draw",mental_fortress="block"}
local function integer(x)
    return type(x)=="number" and x==x and x%1==0 and x>=0 and x<=2147483647
end
local function player(state)
    assert(type(state)=="table" and type(state.player)=="table", "missing stance player")
    assert(valid[state.player.stance or "Neutral"], "invalid current stance")
    return state.player
end
local function queueTotal(state)
    local q, total = state.stanceQueue or {}, 0.0
    assert(type(q)=="table", "invalid stance queue")
    local n=0
    for k,e in pairs(q) do
        assert(type(k)=="number" and k%1==0 and k>=1 and k<=#q, "invalid stance queue index")
        assert(type(e)=="table" and integer(e.amount), "invalid stance queue event")
        if powerKinds[e.reason] then
            assert(e.kind==powerKinds[e.reason] and e.amount>0,"invalid stance power event")
        else
            assert(amounts[e.reason]~=nil and amounts[e.reason]==e.amount and e.kind==nil, "invalid stance energy event")
            total=total+e.amount
        end
        n=n+1
    end
    assert(n==#q, "sparse stance queue")
    return total
end
local function orderedPowers(state)
    local order,seen,n=state.stancePowerOrder or {},{},0
    assert(type(order)=="table" and type(state.player.statuses)=="table","invalid stance power state")
    for k,id in pairs(order) do
        assert(type(k)=="number" and k%1==0 and k>=1 and k<=#order,"invalid stance power index")
        assert(powerKinds[id] and not seen[id],"unknown or duplicate stance power order")
        seen[id]=true;n=n+1
    end
    assert(n==#order,"sparse stance power order")
    for id in pairs(powerKinds) do
        local value=state.player.statuses[id] or 0
        assert(integer(value),"invalid stance power amount")
        assert(value==0 or seen[id],"active stance power missing acquisition order")
    end
    return order
end
local function active(state)
    return state.player.hp>0 and state.phase~="victory" and state.phase~="defeat"
end
local function optionsOf(options)
    options=options or {}
    assert(type(options)=="table", "invalid stance options")
    for k,v in pairs(options) do
        assert((k=="cannotChange" or k=="violetLotus") and type(v)=="boolean", "invalid stance option")
    end
    return options
end

-- This is the ChangeStance action, not its caller's entire effect list. Energy
-- gains are appended, never executed recursively inside the stance transition.
function M.change(state, id, options)
    local p=player(state)
    assert(valid[id], "invalid destination stance")
    local opts=optionsOf(options)
    assert(integer(p.hp) and integer(state.energy), "invalid stance combat state")
    local pending=queueTotal(state)
    local powerOrder=orderedPowers(state)
    if not active(state) or opts.cannotChange then return false end
    if id==(p.stance or "Neutral") then
        Events.onModifyPower(state,'ChangeStanceAction',#state.events)
        return false -- Preserve the existing "stance actually changed" result.
    end
    assert(type(state.events)=="table", "missing combat events")
    local old=p.stance or "Neutral"
    local gains={}
    for _,power in ipairs(powerOrder) do
        local amount=p.statuses[power] or 0
        if amount>0 and (power~="rushdown" or id=="Wrath") then
            gains[#gains+1]={reason=power,kind=powerKinds[power],amount=amount}
        end
    end
    if old=="Calm" and opts.violetLotus then gains[#gains+1]={reason="violet_lotus",amount=1} end
    if old=="Calm" then gains[#gains+1]={reason="calm_exit",amount=2} end
    if id=="Divinity" then gains[#gains+1]={reason="divinity_enter",amount=3} end
    local total=state.energy+0.0+pending
    for _,e in ipairs(gains) do if not e.kind then total=total+e.amount end end
    assert(integer(total), "stance energy overflow")
    p.stance=id
    p.stanceKnown=true
    state.stanceQueue=state.stanceQueue or {}
    for _,e in ipairs(gains) do state.stanceQueue[#state.stanceQueue+1]=e end
    local callbackBefore=#state.events
    Events.emit(state,"stance",{from=old,to=id})
    Events.onModifyPower(state,'ChangeStanceAction',callbackBefore)
    local plan=require('abyss_watcher_flow_cards').planStanceChange(state,old,id)
    if #plan.bottom>0 then
        state.stanceCardQueue=state.stanceCardQueue or {}
        for _,effect in ipairs(plan.bottom) do state.stanceCardQueue[#state.stanceCardQueue+1]=effect end
    end
    return true
end

-- Invoke at the owning combat action queue's BOTTOM boundaries. The current
-- core has no general action scheduler: integration must not flush early when
-- card effects already waiting ahead of these gains have yet to execute.
function M.flush(state, api)
    player(state)
    assert(integer(state.energy), "invalid stance energy")
    local total=queueTotal(state)
    if not active(state) then state.stanceQueue=nil; return 0 end
    assert(integer(state.energy+0.0+total), "stance energy overflow")
    assert(type(state.events)=="table", "missing combat events")
    local queue=state.stanceQueue or {}
    for _,e in ipairs(queue) do
        if e.kind then assert(type(api)=="table" and type(api[e.kind])=="function","stance power needs combat "..e.kind) end
    end
    state.stanceQueue=nil
    for _,e in ipairs(queue) do
        if e.kind=="draw" then
            api.draw(state,e.amount)
        elseif e.kind=="block" then
            api.block(state,state.player,e.amount,true)
        else
            state.energy=state.energy+e.amount
            Events.emit(state,"energy",{amount=e.amount,reason=e.reason})
        end
    end
    local recalls=state.stanceCardQueue;state.stanceCardQueue=nil
    for _,effect in ipairs(recalls or {}) do
        local plan=require('abyss_watcher_flow_cards').planEffect(state,effect)
        require('abyss_flow_actions').enqueue(state,plan)
    end
    return total
end

function M.startTurn(state, options)
    local p=player(state)
    if p.stance=="Divinity" then return M.change(state,"Neutral",options) end
    return false
end

-- Apply at the shared Actor.attackAmount modifier stage, before its final floor.
-- Never pre-multiply base damage (that would incorrectly multiply Strength).
function M.damageMultiplier(state, source, target, fixed)
    local p=player(state)
    assert(type(source)=="table" and type(target)=="table", "invalid stance damage actors")
    assert(fixed==nil or type(fixed)=="boolean", "invalid stance damage type")
    if fixed then return 1 end
    local n=1
    if source==p then
        if p.stance=="Wrath" then n=2 elseif p.stance=="Divinity" then n=3 end
    end
    if target==p and p.stance=="Wrath" then n=n*2 end
    return n
end

function M.reset(state)
    local p=player(state)
    p.stance="Neutral"
    state.stanceQueue=nil
    state.stancePowerOrder=nil
    if p.statuses then p.statuses.rushdown=nil;p.statuses.mental_fortress=nil end
end

return M
