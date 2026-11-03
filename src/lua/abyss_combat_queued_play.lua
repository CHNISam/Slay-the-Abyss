-- ActionQueue protocol: capture use-time values and keep useCard as the boundary.
-- Combat retains snapshots, pause/resume handlers and completion ownership.
local Actors=require('abyss_actor')
local Effects=require('abyss_effects')
local EnemyAI=require('abyss_enemy_ai')
local TimeEater=require('abyss_time_eater')
local RelicHooks=require('abyss_relic_hooks')
local Rare=require('abyss_rare_relics')
local Boss=require('abyss_boss_relics')
local Uncommon=require('abyss_uncommon_relics')
local ShopRelics=require('abyss_shop_relics')
local Awakened=require('abyss_awakened_one')
local copy=require('abyss_copy').copy
local M={}

local function hasPlayerTrigger(state)
    local trigger=false
    for _,id in ipairs({'after_image','thousand_cuts','envenom','rage','heat_sinks','storm'})do
        if(state.player.statuses[id]or 0)>0 then trigger=true end
    end
    for _,enemy in ipairs(state.enemies)do if enemy.statuses.choked~=nil or enemy.statuses.slow~=nil then trigger=true end end
    return trigger
end

local function drawCallbacks(state,card)
    local statuses=state.player.statuses
    local hooks=state.catalog.cards.void or(statuses.evolve or 0)>0 or(statuses.fire_breathing or 0)>0
    local active=false
    for _,effect in ipairs(card.effects)do
        if effect.op=='playTop'or hooks and(effect.op=='draw'or effect.op=='requestDiscard')then active=true end
    end
    return active
end

local function exhaustHooks(state,card)
    local statuses=state.player.statuses
    local hooks=(statuses.feel_no_pain or 0)>0 or(statuses.dark_embrace or 0)>0
    return hooks and require('abyss_exhaust').shouldExhaust(state,card)
end

local function immediateQueue(state,card)
    return TimeEater.active(state)or Effects.requiresQueue(card.effects)or card.experimental==true
        or require('abyss_hp_loss').requiresQueue(state)
        or card.type=='skill'and(state.player.statuses.burst or 0)>0
end

function M.required(state,card)
    local trigger=hasPlayerTrigger(state)
    local draw=drawCallbacks(state,card)
    return immediateQueue(state,card)
        or require('abyss_defect_final_cards').needsQueue(state)or state.player.stance~=nil
        or draw or trigger or card.type=='skill'and(state.player.statuses.corruption or 0)~=0
        or #(state.relics or {})>0 or exhaustHooks(state,card)
end

