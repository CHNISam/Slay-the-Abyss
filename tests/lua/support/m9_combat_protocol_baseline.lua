-- Frozen protocol source from aa4d56f57c15727668ef8675e626b44e67a5aaa5.
-- Only lexical dependencies are supplied; both function bodies are byte-preserved.
return function(M,hooks)
local Actors=require('abyss_actor')
local Effects=require('abyss_effects')
local EnemyAI=require('abyss_enemy_ai')
local RelicHooks=require('abyss_relic_hooks')
local Rare=require('abyss_rare_relics')
local Boss=require('abyss_boss_relics')
local Uncommon=require('abyss_uncommon_relics')
local ShopRelics=require('abyss_shop_relics')
local Awakened=require('abyss_awakened_one')
local CardActions=require('abyss_card_actions')
local copy=require('abyss_copy').copy
local event,paidCost,queueUseCopies=hooks.event,hooks.paidCost,hooks.queueUseCopies
local queuedHandlers,finishQueuedPlay=hooks.handlers,hooks.finish
local function beginQueuedPlay(state, uid, targetIndex, instance, position, card, automatic)
    if not automatic and (card.target=='ENEMY'or card.target=='SELF_AND_ENEMY')then Actors.faceTarget(state,state.enemies[targetIndex])end
    local previous = state.resolvingCard
    state.resolvingCard = true
    local reactions = EnemyAI.cardReactions(state, card)
    local enemyUse={}
    if not card.dontTriggerOnUseCard then
        local sharp={};for _,reaction in ipairs(reactions) do sharp[reaction.source]=reaction.amount end
        for _,enemy in ipairs(state.enemies) do
            local filter={choked=true,curiosity=true,sharp_hide=(enemy.statuses.sharp_hide or 0)>0}
            for _,entry in ipairs(require('abyss_power_schedule').list(enemy,filter)) do
                local curiosity=Awakened.useEffect(enemy,card,entry)
                if curiosity then enemyUse[#enemyUse+1]={kind='effect',effect=curiosity}
                elseif entry.id=='choked' and Actors.isActive(enemy) then
                    enemyUse[#enemyUse+1]={kind='effect',effect={op='loseHp',targetId=enemy.id,value=entry.amount,sourceNull=true}}
                elseif entry.id=='sharp_hide' and sharp[enemy.id] then
                    enemyUse[#enemyUse+1]={kind='effect',effect={op='capturedSharpHide',sourceId=enemy.id,value=sharp[enemy.id]}}
                end
            end
        end
    end
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {}
    state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    require('abyss_run_scoring').played(state,card)
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
    -- X actions read the card's explicit free flag, not Swivel's FreeAttackPower.
    local freeToPlayOnce=automatic~=nil or instance.freeToPlayOnce==true
    local energyOnUse=automatic and automatic.energyOnUse or state.energy
    if energyOnUse==nil then energyOnUse=state.energy end
    require('abyss_silent_final_cards').onUse(M,state,card,instance,targetIndex,energyOnUse,automatic and automatic.purge)
    require('abyss_watcher_final_cards').used(state,card,automatic and automatic.purge)
    if not automatic then state.energy=state.energy-paidCost(state,card) end
    if position then table.remove(state.hand, position) end
    if not (automatic and automatic.purge)then instance.freeToPlayOnce=nil end
    state.cardInUse = instance
    local target = state.enemies[targetIndex]
    state.pendingPlay = {uid=uid, cardType=card.type, exhaust=require("abyss_exhaust").shouldExhaust(state,card),
        targetId=target and target.id, reactions=reactions, previous=previous,
        energyOnUse=energyOnUse,
        purge=automatic and automatic.purge or nil,freeToPlayOnce=freeToPlayOnce}
    state.pendingPlay.dontTriggerOnUseCard=card.dontTriggerOnUseCard
    if automatic and automatic.exhaustCards then state.pendingPlay.exhaust=true end
    event(state, "play", {uid=uid,cardId=instance.cardId,target=targetIndex})
    RelicHooks.onUseCard(state,card)
    Rare.onPlayCard(state);Boss.onPlayCard(state)
    local uncommonEffects=card.dontTriggerOnUseCard and {}or Uncommon.onUseCard(state,card,instance,M)
    if instance.exhaust then state.pendingPlay.exhaust=true end
    local actions = {}
    local triggerPlan=require('abyss_card_triggers').prepareUse(state,card)
    local colorlessTail=require('abyss_colorless_cards').onUse(state,card)
    local triggerActive=#triggerPlan.top+#triggerPlan.beforeUse+#triggerPlan.afterUse>0
        or (state.player.statuses.envenom or 0)>0
    local advanced=Effects.requiresQueue(card.effects) or card.experimental==true or require('abyss_hp_loss').requiresQueue(state) or triggerActive
    local effects=require('abyss_defect_final_cards').prepareEffects(state,copy(card.effects))
    for _,effect in ipairs(effects)do
        if (effect.op=='applyStatus' or effect.op=='applyStatusAll') and effect.status=='poison'
            or effect.op=='cripplingPoison' then effect.poisonBonus=Actors.poisonBonus(state,target,state.player) end
        if effect.op=='playTop'then
            local pool={};for i,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then pool[#pool+1]=i end end
            if #pool>0 then effect.targetIndex=pool[M.cardRandom(state,#pool)]end
        end
    end
    if not advanced then
        actions[1]={kind="effect",effect={op="effectBatch",effects=effects}}
    else
    for _, effect in ipairs(effects) do
      for _,prepared in ipairs(require('abyss_watcher_attack_cards').prepareEffect(state,effect)) do
        local queued=copy(prepared)
        queued=require('abyss_silent_final_cards').prepare(M,state,queued)
        if queued.op=='damage' or queued.op=='heelHook' or queued.op=='watcherFinalLessonLearned' then
            queued.normalAmount=M.attackAmount(state,state.player,target,queued.value)
        elseif queued.op=='damageAll' then
            queued.normalAmounts={}
            for _,enemy in ipairs(state.enemies) do queued.normalAmounts[enemy.id]=M.attackAmount(state,state.player,enemy,queued.value) end
        elseif (queued.op=='block' and not queued.fixed) or queued.op=='nextBlock' then
            if queued.op=='block' then queued.blockCallbackAmount=Actors.blockFloat(state,state.player,queued.value)end
            queued.value=M.blockAmount(state,state.player,queued.value);queued.fixed=true
            if queued.op=='nextBlock' then queued.fixed=nil end
        elseif queued.op=='conditional' then
            for _,nested in ipairs(queued['then']) do
                if nested.op=='damage' then nested.normalAmount=M.attackAmount(state,state.player,target,nested.value) end
            end
        end
        local utility=require('abyss_defect_utility_cards')
        if utility.prepareEffect then queued=utility.prepareEffect(state,queued,target) end
        queued=require('abyss_flow_actions').prepare(state,queued,target,{instance=instance,uid=uid})
        if queued.op=="gainExhaustPower" and queued.status=="corruption" then require("abyss_corruption").prepare(state) end
        if queued.op=="gainMantra" then queued=require("abyss_mantra").prepareGain(state,queued.value) end
        if queued.op=="whirlwind" or queued.op=="reaperDamage" then
            queued.matrix={}
            for _,enemy in ipairs(state.enemies) do
                queued.matrix[#queued.matrix+1]={targetId=enemy.id,amount=M.attackAmount(state,state.player,enemy,queued.value)}
            end
        end
        if queued.op=='damage' and (queued.times or 1)>1 then
            local count=queued.times;queued.times=nil
            for _=1,count do actions[#actions+1]={kind='effect',effect=copy(queued)} end
        else actions[#actions+1]={kind="effect",effect=queued} end
      end
    end
    end
    for _,action in ipairs(triggerPlan.beforeUse) do actions[#actions+1]=action end
    local vigor=require('abyss_watcher_flow_cards').planUseCard(state,card)
    for _,effect in ipairs(vigor.bottom) do actions[#actions+1]={kind='effect',effect=effect} end
    for _,action in ipairs(enemyUse) do actions[#actions+1]=action end
    if #enemyUse==0 and not card.dontTriggerOnUseCard then
        actions[#actions+1]={kind='effect',effect={op='onUseReactions'}}
    end
    for _,effect in ipairs(uncommonEffects)do actions[#actions+1]={kind='effect',effect=effect}end
    actions[#actions + 1] = {kind="useCard"}
    if colorlessTail then actions[#actions+1]={kind='effect',effect=colorlessTail} end
    for _,action in ipairs(triggerPlan.afterUse) do actions[#actions+1]=action end
    queueUseCopies(state,instance,card,targetIndex,energyOnUse,automatic and automatic.purge,freeToPlayOnce)
    local queue = require("abyss_action_queue")
    queue.start(state, actions)
    if not card.dontTriggerOnUseCard then Rare.onUseCard(state,card);ShopRelics.onUseCard(state,card)end
    for _,action in ipairs(triggerPlan.top) do queue.pushTop(state,action) end
    local result = queue.run(state, queuedHandlers)
    if result ~= "pause" then finishQueuedPlay(state) end
    return true
end

local function queueNativePlay(state, uid, targetIndex, instance, card, free, forceExhaust, purge, top, energyOnUse)
    state.resolvingCard = true
    state.cardInUse=instance
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {};state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    require('abyss_run_scoring').played(state,card)
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
    local reactions = EnemyAI.cardReactions(state, card)
    local x=energyOnUse or state.energy
    local necronomiconFree=free or instance.freeToPlayOnce==true
    require('abyss_silent_final_cards').onUse(M,state,card,instance,targetIndex,x,purge)
    require('abyss_watcher_final_cards').used(state,card,purge)
    local colorlessTail=require('abyss_colorless_cards').onUse(state,card)
    -- Native already dispatches Rage's Block below. Only that hook is skipped;
    -- foreign After Image/Thousand Cuts/Heat Sinks/Storm keep their semantics.
    local triggerPlan=require('abyss_card_triggers').prepareUse(state,card,true)
    if not free and not instance.freeToPlayOnce then state.energy=state.energy-(card.costMode=="all_energy" and state.energy or card.cost) end
    if not purge then instance.freeToPlayOnce=nil end
    event(state, "play", { uid = uid, cardId = instance.cardId, target = targetIndex })
    RelicHooks.onUseCard(state,card)
    Rare.onPlayCard(state);Boss.onPlayCard(state)
    local uncommonEffects=card.dontTriggerOnUseCard and {}or Uncommon.onUseCard(state,card,instance,M)
    local items={}
    for i,effect in ipairs(card.effects) do
        if not (effect.targetGroup and card.effects[i-1] and card.effects[i-1].targetGroup) then
            local e=copy(effect)
            if (e.op=='applyStatus' or e.op=='applyStatusAll') and e.status=='poison'
                or e.op=='cripplingPoison' then e.poisonBonus=Actors.poisonBonus(state,state.enemies[targetIndex],state.player) end
            e=require('abyss_silent_final_cards').prepare(M,state,e)
            if e.op=='colorless' and e.kind=='transmutation' then e.energyOnUse=x end
            if e.op=='silentFinal' and e.kind=='doppelganger'then e.energyOnUse=x end
            if e.op=='colorless' and (e.kind=='greed' or e.kind=='ritual') then
                e.resolved={};for _,enemy in ipairs(state.enemies)do e.resolved[enemy.id]=Actors.attackAmount(state,state.player,enemy,e.damage or e.value)end
            end
            if e.op=='originalV4' then e.paidEnergy=free and 0 or (card.costMode=='all_energy' and x or card.cost) end
            if e.op=="playTop" then
                local pool={}; for j,enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then pool[#pool+1]=j end end
                if #pool>0 then e.targetIndex=pool[M.cardRandom(state,#pool)] end
            end
            if e.op=="damage" or e.op=="damageAll" or e.op=="fiendFire" or e.op=="feed"
                or e.op=="reaper" or e.op=="damageRandom" or e.op=="damageEqualToBlock" then
                e.resolved={}
                for _,enemy in ipairs(state.enemies) do
                    e.resolved[enemy.id]=Actors.attackAmount(state,state.player,enemy,e.op=="damageEqualToBlock" and state.player.block or e.value)
                end
            end
            if e.targetGroup then e={op="effectBatch",effects={e,copy(card.effects[i+1])}} end
            if e.times=="X" then e.times=x+ShopRelics.xBonus(state); if e.times==0 then e=nil end end
            if e then items[#items+1]=e end
        end
    end
    local coreOnly=true
    for _,e in ipairs(items) do if CardActions.supports(e.op) then coreOnly=false end end
    if coreOnly and not require('abyss_hp_loss').requiresQueue(state) then
        local batch={}
        for _,e in ipairs(items) do
            if e.op=="effectBatch" then for _,part in ipairs(e.effects) do batch[#batch+1]=part end
            else batch[#batch+1]=e end
        end
        if #batch>0 then items={{op="effectBatch",effects=batch}} end
    end
    if card.type=="attack" and (state.player.statuses.rage or 0)>0 then
        items[#items+1]={op="block",value=state.player.statuses.rage,fixed=true}
    end
    for _,a in ipairs(triggerPlan.beforeUse)do items[#items+1]={op='silentFinal',kind='trigger',action=a.effect}end
    if not card.dontTriggerOnUseCard then for _,enemy in ipairs(state.enemies)do
        for _,entry in ipairs(require('abyss_power_schedule').list(enemy,{choked=true,curiosity=true}))do
            local curiosity=Awakened.useEffect(enemy,card,entry)
            if curiosity then items[#items+1]=curiosity
            elseif entry.id=='choked'and Actors.isActive(enemy)then
                items[#items+1]={op='silentFinal',kind='choke',targetId=enemy.id,value=entry.amount}
            end
        end
    end end
    -- Each captured Sharp Hide is a separate retained DAMAGE action. Its TOP
    -- HP-loss callbacks must run before the following UseCardAction/disposal.
    for _,reaction in ipairs(reactions)do
        items[#items+1]={op='capturedSharpHide',sourceId=reaction.source,value=reaction.amount}
    end
    -- Leave non-array reactions (Hex, etc.) on their original disposal path.
    for i=#reactions,1,-1 do reactions[i]=nil end
    for _,effect in ipairs(uncommonEffects)do items[#items+1]=effect end
    local exhaust=card.exhaust or instance.exhaust or forceExhaust or card.type=="skill" and (state.player.statuses.corruption or 0)>0
    items[#items+1]={op="dispose",exhaust=exhaust,purge=purge,cardType=card.type,reactions=reactions,
        dontTriggerOnUseCard=card.dontTriggerOnUseCard}
    if colorlessTail then items[#items+1]=colorlessTail end
    for _,a in ipairs(triggerPlan.afterUse)do items[#items+1]={op='silentFinal',kind='trigger',action=a.effect}end
    queueUseCopies(state,instance,card,targetIndex,x,purge,necronomiconFree)
    if top then
        for i=#items,1,-1 do CardActions.enqueue(state,items[i],state.player,state.enemies[targetIndex],instance,true) end
    else for _,e in ipairs(items) do CardActions.enqueue(state,e,state.player,state.enemies[targetIndex],instance) end end
    for _,a in ipairs(triggerPlan.top)do CardActions.enqueue(state,{op='silentFinal',kind='trigger',action=a.effect},state.player,nil,instance,true)end
    if not card.dontTriggerOnUseCard then Rare.onUseCard(state,card);ShopRelics.onUseCard(state,card)end
    -- AbstractPlayer.useCard invokes these hand callbacks after use and the
    -- UseCardAction constructor (including Enrage's TOP Strength). Each Pain
    -- then adds LoseHP to TOP, above both those reactions and card effects.
    for _,held in ipairs(state.hand) do
        if held.cardId=='pain' and held~=instance then
            CardActions.enqueue(state,{op='loseHp',value=M.cardDefinition(state,held).onOtherCardHpLoss},state.player,nil,nil,true)
        end
    end
end

return {begin=beginQueuedPlay,queue=queueNativePlay}
end
