package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run = require("abyss_combat"), require("abyss_run")
local Nodes, Map = require("abyss_nodes"), require("abyss_map")
local Effects, data = require("abyss_effects"), require("abyss_data")
local count = 0
local function equal(a, b, label) assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn) fn(); count = count + 1; print("ok card_pool " .. count .. " - " .. name) end

local oracle = dofile("tests/lua/support/card_pool_oracle.lua")
local cases, blocked = oracle.cases, oracle.blocked
local function find(entries, id) for _, value in ipairs(entries) do if value.id == id then return value end end end
local function execute(case, upgraded, run)
    local s
    if run then
        -- Deck acquisition/upgrade was performed by the public node commands.
        run.floor, run.phase = 1, "map"
        assert(Run.startCombat(run, "cultist_solo")); s = run.combat
    else
        local deck = {{cardId=case.id, upgraded=upgraded}}
        for _ = 1, 12 do deck[#deck+1] = "defend" end
        s = Combat.new(data, {deck=deck, enemies={"jaw_worm", "jaw_worm"}, seed=42})
    end
    local card
    for _, pile in ipairs({s.hand, s.draw}) do
        for i, instance in ipairs(pile) do
            if instance.cardId == case.id and instance.upgraded == upgraded then
                card = table.remove(pile, i); break
            end
        end
        if card then break end
    end
    assert(card, "missing acquired instance")
    s.hand[#s.hand+1] = card
    -- Boundary fixture: enough enemy HP for every card, space for five draws,
    -- and existing block to distinguish doubling/current-block attacks.
    s.player.hp, s.player.block = 60, 12
    for _, enemy in ipairs(s.enemies) do enemy.hp, enemy.maxHp, enemy.block = 300, 300, 0 end
    if case.vulnerable then Combat.addStatus(s.enemies[1], "vulnerable", 1) end
    local n = upgraded and 2 or 1
    local hand, energy = #s.hand, s.energy
    local catalog = Combat.copy(s.catalog.cards[case.id])
    assert(Combat.play(s, card.uid, 1))
    equal(s.energy, energy - case.cost[n] + (case.energy and case.energy[n] or 0), "energy")
    equal(s.player.hp, 60 - (case.hpLoss or 0), "HP payment")
    equal(s.player.block, 12 + (case.block and case.block[n] or 0), "block")
    equal(#s.hand, hand - 1 + (case.draw and case.draw[n] or 0), "draw")
    equal(s.enemies[1].hp, 300 - (case.damage and case.damage[n] or 0), "damage")
    if s.enemies[2] then equal(s.enemies[2].hp, 300 - (case.area and case.damage and case.damage[n] or 0), "area damage") end
    if case.enemyStatus then
        for i, enemy in ipairs(s.enemies) do
            equal(enemy.statuses[case.enemyStatus] or 0, (i == 1 or case.area) and case.stacks[n] or 0, "status")
            if case.secondStatus then equal(enemy.statuses[case.secondStatus] or 0, (i == 1 or case.area) and case.stacks[n] or 0) end
        end
    end
    if case.ownStatus then equal(s.player.statuses[case.ownStatus], case.stacks[n]) end
    equal(s.player.noDraw == true, case.noDraw == true)
    if case.temporary then equal(s.player.temporaryStrength, case.stacks[n]) end
    local exhaust = case.exhaust
    equal(#s.exhaust, exhaust and 1 or 0)
    equal(#s.discard, (exhaust or case.power) and 0 or case.copies and 2 or 1)
    if case.copies then
        local copy = s.discard[1]
        equal(copy.cardId, "anger"); equal(copy.upgraded, upgraded); assert(copy.uid ~= card.uid)
    end
    if case.growth then equal(card.damageBonus, case.growth[n]) end
    equal(s.catalog.cards[case.id].effects[1].value, catalog.effects[1].value, "catalog immutable")
    equal(Combat.play(s, card.uid, 1), false, "stale UID")
end

test("the historical 30-card regression remains inside the complete 75-card pool", function()
    local supported = {}
    for _, card in ipairs(data.cards.cards) do
        if card.type~="status" and card.type~="curse" and Effects.supported(card.effects) then supported[card.id] = true end
    end
    equal(#cases, 30)
    for _, case in ipairs(cases) do assert(supported[case.id], case.id); supported[case.id] = nil end
    local remaining=0;for _ in pairs(supported) do remaining=remaining+1 end;equal(remaining,45)
    for _, id in ipairs(blocked) do
        local s = Combat.new(data, {deck={id}})
        s.energy=10
        equal(Combat.canPlay(s, s.hand[1].uid, 1), true, id)
    end
end)
for _, case in ipairs(cases) do
    for _, upgraded in ipairs({false, true}) do
        test(case.id .. (upgraded and "+" or "") .. " executes exact independent expected outcome", function() execute(case, upgraded) end)
    end
end

-- Reuse only immutable, same-seed source maps and genuinely entered cold rooms.
-- Every caller receives deep copies before changing gold/deck/stock/RNG state.
local function fixtureCopy(value, seen)
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, entry in pairs(value) do
        result[key] = type(entry) == 'table' and fixtureCopy(entry, seen) or entry
    end
    return result
end
local function sameFixture(a, b)
    assert(type(a) == 'table' and type(b) == 'table')
    for key, value in pairs(a) do
        if type(value) == 'table' then sameFixture(value, b[key]) else equal(value, b[key]) end
    end
    for key in pairs(b) do assert(a[key] ~= nil, 'extra cached field: ' .. tostring(key)) end
end
local function coldState(run)
    return {deck=run.deck, nextDeckUid=run.nextDeckUid, shopRng=run.shopRng,
        cardRng=run.cardRng, cardRarityOffset=run.cardRarityOffset, miscRng=run.miscRng,
        eventRng=run.eventRng, treasureRng=run.treasureRng, cards=run.nodeFlow.cards,
        campChoice=run.nodeFlow.campChoice, upgradesLeft=run.nodeFlow.upgradesLeft}
end
local function cloneEntry(cached)
    -- Copy the whole bundle once: independent copies of run/flow would break
    -- genuine entry's shared merchant/potion RNG references.
    local bundle = fixtureCopy(cached.bundle)
    if bundle.run.nodeFlow.type == 'shop' then
        assert(cached.bundle.run.shopRng == cached.bundle.run.nodeFlow.shopRng)
        assert(bundle.run.shopRng == bundle.run.nodeFlow.shopRng)
        assert(bundle.run.shopRng ~= cached.bundle.run.shopRng)
    end
    assert(bundle.run.deck ~= cached.bundle.run.deck)
    return bundle.run, bundle.map
end
local mapTemplates, entryTemplates = {}, {}
local function mapForSeed(seed)
    if not mapTemplates[seed] then mapTemplates[seed] = Map.generate(data, seed) end
    return fixtureCopy(mapTemplates[seed])
end
local function entered(kind,seed)
    seed = seed or 42
    local key = kind .. ":" .. seed
    local cached = entryTemplates[key]
    if cached then return cloneEntry(cached) end
    local run, map = Run.new(data, seed), mapForSeed(seed)
    -- Stage prior navigation as a node-unit fixture, then use actual enter.
    local path=dofile('tests/lua/support/map_routes.lua').to(map,function(node)return node.type==kind end)
    for i=1,#path-1 do assert(Map.choose(map,path[i]))end
    assert(Nodes.enter(run,map,path[#path]))
    cached = {bundle={run=run, map=map}, pristine=fixtureCopy(coldState(run))}
    entryTemplates[key] = cached
    return cloneEntry(cached)
end
local shopSeedByCard=dofile('tests/fixtures/warrior75-shop-seeds.lua')
local function seedOffering(id)
    return shopSeedByCard[id] and shopSeedByCard[id].seed
end
for _, case in ipairs(cases) do
    test(case.id .. " obtained legally and camp-upgraded permanent instance executes next battle", function()
        local run
        if find(data.cards.cards, case.id).rarity == "basic" then run = Run.new(data, 42)
        else
            -- Find a deterministic sampled shop, rather than requiring a catalogue.
            local seed=seedOffering(case.id)
            assert(seed,'supported card must be reachable in sampled stock: '..case.id)
            run = entered("shop",seed)
            local offer = assert(find(run.nodeFlow.cards, case.id), "not offered: " .. case.id)
            -- Economic boundary fixture: exact purchase price, no free award.
            run.gold = offer.price
            local oldSize, nextUid = #run.deck, run.nextDeckUid
            assert(Nodes.buyCard(run, case.id)); equal(run.gold, 0); equal(#run.deck, oldSize + 1)
            equal(run.deck[#run.deck].uid, nextUid); equal(Nodes.buyCard(run, case.id), false)
            assert(Nodes.leaveShop(run))
        end
        local instance
        for _, value in ipairs(run.deck) do if value.cardId == case.id then instance = value; break end end
        assert(instance)
        -- A real camp flow on a separate deterministic map with this run's deck.
        local camp, map = entered("camp")
        camp.deck, camp.nextDeckUid = Combat.copy(run.deck), run.nextDeckUid
        assert(Nodes.upgrade(camp, instance.uid)); equal(camp.phase, "map")
        equal(Nodes.upgrade(camp, instance.uid), false)
        for _ = 1, 12 do
            camp.deck[#camp.deck+1] = {uid=camp.nextDeckUid, cardId="defend", upgraded=false}
            camp.nextDeckUid = camp.nextDeckUid + 1
        end
        execute(case, true, camp)
    end)
end

-- All30 real purchases/upgrades must leave their shared cold templates intact.
for _, cached in pairs(entryTemplates) do sameFixture(coldState(cached.bundle.run), cached.pristine) end

test("the seven formerly disabled cards have ordinary camp upgrades", function()
    local shop = entered("shop")
    local camp, map = entered("camp")
    for _, id in ipairs(blocked) do
        camp.deck[#camp.deck+1] = {uid=camp.nextDeckUid, cardId=id, upgraded=false}
        camp.nextDeckUid = camp.nextDeckUid + 1
    end
    local options = Nodes.view(camp, map).node.upgradeCards
    local found={};for _,instance in ipairs(options) do found[instance.cardId]=true end
    for _,id in ipairs(blocked) do assert(found[id],'missing real upgrade: '..id) end
end)

test("all audited nonrare rewards occur after real starter victories; first A0 rewards contain no rare", function()
    local wanted, remaining = {}, 0
    for _, case in ipairs(cases) do
        local rarity=find(data.cards.cards,case.id).rarity
        if rarity=="common" or rarity=="uncommon" then wanted[case.id], remaining = true, remaining + 1 end
    end
    for seed = 1, 4096 do
        local predicted=require("abyss_card_pool").prepareRewards({data=data,cardRng=require("abyss_sts_random").fromSeed(tostring(seed)),cardRarityOffset=5,encounterTier="normal"})
        local useful=false;for _,id in ipairs(predicted) do if wanted[id] then useful=true end end
        if useful then
        local run = Run.new(data, seed)
        assert(Run.startCombat(run, "cultist_solo"))
        for _ = 1, 100 do
            if run.phase ~= "combat" then break end
            local chosen
            for _, instance in ipairs(run.combat.hand) do
                if Combat.canPlay(run.combat, instance.uid, 1) then
                    if not chosen or Combat.cardDefinition(run.combat, instance).type == "attack" then chosen = instance end
                end
            end
            if chosen then assert(Run.play(run, chosen.uid, 1)) else assert(Run.endTurn(run)) end
        end
        equal(run.phase, "reward", "original starter victory")
        for choice, id in ipairs(Run.rewardOptions(run)) do
            assert(find(data.cards.cards,id).rarity~='rare','initial A0 pity offset prevents rare cards')
            if wanted[id] then
                local claimed = Combat.copy(run)
                assert(Run.claimCardReward(claimed, choice)); dofile('tests/lua/support/finish_combat_rewards.lua')(claimed)
                equal(#claimed.deck, 11); equal(claimed.deck[11].cardId, id)
                assert(Run.startCombat(claimed, "cultist_solo"))
                local acquired = 0
                for _, pile in ipairs({claimed.combat.hand, claimed.combat.draw}) do
                    for _, instance in ipairs(pile) do if instance.cardId == id then acquired = acquired + 1 end end
                end
                equal(acquired, 1, "reward persists into next battle")
                wanted[id], remaining = nil, remaining - 1
            end
        end
        end -- selected coverage seed
        if remaining == 0 then break end
    end
    equal(remaining, 0, "unseen playable rewards")
end)
print("LUA_CARD_POOL_PASS " .. count)
