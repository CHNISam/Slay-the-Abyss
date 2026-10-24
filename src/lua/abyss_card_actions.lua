-- Shared combat card actions. Data only continuations can pause for a real UID
-- choice; no UI callbacks, platform objects, or permanent deck writes live here.
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local M = {}
local operations = { exhaustRandom=true, exhaustChoose=true, exhaustNonAttacks=true,
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
    c.uid=state.nextUid
    state.nextUid=state.nextUid+1.0
    assert(state.nextUid>c.uid and state.nextUid<math.huge,"nextUid cannot advance")
    return c
end

function M.toHand(state, c)
    local pile=#state.hand<state.rules.player.maxHand and state.hand or state.discard
    pile[#pile+1]=c
end

local function candidates(combat,state,op)
    local pile=op=="recoverExhaust" and state.exhaust or op=="discardToDraw" and state.discard or state.hand
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
    local options=candidates(combat,state,op)
    if #options==0 then return end
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
            for _=1,count do M.toHand(state,M.fresh(combat,state,c.cardId,c)) end
        end
    else error("invalid choice operation") end
    Events.emit(state,"card_choice_resolved",{op=op,uid=uid})
end

function M.choose(combat,state,token,uid)
    local choice=state.pendingChoice
    if not choice or token~=choice.token then return false,"stale_card_choice" end
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
    if op=="exhaustChoose" or op=="recoverExhaust" or op=="discardToDraw" or op=="handToDraw"
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
            source.hp=math.min(source.maxHp,source.hp+e.maxHp)
            Events.emit(state,"max_hp",{amount=e.maxHp,target=source.id})
        end
    elseif op=="reaper" then
        local healed,reactions=0,{}
        for _,v in ipairs(state.enemies) do healed=healed+combat.damage(state,source,v,value,nil,reactions,e.resolved and e.resolved[v.id]) end
        Actors.resolveDamageReactions(state,reactions,combat.retaliate)
        M.enqueue(state,{op="heal",value=healed},source)
    elseif op=="playTop" then
        combat.autoplayTop(state,e.targetIndex)
    elseif op=="block" and e.fixed then combat.block(state,source,value,true)
    elseif op=="heal" then
        if source.hp>0 then
            local amount=math.min(value,source.maxHp-source.hp)
            source.hp=source.hp+amount
            Events.emit(state,"heal",{target=source.id,amount=amount})
        end
    elseif op=="dispose" then
        combat.disposeCard(state,item)
    elseif op=="effectBatch" then combat.applyEffects(state,e.effects,source,target,c)
    else combat.applyEffects(state,{e},source,target,c) end
end

-- Only source-supported retained actions may survive victory. Selection and
-- draws are cleared, but disposal, damage, ordinary block and healing survive.
local retained={dispose=true,damage=true,damageAll=true,damageRandom=true,block=true,heal=true,feed=true,reaper=true,effectBatch=true}
function M.drain(combat,state)
    if state.drainingCardActions then return end
    state.drainingCardActions=true
    while not state.pendingChoice do
        local outcome=combat.outcome(state)
        if state.cardActions and #state.cardActions>0 then
            local item=table.remove(state.cardActions,1)
            if not outcome or outcome=="victory" and retained[item.effect.op] then M.apply(combat,state,item) end
        elseif not outcome and state.queuedCards and #state.queuedCards>0 then
            combat.resolveQueuedCard(state,table.remove(state.queuedCards,1))
        else break end
    end
    state.drainingCardActions=nil
    if not state.pendingChoice then state.cardActions=nil; state.queuedCards=nil; state.resolvingCard=nil end
end
return M
