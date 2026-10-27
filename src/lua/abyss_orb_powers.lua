-- Source-derived subset: stable same-priority Loop/Bias hooks and Electro.
local Actors=require('abyss_actor')
local Orbs=require('abyss_orbs')
local Focus=require('abyss_focus')
local Events=require('abyss_events')
local M={}
local MAX=2147483647
local function integer(n) return type(n)=='number' and n==math.floor(n) and n>=0 and n<=MAX end
local function live(state)
    if not Actors.isActive(state.player) then return false end
    for _,enemy in ipairs(state.enemies) do if Actors.isPresent(enemy) then return true end end
    return false
end
local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
function M.withCards(data)
    local result=copy(data)
    local ids={};for _,c in ipairs(result.cards.cards) do ids[c.id]=true end
    for _,id in ipairs({'loop','electrodynamics'}) do assert(not ids[id],'orb power card already defined') end
    result.cards.cards[#result.cards.cards+1]={id='loop',sourceId='Loop',name='循环',type='power',rarity='uncommon',cost=1,
        effects={{op='gainOrbPower',status='loop',value=1}},upgrade={effects={{op='gainOrbPower',status='loop',value=2}}}}
    local function electro(count)
        local out={{op='gainOrbPower',status='electrodynamics',value=1}}
        for _=1,count do out[#out+1]={op='channelOrb',orb='lightning',value=1} end
        return out
    end
    result.cards.cards[#result.cards.cards+1]={id='electrodynamics',sourceId='Electrodynamics',name='电动力学',type='power',rarity='rare',cost=2,
        effects=electro(2),upgrade={effects=electro(3)}}
    local present={};for _,s in ipairs(result.statuses.statuses) do present[s.id]=true end
    assert(not present.loop and not present.electrodynamics,'orb power status already defined')
    result.statuses.statuses[#result.statuses.statuses+1]={id='loop',name='循环',kind='buff',stack='intensity',decay='none',
        description='每个玩家回合开始，使最前方充能球额外触发与层数相同次数的被动。'}
    result.statuses.statuses[#result.statuses.statuses+1]={id='electrodynamics',name='电动力学',kind='buff',stack='none',decay='none',
        description='闪电球的被动与唤起改为对所有存活敌人生效。'}
    return result
end
function M.recordApplied(state,id)
    assert(id=='loop' or id=='bias','unknown ordered orb power')
    assert((state.player.statuses[id] or 0)>0,'record requires successful Power application')
    local order=state.orbPowerOrder
    if not order then order={};state.orbPowerOrder=order end
    for _,known in ipairs(order) do if known==id then return end end
    order[#order+1]=id
end
function M.apply(state,id,value)
    assert(state.orbs,'orb powers require enabled orbs')
    assert((id=='loop' and (value==1 or value==2)) or (id=='electrodynamics' and value==1),'unsupported orb power application')
    if not live(state) then return false end
    local current=state.player.statuses[id] or 0
    assert(integer(current) and integer(current+0.0+value),'orb Power stack overflow')
    local applied=Actors.applyPower(state,state.player,id,value,state.player)
    if applied and id=='loop' then M.recordApplied(state,id) end
    return applied
end
local function orderOf(state)
    local result,seen={},{}
    for _,id in ipairs(state.orbPowerOrder or {}) do
        assert((id=='loop' or id=='bias') and not seen[id],'invalid orb Power order')
        seen[id]=true;result[#result+1]=id
    end
    local missing={}
    for _,id in ipairs({'loop','bias'}) do if (state.player.statuses[id] or 0)>0 and not seen[id] then missing[#missing+1]=id end end
    -- An old raw Bias fixture may have no registration history. One unique
    -- Power is unambiguous; two with missing history must not be guessed.
    if #missing>0 then
        assert(#missing==1 and #result==0,'unknown Loop/Bias acquisition order')
        result[1]=missing[1]
    end
    return result
end
-- Construct a selected Power slot, ordinary orb hooks, or the legacy full set.
-- Dark growth is intentionally synchronous; queued actions contain no actors.
function M.prepareStart(state,slot)
    assert(slot==nil or slot=='loop' or slot=='bias' or slot=='orbs','invalid orb start slot')
    if slot~='bias' then assert(state.orbs,'orb powers require enabled orbs') end
    local actions={}
    if not live(state) then return actions end
    if (slot=='bias' or slot=='loop') and rawget(state.player.statuses,slot)==nil then return actions end
    local function passive(index,phase)
        local a=Orbs.preparePassive(state,index,phase)
        if a then
            local data={}
            for k,v in pairs(a) do if k~='target' then data[k]=v end end
            if a.target then data.targetId=a.target.id end
            actions[#actions+1]={kind='effect',effect={op='orbStart',action=data}}
        end
    end
    local ids=slot and (slot=='orbs' and {} or {slot}) or orderOf(state)
    for _,id in ipairs(ids) do
        local count=state.player.statuses[id] or 0
        assert(integer(count),'invalid orb Power count')
        if id=='bias' and (slot~=nil or count>0) then
            actions[#actions+1]={kind='effect',effect={op='gainStatus',status='focus',value=-count}}
        elseif id=='loop' and count>0 then
            for _=1,count do
                for _,phase in ipairs({'start','end'}) do passive(1,phase) end
            end
        end
    end
    -- Normal orb start-of-turn hooks follow the Power hooks, still pre-draw.
    if slot==nil or slot=='orbs' then
        for index=1,#state.orbs.balls do passive(index,'start') end
    end
    return actions
end
-- Compatibility host: preparation remains separate from execution so every
-- Loop passive observes the old Focus before any queued Bias change resolves.
function M.startTurnPower(state,api)
    assert(state.orbs,'orb powers require enabled orbs')
    if not live(state) then return false end
    local actions=M.prepareStart(state)
    for _,entry in ipairs(actions) do
        if not Actors.isActive(state.player) then break end
        local effect=entry.effect
        if effect.op=='gainStatus' then
            if live(state) then Focus.apply(state,state.player,effect.value,state.player) end
        else
            local action=copy(effect.action)
            if action.targetId then
                for _,enemy in ipairs(state.enemies) do if enemy.id==action.targetId then action.target=enemy;break end end
                action.targetId=nil
            end
            Orbs.resolve(state,action,api)
        end
    end
    Events.emit(state,'orb_start_turn_powers',{count=#actions})
    return true
end
return M
