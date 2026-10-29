-- Shared node-state queries; no room command or stream ownership lives here.
local Combat = require("abyss_combat")
local Capability = require("abyss_card_capability")

local Acts = require('abyss_acts')

local function find(entries, id, field)
    for i, entry in ipairs(entries) do if entry[field or "id"] == id then return entry, i end end
end

local function owns(entries, id)
    for _, owned in ipairs(entries) do if owned == id then return true end end
    return false
end

-- Both camp Recall and the linked chest choice consume the same existing
-- campaign/history input. Neither command creates or persists qualification.
local function endingKeyEligible(run,key)
    if run.campaign~=true then return false,'campaign_unavailable' end
    if Acts.isCompetition(run) then return false,'ending_unavailable' end
    if run.act~=1 and run.act~=2 and run.act~=3 and run.act~=4 then return false,'invalid_act' end
    if run.endingUnlocked~=true then return false,'ending_history_required' end
    local keys=run.keys
    if type(keys)~='table' or getmetatable(keys)~=nil or type(keys.ruby)~='boolean'
        or type(keys.emerald)~='boolean' or type(keys.sapphire)~='boolean' then return false,'invalid_keys' end
    if keys[key] then return false,key..'_key_owned' end
    return true
end

local function playable(card)
    return card.type ~= "status" and card.type ~= "curse"
        and Capability.isImplemented(card)
end

local function upgradeable(run, instance)
    local definition = find(run.data.cards.cards, instance.cardId)
    if instance.upgraded and not (definition and definition.repeatable) then return false end
    if not definition or not definition.upgrade or not next(definition.upgrade) then return false end
    local upgraded = Combat.copy(definition)
    for key, value in pairs(definition.upgrade) do upgraded[key] = value end
    return playable(upgraded)
end

local function upgradeCards(run)
    local result = {}
    for _, instance in ipairs(run.deck) do
        if upgradeable(run, instance) then result[#result + 1] = Combat.copy(instance) end
    end
    return result
end

local function healingPreview(run,amount)
    if require('abyss_potion_health').blocked(run.relics)then return 0 end
    return math.min(run.maxHp-run.hp,amount)
end

local function matchingMap(flow, map)
    return not flow or (flow.mapSeed == map.seed and flow.mapSignature == map.sourceSignature
        and flow.id == map.currentNodeId and flow.floor == map.floor)
end

local function pending(run, kind)
    local flow = run.nodeFlow
    if not flow or flow.complete then return nil, "no_pending_node" end
    if flow.type ~= kind or run.phase ~= "node" then return nil, "wrong_node_type" end
    return flow
end

local function complete(run, result)
    run.nodeFlow.complete, run.nodeFlow.result = true, result or "complete"
    run.phase = "map"
    return true, run.nodeFlow.result
end

return {find=find,owns=owns,endingKeyEligible=endingKeyEligible,upgradeable=upgradeable,upgradeCards=upgradeCards,healingPreview=healingPreview,matchingMap=matchingMap,pending=pending,complete=complete}
