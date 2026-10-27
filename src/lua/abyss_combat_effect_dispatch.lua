-- Dispatch only; synchronization and queue ownership remain in Combat.
local Actors=require('abyss_actor')
local PlatedArmor=require('abyss_plated_armor')
local Act2Powers=require('abyss_act2_powers')
local Awakened=require('abyss_awakened_one')
local CardActions=require('abyss_card_actions')
local Damage=require('abyss_combat_effect_damage')
local handlers={}
for _,group in ipairs({Damage,require('abyss_combat_effect_choice'),require('abyss_combat_effect_powers'),require('abyss_combat_effect_cards')})do
    for op,handler in pairs(group)do handlers[op]=handler end
end
local Handlers={}
local function endingReactions(combat,state,effect)
    if effect.op=='heartBeat'then return true,combat.heartBeat(state,effect)end
    if effect.op=='spireDeathRemove'then return true,Actors.removeSpireDeathPower(state,effect)end
    return false
end
local function reactions(c)
    local M,state,action,queue=c.combat,c.state,c.action,c.queue
    local ending,result=endingReactions(M,state,action.effect)
    if ending then return true,result end
    if action.effect.op=='awakenedAction'then
        Awakened.resolve(Actors,state,action.effect)
        return true,true
    end
    if action.effect.op=='staticRetaliation'then return true,M.staticRetaliation(state,action.effect)end
    if PlatedArmor.supports(action.effect.op)then
        return true,PlatedArmor.apply(M,state,action.effect,CardActions.enqueueReaction)
    end
    if Act2Powers.supports(action.effect.op)then return true,Act2Powers.apply(Actors,state,action.effect)end
    if action.effect.op=='discover'then
        require('abyss_potion_discovery').begin(M,state,action.effect)
        return true,'pause'
    end
    if action.effect.op=='potionStanceChoice'then return true,require('abyss_potion_stance').begin(state)end
    if require('abyss_end_turn_powers').ops[action.effect.op]then return true,require('abyss_end_turn_powers').apply(M,state,action.effect,queue)end
    if action.effect.op=='ownerEndRetain'then
        return true,require('abyss_silent_final_cards').beginRetain(state)and 'pause'or true
    end
    if action.effect.op=='classPotionDarkness'then
        return true,require('abyss_class_potions').darkness(M,state,action.effect,queue)
    end
    return false
end
local function classEffects(c)
    local M,state,action,queue=c.combat,c.state,c.action,c.queue
    local final=require('abyss_watcher_final_cards')
    if final.ops[action.effect.op] then return true,final.execute(M,state,action.effect,queue) end
    if action.effect.op=='silentFinal'then
        local target;for _,e in ipairs(state.enemies)do if state.pendingPlay and e.id==state.pendingPlay.targetId then target=e end end
        require('abyss_silent_final_cards').apply(M,state,{effect=action.effect,source=state.player,target=target,instance=state.cardInUse})
        return true,true
    end
    if action.effect.op=='defectFinal'then
        return true,require('abyss_defect_final_cards').execute(M,state,action.effect,queue)
    end
    if action.effect.op=='colorless' then
        require('abyss_colorless_cards').apply(M,state,{effect=action.effect,source=state.player})
        return true,true
    end
    if action.effect.op=='giantHeadSlow'then
        require('abyss_giant_head').applySlow(Actors,state,action.effect)
        return true,true
    end
    return false
end
local function selectedTarget(state,effect,context)
    local target
    for _,enemy in ipairs(state.enemies) do if enemy.id==context.targetId then target=enemy;break end end
    if effect.targetId then
        for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId then target=enemy;break end end
    end
    return target
end
local function plannedEffects(c,context,target)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local flow=require('abyss_flow_actions')
    local classPlan=flow.plan(state,effect,{target=target,uid=context.uid,instance=state.cardInUse,
        energyOnUse=context.energyOnUse,cardDefinition=M.cardDefinition})
    if classPlan then flow.enqueue(state,classPlan,queue);return true end
    local utility=require('abyss_defect_utility_cards')
    local plan=utility.planEffect and utility.planEffect(state,effect,{target=target,
        energyOnUse=context.energyOnUse,cardsPlayedBefore=math.max(0,#(state.cardsPlayedThisTurn or {})-1)})
    if plan then
        if plan.consumeAllEnergy and not context.freeToPlayOnce then state.energy=0 end
        for i=#plan.top,1,-1 do queue.pushTop(state,{kind='effect',effect=plan.top[i]}) end
        for _,e in ipairs(plan.bottom) do queue.pushBottom(state,{kind='effect',effect=e}) end
        return true
    end
    return false
end
local function executeRounds(c,context,target)
    local M,state,effect,queue=c.combat,c.state,c.effect,c.queue
    local normalMatrix,queueCurlUp,queueStanceGains=c.helpers.normalMatrix,c.helpers.queueCurlUp,c.helpers.queueStanceGains
    if effect.op == "whirlwind" then
        local rounds=context.energyOnUse
        assert(type(rounds)=="number" and rounds%1==0 and rounds>=0 and rounds<=2147483647,"invalid X snapshot")
        if rounds>0 then
            queue.pushBottom(state,{kind="effect",effect={op="whirlwindRounds",remaining=rounds,matrix=effect.matrix}})
            if not context.freeToPlayOnce then state.energy=0 end
        end
    elseif effect.op == "whirlwindRounds" then
        normalMatrix(state,effect.matrix)
        if effect.remaining>1 and not M.outcome(state) then
            queue.pushTop(state,{kind="effect",effect={op="whirlwindRounds",remaining=effect.remaining-1,matrix=effect.matrix}})
        end
    elseif effect.op == "reaperDamage" then
        local dealt=normalMatrix(state,effect.matrix)
        queueCurlUp(state,queue)
        if dealt>0 then queue.pushBottom(state,{kind="effect",effect={op="heal",value=dealt}}) end
    else
        M.applyEffects(state,{effect},state.player,target,state.cardInUse)
    end
    queueCurlUp(state,queue)
    queueStanceGains(state,queue)
    return true
end
local function fallback(c)
    local context=c.state.pendingPlay or {}
    local target=selectedTarget(c.state,c.effect,context)
    if plannedEffects(c,context,target)then return true end
    return executeRounds(c,context,target)
end
function Handlers.apply(helpers,state,action,queue)
    local c={helpers=helpers,combat=helpers.combat,state=state,action=action,effect=action.effect,queue=queue}
    local handled,result,reason=reactions(c)
    if handled then return result,reason end
    handled,result,reason=classEffects(c)
    if handled then return result,reason end
    local effect=action.effect
    local handler=handlers[effect.op]
    if effect.op=='loseHp' and effect.targetId then handler=Damage.markLoseHp end
    if handler then return handler(c)end
    return fallback(c)
end
return Handlers
