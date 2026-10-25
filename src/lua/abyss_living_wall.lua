-- LivingWall at fixed source 319009d5. No event-pool registration here.
local C = require('abyss_combat')
local Transform = require('abyss_transform_card')
local Capability = require('abyss_card_capability')
local M = {}
local function find(entries,id,key)
    for i,entry in ipairs(entries) do if entry[key or 'id']==id then return entry,i end end
end
local protected = {Necronomicurse=true,CurseOfTheBell=true,AscendersBane=true,
    necronomicurse=true,curse_of_the_bell=true,ascenders_bane=true}
function M.purgeCards(run)
    local rows={}
    for _,card in ipairs(run.deck) do
        local context=run.transformContext
        local source=context and context.cards and context.cards[card.cardId]
        local sourceId=source and source.sourceId or card.cardId
        if not protected[sourceId] and not protected[card.cardId] and not card.inBottleFlame and not card.inBottleLightning and not card.inBottleTornado then
            -- Source addToTop is group.add(c), preserving masterDeck order.
            rows[#rows+1]=C.copy(card)
        end
    end
    return rows
end
-- Context is supplied by the complete source-pool owner, never synthesized
-- from the smaller playable catalog. Unsupported draws are atomic refusals.
local function transformed(run,instance)
    local context=run.transformContext
    if type(context)~='table' or type(context.cards)~='table' or type(context.sourceToLocal)~='table' then
        return nil,'event_content_unavailable'
    end
    local original=context.cards[instance.cardId]
    if type(original)~='table' then return nil,'event_content_unavailable' end
    local selected,rng=Transform.select(original.category,original.sourceId,context.pools,run.miscRng)
    if not selected then return nil,'event_content_unavailable' end
    local id=context.sourceToLocal[selected.cardId]
    local definition=type(id)=='string' and find(run.data.cards.cards,id)
    if not Capability.isImplemented(definition) then return nil,'event_content_unavailable' end
    local uid=run.nextDeckUid
    if type(uid)~='number' or uid%1~=0 or uid<1 or uid>=9007199254740991.0 or find(run.deck,uid,'uid') then
        return nil,'invalid_deck_uid'
    end
    return {uid=uid,cardId=id,upgraded=false},rng,selected.cardId
end
function M.choose(run,flow,choice,uid,upgradeable,upgradeCards)
    if choice~='forget' and choice~='change' and choice~='grow' then return false,'invalid_event_choice' end
    if uid~=nil and flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
    if flow.event.stage=='choose_card' and choice~=flow.event.choice then return false,'invalid_event_choice' end
    local purge=M.purgeCards(run)
    if not flow.event.stage and uid==nil then
        if choice=='grow' and #upgradeCards(run)==0 then return false,'card_not_upgradeable' end
        flow.event.choice=choice
        if #purge==0 then flow.event.empty=true;return true,'complete' end
        flow.event.stage='choose_card'
        return true,'choose_card'
    end
    -- Explicit UID commands must select a currently legal card, even when the
    -- previously displayed group has gone empty. Never turn stale input into success.
    local instance,position=find(run.deck,uid,'uid')
    if not instance then return false,'invalid_card' end
    if choice=='grow' then
        if not upgradeable(run,instance) then return false,'card_not_upgradeable' end
        instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
        instance.upgraded=true;flow.event.upgradedUids={uid}
    else
        if not find(purge,uid,'uid') then return false,'card_not_purgeable' end
        if choice=='forget' then
            table.remove(run.deck,position);flow.event.removedUid=uid
        else
            local card,rng,sourceId=transformed(run,instance)
            if not card then return false,rng end
            -- Source removes the old card then ShowCardAndObtain appends the
            -- fresh unupgraded card. Publish the advanced misc only with both.
            table.remove(run.deck,position);run.deck[#run.deck+1]=card
            run.nextDeckUid=card.uid+1.0;run.miscRng=rng
            flow.event.removedUid=uid;flow.event.obtainedCardUid=card.uid;flow.event.obtainedSourceId=sourceId
        end
    end
    flow.event.choice=choice;flow.event.stage='result'
    return true,'complete'
end
return M
