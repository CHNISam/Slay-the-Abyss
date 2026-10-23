package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run = require("abyss_run")
local Combat = require("abyss_combat")
local data = require("abyss_data")
local count = 0
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn) fn(); count = count + 1; print("ok run " .. count .. " - " .. name) end

local function win(seed)
    local run = Run.new(data, seed or 1)
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
    equal(run.phase, "reward")
    return run
end

test("real ten-card starter wins a complete encounter without state edits", function()
    local run = win(42)
    equal(#run.deck, 10); equal(run.lastResult.outcome, "victory")
    assert(run.hp > 0 and run.hp <= run.maxHp)
    equal(run.gold, data.rules.player.startingGold + data.rules.rewards.normalGold)
    equal(#Run.rewardOptions(run), data.rules.rewards.cardChoices)
end)

test("selected reward becomes a unique permanent instance in next combat", function()
    local run = win(53)
    local cardId = Run.rewardOptions(run)[1]
    assert(Run.claimCardReward(run, 1))
    equal(#run.deck, 11); equal(run.deck[11].cardId, cardId); equal(run.deck[11].uid, 11)
    assert(Run.startCombat(run, "cultist_solo"))
    local instances = 0
    for _, pile in ipairs({ run.combat.hand, run.combat.draw }) do
        for _, card in ipairs(pile) do if card.cardId == cardId then instances = instances + 1 end end
    end
    equal(instances, 1)
end)

test("reward choices are deterministic, unique and protected from UI mutation", function()
    local a, b = win(13), win(13)
    local choices, seen = Run.rewardOptions(a), {}
    for i, id in ipairs(choices) do equal(id, Run.rewardOptions(b)[i]); assert(not seen[id]); seen[id] = true end
    choices[1] = "unknown"
    assert(Run.rewardOptions(a)[1] ~= "unknown")
end)

test("invalid and repeated claims do not award a card or money", function()
    local run = win(5)
    local gold, seed = run.gold, run.seed
    for _, choice in ipairs({ -1, 0.5, 4, "1", false, {} }) do
        equal(Run.claimCardReward(run, choice), false)
        equal(#run.deck, 10); equal(run.gold, gold); equal(run.seed, seed); equal(run.phase, "reward")
    end
    equal(Run.claimCardReward(run, nil), false)
    assert(Run.claimCardReward(run, 1))
    equal(Run.claimCardReward(run, 1), false); equal(Run.finishCombat(run), false)
    equal(#run.deck, 11); equal(run.gold, gold)
end)

test("skip is explicit and consumes exactly the pending reward", function()
    local run = win(9)
    assert(Run.claimCardReward(run, 0))
    equal(#run.deck, 10); equal(run.phase, "map"); equal(#Run.rewardOptions(run), 0)
    equal(Run.claimCardReward(run, 0), false)
end)

test("unfinished and invalid battle commands preserve persistent resources", function()
    local run = Run.new(data, 7)
    local seed, gold = run.seed, run.gold
    equal(Run.startCombat(run, "unknown"), false)
    equal(Run.startCombat(run, "boss_guardian"), false)
    equal(run.phase, "map"); equal(run.seed, seed)
    assert(Run.startCombat(run, "cultist_solo"))
    equal(Run.startCombat(run, "cultist_solo"), false)
    equal(Run.finishCombat(run), false)
    equal(run.gold, gold); equal(#run.deck, 10); equal(run.hp, run.maxHp)
end)

test("loss never heals with starting relic or awards resources", function()
    local run = Run.new(data, 10)
    run.hp = 1
    assert(Run.startCombat(run, "jaw_solo"))
    assert(Run.endTurn(run))
    equal(run.phase, "defeat"); equal(run.hp, 0)
    equal(run.gold, data.rules.player.startingGold); equal(#run.deck, 10)
    equal(Run.claimCardReward(run, 1), false); equal(Run.finishCombat(run), false)
end)

test("same-run instances and input catalogs do not share writable state", function()
    local a, b = Run.new(data, 1), Run.new(data, 1)
    a.deck[1].upgraded = true
    a.data.cards.cards[1].effects[1].value = 999
    equal(b.deck[1].upgraded, false); equal(b.data.cards.cards[1].effects[1].value, 6)
    equal(data.cards.cards[1].effects[1].value, 6)
end)

print("LUA_RUN_PASS " .. count)
