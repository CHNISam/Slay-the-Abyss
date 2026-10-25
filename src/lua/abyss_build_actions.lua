-- Source-specific card actions. Plans contain data; Combat owns execution.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local M={}
M.ops={gainStrengthPower=true,spotWeakness=true,makeTempCardInHand=true,
    barrageDamage=true,compileDriverDraw=true,weakIfAttacking=true,nextEnergy=true,
    doubleEnergy=true,xBlock=true,ftlDamage=true,bowlingBash=true,halt=true,
    previousCardType=true,drawToHandSize=true,makeTempCard=true}
M.ops.nextBlock=true;M.ops.heelHook=true;M.ops.gainCardTriggerPower=true
M.ops.pileChoice=true
local function integer(n,min)
    assert(type(n)=='number' and n==n and n%1==0 and n>=(min or 0) and n<=2147483647,'invalid build action amount')
    return n
end
function M.isAttacking(target)
    if not Actors.isActive(target) then return false end
    if type(target.intentBaseDmg)=='number' then return target.intentBaseDmg>=0 end
    local intent=target.intents and target.intents[target.intentIndex]
    if not intent then return false end
    for _,effect in ipairs(intent.effects or {}) do
        if effect.op=='damage' or effect.op=='damageAll' then return true end
    end
    return false
end
function M.makeCard(state,effect)
    local id=effect.cardId or effect.card
    assert(type(id)=='string' and state.catalog.cards[id],'unknown temporary card')
    assert((state.player.statuses.master_reality or 0)==0,'Master Reality generation unsupported')
    local count=integer(effect.value)
    local pile=effect.pile or 'hand'
    assert(pile=='hand' or pile=='draw','invalid temporary destination')
    if pile=='draw' then assert(effect.randomSpot==true and state.cardRandomRng,'missing card insertion RNG') end
    local seen={}
    for _,name in ipairs({'hand','draw','discard','exhaust'}) do
        for _,c in ipairs(state[name]) do seen[c.uid]=true end
    end
    if state.cardInUse then seen[state.cardInUse.uid]=true end
    for _=1,count do
        local uid=state.nextUid
        assert(type(uid)=='number' and uid>0 and uid%1==0 and uid+1.0>uid and uid+1.0<math.huge and not seen[uid],'invalid nextUid')
        local card={uid=uid,cardId=id,upgraded=effect.upgraded==true}
        require('abyss_warrior_status_cards').created(state,card,'make_copy')
        if id=='shiv' then require('abyss_shivs').created(state,card) end
        state.nextUid=uid+1.0;seen[uid]=true
        local destination=pile
        if pile=='hand' and #state.hand>=state.rules.player.maxHand then destination='discard' end
        if destination=='draw' and #state.draw>0 then
            local i=require('abyss_sts_random').randomInt(state.cardRandomRng,#state.draw-1)+1
            table.insert(state.draw,i,card)
        else state[destination][#state[destination]+1]=card end
        if destination=='hand' and (state.player.statuses.corruption or 0)~=0 then
            require('abyss_corruption').created(state,card)
        end
        Events.emit(state,'cards_created',{source=state.player.id,cardId=id,amount=1,pile=destination})
    end
end
function M.applyNextEnergy(state,n,id)
    n=integer(n);id=id or 'energized'
    Actors.applyPower(state,state.player,id,math.min(n,999),state.player)
    if state.player.statuses[id] then state.player.statuses[id]=math.min(999,state.player.statuses[id]) end
end
return M
