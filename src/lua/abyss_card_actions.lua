-- Shared combat card actions. Data only continuations can pause for a real UID
-- choice; no UI callbacks, platform objects, or permanent deck writes live here.
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local PlatedArmor = require('abyss_plated_armor')
local Act2Powers = require('abyss_act2_powers')
local TimeEater=require('abyss_time_eater')
local M = {}
local operations = { timeEater=true, writhingRoll=true,writhingParasite=true, classPotion=true, silentFinal=true, discover=true, colorless=true, heal=true, originalV4=true, exhaustRandom=true, exhaustChoose=true, exhaustNonAttacks=true,
    exhaustMany=true,discardRedraw=true,discardToHand=true,randomizeHandCost=true,
    secondWind=true, fiendFire=true, recoverExhaust=true, upgradeHand=true,
    discardToDraw=true, handToDraw=true, dualWield=true, generateAttack=true,
    makeTempCardInHand=true, makeTempCardInDraw=true, doubleStrength=true,
    spotWeakness=true, feed=true, reaper=true, playTop=true, damageRandom=true }
for _,op in ipairs({'rareGamblingChip','rareRelicGenerate','rareRelicDamageAll','rareRelicWeak','shopRelic'})do operations[op]=true end
function M.supports(op) return operations[op] == true end

