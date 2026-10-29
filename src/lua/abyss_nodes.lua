-- Seven node flows over the existing same-run state. Adapters must navigate via enter/available.
-- Battle commands/reward selection remain Run commands, followed by completeCombat.
-- Combat relic effects and persistence restoration belong to their owning modules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Combat = require("abyss_combat")
local Capability = require("abyss_card_capability")

local Inventory = require("abyss_inventory")
local Shop = require("abyss_shop")
local External=require('abyss_external_random')

local CardPool = require('abyss_card_pool')
local LivingWall = require('abyss_living_wall')

local RelicHooks = require('abyss_relic_hooks')

local Act2Events = require('abyss_act2_events')
local Match=require('abyss_match_event')

local Acts = require('abyss_acts')
local Treasure=require('abyss_treasure')
local Neow=require('abyss_neow')
local TreasureSource=require('abyss_treasure_source')

local M = {}
local battleKinds = { combat = true, elite = true, boss = true }

local Common=require('abyss_nodes_common')
local find,owns=Common.find,Common.owns
local endingKeyEligible=Common.endingKeyEligible
local upgradeable,upgradeCards=Common.upgradeable,Common.upgradeCards
local healingPreview,matchingMap=Common.healingPreview,Common.matchingMap
local pending,complete=Common.pending,Common.complete

local Sources=require('abyss_nodes_sources')
local campSource=Sources.campSource

local enter=require('abyss_nodes_entry')(M)

local function validateEntryMap(run,map)
    if type(map)~='table' or getmetatable(map)~=nil then return false,'invalid_snapshot' end
    -- Chapter birth facts, not caller-supplied markers, decide whether this is
    -- a canonical map. Keep the old no-birth component API, but never let an
    -- Emerald contract manufacture its own context or downgrade a born map.
    local canonical=run.mapBirthAct~=nil or run.mapBirthContext~=nil
        or map.emeraldSelection~=nil or map.mapRng~=nil or map.emeraldBoost~=nil
    if not canonical and type(map.nodes)=='table' then
        for _,node in next,map.nodes do
            if type(node)=='table' and rawget(node,'hasEmeraldKey')~=nil then canonical=true;break end
        end
    end
    if canonical then
        local restored,reason=M.restoreMap(run,map)
        if not restored then return false,reason end
    end
    return true
end

function M.enter(run,map,nodeId)
    -- Validate the original graph/continuous stream before a copy can discard
    -- metatables and before room hooks, encounter consumption or battle setup.
    local valid,why=validateEntryMap(run,map)
    if not valid then return false,why end
    -- Map.choose and every entry hook stay private until battle setup and room
    -- preparation both succeed. Keep the public map/root/path owners stable.
    local stagedMap=Combat.copy(map)
    local ok,reason=Run.transaction(run,function(staged)return enter(staged,stagedMap,nodeId)end)
    if not ok then return false,reason end
    map.floor,map.currentNodeId=stagedMap.floor,stagedMap.currentNodeId
    if stagedMap.mapRng then
        map.mapRng,map.emeraldBoost=Combat.copy(stagedMap.mapRng),Combat.copy(stagedMap.emeraldBoost)
    end
    for i=#map.path,1,-1 do map.path[i]=nil end
    for i,id in ipairs(stagedMap.path)do map.path[i]=id end
    return true,reason
end

-- Opening is outside the map. It must not count as a visited room, spend an
-- event draw, or run room-entry relic hooks. Existing direct Run.new stays valid.
function M.beginNeow(run,map,history)
    if type(map)~='table' or type(map.path)~='table' or map.floor~=0 or map.currentNodeId~=nil or #map.path~=0 then return false,'neow_opening_unavailable' end
    return Run.transaction(run,function(staged)
        if staged.phase~='map' or staged.nodeFlow~=nil or staged.runSeed~=map.runSeed then return false,'neow_opening_unavailable' end
        local flow={type='event',roomKind='neow',mapSeed=map.seed,mapSignature=map.sourceSignature,floor=map.floor,event={id='neow'}}
        local ok,why=Neow.prepare(staged,flow.event,history);if not ok then return false,why end
        staged.nodeFlow,staged.phase,staged.floor=flow,'node',0
        staged.neowStatus='available'
        return true
    end)
