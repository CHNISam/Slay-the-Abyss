-- Source-derived rules, independently implemented. Explicit opt-in combat subset.
local Actors = require('abyss_actor')
local Random = require('abyss_sts_random')
local Events = require('abyss_events')
local Focus = require('abyss_focus')
local M = {}
local kinds = {lightning=true, frost=true, dark=true, plasma=true}
local function integer(n) return type(n)=='number' and n==math.floor(n) and math.abs(n)<=2147483647 end
local function living(a)
    return Actors.isActive(a) and not a.halfDead and not a.isDying and not a.isEscaping
end
local function candidates(state)
    local out={}
    for _,a in ipairs(state.enemies) do if living(a) then out[#out+1]=a end end
    return out
end
local function apiReady(state,api,lightning)
    assert(api and type(api.damage)=='function' and type(api.block)=='function','missing orb combat API')
    if lightning then assert(state.cardRandomRng,'lightning requires independent cardRandomRng'); Random.snapshot(state.cardRandomRng) end
end
local function running(state)
    if not living(state.player)then return false end
    for _,enemy in ipairs(state.enemies)do if Actors.isPresent(enemy)then return true end end
    return false
end
local function container(state)
    local o=assert(state.orbs,'orbs not initialized')
    assert(integer(o.slots) and o.slots>=0 and o.slots<=10 and #o.balls<=o.slots,'invalid orb slots')
    Focus.sync(state)
    return o
end
function M.init(state,slots,options)
    assert(integer(slots) and slots>=0 and slots<=10,'invalid orb slots')
    assert(options==nil or (type(options)=='table' and next(options)==nil),'unsupported orb options')
    assert(state.orbs==nil,'orbs already initialized')
    Focus.ensureDefinitions(state)
    state.orbs={slots=slots,focus=Focus.value(state),balls={}}
    require('abyss_defect_engine_cards').initHistory(state)
    return state.orbs
end
function M.snapshot(state)
    local o=container(state)
    local result={slots=o.slots,focus=o.focus,balls={}}
    for i,b in ipairs(o.balls) do result.balls[i]={kind=b.kind,stored=b.stored} end
    return result
end
local function emit(state,kind,detail)
    detail=detail or {}; detail.orbs=M.snapshot(state)
    Events.emit(state,kind,detail)
end
function M.setFocus(state,value)
    assert(integer(value),'invalid focus')
    state.player.statuses.focus=value
    Focus.sync(state)
    container(state)
    emit(state,'orb_focus',{amount=value})
end
local function amount(state,b,evoke)
    if b.kind=='plasma' then return evoke and 2 or 1 end
    if b.kind=='dark' and evoke then return b.stored end
    local base=b.kind=='lightning' and (evoke and 8 or 3) or b.kind=='frost' and (evoke and 5 or 2) or 6
    return math.max(0,base+0.0+Focus.value(state))
end
-- Read-only values for the ordered orb HUD. Does not sync, roll, or queue work.
function M.view(state)
    local o=assert(state.orbs,"orbs not initialized")
    assert(integer(o.slots) and o.slots>=0 and o.slots<=10 and #o.balls<=o.slots,"invalid orb slots")
    local result={slots=o.slots,focus=Focus.value(state),balls={}}
    for i,b in ipairs(o.balls) do
        assert(kinds[b.kind],"invalid orb kind")
        result.balls[i]={kind=b.kind,passive=amount(state,b,false),evoke=amount(state,b,true)}
    end
    return result
end
-- Dark targets lock when its damage action is created; lightning chooses on resolution.
local function action(state,b,evoke)
    local a={kind=b.kind,amount=amount(state,b,evoke)}
    if b.kind=='lightning' then a.hitAll=(state.player.statuses.electrodynamics or 0)>0 end
    assert(integer(a.amount) and a.amount>=0,'orb amount overflow')
    if b.kind=='dark' then
        for _,enemy in ipairs(candidates(state)) do
            if not a.target or enemy.hp<a.target.hp then a.target=enemy end
        end
    end
    return a
end
-- Callers may prepare an action before resolving other queued work. Do not retarget Dark.
function M.prepareEvoke(state,remove,alreadyQueued)
    local o=container(state)
    assert(alreadyQueued==nil or alreadyQueued==true,'invalid prepared evoke flag')
    if not living(state.player) or not running(state) and not alreadyQueued or #o.balls==0 then return nil end
    local a=action(state,o.balls[1],true)
    if remove~=false then table.remove(o.balls,1) end
    return a
end
function M.resolve(state,a,api)
    if not a or not living(state.player) then return false end
    -- clearPostCombatActions retains queued GainBlockAction. This exception
    -- applies only to an action already created while combat was running.
    if a.kind~='frost' and not running(state) then return false end
    apiReady(state,api,a.kind=='lightning' and not a.hitAll)
    assert(kinds[a.kind] and integer(a.amount) and a.amount>=0,'invalid orb action')
    if a.kind=='frost' then api.block(state,state.player,a.amount,true)
    elseif a.kind=='plasma' then
        local energy=state.energy+0.0+a.amount
        assert(integer(energy) and energy>=0,'orb energy overflow')
        state.energy=energy
    else
        local target=a.target
        if a.kind=='lightning' and a.hitAll then
            local reactions={}
            for _,enemy in ipairs(candidates(state)) do
                api.damage(state,state.player,enemy,require('abyss_defect_engine_cards').orbDamage(enemy,a.amount),true,reactions)
            end
            Actors.resolveDamageReactions(state,reactions,api.retaliate)
        elseif a.kind=='lightning' then
            local enemies=candidates(state)
            assert(state.cardRandomRng,'lightning requires independent cardRandomRng')
            if #enemies>0 then target=enemies[Random.randomInt(state.cardRandomRng,#enemies-1)+1]end
        end
        if living(target) then api.damage(state,state.player,target,require('abyss_defect_engine_cards').orbDamage(target,a.amount),true) end
    end
    emit(state,'orb_effect',{orb=a.kind,amount=a.amount,target=a.target and a.target.id})
    return true
end
function M.evoke(state,api,alreadyQueued)
    local first=container(state).balls[1]
    apiReady(state,api,first and first.kind=='lightning' and (state.player.statuses.electrodynamics or 0)<=0 and running(state))
    if first and first.kind=='plasma' then assert(integer(state.energy+2.0),'orb energy overflow') end
    local a=M.prepareEvoke(state,true,alreadyQueued)
    return M.resolve(state,a,api)
end
function M.dualcast(state,api)
    local first=container(state).balls[1]
    apiReady(state,api,first and first.kind=='lightning' and (state.player.statuses.electrodynamics or 0)<=0 and running(state))
    if first and first.kind=='plasma' then assert(integer(state.energy+4.0),'orb energy overflow') end
    if not M.resolve(state,M.prepareEvoke(state,false),api) then return false end
    -- Resolve the first hit before constructing the second target-selection action.
    return M.evoke(state,api,true)
end
local function channel(state,kind,api,existing)
    assert(kinds[kind],'unsupported orb kind')
    local o=container(state)
    if o.slots==0 or not running(state) then return false end
    if #o.balls==o.slots then
        M.evoke(state,api)
        if not running(state) then return false end
    end
    o.balls[#o.balls+1]=existing or {kind=kind,stored=kind=='dark' and 6 or nil}
    require('abyss_defect_engine_cards').onChannel(state,kind)
    emit(state,'orb_channel',{orb=kind})
    return true
end
function M.channel(state,kind,api)return channel(state,kind,api)end
function M.rechannel(state,ball,api)
    assert(type(ball)=='table' and kinds[ball.kind],'invalid existing orb')
    return channel(state,ball.kind,api,ball)
end
-- Construct a passive action now, before queued Focus changes execute.
-- Dark is the exception: its stored damage grows synchronously in the hook.
function M.preparePassive(state,index,phase)
    assert(phase=='start' or phase=='end','invalid orb passive phase')
    local o=container(state)
    if not running(state) then return nil end
    local b=o.balls[index]
    if not b then return nil end
    assert(kinds[b.kind],'unsupported orb kind')
    if phase=='start' then
        if b.kind=='plasma' then return action(state,b,false) end
    elseif b.kind=='dark' then
        local stored=b.stored+0.0+amount(state,b,false)
        assert(integer(stored),'dark stored damage overflow')
        b.stored=stored
        emit(state,'orb_dark_growth',{amount=amount(state,b,false),index=index})
    elseif b.kind~='plasma' then return action(state,b,false) end
    return nil
end
function M.startTurn(state,api)
    apiReady(state,api,false)
    local o=container(state)
    local actions={}
    for _,b in ipairs(o.balls) do if b.kind=='plasma' then actions[#actions+1]=action(state,b,false) end end
    for _,a in ipairs(actions) do M.resolve(state,a,api) end
end
function M.endTurn(state,api)
    local o=container(state)
    if not running(state) then return end
    apiReady(state,api,false)
    for _,b in ipairs(o.balls) do
        if b.kind=='lightning' and (state.player.statuses.electrodynamics or 0)<=0 then apiReady(state,api,true) end
        if b.kind=='dark' then assert(integer(b.stored+0.0+amount(state,b,false)),'dark stored damage overflow') end
    end
    local actions={}
    for _,b in ipairs(o.balls) do
        if b.kind=='dark' then b.stored=b.stored+0.0+amount(state,b,false)
        elseif b.kind~='plasma' then actions[#actions+1]=action(state,b,false) end
    end
    for _,a in ipairs(actions) do M.resolve(state,a,api) end
    emit(state,'orb_end_turn')
end
-- Darkness+ triggers each existing Dark orb's passive immediately.
function M.darkImpulse(state)
    local o=container(state)
    if not running(state) then return false end
    for _,b in ipairs(o.balls) do
        if b.kind=='dark' then assert(integer(b.stored+0.0+amount(state,b,false)),'dark stored damage overflow') end
    end
    for _,b in ipairs(o.balls) do
        if b.kind=='dark' then b.stored=b.stored+0.0+amount(state,b,false) end
    end
    emit(state,'orb_dark_impulse')
    return true
end
function M.gainSlots(state,count)
    assert(integer(count) and count>=0,'invalid orb slot gain')
    local o=container(state)
    if not running(state) then return false end
    local before=o.slots
    o.slots=math.min(10,o.slots+0.0+count)
    if o.slots~=before then emit(state,'orb_slots',{amount=o.slots-before}) end
    return true
end
function M.loseSlots(state,count)
    assert(integer(count) and count>=0,'invalid orb slot loss')
    local o=container(state)
    if not running(state) then return false end
    local before=o.slots
    o.slots=math.max(0,o.slots-0.0-count)
    while #o.balls>o.slots do table.remove(o.balls) end
    if o.slots~=before then emit(state,'orb_slots',{amount=o.slots-before}) end
    return true
end
return M
