package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run = require("abyss_combat"), require("abyss_run")
local Nodes, Map = require("abyss_nodes"), require("abyss_map")
local Effects, data = require("abyss_effects"), require("abyss_data")
local count = 0
local function equal(a, b, label) assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn) fn(); count = count + 1; print("ok card_pool_rewards " .. count .. " - " .. name) end

local oracle = dofile("tests/lua/support/card_pool_oracle.lua")
local cases, blocked = oracle.cases, oracle.blocked
local function find(entries, id) for _, value in ipairs(entries) do if value.id == id then return value end end end

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
        if remaining == 0 then break end
    end
    equal(remaining, 0, "unseen playable rewards")
end)
print("LUA_CARD_POOL_REWARDS_PASS " .. count)