end

function M.advanceAct(run,map)
    if (run.act or 1)~=(map.act or 1) or run.runSeed~=map.runSeed
        or not matchingMap(run.nodeFlow,map) then return false,'map_mismatch' end
    local nextMap
    local ok,reason=Run.transaction(run,function(staged)
        local advanced,why=Run.advanceAct(staged)
        if not advanced then return false,why end
        nextMap=Map.generate(staged.data,staged.runSeed,staged.act,assert(Run.mapContext(staged)))
        return true
    end)
    if not ok then return false,reason end
    for key in pairs(map)do map[key]=nil end
    for key,value in pairs(nextMap)do map[key]=value end
    return true
end

local function shopOffer(flow,category,reference,bySlot)
    local offer
    if bySlot or category=='potions' then offer=flow[category][reference]
    elseif category=='cards' then
        -- Courier may legitimately stock the same card at different prices.
        -- Keep the ID API only when it identifies exactly one shelf offer.
        for _, candidate in ipairs(flow.cards) do
            if candidate.id==reference then
                if offer then return nil end
                offer=candidate
            end
        end
    else offer=find(flow[category],reference) end
    return offer
end

local function validateShopPotion(run,category,offer)
    if category=='potions' then
        if Shop.owns(run,'sozu') then return false,'potions_blocked' end
        if Run.potionCount(run)>=Run.potionCapacity(run) then return false,'potion_slots_full' end
        if not find(run.data.potions.potions,offer.id) then return false,'unknown_potion' end
    end
    return true
end

local function restockShop(run,flow,category,offer)
    local stagedRun,stagedFlow={},Combat.copy(flow)
    for k,v in pairs(run)do stagedRun[k]=v end
    local called,transaction=pcall(Shop.afterPurchase,stagedRun,stagedFlow,category,stagedFlow[category][offer.slot])
    if not called then return false,'shop_content_unavailable' end
    flow.cards,flow.relics,flow.potions,flow.shopRng=stagedFlow.cards,stagedFlow.relics,stagedFlow.potions,stagedFlow.shopRng
    run.shopRng=flow.shopRng
    run.relicPool=stagedRun.relicPool
    run.cardRng,run.cardRarityOffset=stagedRun.cardRng,stagedRun.cardRarityOffset
    -- Commit session entropy only after all staged grants/hooks succeed.
    if transaction and not pcall(External.commit,transaction) then return false,'shop_content_unavailable' end
    return true
end

function M.restoreMap(run,snapshot)
    local context,reason=Run.mapContext(run)
    if not context then return nil,reason end
    if type(snapshot)~='table' or snapshot.runSeed~=run.runSeed or (snapshot.act or 1)~=(run.act or 1)then
        return nil,'map_mismatch'
    end
    return Map.restore(run.data,snapshot,context)
end

local function endingOwnerMismatch(run,owner)
    return run.phase~='ending_proceed' or run.act~=4 or run.floor~=55 or type(owner)~='table'
        or owner.version~=1 or owner.act~=4 or owner.floor~=55 or owner.runSeed~=run.runSeed
        or owner.encounterId~=run.encounterId or owner.combatGeneration~=run.combatGeneration

end

local function endingFlowMismatch(flow,owner,map)
    return type(flow)~='table' or flow.type~='boss' or flow.complete~=false
        or flow.encounterId~=owner.encounterId or type(map)~='table'
end

