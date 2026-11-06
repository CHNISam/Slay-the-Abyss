-- CardActions protocol: capture values at use time, retain disposal and TOP order.
-- Combat owns the transaction and drain; this owner never calls back into play.
local Actors=require('abyss_actor')
local EnemyAI=require('abyss_enemy_ai')
local CardActions=require('abyss_card_actions')
local RelicHooks=require('abyss_relic_combat_hooks')
local Rare=require('abyss_relic_family_combat').rare
local Boss=require('abyss_relic_family_combat').boss
local Uncommon=require('abyss_relic_family_combat').uncommon
local ShopRelics=require('abyss_relic_family_combat').shop
local ShopRelicsQueries=require('abyss_relic_queries').shop
local Awakened=require('abyss_awakened_one')
local copy=require('abyss_copy').copy
local M={}

function M.nativeOnly(card)
    local nativeOnly=false
    for _,effect in ipairs(card.effects)do
        if CardActions.supports(effect.op) and not require('abyss_build_actions').ops[effect.op]
            and not require('abyss_flow_actions').ops[effect.op] or effect.times=='X'then nativeOnly=true end
    end
    return nativeOnly
end

function M.preferred(state,card,isNative,nativeOnly)
    return isNative and(not state.experimentalMechanics or nativeOnly or card.silentFinalCard or card.runNativeABI)
end

local function recordPlay(state,card)
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {}
    state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    require('abyss_run_scoring').played(state,card)
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
end

