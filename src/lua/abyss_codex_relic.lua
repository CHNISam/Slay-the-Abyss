-- Nilry's Codex/CodexAction at fixed319009d5. An optional three-card combat
-- reward, NOT Discovery: no zero-cost hand card and no retrieval RNG redraw.
local Events=require('abyss_events')
local M={}
local function owns(state)
    for _,id in ipairs(state.relics or {})do if id=='nilrys_codex'or id=="Nilry's Codex"then return true end end
    return false
end
local function pool(state)
    local result={}
    for _,rarity in ipairs({'common','uncommon','rare'})do
        for _,id in ipairs(assert(state.sourcePools.src[rarity],'missing Codex source pool'))do
            local d=assert(state.catalog.cards[id],'missing Codex source card '..id)
            if not d.healing then result[#result+1]=id end
        end
    end
    local distinct={};for _,id in ipairs(result)do distinct[id]=true end
    local count=0;for _ in pairs(distinct)do count=count+1 end
    assert(count>=3,'incomplete Codex source pool')
    return result
end
function M.begin(combat,state)
    if not owns(state)or state.codexEndTurnResolved==state.turn or combat.outcome(state)then return false end
    assert(state.phase=='player'and not state.pendingChoice,'invalid Codex owner turn')
    local candidates=pool(state);local cards,seen={},{}
    while #cards<3 do
        local id=candidates[combat.cardRandom(state,#candidates)]
        if not seen[id]then seen[id]=true;cards[#cards+1]={uid=#cards+1,cardId=id,upgraded=false}end
    end
    local serial=state.choiceSerial or 0
    assert(type(serial)=='number'and serial%1==0 and serial>=0 and serial<2147483647,'invalid Codex choice serial')
    state.choiceSerial=serial+1
    state.pendingChoice={op='codex',token=state.choiceSerial,uids={1,2,3},cards=cards,
        optional=true,turn=state.turn}
    Events.emit(state,'card_choice',{op='codex',token=state.choiceSerial})
    return true
end
function M.choose(combat,state,token,index,implemented)
    local p=state.pendingChoice
    if not p or p.op~='codex'or p.token~=token or p.turn~=state.turn or state.phase~='player'then return false,'stale_card_choice'end
    if type(index)~='number'or index%1~=0 or(index~=0 and not p.cards[index])then return false,'invalid_card_choice'end
    if index~=0 then
        if not implemented or not implemented(state.catalog.cards[p.cards[index].cardId])then return false,'card_content_unavailable'end
        local actions=require('abyss_card_actions')
        local c=actions.fresh(combat,state,p.cards[index].cardId)
        actions.created(combat,state,c)
        -- CardGroup.addToRandomSpot: no RNG when empty; bounded(size-1)
        -- otherwise (even size1), inserting BEFORE its sampled source slot.
        if #state.draw==0 then state.draw[1]=c
        else table.insert(state.draw,combat.cardRandom(state,#state.draw),c)end
        Events.emit(state,'cards_created',{source=state.player.id,relic='nilrys_codex',cardId=c.cardId,amount=1,pile='draw'})
    end
    state.codexEndTurnResolved=state.turn
    state.pendingChoice=nil
    Events.emit(state,'card_choice_resolved',{op='codex',index=index})
    return true
end
return M
