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
    print((ok and "ok" or "not ok") .. " entrench " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function battle(upgraded, copies)
    local deck = {}
    for _ = 1, copies or 1 do deck[#deck + 1] = { cardId = "entrench", upgraded = upgraded } end
    return Combat.new(data, { seed = 42, deck = deck })
end
local function refused(state, uid, reason)
    local before = Combat.copy(state)
    local ok, actual = Combat.play(state, uid)
    equal(ok, false); equal(actual, reason); same(state, before)
end

for _, upgraded in ipairs({ false, true }) do
    test((upgraded and "upgraded" or "normal") .. " doubles existing block at catalog cost without a target", function()
        local state = battle(upgraded)
        Combat.block(state, state.player, 7)
        local card = state.hand[1]
        local catalog = Combat.copy(state.catalog)
        local cost = upgraded and 1 or 2
        equal(Combat.cardDefinition(state, card).cost, cost)
        local energy, events = state.energy, #state.events
        assert(Combat.play(state, card.uid))
        equal(state.player.block, 14); equal(state.energy, energy - cost)
        equal(#state.hand, 0); equal(#state.discard, 1); equal(#state.exhaust, 0)
        equal(state.discard[1].uid, card.uid); equal(#state.events, events + 2)
        equal(state.events[#state.events - 1].kind, "play")
        equal(state.events[#state.events].kind, "block")
        equal(state.events[#state.events].detail.amount, 7)
        same(state.catalog, catalog)
        refused(state, card.uid, "card_not_in_hand")
    end)
    test((upgraded and "upgraded" or "normal") .. " insufficient energy preserves complete state", function()
        local state = battle(upgraded)
        state.energy = (upgraded and 1 or 2) - 1
        Combat.block(state, state.player, 7)
        refused(state, state.hand[1].uid, "insufficient_energy")
    end)
end

test("zero block stays zero even with dexterity", function()
    local state = battle(false)
    Combat.addStatus(state.player, "dexterity", 4)
    assert(Combat.play(state, state.hand[1].uid))
    equal(state.player.block, 0)
end)

for _, dexterity in ipairs({ 3, -3 }) do
test("existing block ignores repeated dexterity " .. dexterity .. " and frail", function()
    local state = battle(false)
    Combat.addStatus(state.player, "dexterity", dexterity)
    Combat.addStatus(state.player, "frail", 2)
    Combat.block(state, state.player, 7)
    local block = dexterity == 3 and 7 or 3
    equal(state.player.block, block)
    assert(Combat.play(state, state.hand[1].uid))
    equal(state.player.block, block * 2)
    equal(state.player.statuses.dexterity, dexterity); equal(state.player.statuses.frail, 2)
end)
end

test("consecutive upgraded copies each double the current block", function()
    local state = battle(true, 3)
    Combat.block(state, state.player, 5)
    for _, expected in ipairs({ 10, 20, 40 }) do
        assert(Combat.play(state, state.hand[1].uid)); equal(state.player.block, expected)
    end
    equal(state.energy, 0); equal(#state.discard, 3)
end)

test("out-of-domain 32-bit seed is normalized by shared final block cap", function()
    local state = battle(true, 2)
    -- Deliberately invalid boundary seed, not a naturally reachable player state.
    state.player.block = 1073741824
    assert(Combat.play(state, state.hand[1].uid)); equal(state.player.block, 999)
    assert(Combat.play(state, state.hand[1].uid)); equal(state.player.block, 999)
end)

-- Explicit boundary fixtures, not claims of a natural run reaching the cap.
for _, upgraded in ipairs({ false, true }) do
for _, fixture in ipairs({ { 499, 998 }, { 500, 999 }, { 600, 999 }, { 999, 999 } }) do
    test((upgraded and "upgraded" or "normal") .. " double block cap from " .. fixture[1], function()
        local state = battle(upgraded)
        Combat.block(state, state.player, fixture[1], true)
        Combat.addStatus(state.player, "dexterity", 20)
        Combat.addStatus(state.player, "frail", 2)
        local energy = state.energy
        assert(Combat.play(state, state.hand[1].uid))
        equal(state.player.block, fixture[2])
        equal(state.energy, energy - (upgraded and 1 or 2))
        equal(state.player.statuses.dexterity, 20)
        equal(state.player.statuses.frail, 2)
    end)
end
end

test("repeated doubling at cap then spending block uses current block", function()
    local state = battle(true, 3)
    Combat.block(state, state.player, 600, true)
    assert(Combat.play(state, state.hand[1].uid)); equal(state.player.block, 999)
    assert(Combat.play(state, state.hand[1].uid)); equal(state.player.block, 999)
    Combat.damage(state, state.enemies[1], state.player, 600, true)
    equal(state.player.block, 399)
    assert(Combat.play(state, state.hand[1].uid)); equal(state.player.block, 798)
end)

test("failure after capped doubling restores the full atomic state", function()
    local state = battle(true)
    Combat.block(state, state.player, 600, true)
    -- A real subsequent effect exception, not a replacement of the block handler.
    state.catalog.cards.entrench.upgrade.effects = {
        { op = "doubleBlock" }, { op = "increaseDamageThisCombat", value = -1 }
    }
    local before = Combat.copy(state)
    local ok, reason = pcall(Combat.play, state, state.hand[1].uid)
    equal(ok, false); assert(tostring(reason):find("invalid card damage growth", 1, true))
    same(state, before)
end)

local function win(seed)
    local run = Run.new(data, seed)
    assert(Run.startCombat(run, "cultist_solo"))
    for _ = 1, 100 do
        if run.phase ~= "combat" then break end
        for _ = 1, 10 do
            if run.phase ~= "combat" then break end
            local chosen
            for _, card in ipairs(run.combat.hand) do
                if Combat.canPlay(run.combat, card.uid, 1) then
                    if not chosen or Combat.cardDefinition(run.combat, card).type == "attack" then chosen = card end
                end
            end
            if not chosen then break end
            assert(Run.play(run, chosen.uid, 1))
        end
        if run.phase == "combat" then assert(Run.endTurn(run)) end
    end
    return run
end

test("real starter victory can award entrench and play it next battle without state edits", function()
    local selected, choice
    for seed = 1, 64 do
        local run = win(seed)
        for i, id in ipairs(Run.rewardOptions(run)) do
            if id == "entrench" then selected, choice = run, i; break end
        end
        if selected then break end
    end
    assert(selected, "entrench never offered in real victory rewards")
    local oldDeck = Combat.copy(selected.deck)
    assert(Run.claimCardReward(selected, choice))
    equal(#selected.deck, #oldDeck + 1)
    for i, card in ipairs(oldDeck) do same(selected.deck[i], card) end
    equal(selected.deck[#selected.deck].cardId, "entrench")
    local before = Combat.copy(selected)
    equal(Run.claimCardReward(selected, choice), false); same(selected, before)
    assert(Run.startCombat(selected, "cultist_solo"))
    for _ = 1, 20 do
        assert(selected.phase == "combat", "battle ended before entrench was played")
        local entrench, defend
        for _, card in ipairs(selected.combat.hand) do
            if card.cardId == "entrench" then entrench = card end
            if card.cardId == "defend" then defend = card end
        end
        if entrench and defend then
            assert(Run.play(selected, defend.uid))
            local block, energy = selected.combat.player.block, selected.combat.energy
            assert(block > 0)
            assert(Run.play(selected, entrench.uid))
            equal(selected.combat.player.block, block * 2); equal(selected.combat.energy, energy - 2)
            equal(#selected.deck, #oldDeck + 1)
            return
        end
        assert(Run.endTurn(selected))
    end
    error("reward card was not playable alongside defend")
end)

assert(failed == 0, tostring(failed) .. " entrench tests failed")
print("LUA_ENTRENCH_PASS " .. count)
