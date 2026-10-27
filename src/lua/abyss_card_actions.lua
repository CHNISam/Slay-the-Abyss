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
    -- Exhaust triggers Power hooks first, the card's own trigger second; both
    -- run after movement. Dark Embrace/FNP append; Sentinel inserts at the top.
    state.exhaust[#state.exhaust+1] = instance
    Events.emit(state, "exhaust", {uid=instance.uid,cardId=instance.cardId})
    local p = state.player
    for _,id in ipairs(Actors.powerSequence(p,{'dark_embrace','feel_no_pain'})) do
        if id=='dark_embrace' and not combat.outcome(state) then
            M.enqueue(state,{op="draw",value=p.statuses[id]})
        elseif id=='feel_no_pain' then M.enqueue(state,{op="block",value=p.statuses[id],fixed=true}) end
    end
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

function M.apply(combat,state,item)
    local e,source,target,c=item.effect,item.source,item.target,item.instance
    local op,value=e.op,e.value
    if op=='writhingRoll'then return require('abyss_writhing_mass').roll(state,e.targetId)end
    if op=='writhingParasite'then return require('abyss_writhing_mass').obtainParasite(state,source)end
    if op=='giantHeadSlow'then return require('abyss_giant_head').applySlow(Actors,state,e)end
    if op=='timeEater'then return TimeEater.execute(combat,state,e,source,M)end
    if PlatedArmor.supports(op)then return PlatedArmor.apply(combat,state,e,M.enqueueReaction)end
    if op=='reptomancerSuicide'then return require('abyss_reptomancer').cleanup(Actors,state,e)end
    if Act2Powers.supports(op)then return Act2Powers.apply(Actors,state,e)end
    if op=='resolveCurlUp'then
        for _,enemy in ipairs(state.enemies)do
            if enemy.id==e.targetId then Actors.resolveCurlUp(state,enemy,e.value);break end
        end
        return
    end
    if op=='enemyAction'then return combat.resolveEnemyAction(state,e,source)end
    if op=='staticRetaliation'then return combat.staticRetaliation(state,e)end
    if op=='classPotion'then return require('abyss_class_potions').apply(combat,state,e)end
    if op=='silentFinal'then return require('abyss_silent_final_cards').apply(combat,state,item)end
    if require('abyss_watcher_final_cards').ops[op]then return require('abyss_watcher_final_cards').execute(combat,state,e)end
    if op=='obtainPotion' then
        state.generatedPotionOffers=state.generatedPotionOffers or {}
        state.generatedPotionOffers[#state.generatedPotionOffers+1]={id=e.id,unavailable=e.unavailable==true}
        if e.unavailable then
            Events.emit(state,'potion_content_unavailable',{id=e.id})
            return
        end
        return require('abyss_potion_generation').obtain(state.potionInventory,state.potionCapacity,e.id,
            require('abyss_relic_hooks').owns(state,'sozu'))
    end
    if op=='discover' then return require('abyss_potion_discovery').begin(combat,state,e)end
    if op=='colorless' then return require('abyss_colorless_cards').apply(combat,state,item) end
    if op=='originalV4' then return require('abyss_original_v4').execute(combat,state,item) end
    if op=='exhaustMany' or op=='discardRedraw' or op=='discardToHand' or op=="exhaustChoose" or op=="recoverExhaust" or op=="discardToDraw" or op=="handToDraw"
        or op=="dualWield" or op=="upgradeHand" and not e.all then return selection(combat,state,item)
    elseif op=="exhaustRandom" then
        if #state.hand>0 then
            local i=#state.hand==1 and not e.alwaysRandom and 1 or combat.cardRandom(state,#state.hand)
            M.exhaust(combat,state,state.hand[i],state.hand)
        end
    elseif op=="fiendFire" then
        -- Snapshot count now. Exhaust actions use random cards; draw hooks go
        -- behind the original hits, so newly drawn cards aren't exhausted.
        local count=#state.hand
        for _=1,count do M.enqueue(state,{op="damage",value=value,resolved=e.resolved},source,target,c,true) end
        for _=1,count do M.enqueue(state,{op="exhaustRandom",alwaysRandom=true},source,nil,nil,true) end
    elseif op=="exhaustNonAttacks" or op=="secondWind" then
        local cards={}
        for _,v in ipairs(state.hand) do
            if combat.cardDefinition(state,v).type~="attack" then cards[#cards+1]=v end
        end
        if op=="secondWind" then
            for _=1,#cards do M.enqueue(state,{op="block",value=value},source,nil,c,true) end
        end
        for _,v in ipairs(cards) do M.enqueue(state,{op="exhaustSpecific",uid=v.uid},source,nil,nil,true) end
    elseif op=="exhaustSpecific" then
        local v=remove(state.hand,e.uid); if v then M.exhaust(combat,state,v) end
    elseif op=="upgradeHand" then
        for _,v in ipairs(state.hand) do if combat.canUpgrade(state,v) then combat.upgrade(state,v) end end
    elseif op=="makeTempCardInHand" or op=="makeTempCardInDraw" then
        for _=1,value do
            local v=M.fresh(combat,state,e.card)
            M.created(combat,state,v)
            if op=='makeTempCardInHand' then M.created(combat,state,v)end
            if op=="makeTempCardInHand" then M.toHand(state,v)
            else table.insert(state.draw,combat.cardRandom(state,#state.draw+1),v) end
        end
    elseif op=="generateAttack" then
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
    elseif op=="doubleStrength" then
        local amount=source.statuses.strength or 0
        if amount~=0 then Actors.applyPower(state,source,"strength",amount,source) end
    elseif op=="spotWeakness" then
        local intent=target and target.intents[target.intentIndex]
        local attacking=false
        for _,f in ipairs(intent and intent.effects or {}) do if f.op=="damage" or f.op=="damageAll" then attacking=true end end
        if attacking then Actors.applyPower(state,source,"strength",value,source) end
    elseif op=="damageRandom" then
        for _=1,e.times or 1 do
            local enemies=liveEnemies(state)
            if #enemies==0 or source.hp<=0 then break end
            local victim=enemies[combat.cardRandom(state,#enemies)]
            combat.damage(state,source,victim,value,e.fixed,nil,e.resolved and e.resolved[victim.id])
        end
    elseif op=="feed" then
        local before=target.hp
        combat.damage(state,source,target,value,nil,nil,e.resolved and e.resolved[target.id])
        if before>0 and target.hp<=0 and not target.escaped and not target.minion and not target.halfDead
            and (target.statuses.minion or 0)<=0 and source.hp>0 then
            source.maxHp=source.maxHp+e.maxHp
            local beforeHp=source.hp
            if state.originalV4 and source==state.player then require('abyss_original_v4_health').heal(state,source,e.maxHp,nil,'feed')
            else source.hp=math.min(source.maxHp,source.hp+(source==state.player and require('abyss_potion_health').blocked(state.relics)and 0 or e.maxHp))end
            Events.emit(state,"max_hp",{amount=e.maxHp,target=source.id})
            require('abyss_relic_hooks').hpChanged(state,source,beforeHp)
        end
    elseif op=="reaper" then
        local healed,reactions=0,{}
        for _,v in ipairs(state.enemies) do healed=healed+combat.damage(state,source,v,value,nil,reactions,e.resolved and e.resolved[v.id]) end
        Actors.resolveDamageReactions(state,reactions,combat.retaliate)
        M.enqueue(state,{op="heal",value=healed},source)
    elseif op=='relicUpgradeRandomHand' then
        require('abyss_relic_hooks').upgradeRandomHand(combat,state)
    elseif op=='randomizeHandCost' then
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
    elseif op=="playTop" then
        combat.autoplayTop(state,e.targetIndex,e.exhaustCards,e.append)
    elseif op=="block" and e.fixed then combat.block(state,source,value,true)
    elseif op=="heal" then
        if source==state.player then
            value=require('abyss_potion_health').modifyHealing(value,state.relics,true)
        end
        if state.originalV4 and source==state.player then
            require('abyss_original_v4_health').heal(state,source,value,nil,e.relic)
        elseif source.hp>0 then
            local amount=math.min(value,source.maxHp-source.hp)
            local beforeHp=source.hp
            source.hp=source.hp+amount
            Events.emit(state,"heal",{target=source.id,amount=amount})
            require('abyss_relic_hooks').hpChanged(state,source,beforeHp)
        end
    elseif op=='darklingAction'then
        require('abyss_darklings').resolve(state,e)
    elseif op=='heartBeat'then
        combat.heartBeat(state,e)
    elseif op=='spireDeathRemove'then
        Actors.removeSpireDeathPower(state,e)
    elseif op=='awakenedAction'then
        require('abyss_awakened_one').resolve(Actors,state,e)
    elseif op=='capturedSharpHide'then
        combat.capturedSharpHide(state,e)
    elseif op=="dispose" then
        combat.disposeCard(state,item)
    elseif op=="effectBatch" then combat.applyEffects(state,e.effects,source,target,c)
    else combat.applyEffects(state,{e},source,target,c) end
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
        else break end
    end
    state.drainingCardActions=nil
    if not state.pendingChoice and not state.pendingDiscard and not state.actionQueue then state.cardActions=nil; state.queuedCards=nil; state.resolvingCard=nil end
    if combat.finishEarlyTurn then combat.finishEarlyTurn(state)end
end
return M
