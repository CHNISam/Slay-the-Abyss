local Effects = require('abyss_effects')
local Combat = require('abyss_combat')
local Pool = require('abyss_event_pool')
local Inventory = require('abyss_inventory')
local Nodes = require('abyss_nodes')
local Run = require('abyss_run')
local Map = require('abyss_map')
local data, manifest = LAUNCH_DATA, LAUNCH_MANIFEST
local function set(rows) local r = {}; for _, row in ipairs(rows) do r[row.id] = true end; return r end
local expected, blocked = set(manifest.cards), set(manifest.exclusions.cards)
for _, card in ipairs(data.cards.cards) do
    if card.type == 'attack' or card.type == 'skill' or card.type == 'power' then
        local supported = Effects.supported(card.effects)
        assert(not not supported == not not expected[card.id], 'Playable card pool drift: ' .. card.id)
        assert(not supported == not not blocked[card.id], 'Excluded card support drift: ' .. card.id)
        if expected[card.id] then
            local upgraded = Combat.copy(card)
            for key, value in pairs(card.upgrade) do upgraded[key] = value end
            assert(Effects.supported(upgraded.effects), 'Unsupported upgrade: ' .. card.id)
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
    if event.poolMode=='explicit-only' then
        assert(not actual[event.id], 'Explicit event admitted to random pool: '..event.id)
        assert(event.id=='living_wall' or Pool.contentId[event.originalId]==event.id, 'Missing explicit source mapping: '..event.id)
    else
        assert(actual[event.id] and Pool.contentId[event.originalId] == event.id, 'Missing launch event: ' .. event.id)
    end
    local chapter=event.act or 1
    local run = Run.new(data, 1, chapter>1 and {experimental=true,campaign=true} or nil)
    if chapter>1 then
        run.act,run.floor=chapter,(chapter-1)*17
        run.encounters=require('abyss_encounter_queue').new(run.runSeed,chapter)
        run.unknown.pools=Pool.new('full',false,chapter)
    end
    local flow = {event = {id = event.id, goldLoss = 20, damage = 16, canAttack = false, healAmount=math.floor(run.maxHp/3)}}
    if event.poolMode=='explicit-only' then
        local map=Map.generate(data,1,chapter)
        local first=Map.available(map)[1]
        for _,node in ipairs(map.nodes) do
            if node.id==first.id then node.type='event';node.eventId=event.id end
        end
        local ok,why=Nodes.enter(run,map,first.id)
        assert(ok,'Missing explicit production entry: '..event.id..'/'..tostring(why))
        assert(run.nodeFlow.event.id==event.id,'Wrong explicit production event: '..event.id)
        flow=run.nodeFlow
    end
    local choices = {}
    for _, option in ipairs(Nodes.eventOptions(run, flow)) do choices[option.choice] = true end
    if event.id == 'golden_wing' then
        flow.event.stage = 'purge'
        for _, option in ipairs(Nodes.eventOptions(run, flow)) do choices[option.choice] = true end
    end
    -- Sensory reward stages require their actual frozen offers. Traverse the
    -- public commands instead of inventing a partial stage-only fixture.
    if event.id=='sensory_stone' then
        local function collect()
            flow=run.nodeFlow
            for _,option in ipairs(Nodes.eventOptions(run,flow))do choices[option.choice]=true end
        end
        assert(Nodes.chooseEvent(run,'continue'));collect()
        assert(Nodes.chooseEvent(run,'three'));collect()
        for group=1,3 do
            assert(Nodes.chooseEvent(run,'open_'..group));collect()
            assert(Nodes.chooseEvent(run,'skip_'..group));collect()
        end
        assert(Nodes.chooseEvent(run,'proceed'));collect()
    end
    if event.id=='the_library' then
        assert(Nodes.chooseEvent(run,'read'))
        flow=run.nodeFlow
        assert(#flow.event.offers==20,'Library requires the complete20 offer group')
        local seen={}
        for _,card in ipairs(flow.event.offers)do
            assert(not seen[card.sourceCardId] and card.uid==nil,'Library source offers must be unique detached previews')
            seen[card.sourceCardId]=true
        end
        assert(Nodes.chooseEvent(run,'select',flow.event.offers[1].offerToken))
        flow=run.nodeFlow
        for _,option in ipairs(Nodes.eventOptions(run,flow))do choices[option.choice]=true end
    end
    for _,stage in ipairs(event.id=='sensory_stone'and{}or event.stages or {}) do
        flow.event.stage=stage
        if stage=='potion_rewards' then
            flow.event.potionOffers={{id='fire_potion',claimed=false},{id='block_potion',claimed=false},{id='strength_potion',claimed=false}}
        end
        for _,option in ipairs(Nodes.eventOptions(run,flow)) do choices[option.choice]=true end
    end
    if event.id=='falling' then
        local empty=Combat.copy(flow);empty.event.stage='choice';empty.event.candidates={}
        for _,option in ipairs(Nodes.eventOptions(run,empty))do choices[option.choice]=true end
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
