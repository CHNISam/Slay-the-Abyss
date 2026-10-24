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
    print((ok and "ok" or "not ok") .. " vulnerable_combo " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local Effects = require("abyss_effects")
local function battle(upgraded, enemies)
    local s = Combat.new(data, {seed = 42, deck = {{cardId = "dropkick", upgraded = upgraded}, "strike", "defend"}, enemies = enemies})
    local instance
    for i = #s.hand, 1, -1 do
        if s.hand[i].cardId == "dropkick" then instance = s.hand[i]
        else s.draw[#s.draw + 1] = table.remove(s.hand, i) end
    end
    return s, instance
end
local function vulnerable(s, index, amount)
    Combat.addStatus(s.enemies[index or 1], "vulnerable", amount or 1)
end
for _, upgraded in ipairs({false, true}) do
    for _, stacks in ipairs({-1, 0, 1}) do
        test((upgraded and "upgraded" or "normal") .. " catalog damage with vulnerable " .. stacks, function()
            local s, c = battle(upgraded)
            if stacks >= 0 then vulnerable(s, 1, stacks) end
            local hp, seed = s.enemies[1].hp, s.seed
            equal(Combat.cardDefinition(s, c).cost, 1)
            assert(Combat.canPlay(s, c.uid, 1)); assert(Combat.play(s, c.uid, 1))
            local base = upgraded and 8 or 5
            equal(hp - s.enemies[1].hp, stacks > 0 and math.floor(base * 1.5) or base)
            equal(s.energy, stacks > 0 and 3 or 2); equal(#s.hand, stacks > 0 and 1 or 0)
            equal(#s.draw, stacks > 0 and 1 or 2); equal(s.discard[1], c); equal(#s.exhaust, 0); equal(s.seed, seed)
            local before = Combat.copy(s)
            local ok, reason = Combat.play(s, c.uid, 1)
            equal(ok, false); equal(reason, "card_not_in_hand"); same(s, before)
        end)
    end
end
for _, target in ipairs({false, 0, -1, 3, 1.5, "1", {}, math.huge, 0/0}) do
    test("invalid target " .. tostring(target) .. " has no mutation", function()
        local s, c = battle(nil, {"cultist", "jaw_worm"})
        local before = Combat.copy(s)
        if target == false then target = nil end
        local ok, why = Combat.canPlay(s, c.uid, target)
        equal(ok, false); equal(why, "invalid_target")
        ok, why = Combat.play(s, c.uid, target)
        equal(ok, false); equal(why, "invalid_target"); same(s, before)
    end)
end
for _, reason in ipairs({"invalid_target", "insufficient_energy", "not_player_turn"}) do
    test(reason .. " remains atomic", function()
        local s, c = battle()
        if reason == "invalid_target" then s.enemies[1].hp = 0
        elseif reason == "insufficient_energy" then s.energy = 0
        else s.phase = "enemy" end
        local before = Combat.copy(s)
        local ok, why = Combat.play(s, c.uid, 1)
        equal(ok, false); equal(why, reason); same(s, before)
    end)
end
for _, index in ipairs({1, 2}) do
    test("condition reads chosen live target " .. index, function()
        local s, c = battle(nil, {"cultist", "jaw_worm"})
        vulnerable(s, 2)
        assert(Combat.play(s, c.uid, index))
        equal(s.energy, index == 2 and 3 or 2); equal(#s.hand, index == 2 and 1 or 0)
    end)
end
test("strength weak vulnerable and block use Actor arithmetic", function()
    local s, c = battle(); vulnerable(s)
    Combat.addStatus(s.player, "strength", 4); Combat.addStatus(s.player, "weak", 1)
    s.enemies[1].block = 3
    local hp = s.enemies[1].hp
    assert(Combat.play(s, c.uid, 1)); equal(hp - s.enemies[1].hp, 7); equal(s.energy, 3); equal(#s.hand, 1)
end)
test("fully blocked attack still triggers positive vulnerable condition", function()
    local s, c = battle(); vulnerable(s); s.enemies[1].block = 100
    local hp = s.enemies[1].hp
    assert(Combat.play(s, c.uid, 1)); equal(s.enemies[1].hp, hp); equal(s.energy, 3); equal(#s.hand, 1)
end)
for _, enemyHp in ipairs({1, 100}) do
    test("thorns source death stops conditional with target HP " .. enemyHp, function()
        local s, c = battle(); vulnerable(s); s.enemies[1].hp = enemyHp
        Combat.addStatus(s.enemies[1], "thorns", 3); s.player.hp = 3
        assert(Combat.play(s, c.uid, 1)); equal(s.phase, "defeat"); equal(s.energy, 2); equal(#s.hand, 0); equal(#s.draw, 2)
    end)
end
test("final lethal target retains vulnerable but clears queued energy and draw", function()
    local s, c = battle(); vulnerable(s); s.enemies[1].hp = 1
    assert(Combat.play(s, c.uid, 1)); equal(s.phase, "victory"); equal(s.enemies[1].statuses.vulnerable, 1)
    equal(s.energy, 2); equal(#s.hand, 0); equal(#s.draw, 2)
end)
test("draw lock blocks draw only, not energy", function()
    local s, c = battle(); vulnerable(s); s.player.noDraw = true
    assert(Combat.play(s, c.uid, 1)); equal(s.energy, 3); equal(#s.hand, 0); equal(#s.draw, 2)
end)
test("full remaining hand stops draw without discarding it", function()
    local s, c = battle(); vulnerable(s)
    -- The played card is removed before drawing. Keep maxHand other real instances.
    local full = Combat.new(data, {deck = {"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike"}})
    for _, pile in ipairs({full.hand, full.draw}) do
        for _, item in ipairs(pile) do
            if #s.hand <= s.rules.player.maxHand then item.uid = s.nextUid; s.nextUid = s.nextUid + 1; s.hand[#s.hand + 1] = item end
        end
    end
    local top, draw, seed, events = s.draw[#s.draw], s.draw, s.seed, #s.events
    assert(Combat.play(s, c.uid, 1)); equal(#s.hand, s.rules.player.maxHand)
    equal(s.draw, draw); equal(#s.draw, 2); equal(s.draw[2], top)
    equal(#s.discard, 1); equal(s.discard[1], c); equal(s.energy, 3)
    equal(s.seed, seed); equal(#s.events, events + 2)
end)
test("empty draw reshuffles discard but never the resolving card", function()
    local s, c = battle(); vulnerable(s); s.discard, s.draw = s.draw, {}
    assert(Combat.play(s, c.uid, 1)); equal(#s.hand, 1); assert(s.hand[1] ~= c); equal(s.discard[1], c); equal(#s.draw, 1)
    local reshuffles = 0; for _, e in ipairs(s.events) do if e.kind == "reshuffle" then reshuffles = reshuffles + 1 end end
    equal(reshuffles, 1)
end)
local function conditional(condition, branch)
    return {op = "conditional", ["if"] = condition, ["then"] = branch}
end
local variants = {
    {name = "nil top level", effects = nil},
    {name = "false top level", effects = false},
    {name = "empty top level", effects = {}},
    {name = "object top level", effects = conditional("unknown", {{op="energy",value=1}})},
    {name = "sparse top level", effects = {[1]={op="damage",value=5}, [3]=conditional("unknown", {{op="energy",value=1}})}},
    {name = "empty branch", effects = {{op="damage",value=5}, conditional("target_vulnerable", {})}},
    {name = "false branch", effects = {{op="damage",value=5}, conditional("target_vulnerable", false)}},
    {name = "object branch", effects = {{op="damage",value=5}, conditional("target_vulnerable", {op="energy",value=1})}},
    {name = "table branch op", effects = {{op="damage",value=5}, conditional("target_vulnerable", {{op={},value=1}})}},
    {name = "table top level op", effects = {{op={},value=1}}},
    {name = "false branch op", effects = {{op="damage",value=5}, conditional("target_vulnerable", {{op=false,value=1}})}},
    {name = "unknown condition", effects = {{op="damage", value=5}, conditional("unknown", {{op="energy", value=1}})}},
    {name = "unsupported branch op", effects = {{op="damage", value=5}, conditional("target_vulnerable", {{op="energy", value=1}, {op="unknown"}})}},
    {name = "nested condition", effects = {{op="damage", value=5}, conditional("target_vulnerable", {conditional("target_vulnerable", {{op="energy", value=1}})})}},
    {name = "unknown nested condition", effects = {{op="damage", value=5}, conditional("target_vulnerable", {conditional("unknown", {{op="energy", value=1}})})}},
    {name = "branch damage not enabled", effects = {{op="damage", value=5}, conditional("target_vulnerable", {{op="damage", value=1}})}},
    {name = "missing target preflight", effects = {conditional("target_vulnerable", {{op="energy", value=1}})}},
    {name = "all target damage not single target preflight", effects = {{op="damageAll", value=5}, conditional("target_vulnerable", {{op="energy", value=1}})}},
    {name = "condition before damage", effects = {conditional("target_vulnerable", {{op="energy", value=1}}), {op="damage", value=5}}},
    {name = "missing branch", effects = {{op="damage", value=5}, conditional("target_vulnerable")}},
    {name = "sparse branch hides unknown op", effects = {{op="damage", value=5}, conditional("target_vulnerable", {[1]={op="energy",value=1}, [3]={op="unknown"}})}},
    {name = "else branch not supported", effects = {{op="damage", value=5}, {op="conditional", ["if"]="target_vulnerable", ["then"]={{op="energy",value=1}}, ["else"]={{op="unknown"}}}}}
}
for _, case in ipairs(variants) do
    test(case.name .. " rejected recursively before payment", function()
        local s, c = battle(); vulnerable(s); s.catalog.cards.dropkick.effects = case.effects
        local supported, reason = Effects.supported(case.effects)
        equal(supported, false); equal(type(reason), "string")
        local before = Combat.copy(s)
        local ok, why = Combat.canPlay(s, c.uid, 1); equal(ok, false); assert(why:find("unsupported_effect:", 1, true))
        ok = Combat.play(s, c.uid, 1); equal(ok, false); same(s, before)
    end)
end
test("post-damage nested draw failure restores original state and references", function()
    local s, c = battle(); vulnerable(s)
    -- A malformed existing discard makes shuffle throw after damage/energy.
    s.draw = {}; s.discard = {{uid=9, cardId="strike"}, {uid=10, cardId="defend"}}; s.seed = "bad seed"
    local before = Combat.copy(s)
    local refs = {s.hand, s.draw, s.discard, s.events, s.player, s.enemies[1], s.enemies[1].statuses}
    assert(Combat.canPlay(s, c.uid, 1)); local ok = pcall(Combat.play, s, c.uid, 1); equal(ok, false); same(s, before)
    equal(s.hand, refs[1]); equal(s.draw, refs[2]); equal(s.discard, refs[3]); equal(s.events, refs[4]); equal(s.player, refs[5]); equal(s.enemies[1], refs[6]); equal(s.enemies[1].statuses, refs[7])
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

test("real starter reward joins permanent deck and is usable in next battle", function()
    local selected, choice
    for seed = 1, 128 do
        local run = win(seed)
        for i, id in ipairs(Run.rewardOptions(run)) do if id == "dropkick" then selected, choice = run, i; break end end
        if selected then break end
    end
    assert(selected, "dropkick never offered in real victory rewards")
    local old = Combat.copy(selected.deck)
    assert(Run.claimCardReward(selected, choice)); dofile('tests/lua/support/finish_combat_rewards.lua')(selected); equal(#selected.deck, #old + 1)
    for i, c in ipairs(old) do same(selected.deck[i], c) end
    equal(selected.deck[#selected.deck].cardId, "dropkick")
    assert(Run.startCombat(selected, "cultist_solo"))
    for _ = 1, 10 do
        assert(selected.phase == "combat")
        local combo, bash
        for _, c in ipairs(selected.combat.hand) do
            if c.cardId == "dropkick" then combo = c elseif c.cardId == "bash" then bash = c end
        end
        if combo then
            if bash then assert(Run.play(selected, bash.uid, 1)) end
            local s = selected.combat
            local hasVulnerable = (s.enemies[1].statuses.vulnerable or 0) > 0
            local hp, energy, hand = s.enemies[1].hp, s.energy, #s.hand
            assert(Run.play(selected, combo.uid, 1))
            equal(hp - s.enemies[1].hp, math.min(hp, hasVulnerable and 7 or 5)); equal(s.energy, energy - (hasVulnerable and 0 or 1))
            equal(#s.hand, hand - (hasVulnerable and 0 or 1)); return
        end
        assert(Run.endTurn(selected))
    end
    error("reward card not played")
end)
assert(failed == 0, failed .. "/" .. count .. " vulnerable combo tests failed")
print("vulnerable combo tests passed: " .. count)