local function randomTarget(combat,state,e)
    if e.op~='playTop'then return end
    local pool={}
    for j,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then pool[#pool+1]=j end end
    if #pool>0 then e.targetIndex=pool[combat.cardRandom(state,#pool)]end
end

local damageOps={damage=true,damageAll=true,fiendFire=true,feed=true,reaper=true,damageRandom=true,damageEqualToBlock=true}
local function captureDamage(state,e)
    local amount
    if damageOps[e.op]then amount=e.op=='damageEqualToBlock'and state.player.block or e.value
    elseif e.op=='colorless'and(e.kind=='greed'or e.kind=='ritual')then amount=e.damage or e.value
    else return end
    e.resolved={}
    for _,enemy in ipairs(state.enemies)do e.resolved[enemy.id]=Actors.attackAmount(state,state.player,enemy,amount)end
end

local function prepareEffect(combat,state,e,targetIndex,x,card,free)
    if (e.op=='applyStatus'or e.op=='applyStatusAll')and e.status=='poison'or e.op=='cripplingPoison'then
        e.poisonBonus=Actors.poisonBonus(state,state.enemies[targetIndex],state.player)
    end
    e=require('abyss_silent_final_cards').prepare(combat,state,e)
    if e.op=='colorless'and e.kind=='transmutation'or e.op=='silentFinal'and e.kind=='doppelganger'then e.energyOnUse=x end
    captureDamage(state,e)
    if e.op=='originalV4'then e.paidEnergy=free and 0 or(card.costMode=='all_energy'and x or card.cost)end
    randomTarget(combat,state,e)
    return e
end

local function effectItems(combat,state,card,targetIndex,x,free)
    local items={}
    for i,effect in ipairs(card.effects)do
        if not(effect.targetGroup and card.effects[i-1]and card.effects[i-1].targetGroup)then
            local e=prepareEffect(combat,state,copy(effect),targetIndex,x,card,free)
            if e.targetGroup then e={op='effectBatch',effects={e,copy(card.effects[i+1])}}end
            if e.times=='X'then e.times=x+ShopRelicsQueries.xBonus(state);if e.times==0 then e=nil end end
            if e then items[#items+1]=e end
        end
    end
    return items
end

local function batchCore(state,items)
    for _,e in ipairs(items)do if CardActions.supports(e.op)then return items end end
    if require('abyss_hp_loss').requiresQueue(state)then return items end
    local batch={}
    for _,e in ipairs(items)do
        if e.op=='effectBatch'then for _,part in ipairs(e.effects)do batch[#batch+1]=part end
        else batch[#batch+1]=e end
    end
    if #batch>0 then return {{op='effectBatch',effects=batch}}end
    return items
end

local function appendTriggers(items,actions)
    for _,a in ipairs(actions)do items[#items+1]={op='silentFinal',kind='trigger',action=a.effect}end
end

local function appendEnemyUse(state,card,items)
    if card.dontTriggerOnUseCard then return end
    for _,enemy in ipairs(state.enemies)do
        for _,entry in ipairs(require('abyss_power_schedule').list(enemy,{choked=true,curiosity=true}))do
            local curiosity=Awakened.useEffect(enemy,card,entry)
            if curiosity then items[#items+1]=curiosity
            elseif entry.id=='choked'and Actors.isActive(enemy)then
                items[#items+1]={op='silentFinal',kind='choke',targetId=enemy.id,value=entry.amount}
            end
        end
    end
end

local function appendDisposal(state,instance,card,items,reactions,forceExhaust,purge)
    -- Clear only the captured array: Hex and other keyed reactions keep identity.
    for _,reaction in ipairs(reactions)do items[#items+1]={op='capturedSharpHide',sourceId=reaction.source,value=reaction.amount}end
    for i=#reactions,1,-1 do reactions[i]=nil end
    local exhaust=card.exhaust or instance.exhaust or forceExhaust or card.type=='skill'and(state.player.statuses.corruption or 0)>0
    return {op='dispose',exhaust=exhaust,purge=purge,cardType=card.type,reactions=reactions,dontTriggerOnUseCard=card.dontTriggerOnUseCard}
end

local function enqueue(state,items,targetIndex,instance,top)
    if top then
        for i=#items,1,-1 do CardActions.enqueue(state,items[i],state.player,state.enemies[targetIndex],instance,true)end
    else for _,e in ipairs(items)do CardActions.enqueue(state,e,state.player,state.enemies[targetIndex],instance)end end
end

local function handCallbacks(combat,state,instance)
    for _,held in ipairs(state.hand)do
        if held.cardId=='pain'and held~=instance then
            CardActions.enqueue(state,{op='loseHp',value=combat.cardDefinition(state,held).onOtherCardHpLoss},state.player,nil,nil,true)
        end
    end
end

local function useHooks(combat,hooks,state,uid,targetIndex,instance,card,free,purge,x)
    require('abyss_silent_final_cards').onUse(combat,state,card,instance,targetIndex,x,purge)
    require('abyss_watcher_final_cards').used(state,card,purge)
    local tail=require('abyss_colorless_cards').onUse(state,card)
    -- Rage is dispatched explicitly; foreign on-use powers still run.
    local plan=require('abyss_card_triggers').prepareUse(state,card,true)
    if not free and not instance.freeToPlayOnce then state.energy=state.energy-(card.costMode=='all_energy'and state.energy or card.cost)end
    if not purge then instance.freeToPlayOnce=nil end
    hooks.event(state,'play',{uid=uid,cardId=instance.cardId,target=targetIndex})
    RelicHooks.onUseCard(state,card)
    Rare.onPlayCard(state);Boss.onPlayCard(state)
    local uncommon=card.dontTriggerOnUseCard and {}or Uncommon.onUseCard(state,card,instance,combat)
    return tail,plan,uncommon
end

function M.queue(combat,hooks,state,uid,targetIndex,instance,card,free,forceExhaust,purge,top,energyOnUse)
    state.resolvingCard=true;state.cardInUse=instance
    recordPlay(state,card)
    local reactions=EnemyAI.cardReactions(state,card)
    local x=energyOnUse or state.energy
    local necronomiconFree=free or instance.freeToPlayOnce==true
    local tail,plan,uncommon=useHooks(combat,hooks,state,uid,targetIndex,instance,card,free,purge,x)
    local items=batchCore(state,effectItems(combat,state,card,targetIndex,x,free))
    if card.type=='attack'and(state.player.statuses.rage or 0)>0 then items[#items+1]={op='block',value=state.player.statuses.rage,fixed=true}end
    appendTriggers(items,plan.beforeUse)
    appendEnemyUse(state,card,items)
    local disposal=appendDisposal(state,instance,card,items,reactions,forceExhaust,purge)
    for _,effect in ipairs(uncommon)do items[#items+1]=effect end
    items[#items+1]=disposal
    if tail then items[#items+1]=tail end
    appendTriggers(items,plan.afterUse)
    hooks.queueUseCopies(state,instance,card,targetIndex,x,purge,necronomiconFree)
    enqueue(state,items,targetIndex,instance,top)
    for _,a in ipairs(plan.top)do CardActions.enqueue(state,{op='silentFinal',kind='trigger',action=a.effect},state.player,nil,instance,true)end
    if not card.dontTriggerOnUseCard then Rare.onUseCard(state,card);ShopRelics.onUseCard(state,card)end
    handCallbacks(combat,state,instance)
end

return M
