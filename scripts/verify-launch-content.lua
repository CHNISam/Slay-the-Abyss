local Effects = require('abyss_effects')
local Combat = require('abyss_combat')
local Pool = require('abyss_event_pool')
local Inventory = require('abyss_inventory')
local Nodes = require('abyss_nodes')
local Run = require('abyss_run')
local data, manifest = LAUNCH_DATA, LAUNCH_MANIFEST
local function set(rows) local r = {}; for _, row in ipairs(rows) do r[row.id] = true end; return r end
local expected, blocked = set(manifest.cards), set(manifest.exclusions.cards)
for _, card in ipairs(data.cards.cards) do
    if card.type == 'attack' or card.type == 'skill' or card.type == 'power' then
        local supported = not card.condition and not card.costMode and Effects.supported(card.effects)
        assert(not not supported == not not expected[card.id], 'Playable card pool drift: ' .. card.id)
        assert(not supported == not not blocked[card.id], 'Excluded card support drift: ' .. card.id)
        if expected[card.id] then
            local upgraded = Combat.copy(card)
            for key, value in pairs(card.upgrade) do upgraded[key] = value end
            assert(not upgraded.condition and not upgraded.costMode and Effects.supported(upgraded.effects), 'Unsupported upgrade: ' .. card.id)
        end
    end
end
local pool = Pool.new(data.rules.events.poolMode)
local actual, listed = {}, set(manifest.events)
for _, kind in ipairs({'act', 'shrine', 'once'}) do
    for _, original in ipairs(pool[kind]) do
        local id = Pool.contentId[original]
        assert(id and listed[id], 'Unlisted production event: ' .. original)
        actual[id] = true
    end
end
for _, event in ipairs(manifest.events) do
    assert(actual[event.id] and Pool.contentId[event.originalId] == event.id, 'Missing launch event: ' .. event.id)
    local run = Run.new(data, 1)
    local flow = {event = {id = event.id, goldLoss = 20, damage = 16, canAttack = false}}
    local choices = {}
    for _, option in ipairs(Nodes.eventOptions(run, flow)) do choices[option.choice] = true end
    if event.id == 'golden_wing' then
        flow.event.stage = 'purge'
        for _, option in ipairs(Nodes.eventOptions(run, flow)) do choices[option.choice] = true end
    end
    local wanted = {}; for _, choice in ipairs(event.choices) do wanted[choice] = true end
    for choice in pairs(choices) do assert(wanted[choice], 'Unlisted event option: ' .. event.id .. '/' .. choice) end
    for choice in pairs(wanted) do assert(choices[choice], 'Missing production event option: ' .. event.id .. '/' .. choice) end
end
for _, relic in ipairs(data.relics.relics) do
    if relic.rarity == 'boss' then
        assert(Inventory.bossEligible(relic, data.rules.player.startingRelics), 'Unobtainable Boss relic: ' .. relic.id)
    end
end
print('Launch production support predicates verified; no platform or live evidence granted.')
