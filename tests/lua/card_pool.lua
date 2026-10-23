package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run = require("abyss_combat"), require("abyss_run")
local Nodes, Map = require("abyss_nodes"), require("abyss_map")
local Effects, data = require("abyss_effects"), require("abyss_data")
local count = 0
local function equal(a, b, label) assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn) fn(); count = count + 1; print("ok card_pool " .. count .. " - " .. name) end

-- Independent expected outcomes, rather than calculating answers from effects.
-- Each pair is base/upgraded. All actors have no modifiers except Dropkick's
-- declared vulnerable fixture; damage numbers below are actual HP lost.
local cases = {
    {id="strike", cost={1,1}, damage={6,9}},
    {id="defend", cost={1,1}, block={5,8}},
    {id="bash", cost={2,2}, damage={8,10}, enemyStatus="vulnerable", stacks={2,3}},
    {id="cleave", cost={1,1}, damage={8,11}, area=true},
    {id="clothesline", cost={2,2}, damage={12,14}, enemyStatus="weak", stacks={2,3}},
    {id="iron_wave", cost={1,1}, damage={5,7}, block={5,7}},
    {id="anger", cost={0,0}, damage={6,8}, copies=true},
    {id="body_slam", cost={1,0}, damage={12,12}},
    {id="flex", cost={0,0}, ownStatus="strength", stacks={2,4}, temporary=true},
    {id="twin_strike", cost={1,1}, damage={10,14}},
    {id="pommel_strike", cost={1,1}, damage={9,10}, draw={1,2}},
    {id="shrug_it_off", cost={1,1}, block={8,11}, draw={1,1}},
    {id="thunderclap", cost={1,1}, damage={4,7}, area=true, enemyStatus="vulnerable", stacks={1,1}},
    {id="uppercut", cost={2,2}, damage={13,13}, enemyStatus="weak", secondStatus="vulnerable", stacks={1,2}},
    {id="inflame", cost={1,1}, ownStatus="strength", stacks={2,3}, power=true},
    {id="battle_trance", cost={0,0}, draw={3,4}, noDraw=true},
    {id="bloodletting", cost={0,0}, hpLoss=3, energy={2,3}},
    {id="barricade", cost={3,2}, ownStatus="barricade", stacks={1,1}, power=true},
    {id="carnage", cost={2,2}, damage={20,28}},
    {id="disarm", cost={1,1}, enemyStatus="strength", stacks={-2,-3}, exhaust=true},
    {id="dropkick", cost={1,1}, damage={7,12}, draw={1,1}, energy={1,1}, vulnerable=true},
    {id="entrench", cost={2,1}, block={12,12}},
    {id="ghostly_armor", cost={1,1}, block={10,13}},
    {id="hemokinesis", cost={1,1}, damage={15,20}, hpLoss=2},
    {id="rampage", cost={1,1}, damage={8,8}, growth={5,8}},
    {id="seeing_red", cost={1,0}, energy={2,2}, exhaust=true},
    {id="shockwave", cost={2,2}, area=true, enemyStatus="weak", secondStatus="vulnerable", stacks={3,5}, exhaust=true},
    {id="offering", cost={0,0}, hpLoss=6, energy={2,2}, draw={3,5}, exhaust=true},
    {id="impervious", cost={2,2}, block={30,40}, exhaust=true},
    {id="bludgeon", cost={3,3}, damage={32,42}},
}
local blocked = {"clash", "true_grit", "warcry", "metallicize", "whirlwind", "demon_form", "reaper"}
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
    local exhaust = case.power or case.exhaust
    equal(#s.exhaust, exhaust and 1 or 0)
    equal(#s.discard, exhaust and 0 or case.copies and 2 or 1)
    if case.copies then
        local copy = s.discard[1]
        equal(copy.cardId, "anger"); equal(copy.upgraded, upgraded); assert(copy.uid ~= card.uid)
    end
    if case.growth then equal(card.damageBonus, case.growth[n]) end
    equal(s.catalog.cards[case.id].effects[1].value, catalog.effects[1].value, "catalog immutable")
    equal(Combat.play(s, card.uid, 1), false, "stale UID")
end

test("supported pool is exactly 30 cards; all seven incomplete rules stay disabled", function()
    local supported = {}
    for _, card in ipairs(data.cards.cards) do
        if not card.costMode and not card.condition and Effects.supported(card.effects) then supported[card.id] = true end
    end
    equal(#cases, 30)
    for _, case in ipairs(cases) do assert(supported[case.id], case.id); supported[case.id] = nil end
    equal(next(supported), nil)
    for _, id in ipairs(blocked) do
        local s = Combat.new(data, {deck={id}})
        equal(Combat.canPlay(s, s.hand[1].uid, 1), false, id)
    end
end)
for _, case in ipairs(cases) do
    for _, upgraded in ipairs({false, true}) do
        test(case.id .. (upgraded and "+" or "") .. " executes exact independent expected outcome", function() execute(case, upgraded) end)
    end
end

local function entered(kind)
    local run, map = Run.new(data, 42), Map.generate(data, 42)
    -- Stage prior navigation as a node-unit fixture, then use actual enter.
    while true do
        local available = Map.available(map)
        for _, node in ipairs(available) do
            if node.type == kind then assert(Nodes.enter(run, map, node.id)); return run, map end
        end
        assert(#available > 0, "route needs " .. kind); assert(Map.choose(map, available[1].id))
    end
end
for _, case in ipairs(cases) do
    test(case.id .. " obtained legally and camp-upgraded permanent instance executes next battle", function()
        local run
        if find(data.cards.cards, case.id).rarity == "basic" then run = Run.new(data, 42)
        else
            run = entered("shop")
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

test("incomplete cards never appear in the generated shop inventory or camp upgrades", function()
    local shop = entered("shop")
    local camp, map = entered("camp")
    for _, id in ipairs(blocked) do
        equal(find(shop.nodeFlow.cards, id), nil)
        camp.deck[#camp.deck+1] = {uid=camp.nextDeckUid, cardId=id, upgraded=false}
        camp.nextDeckUid = camp.nextDeckUid + 1
    end
    local options = Nodes.view(camp, map).node.upgradeCards
    for _, instance in ipairs(options) do
        for _, id in ipairs(blocked) do assert(instance.cardId ~= id, "incomplete camp upgrade: " .. id) end
    end
end)

test("all 27 reward cards occur after real original-data starter victories and can be claimed", function()
    local wanted, remaining = {}, 0
    for _, case in ipairs(cases) do
        if find(data.cards.cards, case.id).rarity ~= "basic" then wanted[case.id], remaining = true, remaining + 1 end
    end
    for seed = 1, 128 do
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
            for _, incomplete in ipairs(blocked) do assert(id ~= incomplete, "incomplete reward: " .. id) end
            if wanted[id] then
                local claimed = Combat.copy(run)
                assert(Run.claimCardReward(claimed, choice))
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
        if remaining == 0 then break end
    end
    equal(remaining, 0, "unseen playable rewards")
end)
print("LUA_CARD_POOL_PASS " .. count)