local function enemyUse(state,card,reactions)
    local actions={}
    if card.dontTriggerOnUseCard then return actions end
    local sharp={};for _,reaction in ipairs(reactions)do sharp[reaction.source]=reaction.amount end
    for _,enemy in ipairs(state.enemies)do
        local filter={choked=true,curiosity=true,sharp_hide=(enemy.statuses.sharp_hide or 0)>0}
        for _,entry in ipairs(require('abyss_power_schedule').list(enemy,filter))do
            local curiosity=Awakened.useEffect(enemy,card,entry)
            if curiosity then actions[#actions+1]={kind='effect',effect=curiosity}
            elseif entry.id=='choked'and Actors.isActive(enemy)then
                actions[#actions+1]={kind='effect',effect={op='loseHp',targetId=enemy.id,value=entry.amount,sourceNull=true}}
            elseif entry.id=='sharp_hide'and sharp[enemy.id]then
                actions[#actions+1]={kind='effect',effect={op='capturedSharpHide',sourceId=enemy.id,value=sharp[enemy.id]}}
            end
        end
    end
    return actions
end

local function recordPlay(state,card)
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {}
    state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    require('abyss_run_scoring').played(state,card)
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
end

local function consume(combat,hooks,state,instance,position,card,targetIndex,automatic)
    local free=automatic~=nil or instance.freeToPlayOnce==true
    local energy=automatic and automatic.energyOnUse or state.energy
    if energy==nil then energy=state.energy end
    require('abyss_silent_final_cards').onUse(combat,state,card,instance,targetIndex,energy,automatic and automatic.purge)
    require('abyss_watcher_final_cards').used(state,card,automatic and automatic.purge)
    if not automatic then state.energy=state.energy-hooks.paidCost(state,card)end
    if position then table.remove(state.hand,position)end
    if not(automatic and automatic.purge)then instance.freeToPlayOnce=nil end
    state.cardInUse=instance
    return free,energy
end

local function pending(state,uid,card,targetIndex,reactions,previous,energy,free,automatic)
    local target=state.enemies[targetIndex]
    state.pendingPlay={uid=uid,cardType=card.type,exhaust=require('abyss_exhaust').shouldExhaust(state,card),
        targetId=target and target.id,reactions=reactions,previous=previous,energyOnUse=energy,
        purge=automatic and automatic.purge or nil,freeToPlayOnce=free,dontTriggerOnUseCard=card.dontTriggerOnUseCard}
    if automatic and automatic.exhaustCards then state.pendingPlay.exhaust=true end
    return target
end

local function randomTarget(combat,state,effect)
    if effect.op~='playTop'then return end
    local pool={};for i,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then pool[#pool+1]=i end end
    if #pool>0 then effect.targetIndex=pool[combat.cardRandom(state,#pool)]end
end

local function prepareEffects(combat,state,card,target)
    local effects=require('abyss_defect_final_cards').prepareEffects(state,copy(card.effects))
    for _,effect in ipairs(effects)do
        if(effect.op=='applyStatus'or effect.op=='applyStatusAll')and effect.status=='poison'or effect.op=='cripplingPoison'then
            effect.poisonBonus=Actors.poisonBonus(state,target,state.player)
        end
        randomTarget(combat,state,effect)
    end
    return effects
end

local function captureAmounts(combat,state,target,e)
    if e.op=='damage'or e.op=='heelHook'or e.op=='watcherFinalLessonLearned'then
        e.normalAmount=combat.attackAmount(state,state.player,target,e.value)
    elseif e.op=='damageAll'then
        e.normalAmounts={}
        for _,enemy in ipairs(state.enemies)do e.normalAmounts[enemy.id]=combat.attackAmount(state,state.player,enemy,e.value)end
    elseif(e.op=='block'and not e.fixed)or e.op=='nextBlock'then
        if e.op=='block'then e.blockCallbackAmount=Actors.blockFloat(state,state.player,e.value)end
        e.value=combat.blockAmount(state,state.player,e.value);e.fixed=true
        if e.op=='nextBlock'then e.fixed=nil end
    elseif e.op=='conditional'then
        for _,nested in ipairs(e['then'])do if nested.op=='damage'then nested.normalAmount=combat.attackAmount(state,state.player,target,nested.value)end end
    end
end

local function prepareQueued(combat,state,prepared,target,instance,uid)
    local e=require('abyss_silent_final_cards').prepare(combat,state,copy(prepared))
    captureAmounts(combat,state,target,e)
    local utility=require('abyss_defect_utility_cards')
    if utility.prepareEffect then e=utility.prepareEffect(state,e,target)end
    e=require('abyss_flow_actions').prepare(state,e,target,{instance=instance,uid=uid})
    if e.op=='gainExhaustPower'and e.status=='corruption'then require('abyss_corruption').prepare(state)end
    if e.op=='gainMantra'then e=require('abyss_mantra').prepareGain(state,e.value)end
    if e.op=='whirlwind'or e.op=='reaperDamage'then
        e.matrix={}
        for _,enemy in ipairs(state.enemies)do e.matrix[#e.matrix+1]={targetId=enemy.id,amount=combat.attackAmount(state,state.player,enemy,e.value)}end
    end
    return e
end

local function appendEffect(actions,e)
    if e.op=='damage'and(e.times or 1)>1 then
        local count=e.times;e.times=nil
        for _=1,count do actions[#actions+1]={kind='effect',effect=copy(e)}end
    else actions[#actions+1]={kind='effect',effect=e}end
end

local function effectActions(combat,state,effects,advanced,target,instance,uid)
    if not advanced then return {{kind='effect',effect={op='effectBatch',effects=effects}}}end
    local actions={}
    for _,effect in ipairs(effects)do
        for _,prepared in ipairs(require('abyss_watcher_attack_cards').prepareEffect(state,effect))do
            appendEffect(actions,prepareQueued(combat,state,prepared,target,instance,uid))
        end
    end
    return actions
end

local function appendActions(actions,tail)
    for _,action in ipairs(tail)do actions[#actions+1]=action end
end

local function appendEffects(actions,effects)
    for _,effect in ipairs(effects)do actions[#actions+1]={kind='effect',effect=effect}end
end

local function advanced(state,card,plan)
    local active=#plan.top+#plan.beforeUse+#plan.afterUse>0 or(state.player.statuses.envenom or 0)>0
    return Effects.requiresQueue(card.effects)or card.experimental==true or require('abyss_hp_loss').requiresQueue(state)or active
end

local function useHooks(combat,hooks,state,uid,targetIndex,instance,card)
    hooks.event(state,'play',{uid=uid,cardId=instance.cardId,target=targetIndex})
    RelicHooks.onUseCard(state,card)
    Rare.onPlayCard(state);Boss.onPlayCard(state)
    local uncommon=card.dontTriggerOnUseCard and {}or Uncommon.onUseCard(state,card,instance,combat)
    if instance.exhaust then state.pendingPlay.exhaust=true end
    return uncommon
end

local function actionsFor(combat,state,uid,target,instance,card,enemies,uncommon)
    local plan=require('abyss_card_triggers').prepareUse(state,card)
    local tail=require('abyss_colorless_cards').onUse(state,card)
    local isAdvanced=advanced(state,card,plan)
    local effects=prepareEffects(combat,state,card,target)
    local actions=effectActions(combat,state,effects,isAdvanced,target,instance,uid)
    appendActions(actions,plan.beforeUse)
    local vigor=require('abyss_watcher_flow_cards').planUseCard(state,card)
    appendEffects(actions,vigor.bottom)
    appendActions(actions,enemies)
    if #enemies==0 and not card.dontTriggerOnUseCard then actions[#actions+1]={kind='effect',effect={op='onUseReactions'}}end
    appendEffects(actions,uncommon)
    actions[#actions+1]={kind='useCard'}
    if tail then actions[#actions+1]={kind='effect',effect=tail}end
    appendActions(actions,plan.afterUse)
    return actions,plan
end

function M.begin(combat,hooks,state,uid,targetIndex,instance,position,card,automatic)
    if not automatic and(card.target=='ENEMY'or card.target=='SELF_AND_ENEMY')then Actors.faceTarget(state,state.enemies[targetIndex])end
    local previous=state.resolvingCard;state.resolvingCard=true
    local reactions=EnemyAI.cardReactions(state,card)
    local enemies=enemyUse(state,card,reactions)
    recordPlay(state,card)
    local free,energy=consume(combat,hooks,state,instance,position,card,targetIndex,automatic)
    local target=pending(state,uid,card,targetIndex,reactions,previous,energy,free,automatic)
    local uncommon=useHooks(combat,hooks,state,uid,targetIndex,instance,card)
    local actions,plan=actionsFor(combat,state,uid,target,instance,card,enemies,uncommon)
    hooks.queueUseCopies(state,instance,card,targetIndex,energy,automatic and automatic.purge,free)
    local queue=require('abyss_action_queue')
    queue.start(state,actions)
    if not card.dontTriggerOnUseCard then Rare.onUseCard(state,card);ShopRelics.onUseCard(state,card)end
    for _,action in ipairs(plan.top)do queue.pushTop(state,action)end
    if queue.run(state,hooks.handlers)~='pause'then hooks.finish(state)end
    return true
end

return M
