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
    print((ok and "ok" or "not ok") .. " block_damage " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function battle(upgraded)
    return Combat.new(data, { seed = 42, deck = { { cardId = "body_slam", upgraded = upgraded } } })
end
local function damageEvent(s)
    for _, e in ipairs(s.events) do if e.kind == "damage" then return e.detail end end
    error("missing damage event")
end
for _, upgraded in ipairs({ false, true }) do
    test((upgraded and "upgraded" or "normal") .. " uses catalog cost and current block without consuming block", function()
        local s = battle(upgraded)
        local instance = s.hand[1]
        local cost = upgraded and 0 or 1
        equal(Combat.cardDefinition(s, instance).cost, cost)
        s.energy, s.player.block = cost, 12
        local hp, seed = s.enemies[1].hp, s.seed
        assert(Combat.play(s, instance.uid, 1))
        equal(s.energy, 0); equal(hp - s.enemies[1].hp, 12); equal(s.player.block, 12)
        equal(#s.hand, 0); equal(s.discard[1], instance); equal(#s.exhaust, 0); equal(s.seed, seed)
        local before = Combat.copy(s)
        local ok, why = Combat.play(s, instance.uid, 1)
        equal(ok, false); equal(why, "card_not_in_hand"); same(s, before)
    end)
end
for _, case in ipairs({
    { name = "zero block is zero attack", block = 0, strength = 0, expected = 0 },
    { name = "zero block still benefits from strength", block = 0, strength = 3, expected = 3 },
    { name = "strength adds to block base", block = 10, strength = 3, expected = 13 },
    { name = "negative strength clamps to zero", block = 2, strength = -3, expected = 0 },
    { name = "weak and vulnerable floor once", block = 10, strength = 3, weak = 1, vulnerable = 1, expected = 14 },
    { name = "dexterity and frail do not modify existing block", block = 10, strength = 0, dexterity = 8, frail = 1, expected = 10 },
    { name = "32 bit base plus strength does not wrap", block = 2147483647, strength = 2147483647, hostileStats = true, vulnerable = 1, expected = 6442450941.0 }
}) do
    test(case.name .. " and core preview matches damage plus absorption", function()
        local s = battle()
        s.player.block = case.block
        for _, id in ipairs({ "strength", "weak", "dexterity", "frail" }) do
            if case[id] then
                -- Arithmetic-only hostile fixture; public signed stats cap at 999.
                if case.hostileStats then s.player.statuses[id] = case[id]
                else Combat.addStatus(s.player, id, case[id]) end
            end
        end
        if case.vulnerable then Combat.addStatus(s.enemies[1], "vulnerable", case.vulnerable) end
        s.enemies[1].hp, s.enemies[1].block = 7000000000.0, 3
        local before = Combat.copy(s)
        local preview = Combat.attackAmount(s, s.player, s.enemies[1], s.player.block)
        equal(preview, case.expected); same(s, before)
        assert(Combat.play(s, s.hand[1].uid, 1))
        local e = damageEvent(s)
        equal(e.amount + e.blocked, preview); equal(s.player.block, case.block)
    end)
end
for _, target in ipairs({ false, 0, -1, 2, 1.5, "1", {}, math.huge, 0/0 }) do
    test("invalid target " .. tostring(target) .. " rejected before all mutation", function()
        local s = battle()
        s.player.block = 10
        local uid, before = s.hand[1].uid, Combat.copy(s)
        local index = target
        if target == false then index = nil end
        local ok, why = Combat.canPlay(s, uid, index)
        equal(ok, false); equal(why, "invalid_target"); same(s, before)
        ok, why = Combat.play(s, uid, index)
        equal(ok, false); equal(why, "invalid_target"); same(s, before)
    end)
end
for _, reason in ipairs({ "invalid_target", "insufficient_energy" }) do
    test(reason .. " rejects atomically", function()
        local s = battle()
        if reason == "invalid_target" then s.enemies[1].hp = 0 else s.energy = 0 end
        local before = Combat.copy(s)
        local ok, why = Combat.play(s, s.hand[1].uid, 1)
        equal(ok, false); equal(why, reason); same(s, before)
    end)
end
for _, case in ipairs({
    { name = "zero Body Slam still triggers thorns", block = 0, hp = 80, enemyHp = 2, phase = "player", lost = 3 },
    { name = "blocked positive attack triggers thorns", block = 5, enemyBlock = 5, hp = 80, enemyHp = 2, phase = "player", lost = 0 },
    { name = "lethal defender retaliates before victory", block = 5, hp = 80, enemyHp = 2, phase = "victory", lost = 0 },
    { name = "insufficient block allows simultaneous death", block = 2, hp = 1, enemyHp = 2, phase = "defeat", lost = 1 }
}) do
    test(case.name, function()
        local s = battle()
        s.player.block, s.player.hp = case.block, case.hp
        s.enemies[1].hp, s.enemies[1].block = case.enemyHp, case.enemyBlock or 0
        Combat.addStatus(s.enemies[1], "thorns", 3)
        assert(Combat.play(s, s.hand[1].uid, 1))
        equal(s.phase, case.phase); equal(s.player.hp, case.hp - case.lost); equal(s.player.block, math.max(0, case.block - (case.block > 0 and 3 or 0)))
        equal(#s.discard,s.player.hp>0 and 1 or 0)
    end)
end
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

test("real starter reward body_slam joins permanent deck and plays after defend next combat", function()
    local selected, choice
    for seed = 1, 128 do
        local run = win(seed)
        for i, id in ipairs(Run.rewardOptions(run)) do
            if id == "body_slam" then selected, choice = run, i; break end
        end
        if selected then break end
    end
    assert(selected, "body_slam never offered in real victory rewards")
    local oldDeck = Combat.copy(selected.deck)
    assert(Run.claimCardReward(selected, choice)); equal(#selected.deck, #oldDeck + 1)
    for i, instance in ipairs(oldDeck) do same(selected.deck[i], instance) end
    equal(selected.deck[#selected.deck].cardId, "body_slam")
    dofile('tests/lua/support/finish_combat_rewards.lua')(selected)
    assert(Run.startCombat(selected, "cultist_solo"))
    for _ = 1, 10 do
        assert(selected.phase == "combat", "battle ended before card was played")
        local slam, defend
        for _, instance in ipairs(selected.combat.hand) do
            if instance.cardId == "body_slam" then slam = instance end
            if instance.cardId == "defend" then defend = instance end
        end
        if slam and defend then
            assert(Run.play(selected, defend.uid))
            local s = selected.combat
            local block, hp, energy = s.player.block, s.enemies[1].hp, s.energy
            assert(block > 0); assert(Run.play(selected, slam.uid, 1))
            equal(s.player.block, block); equal(hp - s.enemies[1].hp, block); equal(s.energy, energy - 1)
            return
        end
        assert(Run.endTurn(selected))
    end
    error("reward card did not play with real defend")
end)
assert(failed == 0, failed .. "/" .. count .. " block damage tests failed")
print("block damage tests passed: " .. count)
