package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Effects = require("abyss_effects")
local Run = require("abyss_run")
local data = require("abyss_data")
local count, failed = 0, 0
local function equal(a, b) assert(a == b or (type(a) == "number" and type(b) == "number" and a ~= a and b ~= b), tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " copied_attack " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
-- Preserve every value and original reference, including existing card contents.
local function unchangedAfter(root)
    local saved = {}
    local function visit(t)
        if type(t) ~= "table" or saved[t] then return end
        local values = {}; saved[t] = values
        for k, v in pairs(t) do values[k] = v; visit(k); visit(v) end
    end
    visit(root)
    return function()
        for original, values in pairs(saved) do
            for k, v in pairs(values) do equal(original[k], v) end
            for k, v in pairs(original) do equal(v, values[k]) end
        end
    end
end
local function battle(upgraded)
    local s = Combat.new(data, {seed=42, deck={{cardId="anger", upgraded=upgraded}}})
    return s, s.hand[1]
end
local function unique(s)
    local seen, total = {}, 0
    for _, pile in ipairs({s.hand, s.draw, s.discard, s.exhaust}) do
        for _, c in ipairs(pile) do
            assert(not seen[c.uid], "duplicate uid"); seen[c.uid] = c; total = total + 1
            assert(c.uid < s.nextUid)
        end
    end
    return total
end
for _, upgraded in ipairs({false, true}) do
    test((upgraded and "upgraded" or "normal") .. " creates separate zero-cost catalog copy after real damage", function()
        local s, c = battle(upgraded)
        local checkCard, checkCatalog = unchangedAfter(c), unchangedAfter(s.catalog)
        local hp, nextUid, seed = s.enemies[1].hp, s.nextUid, s.seed
        s.energy = 0
        assert(Combat.canPlay(s, c.uid, 1)); assert(Combat.play(s, c.uid, 1))
        local created = s.discard[1]
        equal(hp - s.enemies[1].hp, upgraded and 8 or 6)
        equal(#s.discard, 2); equal(s.discard[2], c); assert(created ~= c)
        equal(created.cardId, "anger"); equal(created.upgraded, upgraded); equal(created.uid, nextUid)
        equal(s.nextUid, nextUid + 1); equal(Combat.cardDefinition(s, created).cost, 0)
        equal(Combat.cardDefinition(s, created).effects[1].value, upgraded and 8 or 6)
        equal(#s.hand, 0); equal(#s.draw, 0); equal(#s.exhaust, 0); equal(s.energy, 0); equal(s.seed, seed)
        equal(unique(s), 2); checkCard(); checkCatalog()
        local check = unchangedAfter(s)
        local ok, reason = Combat.play(s, c.uid, 1)
        equal(ok, false); equal(reason, "card_not_in_hand"); check()
    end)
    test((upgraded and "upgraded" or "normal") .. " reshuffles and replays generated and original instances with fresh UIDs", function()
        local s, c = battle(upgraded)
        assert(Combat.play(s, c.uid, 1)); local generated = s.discard[1]
        assert(Combat.endTurn(s)); equal(#s.hand, 2); equal(#s.discard, 0)
        s.energy = 0
        local hp = s.enemies[1].hp
        assert(Combat.play(s, generated.uid, 1)); assert(Combat.play(s, c.uid, 1))
        equal(hp - s.enemies[1].hp, upgraded and 16 or 12)
        equal(unique(s), 4); equal(s.nextUid, 5); equal(s.energy, 0)
        for _, v in ipairs(s.discard) do equal(v.upgraded, upgraded) end
    end)
end
for _, target in ipairs({false, 0, -1, 2, 1.5, "1", {}, math.huge, 0/0}) do
    test("invalid target " .. tostring(target) .. " rejects without allocating", function()
        local s, c = battle(); local check = unchangedAfter(s)
        if target == false then target = nil end
        local ok, reason = Combat.play(s, c.uid, target)
        equal(ok, false); equal(reason, "invalid_target"); check()
    end)
end
test("controlled positive cost with insufficient energy rejects before copying", function()
    local s, c = battle(); s.catalog.cards.anger.cost = 1; s.energy = 0
    local check = unchangedAfter(s); local ok, reason = Combat.play(s, c.uid, 1)
    equal(ok, false); equal(reason, "insufficient_energy"); check()
end)
for _, hp in ipairs({1, 40}) do
    test("thorns source death stops copy with enemy starting hp " .. hp, function()
        local s, c = battle(); s.player.hp = 3; s.enemies[1].hp = hp
        Combat.addStatus(s.enemies[1], "thorns", 3)
        assert(Combat.play(s, c.uid, 1)); equal(s.phase, "defeat")
        equal(s.nextUid, 2); equal(#s.discard, 0);equal(s.cardInUse,c)
    end)
end
test("final lethal target clears queued copy before victory", function()
    local s, c = battle(); s.enemies[1].hp = 1
    assert(Combat.play(s, c.uid, 1)); equal(s.phase, "victory"); equal(#s.discard, 1); equal(s.nextUid, 2)
    equal(s.events[#s.events].kind, "victory")
end)
test("controlled subsequent draw can draw the new copy but never its resolving source", function()
    local s, c = battle(true)
    table.insert(s.catalog.cards.anger.upgrade.effects, {op="draw", value=2})
    assert(Combat.play(s, c.uid, 1)); equal(#s.hand, 1); assert(s.hand[1] ~= c)
    equal(s.hand[1].uid, 2); equal(s.hand[1].upgraded, true); equal(s.discard[1], c); equal(unique(s), 2)
end)
for _, mode in ipairs({"unknown card", "different card", "missing card"}) do
    test(mode .. " copy rejects or rolls back all damage", function()
        local s, c = battle()
        s.catalog.cards.anger.effects[2].card = mode == "unknown card" and "missing" or mode == "different card" and "strike" or nil
        local check = unchangedAfter(s)
        local called, result = pcall(Combat.play, s, c.uid, 1)
        assert(not called or result == false); check()
    end)
end
test("unknown played card retains existing thrown-error API without mutation", function()
    local s, c = battle(); c.cardId = "missing"; local check = unchangedAfter(s)
    local ok, reason = pcall(Combat.play, s, c.uid, 1)
    equal(ok, false); assert(tostring(reason):find("unknown card", 1, true)); check()
end)
test("copy-only direct effect rejects absent played-card context without mutation", function()
    local s = battle(); local check = unchangedAfter(s)
    local ok, reason = pcall(Combat.applyEffects, s, {{op="addCardToDiscard",card="anger"}}, s.player)
    equal(ok, false); assert(tostring(reason):find("played card", 1, true)); check()
end)
test("optional context survives direct conditional recursion without enabling new conditional card branches", function()
    local s, c = battle(true); Combat.addStatus(s.enemies[1], "vulnerable", 1)
    local effects = {{op="conditional", ["if"]="target_vulnerable", ["then"]={{op="addCardToDiscard",card="anger"}}}}
    equal(Effects.supported(effects), false)
    Combat.applyEffects(s, effects, s.player, s.enemies[1], c)
    equal(s.discard[1].upgraded, true); equal(s.discard[1].uid, 2); equal(s.hand[1], c)
end)
test("failure after copy and reshuffle restores allocator, piles, RNG and every original reference", function()
    local s = Combat.new(data, {seed=42, deck={"anger", "strike", "defend"}})
    local c
    for i = #s.hand, 1, -1 do
        if s.hand[i].cardId == "anger" then c = s.hand[i]
        else s.discard[#s.discard+1] = table.remove(s.hand,i) end
    end
    table.insert(s.catalog.cards.anger.effects, {op="draw",value=2})
    table.insert(s.catalog.cards.anger.effects, {op="gainStatus",status="missing",value=1})
    local check = unchangedAfter(s)
    assert(Combat.canPlay(s, c.uid, 1))
    local ok, reason = pcall(Combat.play, s, c.uid, 1)
    equal(ok, false); assert(tostring(reason):find("unknown status", 1, true)); check()
    table.remove(s.catalog.cards.anger.effects)
    local seed = s.seed
    assert(Combat.play(s, c.uid, 1)); equal(s.nextUid, 5); equal(unique(s), 4); assert(s.seed ~= seed)
end)
for _, uid in ipairs({false, -1, 0, 1.5, math.huge, 0/0, 9007199254740992.0}) do
    test("controlled invalid or nonadvancing nextUid " .. tostring(uid) .. " rolls back", function()
        local s, c = battle(); s.nextUid = uid
        local check = unchangedAfter(s)
        local ok = pcall(Combat.play, s, c.uid, 1); equal(ok, false)
        check()
    end)
end
test("allocator crosses signed 32-bit boundary without wrap", function()
    local s, c = battle(); s.nextUid = 2147483647
    assert(Combat.play(s,c.uid,1)); equal(s.discard[1].uid,2147483647); equal(s.nextUid,2147483648.0)
    Combat.draw(s,2); assert(Combat.play(s,c.uid,1)); equal(s.nextUid,2147483649.0); equal(unique(s),3)
end)
local function finishBattle(run)
    for _ = 1, 100 do
        if run.phase ~= "combat" then return end
        for _ = 1, 30 do
            if run.phase ~= "combat" then break end
            local chosen
            for _, c in ipairs(run.combat.hand) do
                if Combat.canPlay(run.combat,c.uid,1) then
                    if not chosen or Combat.cardDefinition(run.combat,c).type == "attack" then chosen = c end
                end
            end
            if not chosen then break end
            assert(Run.play(run,chosen.uid,1))
        end
        if run.phase == "combat" then assert(Run.endTurn(run)) end
    end
    error("battle never finished")
end
test("real reward followed by next combat uses copy without leaking generated cards to Run or following battle", function()
    local run, choice
    for seed = 1, 128 do
        local candidate = Run.new(data, seed); assert(Run.startCombat(candidate,"cultist_solo")); finishBattle(candidate)
        for i,id in ipairs(Run.rewardOptions(candidate)) do if id == "anger" then run,choice = candidate,i; break end end
        if run then break end
    end
    assert(run, "anger never offered by real victory")
    local oldSize = #run.deck
    assert(Run.claimCardReward(run,choice)); equal(#run.deck,oldSize+1)
    local checkDeck, nextDeckUid = unchangedAfter(run.deck), run.nextDeckUid
    dofile('tests/lua/support/finish_combat_rewards.lua')(run)
    assert(Run.startCombat(run,"cultist_solo"))
    local played = false
    for _ = 1, 10 do
        assert(run.phase == "combat")
        for _, c in ipairs(run.combat.hand) do
            if c.cardId == "anger" then
                local s, hp, n = run.combat, run.combat.enemies[1].hp, run.combat.nextUid
                assert(Run.play(run,c.uid,1)); equal(hp-s.enemies[1].hp,6); equal(s.nextUid,n+1)
                equal(unique(s),#run.deck+1); played = true; break
            end
        end
        if played then break end
        assert(Run.endTurn(run))
    end
    assert(played); checkDeck(); equal(run.nextDeckUid,nextDeckUid)
    finishBattle(run); equal(run.phase,"reward"); checkDeck()
    assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); assert(Run.startCombat(run,"cultist_solo"))
    equal(unique(run.combat),#run.deck); equal(run.combat.nextUid,#run.deck+1)
    checkDeck(); equal(run.nextDeckUid,nextDeckUid)
end)
assert(failed == 0, failed .. "/" .. count .. " copied attack tests failed")
print("copied attack tests passed: " .. count)
