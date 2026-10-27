-- Continuation-owned powers operations. Return values preserve pause and early exits.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local EnemyAI=require('abyss_enemy_ai')
local Handlers={}
function Handlers.darklingAction(c)
    require('abyss_darklings').resolve(c.state,c.effect);return true
end
function Handlers.reptomancerSuicide(c)
    return require('abyss_reptomancer').cleanup(Actors,c.state,c.effect)
end
function Handlers.timeEater(c)
    return require('abyss_time_eater').execute(c.combat,c.state,c.effect,c.state.player,require('abyss_card_actions'))
end
function Handlers.orbStart(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local copy=c.helpers.copy
    local prepared=copy(effect.action)
    if prepared.targetId then
        for _,enemy in ipairs(state.enemies) do if enemy.id==prepared.targetId then prepared.target=enemy;break end end
        prepared.targetId=nil
    end
    require('abyss_orbs').resolve(state,prepared,M);return true
end

function Handlers.turnPoison(c)
    local state=c.state
    local effect=c.effect
    for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId and Actors.isActive(enemy) then
            local value=enemy.statuses.poison~=nil and effect.value or effect.newPowerAmount
            Actors.applyPower(state,enemy,'poison',value,state.player,nil,effect.poisonBonus);break
    end end
    return true
end

function Handlers.removeStatus(c)
    local state=c.state
    local effect=c.effect
    local event=c.helpers.event
    local target=state.player
    if effect.targetId and effect.targetId~=target.id then
        target=nil
        for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId then target=enemy;break end end
    end
    if target and target.statuses[effect.status]~=nil then
        if effect.op=='reduceStatus' or effect.op=='reduceFlowPower' then
            local value=target.statuses[effect.status]-effect.value
            if value>0 then target.statuses[effect.status]=value;return true end
        end
        local removed=target.statuses[effect.status]
        require('abyss_power_schedule').remove(state,target,effect.status)
        target.statuses[effect.status]=nil
        event(state,'status_removed',{source=target.id,target=target.id,status=effect.status,amount=-removed})
    end
    return true
end
Handlers.reduceStatus=Handlers.removeStatus
Handlers.removeFlowPower=Handlers.removeStatus
Handlers.reduceFlowPower=Handlers.removeStatus

function Handlers.loseEnergy(c)
    local state=c.state
    local effect=c.effect
    state.energy=math.max(0,state.energy-effect.value);return true
end

function Handlers.gainWatcherFlowPower(c)
    local state=c.state
    local effect=c.effect
    local target=state.player
    if effect.op~='gainWatcherFlowPower' then
        target=nil
        local id=effect.targetId or state.pendingPlay and state.pendingPlay.targetId
        for _,enemy in ipairs(state.enemies) do if enemy.id==id then target=enemy;break end end
    end
    if Actors.isActive(target) then
        if effect.op=='applyFlowStatus' then Actors.applyPower(state,target,effect.status,effect.value,state.player)
        elseif Actors.artifactBlocksPower(target,effect.status,effect.value) then Actors.tryBlockDebuff(state,target,effect.status)
        else
            local plan=require('abyss_watcher_flow_cards').applicationPlan(state,target,effect.status,effect.value)
            if Actors.applyPower(state,target,effect.status,plan.incoming,state.player) then
                target.statuses[effect.status]=plan.after
                state.events[#state.events].frame=Events.frame(state)
            end
        end
    end
    return true
end
Handlers.applyWatcherFlowPower=Handlers.gainWatcherFlowPower
Handlers.applyFlowStatus=Handlers.gainWatcherFlowPower

function Handlers.gainCardTriggerPower(c)
    local state=c.state
    local effect=c.effect
    require('abyss_card_triggers').apply(state,effect.status,effect.value);return true
end

function Handlers.cardTriggerStorm(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    for _,nextAction in ipairs(require('abyss_card_triggers').expandStorm(state,effect)) do queue.pushTop(state,nextAction) end
    return true
end

function Handlers.cardTriggerPoison(c)
    local state=c.state
    local effect=c.effect
    require('abyss_card_triggers').resolveEnvenom(state,effect);return true
end

function Handlers.cardTriggerDamageAll(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    require('abyss_card_triggers').resolveDamageAll(state,effect,M);return true
end

function Handlers.removeCardTriggerPower(c)
    local state=c.state
    local effect=c.effect
    require('abyss_card_triggers').removePower(state,effect.status);return true
end

function Handlers.onUseReactions(c)
    local state=c.state
    EnemyAI.afterCard(state,assert(state.pendingPlay).reactions);return true
end

function Handlers.capturedSharpHide(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    M.capturedSharpHide(state,effect);return true
end

function Handlers.gainStrengthPower(c)
    local state=c.state
    local effect=c.effect
    require('abyss_warrior_strength_cards').applyPower(state,effect.status,effect.value)
    return true
end

function Handlers.gainStatusPower(c)
    local state=c.state
    local effect=c.effect
    require('abyss_warrior_status_cards').applyPower(state,effect.status,effect.value);return true
end

function Handlers.removeStatusPower(c)
    local state=c.state
    local effect=c.effect
    require('abyss_power_schedule').remove(state,state.player,effect.status)
    state.player.statuses[effect.status]=nil;return true
end

function Handlers.evokeOrb(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local orbs=require('abyss_orbs')
    local prepared=orbs.prepareEvoke(state,effect.op=='evokeOrb',true)
    orbs.resolve(state,prepared,M)
    return true
end
Handlers.evokeWithoutRemovingOrb=Handlers.evokeOrb

function Handlers.spotWeakness(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local build=require('abyss_build_actions')
    local context=assert(state.pendingPlay)
    for _,target in ipairs(state.enemies) do
        if target.id==context.targetId and build.isAttacking(target) then
            queue.pushBottom(state,{kind='effect',effect={op='gainStatus',status='strength',value=effect.value}})
        end
    end
    return true
end

function Handlers.nextEnergy(c)
    local state=c.state
    local effect=c.effect
    local build=require('abyss_build_actions')
    build.applyNextEnergy(state,effect.value,effect.status);return true
end

function Handlers.nextBlock(c)
    local state=c.state
    local effect=c.effect
    require('abyss_silent_attack_cards').applyNextBlock(state,effect.value);return true
end

function Handlers.removeNextEnergy(c)
    local state=c.state
    local effect=c.effect
    state.player.statuses[effect.status]=nil;return true
end

function Handlers.postDrawPoison(c)
    local M=c.combat
    local state=c.state
    require('abyss_poison').postDraw(state,M);return true
end

function Handlers.voidEnergy(c)
    local state=c.state
    local effect=c.effect
    state.energy=math.max(0,state.energy-effect.value);return true
end

function Handlers.applyMantra(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local ok,reason=require("abyss_mantra").apply(state,effect.value,queue,effect.nullSource)
    assert(ok,reason);return true
end

function Handlers.removeMantra(c)
    local state=c.state
    return require("abyss_mantra").remove(state)
end

return Handlers