function M.endingProceedSource(run,map)
    local owner,flow=run.endingProceed,run.nodeFlow
    if endingOwnerMismatch(run,owner) or endingFlowMismatch(flow,owner,map) then return nil,'ending_proceed_source_mismatch' end
    local birth=Run.mapContext(run)
    if not birth or not birth.endingUnlocked or not birth.emeraldOwned then return nil,'ending_history_required' end
    local ok,restored=pcall(function()return M.restoreMap(run,map)end)
    if not ok or not restored or map.act~=4 or map.floor~=55 or not matchingMap(flow,map)
        or map.path[#map.path]~=flow.id then return nil,'map_mismatch' end
    local last=restored.nodes[#restored.nodes]
    if last.id~=flow.id or last.type~='boss' or last.floor~=55 then return nil,'map_mismatch' end
    return owner
end

function M.proceedEnding(run,map,expectedOwner)
    if expectedOwner==nil or not rawequal(expectedOwner,run.endingProceed) then return false,'ending_proceed_owner_mismatch' end
    local owner,reason=M.endingProceedSource(run,map)
    if not rawequal(owner,expectedOwner) then return false,reason or 'ending_proceed_owner_mismatch' end
    return Run.proceedEnding(run,expectedOwner)
end

local function eventView(run,node)
    local rules = run.data.rules.events[node.event.id] or {}
    node.event.removeCost = rules.removeCost or 0
    node.upgradeCards=upgradeCards(run)
    node.upgradesLeft=1
    if node.event.id=='living_wall' then node.event.purgeCards=LivingWall.purgeCards(run) end
    if node.event.id=='bonfire' then node.event.purgeCards=LivingWall.purgeCards(run) end
    if node.event.id=='transmogrifier' then node.event.purgeCards=LivingWall.purgeCards(run) end
    if node.event.id=='wheel' then node.event.purgeCards=LivingWall.purgeCards(run) end
    if Act2Events.ids[node.event.id] then Act2Events.view(run,node.event) end
    if node.event.id=='match_game' then Match.view(run,node.event) end
    if node.event.id=='neow'then Neow.view(run,node.event)end
    if node.event.id == "cleric" then
        node.event.healCost = rules.healCost
        node.event.heal = healingPreview(run,math.floor(run.maxHp * rules.healPercent / 100))
    end
    node.event.options=M.eventOptions(run,node)
end

function M.view(run, map)
    local available, mapView = M.available(run, map), Map.view(map)
    local enabled = #available > 0
    if not enabled then for _, node in ipairs(mapView.nodes) do node.available = false end end
    local node = run.nodeFlow and Combat.copy(run.nodeFlow) or nil
    if run.phase=='ending_proceed' then
        node=node or {id=map.currentNodeId,floor=55,complete=false}
        node.type,node.event,node.reward='ending_proceed',nil,nil
        node.canProceed=M.endingProceedSource(run,map)~=nil
        return {phase=run.phase,node=node,map=mapView,available={},navigationEnabled=false}
    end
    if node and not node.complete then
        node.purgeCards=LivingWall.purgeCards(run)
        if node.type == "camp" then
            node.upgradeCards = upgradeCards(run)
            node.canRest=not RelicHooks.owns(run,'coffee_dripper')
            node.canForge=not RelicHooks.owns(run,'fusion_hammer') and #node.upgradeCards>0
            node.canLeaveCamp=not node.canRest and not node.canForge and not endingKeyEligible(run,'ruby')
            node.heal = healingPreview(run,RelicHooks.campHealAmount(run,math.floor(run.maxHp * run.data.rules.camp.healPercent / 100)))
            node.dreamCatcher=RelicHooks.owns(run,'dream_catcher')
        elseif node.type == "shop" then
            node.removePrice = Shop.removePrice(run)
            node.removeAvailable = not node.removalUsed
        elseif node.type == "event" then
            eventView(run,node)
        end
    end
    return { phase = run.phase, node = node, map = mapView, available = available, navigationEnabled = enabled }
end

local function recallEligible(run)
    return endingKeyEligible(run,'ruby')
end

function M.recallSource(run,map)
    local source,reason=campSource(run,map);if not source then return nil,reason end
    local eligible,why=recallEligible(run);if not eligible then return nil,why end
    return source
end

function M.recall(run,map,source)
    local current,reason=M.recallSource(run,map)
    if current then
        if type(source)~='table' or getmetatable(source)~=nil then reason='camp_source_mismatch'
        else
            for key,value in pairs(current)do
                if source[key]~=value then reason='camp_source_mismatch';break end
            end
        end
    end
    -- Preserve original-owner validation before graph copying, but pass a
    -- refused nested command through the existing transaction poison path.
    if not current or reason then return Run.transaction(run,function()return false,reason end)end
    return Run.transaction(run,function(staged)
        local accepted,detail=recallEligible(staged);if not accepted then return false,detail end
        -- No rest/forge hooks or random stream belongs to Recall. Resolve the
        -- room and its rewards, then grant only the Ruby key exactly once.
        staged.keys.ruby=true
        staged.nodeFlow.campChoice='recall'
        staged.nodeFlow.reward=nil
        return complete(staged,'recall')
    end)
end

function M.rest(run)
    return Run.transaction(run,function(staged)
        local flow,reason=pending(staged,'camp');if not flow then return false,reason end
        if flow.campChoice then return false,'camp_choice_made' end
        if RelicHooks.owns(staged,'coffee_dripper') then return false,'rest_blocked_by_relic' end
        local healing=RelicHooks.campHealAmount(staged,math.floor(staged.maxHp*staged.data.rules.camp.healPercent/100))
        flow.restHealed=Run.heal(staged,healing)
        flow.campChoice='rest'
        flow.restReward=RelicHooks.onRest(staged,function(owner)
            -- RestRoom uses ordinary reward chances, independently of the
            -- previous encounter. Its persistent card RNG/offset still advance.
            local context={data=owner.data,cardRng=owner.cardRng,
                cardRarityOffset=owner.cardRarityOffset,encounterTier='normal'}
            local cards,rng,offset,upgrades=CardPool.prepareRewards(context)
            for _,id in ipairs(cards)do
                if not Capability.isImplemented(find(owner.data.cards.cards,id))then error('card_content_unavailable')end
            end
            owner.cardRng,owner.cardRarityOffset=rng,offset
            local reward={cards=cards,resolved=false,cardUpgrades=upgrades}
            RelicHooks.previewCardReward(owner,reward,true)
            return reward
        end)
        if flow.restReward then return true,'choose_rest_card' end
        return complete(staged)
    end)
end

function M.claimRestReward(run,choice)
    return Run.transaction(run,function(staged)
        local flow,reason=pending(staged,'camp');if not flow then return false,reason end
        local reward=flow.restReward
        if flow.campChoice~='rest' or not reward or reward.resolved then return false,'no_pending_reward' end
        if type(choice)~='number' or choice%1~=0 or choice<0 or choice>#reward.cards then return false,'invalid_reward_choice' end
        if choice>0 then
            local ok,why=Run.obtainCard(staged,reward.cards[choice],
                {upgraded=reward.cardUpgrades and reward.cardUpgrades[choice]==true});if not ok then return false,why end
        end
        reward.resolved,reward.choice=true,choice
        return complete(staged)
    end)
end

function M.upgrade(run, uid)
    local flow, reason = pending(run, "camp"); if not flow then return false, reason end
    if flow.campChoice and flow.campChoice ~= "upgrade" then return false, "camp_choice_made" end
    if RelicHooks.owns(run,'fusion_hammer') then return false,'upgrade_blocked_by_relic' end
    local instance = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    if flow.upgradesLeft <= 0 or not upgradeable(run, instance) then return false, "card_not_upgradeable" end
    instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
    instance.upgraded, flow.campChoice = true, "upgrade"
    flow.upgradesLeft = flow.upgradesLeft - 1
    if flow.upgradesLeft == 0 or #upgradeCards(run) == 0 then return complete(run) end
    return true
end

-- RestRoom permits proceeding when all supported camp actions are unusable.
-- This does not simulate rest/smith or grant any of their hooks and benefits.
function M.leaveCamp(run)
    return Run.transaction(run,function(staged)
        local flow,reason=pending(staged,'camp');if not flow then return false,reason end
        if flow.campChoice then return false,'camp_choice_made' end
        if endingKeyEligible(staged,'ruby') or not RelicHooks.owns(staged,'coffee_dripper') or
            (not RelicHooks.owns(staged,'fusion_hammer') and #upgradeCards(staged)>0) then
            return false,'camp_action_available'
        end
        flow.campChoice='leave';return complete(staged)
    end)
end

local function purchaseCommand(run, category, reference, bySlot)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    local offer=shopOffer(flow,category,reference,bySlot)
    local id=offer and offer.id
    if not offer or offer.sold or offer.unavailable or (category == "relics" and owns(run.relics, id)) then
        return false, "item_unavailable"
    end
    if run.gold < offer.price then return false, "insufficient_gold" end
    local valid,detail=validateShopPotion(run,category,offer);if not valid then return false,detail end
    -- Run.transaction rolls back payment/equip if restock fails. Equip first:
    -- source StoreRelic.purchaseRelic observes its effects during Courier draw.
    run.gold = run.gold - offer.price
    RelicHooks.onSpendGold(run,'shop')
    if category == "cards" then
        local ok,why=Run.obtainCard(run,id,{upgraded=offer.upgraded,upgrades=offer.upgrades});if not ok then return false,why end
    elseif category=='potions' then
        local ok,why=Run.obtainPotion(run,offer.id);if not ok then return false,why end
    else
        local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
    end
    return restockShop(run,flow,category,offer)
end

local function purchase(run,category,reference,bySlot)
    return Run.transaction(run,function(staged)return purchaseCommand(staged,category,reference,bySlot)end)
end

function M.buyCard(run, id) return purchase(run, "cards", id) end
function M.buyCardSlot(run, slot)
    if type(slot)~='number' or slot%1~=0 or slot<1 or slot>7 then return false,'item_unavailable' end
    return purchase(run,'cards',slot,true)
end
function M.buyRelic(run, id) return purchase(run, "relics", id) end
function M.buyPotion(run, slot)
    if type(slot)~='number' or slot%1~=0 or slot<1 or slot>3 then return false,'item_unavailable' end
    return purchase(run,'potions',slot)
end

local function removeCard(run, uid)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    -- The service is a one-use offer per shop; the price increase belongs to later shops.
    if flow.removalUsed then return false, "removal_unavailable" end
    local instance = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    if not find(LivingWall.purgeCards(run),uid,'uid') then return false,'card_not_purgeable' end
    local price = Shop.removePrice(run)
    if run.gold < price then return false, "insufficient_gold" end
    run.gold, run.shopRemoveCount = run.gold - price, (run.shopRemoveCount or 0) + 1
    RelicHooks.onSpendGold(run,'shop')
    local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
    flow.removalUsed = true
    return true
end

function M.removeCard(run,uid)
    return Run.transaction(run,function(staged)return removeCard(staged,uid)end)
end

function M.leaveShop(run)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    return complete(run)
end

local function openSourceTreasure(run,flow)
    local prepared,why=Treasure.open(run,flow.chest,flow.reward)
    if not prepared then return false,why end
    for _,key in ipairs({'treasureRng','relicPool','cardRng','relicCounters'})do run[key]=prepared[key]end
    for _,id in ipairs(prepared.curseSourceIds)do
        local ok,reason=Run.obtainCard(run,id);if not ok then return false,reason end
    end
    flow.chest,flow.reward=prepared.chest,prepared.reward
    return true
end
function M.openTreasure(run)
    return Run.transaction(run,function(staged)
        local flow,why=pending(staged,'treasure');if not flow then return false,why end
        if not flow.chest then return false,'source_chest_required' end
        return openSourceTreasure(staged,flow)
    end)
end
local function treasureRewardCoordinatesMismatch(run,flow)
    return run.floor~=flow.floor or type(flow.floor)~='number' or flow.floor%1~=0 or flow.floor<1 or flow.floor>55
        or type(flow.id)~='string' or flow.id=='' or type(run.runSeed)~='string' or flow.mapSeed~=run.runSeed
        or type(flow.mapSignature)~='string' or flow.mapSignature==''

end

local function treasureRewardOwnerMismatch(run,flow)
    return treasureRewardCoordinatesMismatch(run,flow) or type(run.roomGeneration)~='number' or run.roomGeneration%1~=0 or run.roomGeneration<1 or run.roomGeneration>2147483647

end

local function treasureRewardShapeMismatch(flow,slot)
    return type(flow.reward)~='table' or getmetatable(flow.reward)~=nil
        or type(flow.reward.items)~='table' or getmetatable(flow.reward.items)~=nil or flow.complete~=false
        or type(slot)~='number' or slot%1~=0 or slot<1
end

function M.treasureRewardSource(run,slot)
    local flow,why=pending(run,'treasure');if not flow then return nil,why end
    if type(flow.chest)~='table' or getmetatable(flow.chest)~=nil or flow.chest.opened~=true then return nil,'chest_closed' end
    if treasureRewardOwnerMismatch(run,flow) or treasureRewardShapeMismatch(flow,slot) then return nil,'treasure_source_mismatch' end
    for _,item in ipairs(flow.reward.items)do if item.slot==slot then
        if getmetatable(item)~=nil then return nil,'treasure_source_mismatch' end
        return {id=flow.id,floor=flow.floor,roomGeneration=run.roomGeneration,slot=slot,
            kind=item.kind,sourceId=item.sourceId or item.kind}
    end end
    return nil,'treasure_reward_unavailable'
end
local function takeSourceTreasure(run,flow,slot)
    local taken,why=Treasure.take(flow.reward,slot);if not taken then return false,why end
    local item=taken.item
    if item.kind=='relic' then
        local ok,reason=Run.obtainRelic(run,item.id);if not ok then return false,reason end
    elseif item.kind=='gold' then Run.gainGold(run,item.amount)
    else
        local eligible,reason=endingKeyEligible(run,'sapphire');if not eligible then return false,reason end
        run.keys.sapphire=true
    end
    flow.reward=taken.reward
    if item.kind=='sapphire' or item.origin=='base' then flow.treasureChoice=item.kind end
    return true,item.kind
end
function M.claimTreasureReward(run,token)
    -- Validate plain source owners before copying can erase a metatable.
    if type(token)~='table' or getmetatable(token)~=nil then
        return Run.transaction(run,function()return false,'treasure_source_mismatch'end)
    end
    local initial,reason=M.treasureRewardSource(run,token.slot)
    if not initial then return Run.transaction(run,function()return false,reason end)end
    return Run.transaction(run,function(staged)
        if type(token)~='table' or getmetatable(token)~=nil then return false,'treasure_source_mismatch' end
        local fields={id=true,floor=true,roomGeneration=true,slot=true,kind=true,sourceId=true}
        for key in pairs(token)do if not fields[key]then return false,'treasure_source_mismatch' end end
        local live,why=M.treasureRewardSource(staged,token.slot);if not live then return false,why end
        for key,value in pairs(live)do if token[key]~=value then return false,'treasure_source_mismatch' end end
        local flow=staged.nodeFlow
        if flow.roomKind=='boss_treasure' then return false,'boss_treasure_choice_required' end
        local ok,kind=takeSourceTreasure(staged,flow,token.slot);if not ok then return false,kind end
        if #flow.reward.items==0 then return complete(staged,kind) end
        return true,kind
    end)
end
local function finishBossTreasure(run)
    if Acts.isCompetition(run) and (run.act~=1 and run.act~=2
        or run.floor~=Acts.get(run.act).last or run.nodeFlow.floor~=run.floor) then
        return false,'boss_treasure_unavailable'
    end
    complete(run,'boss_treasure_complete')
    if Acts.isCompetition(run) and run.act==2 then
        run.phase,run.pendingAct,run.ending='victory',nil,'two_act_complete'
    elseif run.campaign then run.phase,run.pendingAct='act_transition',(run.act or 1)+1
    else run.phase='victory' end
    return true,'boss_treasure_complete'
end
function M.leaveTreasure(run)
    return Run.transaction(run,function(staged)
        local flow,why=pending(staged,'treasure');if not flow then return false,why end
        if flow.roomKind=='boss_treasure' then
            return finishBossTreasure(staged)
        end
        return complete(staged,'treasure_skipped')
    end)
end

local function claimTreasure(run)
    local flow, reason = pending(run, "treasure"); if not flow then return false, reason end
    if flow.roomKind == "boss_treasure" then return false, "boss_treasure_choice_required" end
    if flow.chest then
        if not flow.chest.opened then local ok,why=openSourceTreasure(run,flow);if not ok then return false,why end end
        local items=Combat.copy(flow.reward.items)
        for _,item in ipairs(items)do if item.kind~='sapphire' then
            local ok,why=takeSourceTreasure(run,flow,item.slot);if not ok then return false,why end
        end end
        return complete(run)
    end
    if flow.reward.relicId then
        if owns(run.relics, flow.reward.relicId) then return false, "relic_already_owned" end
        local ok,why=Run.obtainRelic(run,flow.reward.relicId);if not ok then return false,why end
        if flow.reward.sapphireKey then
            flow.reward.sapphireKey=nil
            flow.treasureChoice='relic'
        end
    else Run.gainGold(run,flow.reward.gold) end
    return complete(run)
end

function M.claimTreasure(run)
    return Run.transaction(run,claimTreasure)
end

-- This token follows Recall's existing map/room-generation ownership pattern.
-- The bounded current reward owner has one base relic, not a full PC chest
-- reward list: reject other shapes instead of sacrificing unrelated rewards.
local function invalidLegacyTreasureShape(reward)
    return type(reward)~='table' or getmetatable(reward)~=nil or type(reward.relicId)~='string'
        or type(reward.sapphireKey)~='table' or getmetatable(reward.sapphireKey)~=nil

end

local function legacyTreasurePair(run,reward)
    if invalidLegacyTreasureShape(reward) or reward.sapphireKey.relicId~=reward.relicId or owns(run.relics,reward.relicId)
        or not find(run.data.relics.relics,reward.relicId) then return nil,'treasure_choice_unavailable' end
    for key in pairs(reward)do
        if key~='relicId' and key~='sapphireKey' then return nil,'treasure_reward_shape_unsupported' end
    end
    for key in pairs(reward.sapphireKey)do
        if key~='relicId' then return nil,'treasure_reward_shape_unsupported' end
    end
    return true
end

local function modernTreasurePair(run,flow,reward)
        if type(flow.chest)~='table'or getmetatable(flow.chest)~=nil or flow.chest.opened~=true then return nil,'chest_closed'end
        local modern,why=TreasureSource.pair(reward);if not modern then return nil,why end
        if modern.relicAvailable and not find(run.data.relics.relics,modern.relicId)then return nil,'treasure_choice_unavailable'end
        if owns(run.relics,modern.relicId) and modern.relicId~='circlet' and modern.relicId~='Circlet'then
            return nil,'treasure_choice_unavailable'
        end
    return modern
end

local function treasureRoom(_run,map,flow)
    local node
    for _,entry in ipairs(map.nodes)do
        if type(entry)~='table' then return nil,'treasure_source_mismatch' end
        if entry.id==flow.id then node=entry end
    end
    if not node or node.floor~=flow.floor or node.roomKind=='boss_treasure'
        or (node.type~='treasure' and not (node.type=='event' and flow.sourceType=='event')) then
        return nil,'treasure_source_mismatch'
    end
    return true
end

function M.treasureSource(run,map)
    local flow,reason=pending(run,'treasure');if not flow then return nil,reason end
    if flow.roomKind=='boss_treasure' then return nil,'boss_treasure_choice_required' end
    local eligible,why=endingKeyEligible(run,'sapphire');if not eligible then return nil,why end
    local reward=flow.reward
    local modern
    if flow.chest then
        modern,why=modernTreasurePair(run,flow,reward);if not modern then return nil,why end
    else
        local valid,detail=legacyTreasurePair(run,reward);if not valid then return nil,detail end
    end
    if Sources.invalidMapOwner(run,map,flow) or Sources.invalidRoomOwner(run,flow)
        or flow.complete~=false or flow.treasureChoice~=nil or Sources.roomMapMismatch(run,map,flow) then
        return nil,'treasure_source_mismatch'
    end
    local valid,detail=treasureRoom(run,map,flow);if not valid then return nil,detail end
    local token={id=flow.id,floor=flow.floor,act=run.act or 1,runSeed=run.runSeed,
        mapSeed=flow.mapSeed,mapSignature=flow.mapSignature,roomGeneration=run.roomGeneration,relicId=reward.relicId}
    if modern then
        token.baseSlot,token.keySlot,token.itemsSignature=modern.baseSlot,modern.keySlot,modern.itemsSignature
    end
    return token
end

local function treasureChoiceSource(run,map,source,choice)
    local current,reason=M.treasureSource(run,map);if not current then return false,reason end
    if type(source)~='table' or getmetatable(source)~=nil then return false,'treasure_source_mismatch' end
    for key,value in pairs(current)do if source[key]~=value then return false,'treasure_source_mismatch' end end
    for key in pairs(source)do if current[key]==nil then return false,'treasure_source_mismatch'end end
    if choice~='relic' and choice~='sapphire' then return false,'invalid_treasure_choice' end
    return true
end

function M.chooseTreasure(run,map,source,choice)
    -- Validate plain owners before Run.transaction's graph copy can normalize
    -- their metatables. A nested preflight refusal must still poison its parent.
    local valid,reason=treasureChoiceSource(run,map,source,choice)
    if not valid then return Run.transaction(run,function()return false,reason end)end
    return Run.transaction(run,function(staged)
        local live,why=treasureChoiceSource(staged,map,source,choice);if not live then return false,why end
        local flow=staged.nodeFlow
        if flow.chest then
            local ok,kind=takeSourceTreasure(staged,flow,choice=='sapphire'and source.keySlot or source.baseSlot)
            if not ok then return false,kind end
            if #flow.reward.items==0 then return complete(staged,choice=='relic'and 'complete'or kind)end
            return true,kind
        end
        if choice=='relic' then return claimTreasure(staged) end
        -- The BLUE effect's gameplay result only changes this flag. Expire its
        -- linked relic in the same transaction; no obtain/equip or gold hook.
        staged.keys.sapphire=true
        staged.nodeFlow.reward.relicId=nil
        staged.nodeFlow.reward.sapphireKey=nil
        staged.nodeFlow.treasureChoice='sapphire'
        return complete(staged,'sapphire')
    end)
end

local function claimSourceBossRelic(run,flow,choice)
        if choice>0 then
            if not flow.chest.opened then local ok,why=openSourceTreasure(run,flow);if not ok then return false,why end end
            local item=flow.reward.items[choice]
            if not item or item.kind~='relic' then return false,'invalid_boss_relic_choice' end
            local ok,why=takeSourceTreasure(run,flow,item.slot);if not ok then return false,why end
            flow.chosenRelic=item.id
        end
    return true
end

local function claimBossTreasure(run, choice)
    local flow, reason = pending(run, "treasure"); if not flow then return false, reason end
    if flow.roomKind ~= "boss_treasure" then return false, "wrong_node_type" end
    if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 0 or choice > #flow.reward.relics then
        return false, "invalid_boss_relic_choice"
    end
    if flow.chest then
        local ok,why=claimSourceBossRelic(run,flow,choice);if not ok then return false,why end
    elseif choice > 0 then
        local id = flow.reward.relics[choice]
        local relic = find(run.data.relics.relics, id)
        if not relic or not Inventory.bossEligible(relic, run.relics) then return false, "boss_relic_unavailable" end
        local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
        flow.chosenRelic = id
    end
    return finishBossTreasure(run)
end

function M.claimBossTreasure(run,choice)
    return Run.transaction(run,function(staged)return claimBossTreasure(staged,choice)end)
end

require('abyss_nodes_events')(M)
local function escapedCombat(run,flow)
    return run.phase=='map' and run.lastResult and run.lastResult.outcome=='escaped'
        and flow.type~='boss' and run.lastResult.encounterId==flow.encounterId
end

local function unfinishedCombat(run,flow)
    return run.phase ~= "map" or not run.lastResult or run.lastResult.outcome ~= "victory"
        or run.lastResult.encounterId ~= flow.encounterId
end

function M.completeCombat(run, map)
    local flow = run.nodeFlow
    if not flow or flow.complete then return false, "no_pending_node" end
    if not battleKinds[flow.type] and not (flow.type=='event' and flow.eventCombat) then return false, "wrong_node_type" end
    if not matchingMap(flow, map) then return false, "map_mismatch" end
    if run.phase == "defeat" then return false, "run_defeated" end
    if run.phase == "reward" then return false, "reward_pending" end
    if escapedCombat(run,flow) then return complete(run,'escaped') end
    if unfinishedCombat(run,flow) then return false,'battle_unfinished' end
    return complete(run, flow.type == "boss" and "boss_victory" or "victory")
end

return M
