package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local data = require("abyss_data")
local count, failed = 0, 0
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected field " .. tostring(k)) end
end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " flex " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function battle(upgraded, copies)
    local deck = { "strike" }
    for _ = 1, copies or 1 do deck[#deck + 1] = { cardId = "flex", upgraded = upgraded } end
    return Combat.new(data, { seed = 42, deck = deck })
end
local function card(state, id)
    for _, entry in ipairs(state.hand) do if entry.cardId == id then return entry end end
    error("missing card " .. id)
end
for _, upgraded in ipairs({ false, true }) do
    local value = upgraded and 4 or 2
    test((upgraded and "upgraded" or "normal") .. " costs zero, grants catalog strength and rejects stale replay atomically", function()
        local s = battle(upgraded)
        s.energy = 0
        local instance, catalog = card(s, "flex"), Combat.copy(s.catalog)
        equal(Combat.cardDefinition(s, instance).cost, 0)
        assert(Combat.play(s, instance.uid))
        equal(s.energy, 0); equal(s.player.statuses.strength, value)
        equal(s.player.temporaryStrength, value); equal(#s.discard, 1)
        equal(s.discard[1].uid, instance.uid); equal(#s.exhaust, 0)
        local before = Combat.copy(s)
        local ok, reason = Combat.play(s, instance.uid)
        equal(ok, false); equal(reason, "card_not_in_hand"); same(s, before); same(s.catalog, catalog)
    end)
    for _, permanent in ipairs({ -3, 0, 3 }) do
        test("temporary " .. value .. " adds damage and expires without removing permanent " .. permanent, function()
            local s = battle(upgraded)
            Combat.addStatus(s.player, "strength", permanent)
            assert(Combat.play(s, card(s, "flex").uid))
            equal(s.player.statuses.strength, permanent + value)
            local hp = s.enemies[1].hp
            assert(Combat.play(s, card(s, "strike").uid, 1))
            equal(hp - s.enemies[1].hp, 6 + permanent + value)
            assert(Combat.endTurn(s)); equal(s.turn, 2)
            equal(s.player.statuses.strength, permanent); equal(s.player.temporaryStrength, 0)
            hp = s.enemies[1].hp
            assert(Combat.play(s, card(s, "strike").uid, 1))
            equal(hp - s.enemies[1].hp, 6 + permanent)
            assert(Combat.endTurn(s)); equal(s.player.statuses.strength, permanent)
            equal(s.player.temporaryStrength, 0)
        end)
    end
end

test("consecutive copies stack, including permanent strength added during the same turn", function()
    local s = battle(true, 3)
    Combat.addStatus(s.player, "strength", -2)
    for i = 1, 3 do
        assert(Combat.play(s, card(s, "flex").uid))
        equal(s.player.temporaryStrength, i * 4); equal(s.player.statuses.strength, -2 + i * 4)
    end
    equal(s.energy, 3)
    Combat.addStatus(s.player, "strength", 5)
    assert(Combat.endTurn(s)); equal(s.player.statuses.strength, 3); equal(s.player.temporaryStrength, 0)
end)

local function win(seed)
    local run = Run.new(data, seed)
    assert(Run.startCombat(run, "cultist_solo"))
    for _ = 1, 100 do
        if run.phase ~= "combat" then break end
        for _ = 1, 10 do
            if run.phase ~= "combat" then break end
            local chosen
            for _, instance in ipairs(run.combat.hand) do
                if Combat.canPlay(run.combat, instance.uid, 1) then
                    if not chosen or Combat.cardDefinition(run.combat, instance).type == "attack" then chosen = instance end
                end
            end
            if not chosen then break end
            assert(Run.play(run, chosen.uid, 1))
        end
        if run.phase == "combat" then assert(Run.endTurn(run)) end
    end
    return run
end

test("real starter victory can award flex and use it next battle without resource or pool edits", function()
    local selected, choice
    for seed = 1, 64 do
        local run = win(seed)
        for i, id in ipairs(Run.rewardOptions(run)) do
            if id == "flex" then selected, choice = run, i; break end
        end
        if selected then break end
    end
    assert(selected, "flex never offered in real victory rewards")
    local oldDeck = Combat.copy(selected.deck)
    assert(Run.claimCardReward(selected, choice)); equal(#selected.deck, #oldDeck + 1)
    for i, instance in ipairs(oldDeck) do same(selected.deck[i], instance) end
    equal(selected.deck[#selected.deck].cardId, "flex")
    dofile('tests/lua/support/finish_combat_rewards.lua')(selected)
    assert(Run.startCombat(selected, "cultist_solo"))
    for _ = 1, 10 do
        assert(selected.phase == "combat", "battle ended before flex was played")
        for _, instance in ipairs(selected.combat.hand) do
            if instance.cardId == "flex" then
                local energy = selected.combat.energy
                assert(Run.play(selected, instance.uid)); equal(selected.combat.energy, energy)
                equal(selected.combat.player.statuses.strength, 2)
                assert(Run.endTurn(selected)); equal(selected.combat.player.statuses.strength, 0)
                equal(selected.combat.player.temporaryStrength, 0)
                return
            end
        end
        assert(Run.endTurn(selected))
    end
    error("reward card was not played")
end)
-- Snapshot every original table/key, including card instances and aliases.
local function unchangedAfter(state)
    local saved = {}
    local function visit(t)
        if type(t) ~= "table" or saved[t] then return end
        local values = {}; saved[t] = values
        for k, v in pairs(t) do values[k] = v; visit(k); visit(v) end
    end
    visit(state)
    return function()
        for original, values in pairs(saved) do
            for k, v in pairs(values) do equal(original[k], v) end
            for k, v in pairs(original) do equal(v, values[k]) end
        end
    end
end
for _, upgraded in ipairs({false, true}) do
    for _, mode in ipairs({"temporary", "permanent"}) do
        test((upgraded and "upgraded" or "normal") .. " " .. mode .. " overflow preserves full state and every reference", function()
            -- Temporary debt uses the public API boundary. Permanent overflow is
            -- a deliberately corrupted-state fixture; normal strength now caps at 999.
            local s = battle(upgraded)
            if mode == "temporary" then Combat.addTemporaryStrength(s.player, 2147483647)
            else s.player.statuses.strength = 2147483647 end
            local instance = card(s, "flex")
            assert(Combat.canPlay(s, instance.uid))
            local before, check = Combat.copy(s), unchangedAfter(s)
            local ok, reason = pcall(Combat.play, s, instance.uid)
            equal(ok, false)
            assert(tostring(reason):find(mode == "temporary" and "temporary strength overflow" or "status stack overflow", 1, true), tostring(reason))
            same(s, before); check(); equal(card(s, "flex"), instance)
        end)
    end
end

test("flex works after draw lock and HP payment; offering retains lock while gaining energy", function()
    local s = Combat.new(data, {seed=42, deck={"battle_trance", "bloodletting", "offering", "flex", "strike"}})
    assert(Combat.play(s, card(s, "battle_trance").uid))
    equal(s.player.noDraw, true)
    local hp, energy = s.player.hp, s.energy
    assert(Combat.play(s, card(s, "bloodletting").uid))
    equal(s.player.hp, hp - 3); equal(s.energy, energy + 2)
    local draw, seed = Combat.copy(s.draw), s.seed
    assert(Combat.play(s, card(s, "flex").uid)); equal(s.player.statuses.strength, 2)
    local hand = #s.hand
    assert(Combat.play(s, card(s, "offering").uid))
    equal(s.player.hp, hp - 9); equal(s.energy, energy + 4)
    equal(#s.hand, hand - 1); same(s.draw, draw); equal(s.seed, seed); equal(s.player.noDraw, true)
    local enemyHp = s.enemies[1].hp
    assert(Combat.play(s, card(s, "strike").uid, 1)); equal(enemyHp - s.enemies[1].hp, 8)
    assert(Combat.endTurn(s)); equal(s.player.statuses.strength, 0)
    equal(s.player.temporaryStrength, 0); equal(s.player.noDraw, false)
end)

test("controlled composite restores HP payment, draw reshuffle, lock and prior temporary gain on later overflow", function()
    local s = Combat.new(data, {seed=42, deck={"flex", "strike", "defend", "bash"}})
    local instance = card(s, "flex")
    for i = #s.hand, 1, -1 do
        if s.hand[i] ~= instance then s.discard[#s.discard+1] = table.remove(s.hand, i) end
    end
    -- Controlled composite fixture exercises current supported operations, not a shipped card.
    s.catalog.cards.flex.effects = {{op="loseHp",value=3}, {op="draw",value=2},
        {op="noDrawThisTurn"}, {op="gainTemporaryStrength",value=2},
        {op="gainTemporaryStrength",value=2147483647}}
    local before, check = Combat.copy(s), unchangedAfter(s)
    local ok, reason = pcall(Combat.play, s, instance.uid)
    equal(ok, false); assert(tostring(reason):find("temporary strength overflow", 1, true), tostring(reason))
    same(s, before); check(); equal(card(s, "flex"), instance)
end)

assert(failed == 0, tostring(failed) .. " flex tests failed")
print("LUA_FLEX_PASS " .. count)
