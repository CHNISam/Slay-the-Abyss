-- Continuation-owned damage operations. Return values preserve pause and early exits.
local Actors=require('abyss_actor')
local EnemyAI=require('abyss_enemy_ai')
local CardActions=require('abyss_card_actions')
local Handlers={}
function Handlers.wallop(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local queueCurlUp=c.helpers.queueCurlUp
    local target
    for _,enemy in ipairs(state.enemies) do if enemy.id==state.pendingPlay.targetId then target=enemy;break end end
    if Actors.isActive(target) then
        local reactions={}
        local lost=M.damage(state,state.player,target,effect.value,false,reactions,effect.normalAmount)
        if lost>0 then M.block(state,state.player,lost,true) end
        Actors.resolveDamageReactions(state,reactions,M.retaliate)
        queueCurlUp(state,queue)
    end
    return true
end

function Handlers.markLoseHp(c)
    local state=c.state
    local effect=c.effect
    for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId and Actors.isActive(enemy) then
            local before=enemy.hp;Actors.loseHp(state,enemy,effect.value)
            EnemyAI.hpLost(state,enemy,before,true)
            break
    end end
    return true
end

function Handlers.skewerHits(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    if effect.remaining>1 then
        queue.pushTop(state,{kind='effect',effect={op='skewerHits',value=effect.value,
                normalAmount=effect.normalAmount,remaining=effect.remaining-1}})
    end
    queue.pushTop(state,{kind='effect',effect={op='damage',value=effect.value,normalAmount=effect.normalAmount}})
    return true
end

function Handlers.applyLockOn(c)
    local state=c.state
    local effect=c.effect
    local context=assert(state.pendingPlay)
    local target
    for _,enemy in ipairs(state.enemies) do if enemy.id==(effect.targetId or context.targetId) then target=enemy;break end end
    if Actors.isActive(target) then
        if effect.op=='applyLockOn' then require('abyss_defect_engine_cards').applyLockOn(state,target,effect.value)
        else target.block=0 end
    end
    return true
end
Handlers.removeBlock=Handlers.applyLockOn

function Handlers.heelHook(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local context=assert(state.pendingPlay)
    local target
    for _,enemy in ipairs(state.enemies) do if enemy.id==context.targetId then target=enemy end end
    if target and (target.statuses.weak or 0)>0 then
        queue.pushBottom(state,{kind='effect',effect={op='energy',value=1}})
        queue.pushBottom(state,{kind='effect',effect={op='draw',value=1}})
    end
    queue.pushTop(state,{kind='effect',effect={op='damage',value=effect.value,normalAmount=effect.normalAmount}})
    return true
end

function Handlers.xBlockRounds(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    M.block(state,state.player,effect.value,true)
    if effect.remaining>1 then
        queue.pushTop(state,{kind='effect',effect={op='xBlockRounds',value=effect.value,remaining=effect.remaining-1}})
    end
    return true
end

function Handlers.combustDamage(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local owner={hp=1,statuses={}}
    for _,enemy in ipairs(state.enemies) do
        if Actors.isActive(enemy) then M.damage(state,owner,enemy,effect.value,true) end
    end
    return true
end
Handlers.statusFireDamage=Handlers.combustDamage

function Handlers.resolveCurlUp(c)
    local state=c.state
    local effect=c.effect
    for _,enemy in ipairs(state.enemies) do
        if enemy.id==effect.targetId then Actors.resolveCurlUp(state,enemy,effect.value);break end
    end
    return true
end

function Handlers.heal(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local event=c.helpers.event
    if effect.relic then
        return CardActions.apply(M,state,{effect=effect,source=state.player})
    end
    -- A source-verified Reaper continuation, not a public card effect ABI.
    local value=effect.value
    assert(type(value)=="number" and value%1==0 and value>=0 and value<=2147483647,"invalid heal amount")
    local player=state.player;if require('abyss_potion_health').blocked(state.relics)then value=0 end
    local before=player.hp
    player.hp=math.min(player.maxHp,player.hp+0.0+value)
    event(state,"heal",{source=player.id,target=player.id,amount=player.hp-before})
    return true
end

return Handlers
