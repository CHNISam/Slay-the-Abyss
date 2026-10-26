-- Fixed 319009 Focus/Bias rules. Player statuses are the only numeric truth.
local Events=require('abyss_events')
local M={}
local function integer(n) return type(n)=='number' and n==math.floor(n) and math.abs(n)<=2147483647 end
local templates={
    focus={name='集中',kind='buff',description='每层提高闪电球伤害、冰霜球格挡和黑暗球的储伤增长；负层数降低这些数值，等离子球的能量不受影响'},
    bias={name='偏差',kind='debuff',description='每个你的回合开始，失去与层数相同的集中；每次失去可由一层人工制品抵挡'},
}
local function definition(id)
    local out={id=id,stack='intensity',decay='none'}
    for k,v in pairs(templates[id]) do out[k]=v end
    return out
end
local function complete(def,id)
    for k,v in pairs(templates[id]) do if def[k]==nil then def[k]=v end end
end
function M.ensureDefinitions(state)
    local defs=assert(state.catalog and state.catalog.statuses,'missing status catalog')
    for _,id in ipairs({'focus','bias'}) do
        if defs[id] then
            assert(defs[id].id==id and defs[id].stack=='intensity' and defs[id].decay=='none','incompatible '..id..' definition')
        else defs[id]=definition(id) end
        complete(defs[id],id)
        for _,actor in ipairs({state.player}) do
            if actor.statusDefinitions and actor.statusDefinitions~=defs then
                if not actor.statusDefinitions[id] then actor.statusDefinitions[id]=definition(id) end
                complete(actor.statusDefinitions[id],id)
            end
        end
    end
end
function M.value(state)
    local value=state.player.statuses.focus
    assert(value==nil or integer(value),'invalid focus')
    return value or 0
end
function M.sync(state)
    local value=M.value(state)
    if state.orbs then state.orbs.focus=value end
    return value
end
function M.remove(state)
    local player=state.player
    if not require('abyss_actor').isActive(player) then return false end
    if player.statuses.focus==nil then M.sync(state);return false end
    local before=player.statuses.focus
    player.statuses.focus=nil
    M.sync(state)
    Events.emit(state,'status_removed',{source=player.id,target=player.id,status='focus',amount=-before})
    return true
end
function M.apply(state,actor,amount,source)
    local Actors=require('abyss_actor')
    if not Actors.isActive(actor) then return false end
    assert(integer(amount),'invalid focus amount')
    M.ensureDefinitions(state)
    local before=actor.statuses.focus
    assert(before==nil or integer(before),'invalid focus')
    if amount<=0 and Actors.tryBlockDebuff(state,actor,'focus') then return false end
    local value=amount
    if before~=nil then
        -- Arithmetic is binary64 before source clamp, not Fengari signed32 wrap.
        value=math.max(-999,math.min(999,before+0.0+amount))
    end
    actor.statuses.focus=value
    if actor==state.player then M.sync(state) end
    Events.emit(state,'status',{source=(source or actor).id,target=actor.id,status='focus',amount=value-(before or 0)})
    -- Source queues TOP removal at exact-zero stack. Current action boundary
    -- has no intervening callbacks, so remove before the next mapped action.
    if before~=nil and value==0 then
        if actor==state.player then M.remove(state)
        else
            actor.statuses.focus=nil
            Events.emit(state,'status_removed',{source=actor.id,target=actor.id,status='focus',amount=0})
        end
    end
    return true
end
function M.startTurn(state,_api)
    local Actors=require('abyss_actor')
    if not Actors.isActive(state.player) then return false end
    local bias=state.player.statuses.bias or 0
    assert(integer(bias) and bias>=0,'invalid bias')
    if bias==0 then return false end
    -- One incoming negative Power per tick, even if Bias has multiple stacks.
    return Actors.applyPower(state,state.player,'focus',-bias,state.player)
end
return M
