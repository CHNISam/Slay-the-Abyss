-- Continuation-owned cards operations. Return values preserve pause and early exits.
local Handlers={}
function Handlers.discardTacticianEnergy(c)
    local state=c.state
    local effect=c.effect
    local event=c.helpers.event
    state.energy=state.energy+effect.value
    event(state,'discard_energy',{uid=effect.uid,amount=effect.value});return true
end

function Handlers.randomManualDiscard(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local discard=require('abyss_discard')
    local uid=effect.op=='randomManualDiscard' and require('abyss_silent_tactics_cards').randomDiscardUid(state) or effect.uid
    if uid then
        local ok,why=discard.discardSpecific(state,uid,effect.incrementFirst==true,M)
        assert(ok,why)
    end
    return true
end
Handlers.discardSpecific=Handlers.randomManualDiscard

function Handlers.drawWithFollowup(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local drawn=M.draw(state,effect.value)
    if #drawn>0 and M.cardDefinition(state,drawn[1]).type=='skill' then
        queue.pushTop(state,{kind='effect',effect={op='block',value=effect.blockAmount,fixed=true}})
    end
    return true
end

function Handlers.reduceGlassKnife(c)
    local state=c.state
    local effect=c.effect
    require('abyss_silent_tactics_cards').reduceGlassKnife(state,effect.uid,effect.value);return true
end

function Handlers.exhaustRandomAny(c)
    local state=c.state
    local queue=c.queue
    return require('abyss_warrior_status_cards').exhaustRandomAny(state,queue)
end

function Handlers.makeTempCardInHand(c)
    local state=c.state
    local effect=c.effect
    local build=require('abyss_build_actions')
    build.makeCard(state,effect);return true
end
Handlers.makeTempCard=Handlers.makeTempCardInHand

function Handlers.previousCardType(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local actions=require('abyss_watcher_attack_cards').planEffect(state,effect)
    for i=#actions,1,-1 do queue.pushTop(state,actions[i]) end
    return true
end
Handlers.halt=Handlers.previousCardType
Handlers.drawToHandSize=Handlers.previousCardType

function Handlers.calculatedGamble(c)
    local state=c.state
    local queue=c.queue
    local actions=require("abyss_silent_discard_cards").gambleActions(state)
    for i=#actions,1,-1 do queue.pushTop(state,actions[i]) end
    return true
end

function Handlers.discardReflexDraw(c)
    local M=c.combat
    local state=c.state
    local effect=c.effect
    local event=c.helpers.event
    M.draw(state,effect.value)
    event(state,"discard_draw",{uid=effect.uid,amount=effect.value})
    return true
end

function Handlers.exhaustHand(c)
    local state=c.state
    local effect=c.effect
    local queue=c.queue
    local findInstance=c.helpers.findInstance
    local instance=findInstance(state,effect.uid)
    assert(instance,"missing queued exhaust card")
    return require("abyss_exhaust").move(state,instance,"hand",queue,{onExhaustRelics=state.onExhaustRelics or {}})
end

function Handlers.restoreRetained(c)
    local state=c.state
    local queue=c.queue
    local event=c.helpers.event
    local cards=state.retainedCards or {}
    local retained=require("abyss_retained_cards")
    for _,instance in ipairs(cards) do
        local _,intent=retained.onRetained(state,instance)
        state.hand[#state.hand+1]=instance
        instance.retain=nil
        if type(intent)=="table" then queue.pushBottom(state,{kind="effect",effect=intent}) end
    end
    state.retainedCards=nil
    if #cards>0 then event(state,"retain",{count=#cards}) end
    return true
end

function Handlers.discardEndHand(c)
    local M=c.combat
    local state=c.state
    if require('abyss_boss_relics').retainsHand(state)then return true end
    while #state.hand>0 do
        local instance=table.remove(state.hand)
        local card=M.cardDefinition(state,instance)
        assert(not card.ethereal and not card.selfRetain and not instance.retain,"unprocessed end-turn card")
        state.discard[#state.discard+1]=instance
        if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
        require("abyss_silent_discard_cards").rememberDiscard(state,true)
    end
    return true
end

function Handlers.reduceRetainedCost(c)
    local state=c.state
    local effect=c.effect
    local event=c.helpers.event
    local findInstance=c.helpers.findInstance
    local instance=findInstance(state,effect.uid)
    assert(instance,"retained cost card left hand")
    require("abyss_retained_cards").reduceBaseCost(state,instance)
    event(state,"retained_cost",{uid=instance.uid,cardId=instance.cardId})
    return true
end

return Handlers
