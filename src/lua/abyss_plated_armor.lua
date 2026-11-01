-- PlatedArmorPower and its three source actions. The host owns both queues.
local Events=require('abyss_events')
local Schedule=require('abyss_power_schedule')
local M={}
local ops={platedReduce=true,platedRemove=true,powerBlock=true,monsterChangeState=true}
function M.supports(op)return ops[op]==true end
function M.retained(effect)return effect.op=='powerBlock' end
local function active(actor)return actor and actor.hp>0 and not actor.escaped end
local function owner(state,id)
    if state.player.id==id then return state.player end
    for _,enemy in ipairs(state.enemies)do if enemy.id==id then return enemy end end
end
function M.hpLost(state,source,target,lost,normal,enqueue)
    if source and source~=target and normal and lost>0 and target.statuses.plated_armor~=nil then
        enqueue(state,{op='platedReduce',targetId=target.id,value=1})
    end
end
function M.preEndCards(state,actor,enqueue)
    if not active(actor)then return end
    for _,entry in ipairs(Schedule.list(actor,{plated_armor=true,metallicize=true}))do
        enqueue(state,{op='powerBlock',targetId=actor.id,value=entry.amount})
    end
end
function M.apply(combat,state,effect,enqueue)
    local target=owner(state,effect.targetId)
    if not target then return true end
    local op=effect.op
    if op=='powerBlock' then
        if active(target)then combat.block(state,target,effect.value,true)end
    elseif op=='monsterChangeState' then
        -- ChangeStateAction deliberately has no dead/escaped guard.
        combat.changeMonsterState(state,target,effect.stateName)
    elseif op=='platedReduce' then
        local amount=target.statuses.plated_armor
        -- Reduce itself has no life guard. Only RemoveSpecificPower does.
        if amount~=nil then
            if effect.value<amount then
                target.statuses.plated_armor=amount-effect.value
                local callbackBefore=#state.events
                Events.emit(state,'status',{source=target.id,target=target.id,status='plated_armor',amount=-effect.value})
                Events.onModifyPower(state,'ReducePowerAction.PlatedArmor',callbackBefore)
            else enqueue(state,{op='platedRemove',targetId=target.id},true)end
        end
    elseif op=='platedRemove' then
        if not active(target) or target.statuses.plated_armor==nil then return true end
        local amount=target.statuses.plated_armor
        -- onRemove observes the existing Power, and appends before deletion.
        if target~=state.player then
            enqueue(state,{op='monsterChangeState',targetId=target.id,stateName='ARMOR_BREAK'})
        end
        Schedule.remove(state,target,'plated_armor')
        target.statuses.plated_armor=nil
        local order={}
        for _,id in ipairs(target.powerOrder or {})do if id~='plated_armor'then order[#order+1]=id end end
        target.powerOrder=order
        local callbackBefore=#state.events
        Events.emit(state,'status',{source=target.id,target=target.id,status='plated_armor',amount=-amount})
        Events.onModifyPower(state,'RemoveSpecificPowerAction.PlatedArmor',callbackBefore)
    else error('unknown Plated action')end
    return true
end
return M