function M.enqueue(state, effect, source, target, instance, top)
    state.cardActions = state.cardActions or {}
    local item = {effect=effect, source=source or state.player, target=target, instance=instance}
    if top then table.insert(state.cardActions, 1, item) else state.cardActions[#state.cardActions+1] = item end
end

-- Damage/HP-loss callbacks join the queue that already owns the action.
-- This enqueues an effect, never a second action manager or a continuation.
function M.enqueueReaction(state,effect,top)
    if state.actionQueue then
        local queue=require('abyss_action_queue')
        local action={kind='effect',effect=effect}
        if top then queue.pushTop(state,action)else queue.pushBottom(state,action)end
    else M.enqueue(state,effect,nil,nil,nil,top)end
end
function M.reactionRetained(effect)
    if effect.op=='rareRelicDamageAll'then return true end
    if require('abyss_corrupt_heart').retained(effect)then return true end
    if effect.op=='reptomancerSuicide'then return true end
    return TimeEater.retained(effect) or effect.op=='awakenedAction' and effect.kind=='heal' or PlatedArmor.retained(effect) or Act2Powers.retained(effect) or effect.op=='resolveCurlUp'
        or effect.op=='damageRandom' or effect.op=='staticRetaliation'
        or effect.op=='silentFinal' and require('abyss_silent_final_cards').allowedAfterVictory(effect)
end

local function remove(pile, uid)
    for i, c in ipairs(pile) do if c.uid == uid then return table.remove(pile, i) end end
end

function M.exhaust(combat, state, instance, pile)
    if pile and not remove(pile, instance.uid) then return false end
    -- CardGroup.moveToExhaustPile dispatches relics, then Powers, then the
    -- card hook. Dark Embrace/FNP append; Sentinel inserts at the top.
    state.exhaust[#state.exhaust+1] = instance
    Events.emit(state, "exhaust", {uid=instance.uid,cardId=instance.cardId})
    require('abyss_rare_relics').onExhaust(state)
    local p = state.player
    for _,id in ipairs(Actors.powerSequence(p,{'dark_embrace','feel_no_pain'})) do
        if id=='dark_embrace' and not combat.outcome(state) then
            M.enqueue(state,{op="draw",value=p.statuses[id]})
        elseif id=='feel_no_pain' then M.enqueue(state,{op="block",value=p.statuses[id],fixed=true}) end
    end
    local rebirth=require('abyss_necronomicurse').exhaustPlan(instance)
    if rebirth then M.enqueue(state,rebirth.effect)end
    local energy=combat.cardDefinition(state,instance).exhaustEnergy
    if energy then
        M.enqueue(state,{op="energy",value=energy},nil,nil,nil,true)
    end
    return true
end

function M.fresh(combat, state, id, prototype)
    assert(state.catalog.cards[id], "unknown generated card")
    local c=prototype and combat.copy(prototype) or {cardId=id,upgraded=false}
    c.dontTriggerOnUseCard=nil -- Stat-equivalent constructors do not copy this physical use flag.
    c.deckUid=nil -- Stat-equivalent generation has a fresh UUID, not master-deck ownership.
    -- Original BloodForBlood.makeCopy discounts a newly generated card by
    -- every HP-loss event already recorded this combat, before a temporary cost.
    if not prototype and id=='blood_for_blood' then
        c.costReduction=state.player.damagedThisCombat or 0
        -- Initialize the new cost ABI once from the same combat history;
        -- subsequent HP loss must continue from this discounted base.
        require('abyss_warrior_status_cards').created(state,c,'make_copy')
    end
    c.uid=state.nextUid
    c.uuid=c.uid
    state.nextUid=state.nextUid+1.0
    assert(state.nextUid>c.uid and state.nextUid<math.huge,"nextUid cannot advance")
    if not prototype then require('abyss_defect_final_cards').created(state,c)end
    return c
end

-- Source generation sites invoke this explicitly: constructors and hand /
-- discard effects can each call upgrade, including repeatable Searing Blow.
-- Retrieval and stat-equivalent copy construction alone never invoke it.
function M.created(combat,state,card)
    if (state.player.statuses.master_reality or 0)==0 then return false end
    local d=assert(state.catalog.cards[card.cardId],'unknown generated card')
    if d.type~='curse' and d.type~='status' then return combat.upgrade(state,card)end
    return false
end

function M.sameInstance(combat,state,prototype)
    assert(type(prototype)=='table'and type(prototype.uid)=='number','missing same-instance prototype')
    local c=M.fresh(combat,state,prototype.cardId,prototype)
    c.uuid=prototype.uuid or prototype.uid
    c.deckUid=prototype.deckUid
    return c
end

function M.toHand(state, c)
    local pile=#state.hand<state.rules.player.maxHand and state.hand or state.discard
    pile[#pile+1]=c
end

local function candidates(combat,state,op)
    local pile=op=="recoverExhaust" and state.exhaust or (op=="discardToDraw" or op=='discardToHand') and state.discard or state.hand
    local result={}
    if op=="recoverExhaust" and #state.hand>=state.rules.player.maxHand then return result end
    for _,c in ipairs(pile) do
        local d=combat.cardDefinition(state,c)
        if (op~="recoverExhaust" or c.cardId~="exhume")
            and (op~="upgradeHand" or combat.canUpgrade(state,c))
            and (op~="dualWield" or d.type=="attack" or d.type=="power") then result[#result+1]=c.uid end
    end
    return result
end

local function selection(combat,state,item)
    local e,op=item.effect,item.effect.op
    if op=='discardToHand' and e.value<=0 then return end
    local options=candidates(combat,state,op)
    if #options==0 then return end
    if op=='exhaustMany' or op=='discardRedraw' or op=='discardToHand' and e.value>1 and #options>e.value then
        state.choiceSerial=(state.choiceSerial or 0)+1
        state.pendingChoice={token=state.choiceSerial,op=op,uids=options,item=item,multiple=true,selected={},
            required=op=='discardToHand' and e.value or nil}
        Events.emit(state,'card_choice',{token=state.choiceSerial,op=op})
        return
    end
    if op=='discardToHand' and #options<=e.value then
        for _,uid in ipairs(options) do M.applyChoice(combat,state,item,uid) end
        return
    end
    if #options==1 then return M.applyChoice(combat,state,item,options[1]) end
    -- Dual Wield's actual selection branch consumes the selected original
    -- and returns amount+1 stat-equivalent copies; its one-eligible-card fast
    -- path retains the original and only adds amount copies.
    if op=="dualWield" then item.replaceSelected=true end
    state.choiceSerial=(state.choiceSerial or 0)+1
    state.pendingChoice={token=state.choiceSerial,op=op,uids=options,item=item}
    Events.emit(state,"card_choice",{token=state.choiceSerial,op=op})
end

function M.applyChoice(combat,state,item,uid)
    local e,op=item.effect,item.effect.op
    if op=="exhaustChoose" then
        local c=remove(state.hand,uid); assert(c,"stale exhaust choice")
        M.exhaust(combat,state,c)
    elseif op=="recoverExhaust" then
        local c=remove(state.exhaust,uid); assert(c and c.cardId~="exhume","invalid Exhume choice")
        M.toHand(state,c)
    elseif op=='discardToHand' then
        if #state.hand>=state.rules.player.maxHand then return end
        local c=remove(state.discard,uid);assert(c,'stale discard choice')
        local definition=combat.cardDefinition(state,c)
        if definition.cost>=0 and definition.costMode~='all_energy' then c.costForTurn=0 end
        state.hand[#state.hand+1]=c
        Events.emit(state,'recover',{uid=c.uid,cardId=c.cardId})
    elseif op=="discardToDraw" or op=="handToDraw" then
        local c=remove(op=="discardToDraw" and state.discard or state.hand,uid)
        assert(c,"stale pile choice"); state.draw[#state.draw+1]=c
    elseif op=="upgradeHand" or op=="dualWield" then
        local c
        for _,v in ipairs(state.hand) do if v.uid==uid then c=v; break end end
        assert(c,"stale hand choice")
        if op=="upgradeHand" then combat.upgrade(state,c)
        else
            local count=e.value
            if item.replaceSelected then
                remove(state.hand,uid)
                local eligible,other={},{}
                for _,v in ipairs(state.hand) do
                    local kind=combat.cardDefinition(state,v).type
                    local pile=(kind=="attack" or kind=="power") and eligible or other
                    pile[#pile+1]=v
                end
                -- The hand selector temporarily removes noneligible cards;
                -- returnCards puts them after the remaining eligible cards.
                for i=#state.hand,1,-1 do state.hand[i]=nil end
                for _,pile in ipairs({eligible,other}) do for _,v in ipairs(pile) do state.hand[#state.hand+1]=v end end
                count=count+1
            end
            for _=1,count do
                local generated=M.fresh(combat,state,c.cardId,c)
                M.created(combat,state,generated)
                M.created(combat,state,generated)
                M.toHand(state,generated)
            end
        end
    else error("invalid choice operation") end
    Events.emit(state,"card_choice_resolved",{op=op,uid=uid})
end

function M.choose(combat,state,token,uid)
    local choice=state.pendingChoice
    if choice and choice.op=='silentFinal'then return require('abyss_silent_final_cards').choose(combat,state,token,uid)end
    if choice and choice.op=='colorless' then return require('abyss_colorless_cards').choose(combat,state,token,uid) end
    if not choice or token~=choice.token then return false,"stale_card_choice" end
    if choice.op=='discover' then
        local ok,reason=require('abyss_potion_discovery').choose(combat,state,token,uid,M)
        if ok then M.drain(combat,state)end
        return ok,reason
    end
    if choice.multiple then
        local valid={};for _,id in ipairs(candidates(combat,state,choice.op)) do valid[id]=true end
        for _,id in ipairs(choice.selected) do if not valid[id] then return false,'stale_card_choice' end end
        if uid==0 then
            if choice.required and #choice.selected~=choice.required then return false,'invalid_card_choice' end
            state.pendingChoice=nil
            for _,id in ipairs(choice.selected) do
                if choice.op=='exhaustMany' then
                    local c=remove(state.hand,id);M.exhaust(combat,state,c)
                elseif choice.op=='discardRedraw' then
                    local c=remove(state.hand,id);state.discard[#state.discard+1]=c
                    Events.emit(state,'discard',{uid=c.uid,cardId=c.cardId,manual=true})
                else M.applyChoice(combat,state,choice.item,id) end
            end
            if choice.op=='discardRedraw' and #choice.selected>0 then M.enqueue(state,{op='draw',value=#choice.selected},nil,nil,nil,true) end
            M.drain(combat,state)
            return true
        end
        if not valid[uid] then return false,'invalid_card_choice' end
        local selected,removed={},false
        for _,id in ipairs(choice.selected) do if id==uid then removed=true else selected[#selected+1]=id end end
        if not removed then
            if choice.required and #selected>=choice.required then return false,'invalid_card_choice' end
            selected[#selected+1]=uid
        end
        choice.selected=selected
        state.choiceSerial=(state.choiceSerial or 0)+1;choice.token=state.choiceSerial
        return true
    end
    local found=false
    for _,id in ipairs(choice.uids) do if id==uid then found=true end end
    if not found then return false,"invalid_card_choice" end
    -- Revalidate eligibility instead of trusting the UI's copied option list.
    found=false
    for _,id in ipairs(candidates(combat,state,choice.op)) do if id==uid then found=true end end
    if not found then return false,"stale_card_choice" end
    state.pendingChoice=nil
    M.applyChoice(combat,state,choice.item,uid)
    M.drain(combat,state)
    return true
end

local function liveEnemies(state)
    local result={}
    for _,v in ipairs(state.enemies) do if Actors.isActive(v) then result[#result+1]=v end end
    return result
end

local function exhaustRandom(combat,state,item)
    if #state.hand>0 then
        local i=#state.hand==1 and not item.effect.alwaysRandom and 1 or combat.cardRandom(state,#state.hand)
        M.exhaust(combat,state,state.hand[i],state.hand)
    end
end

local function fiendFire(_,state,item)
    -- Snapshot count now. Exhaust actions use random cards; draw hooks go
    -- behind the original hits, so newly drawn cards aren't exhausted.
    local count=#state.hand
    for _=1,count do M.enqueue(state,{op="damage",value=item.effect.value,resolved=item.effect.resolved},item.source,item.target,item.instance,true) end
    for _=1,count do M.enqueue(state,{op="exhaustRandom",alwaysRandom=true},item.source,nil,nil,true) end
end

local function exhaustNonAttacks(combat,state,item)
    local cards={}
    for _,v in ipairs(state.hand) do
        if combat.cardDefinition(state,v).type~="attack" then cards[#cards+1]=v end
    end
    if item.effect.op=="secondWind" then
        for _=1,#cards do M.enqueue(state,{op="block",value=item.effect.value},item.source,nil,item.instance,true) end
    end
    for _,v in ipairs(cards) do M.enqueue(state,{op="exhaustSpecific",uid=v.uid},item.source,nil,nil,true) end
end

local function exhaustSpecific(combat,state,item)
    local v=remove(state.hand,item.effect.uid); if v then M.exhaust(combat,state,v) end
end

-- Hand mutation actions share constructors and hooks, but retain their own
-- RNG boundaries: generated cards consume UID before their insertion roll.
local function upgradeAllHand(combat,state)
    for _,v in ipairs(state.hand) do if combat.canUpgrade(state,v) then combat.upgrade(state,v) end end
end

local function makeTemporaryCards(combat,state,item)
    local e=item.effect
    local op,value=e.op,e.value
    for _=1,value do
        local v=M.fresh(combat,state,e.card)
        M.created(combat,state,v)
        if op=='makeTempCardInHand' then M.created(combat,state,v)end
        if op=="makeTempCardInHand" then M.toHand(state,v)
        else table.insert(state.draw,combat.cardRandom(state,#state.draw+1),v) end
    end
end

local function generateAttack(combat,state)
    local pool={}
    for _,rarity in ipairs({'common','uncommon','rare'}) do
        for _,id in ipairs(state.sourcePools.src[rarity]) do
            local d=state.catalog.cards[id]
            if d.type=="attack" and not d.healing then pool[#pool+1]=id end
        end
    end
    local v=M.fresh(combat,state,pool[combat.cardRandom(state,#pool)])
    v.costForTurn=0
    M.created(combat,state,v)
    M.created(combat,state,v)
    M.toHand(state,v)
end

local function randomizeHandCost(combat,state)
    for _,card in ipairs(state.hand) do
        local cost=combat.combatBaseCost(state,card)
        if cost>=0 then
            local nextCost=combat.cardRandom(state,4)-1
            if nextCost~=cost then
                card.costOverride,card.costForTurn=nextCost,nextCost
                if card.cardId=='blood_for_blood' then card.costReduction=0 end
            end
        end
    end
end

local function upgradeHand(combat,state,item)
    if item.effect.all then upgradeAllHand(combat,state)
    else return selection(combat,state,item)end
end

local function resolveCurlUp(_,state,item)
    local e=item.effect
    for _,enemy in ipairs(state.enemies)do
        if enemy.id==e.targetId then Actors.resolveCurlUp(state,enemy,e.value);break end
    end
end

local function obtainPotion(_,state,item)
    local e=item.effect
    state.generatedPotionOffers=state.generatedPotionOffers or {}
    state.generatedPotionOffers[#state.generatedPotionOffers+1]={id=e.id,unavailable=e.unavailable==true}
    if e.unavailable then
        Events.emit(state,'potion_content_unavailable',{id=e.id})
        return
    end
    return require('abyss_potion_generation').obtain(state.potionInventory,state.potionCapacity,e.id,
        require('abyss_relic_hooks').owns(state,'sozu'))
end

local function doubleStrength(_,state,item)
    local source=item.source
    local amount=source.statuses.strength or 0
    if amount~=0 then Actors.applyPower(state,source,"strength",amount,source)end
end

local function spotWeakness(_,state,item)
    local target=item.target
    local intent=target and target.intents[target.intentIndex]
    local attacking=false
    for _,f in ipairs(intent and intent.effects or {})do if f.op=="damage" or f.op=="damageAll"then attacking=true end end
    if attacking then Actors.applyPower(state,item.source,"strength",item.effect.value,item.source)end
end

local function damageRandom(combat,state,item)
    local e,source=item.effect,item.source
    for _=1,e.times or 1 do
        local enemies=liveEnemies(state)
        if #enemies==0 or source.hp<=0 then break end
        local victim=enemies[combat.cardRandom(state,#enemies)]
        combat.damage(state,source,victim,e.value,e.fixed,nil,e.resolved and e.resolved[victim.id])
    end
end

local function feedReward(state,source,amount)
    source.maxHp=source.maxHp+amount
    local beforeHp=source.hp
    local healing=source==state.player and require('abyss_potion_health').modifyHealing(amount,state.relics,true)or amount
    if state.originalV4 and source==state.player then require('abyss_original_v4_health').heal(state,source,healing,nil,'feed')
    else source.hp=math.min(source.maxHp,source.hp+healing)end
    Events.emit(state,"max_hp",{amount=amount,target=source.id})
    require('abyss_relic_hooks').hpChanged(state,source,beforeHp)
end

local function feed(combat,state,item)
    local e,source,target=item.effect,item.source,item.target
    local before=target.hp
    combat.damage(state,source,target,e.value,nil,nil,e.resolved and e.resolved[target.id])
    if before>0 and target.hp<=0 and not target.escaped and not target.minion and not target.halfDead
        and (target.statuses.minion or 0)<=0 and source.hp>0 then feedReward(state,source,e.maxHp)end
end

local function reaper(combat,state,item)
    local e,source=item.effect,item.source
    local healed,reactions=0,{}
    for _,v in ipairs(state.enemies)do healed=healed+combat.damage(state,source,v,e.value,nil,reactions,e.resolved and e.resolved[v.id])end
    Actors.resolveDamageReactions(state,reactions,combat.retaliate)
    M.enqueue(state,{op="heal",value=healed},source)
end

local function heal(_,state,item)
    local e,source=item.effect,item.source
    local value=e.value
    if source==state.player then value=require('abyss_potion_health').modifyHealing(value,state.relics,true)end
    if state.originalV4 and source==state.player then
        require('abyss_original_v4_health').heal(state,source,value,nil,e.relic)
    elseif source.hp>0 then
        local amount=math.min(value,source.maxHp-source.hp)
        local beforeHp=source.hp
        source.hp=source.hp+amount
        Events.emit(state,"heal",{target=source.id,amount=amount})
        require('abyss_relic_hooks').hpChanged(state,source,beforeHp)
    end
end

local function applyFallback(combat,state,item)
    combat.applyEffects(state,{item.effect},item.source,item.target,item.instance)
end

local function block(combat,state,item)
    if item.effect.fixed then combat.block(state,item.source,item.effect.value,true)
    else applyFallback(combat,state,item)end
end

local function rareRelic(combat,state,item)
    require('abyss_rare_relics').applyEffect(combat,state,item.effect)
end

-- Execution is deliberately broader than supports(), which controls admission
-- to native card routing. Every known local operation has one finite lookup.
local actionHandlers={
    exhaustRandom=exhaustRandom,fiendFire=fiendFire,exhaustNonAttacks=exhaustNonAttacks,
    secondWind=exhaustNonAttacks,exhaustSpecific=exhaustSpecific,
    upgradeHand=upgradeHand,makeTempCardInHand=makeTemporaryCards,makeTempCardInDraw=makeTemporaryCards,
    generateAttack=generateAttack,randomizeHandCost=randomizeHandCost,
    exhaustMany=selection,discardRedraw=selection,discardToHand=selection,exhaustChoose=selection,
    recoverExhaust=selection,discardToDraw=selection,handToDraw=selection,dualWield=selection,
    resolveCurlUp=resolveCurlUp,obtainPotion=obtainPotion,doubleStrength=doubleStrength,
    spotWeakness=spotWeakness,damageRandom=damageRandom,feed=feed,reaper=reaper,heal=heal,block=block,
    rareGamblingChip=rareRelic,rareRelicGenerate=rareRelic,rareRelicDamageAll=rareRelic,rareRelicWeak=rareRelic,
}
function actionHandlers.shopRelic(combat,state,item)
    if item.effect.kind=='toolbox'then return require('abyss_shop_relics').beginToolbox(combat,state)end
    return require('abyss_shop_relics').execute(state,item.effect)
end
function actionHandlers.writhingRoll(_,state,item)return require('abyss_writhing_mass').roll(state,item.effect.targetId)end
function actionHandlers.writhingParasite(_,state,item)return require('abyss_writhing_mass').obtainParasite(state,item.source)end
function actionHandlers.giantHeadSlow(_,state,item)return require('abyss_giant_head').applySlow(Actors,state,item.effect)end
function actionHandlers.timeEater(combat,state,item)return TimeEater.execute(combat,state,item.effect,item.source,M)end
function actionHandlers.reptomancerSuicide(_,state,item)return require('abyss_reptomancer').cleanup(Actors,state,item.effect)end
function actionHandlers.enemyAction(combat,state,item)return combat.resolveEnemyAction(state,item.effect,item.source)end
function actionHandlers.staticRetaliation(combat,state,item)return combat.staticRetaliation(state,item.effect)end
function actionHandlers.classPotion(combat,state,item)return require('abyss_class_potions').apply(combat,state,item.effect)end
function actionHandlers.silentFinal(combat,state,item)return require('abyss_silent_final_cards').apply(combat,state,item)end
function actionHandlers.discover(combat,state,item)return require('abyss_potion_discovery').begin(combat,state,item.effect)end
function actionHandlers.colorless(combat,state,item)return require('abyss_colorless_cards').apply(combat,state,item)end
function actionHandlers.originalV4(combat,state,item)return require('abyss_original_v4').execute(combat,state,item)end
function actionHandlers.relicUpgradeRandomHand(combat,state)require('abyss_relic_hooks').upgradeRandomHand(combat,state)end
function actionHandlers.playTop(combat,state,item)
    local e=item.effect
    combat.autoplayTop(state,e.targetIndex,e.exhaustCards,e.append)
end
function actionHandlers.darklingAction(_,state,item)require('abyss_darklings').resolve(state,item.effect)end
function actionHandlers.heartBeat(combat,state,item)combat.heartBeat(state,item.effect)end
function actionHandlers.spireDeathRemove(_,state,item)Actors.removeSpireDeathPower(state,item.effect)end
function actionHandlers.awakenedAction(_,state,item)require('abyss_awakened_one').resolve(Actors,state,item.effect)end
function actionHandlers.capturedSharpHide(combat,state,item)combat.capturedSharpHide(state,item.effect)end
function actionHandlers.dispose(combat,state,item)combat.disposeCard(state,item)end
function actionHandlers.effectBatch(combat,state,item)
    combat.applyEffects(state,item.effect.effects,item.source,item.target,item.instance)
end

function M.apply(combat,state,item)
    local handler=actionHandlers[item.effect.op]
    if handler then return handler(combat,state,item)end
    -- These domains own their operation sets; keep their dynamic admission
    -- checks instead of duplicating their private lists in this registry.
    local e=item.effect
    if PlatedArmor.supports(e.op)then return PlatedArmor.apply(combat,state,e,M.enqueueReaction)end
    if Act2Powers.supports(e.op)then return Act2Powers.apply(Actors,state,e)end
    if require('abyss_watcher_final_cards').ops[e.op]then return require('abyss_watcher_final_cards').execute(combat,state,e)end
    applyFallback(combat,state,item)
end

-- Only source-supported retained actions may survive victory. Selection and
-- draws are cleared, but disposal, damage, ordinary block and healing survive.
local retained={originalV4=true,dispose=true,capturedSharpHide=true,damage=true,damageAll=true,damageRandom=true,loseHp=true,block=true,heal=true,feed=true,reaper=true,effectBatch=true}
function M.drain(combat,state)
    if state.drainingCardActions then return end
    state.drainingCardActions=true
    while not state.pendingChoice and not state.pendingDiscard and not state.actionQueue do
        local outcome=combat.outcome(state)
        if state.cardActions and #state.cardActions>0 then
            local item=table.remove(state.cardActions,1)
            local keep=retained[item.effect.op] or (M.reactionRetained(item.effect) or item.effect.op=='silentFinal' and require('abyss_silent_final_cards').allowedAfterVictory(item.effect))
            if item.effect.op=='enemyAction'then keep=combat.enemyActionRetained(item.effect)end
            if not outcome or outcome=="victory" and keep then M.apply(combat,state,item) end
        elseif not outcome and state.queuedCards and #state.queuedCards>0 then
            combat.resolveQueuedCard(state,table.remove(state.queuedCards,1))
        else
            -- Refresh observes the empty manager, then its draw joins this owner.
            local rare=require('abyss_rare_relics')
            local drew=not outcome and not state.endTurnAfterCard and rare.owns(state,'unceasing_top')
                and rare.onRefreshHand(state,true)
            if not drew then break end
        end
    end
    state.drainingCardActions=nil
    if not state.pendingChoice and not state.pendingDiscard and not state.actionQueue then state.cardActions=nil; state.queuedCards=nil; state.resolvingCard=nil end
    if combat.finishEarlyTurn then combat.finishEarlyTurn(state)end
end
return M
