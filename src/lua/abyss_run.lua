-- Same-run deck and reward ownership. Platform/UI adapters issue these commands.
local Combat = require("abyss_combat")
local Effects = require("abyss_effects")
local M = {}

local function find(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
end

function M.new(data, seed)
    seed = seed or 1
    assert(type(seed) == "number" and seed % 1 == 0, "seed must be an integer")
    local run = { version = data.rules.version, data = Combat.copy(data), seed = seed % 65536,
        phase = "map", floor = 1, hp = data.rules.player.maxHp, maxHp = data.rules.player.maxHp,
        gold = data.rules.player.startingGold, deck = {}, nextDeckUid = 1,
        relics = Combat.copy(data.rules.player.startingRelics), potions = {} }
    for _, id in ipairs(data.cards.starter_deck.cards) do
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = id, upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    end
    return run
end

function M.startCombat(run, encounterId)
    if run.phase ~= "map" then return false, "not_on_map" end
    local encounter = find(run.data.enemies.encounters, encounterId)
    if not encounter then return false, "unknown_encounter" end
    if run.floor < encounter.minFloor or run.floor > encounter.maxFloor then return false, "wrong_floor" end
    local battle = Combat.new(run.data, { seed = run.seed, hp = run.hp, deck = run.deck, enemies = encounter.enemies })
    run.combat, run.encounterId, run.encounterTier = battle, encounter.id, encounter.tier
    run.phase = "combat"
    return true
end

local function rewardCandidates(run)
    local candidates = {}
    for _, card in ipairs(run.data.cards.cards) do
        if card.rarity ~= "basic" and card.rarity ~= "special" and not card.condition and not card.costMode
            and Effects.supported(card.effects) then candidates[#candidates + 1] = card.id end
    end
    return candidates
end

function M.finishCombat(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local result = Combat.outcome(run.combat)
    if not result then return false, "battle_unfinished" end
    run.hp, run.seed = run.combat.player.hp, run.combat.seed
    run.lastResult = { outcome = result, turn = run.combat.turn, encounterId = run.encounterId }
    if result == "defeat" then
        run.phase, run.rewards = "defeat", nil
        return true
    end
    -- Combat-end relics apply once, before the reward transaction is offered.
    for _, id in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, id)
        if relic and relic.trigger == "combat_end" then
            for _, effect in ipairs(relic.effects) do
                if effect.op == "heal" then run.hp = math.min(run.maxHp, run.hp + effect.value) end
            end
        end
    end
    local gold = run.data.rules.rewards[run.encounterTier .. "Gold"]
    -- The content table calls ordinary encounters 'normal'.
    assert(type(gold) == "number", "unknown encounter reward tier")
    run.gold = run.gold + gold
    local pool, choices = rewardCandidates(run), {}
    for _ = 1, math.min(run.data.rules.rewards.cardChoices, #pool) do
        choices[#choices + 1] = table.remove(pool, Combat.random(run, #pool))
    end
    run.rewards, run.phase = { cards = choices, gold = gold }, "reward"
    return true
end

function M.rewardOptions(run)
    if run.phase ~= "reward" then return {} end
    return Combat.copy(run.rewards.cards)
end

function M.claimCardReward(run, choice)
    if run.phase ~= "reward" then return false, "no_pending_reward" end
    if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 0 or choice > #run.rewards.cards then
        return false, "invalid_reward_choice"
    end
    if choice > 0 then
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = run.rewards.cards[choice], upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    end
    run.phase, run.rewards, run.combat = "map", nil, nil
    return true
end

function M.play(run, uid, targetIndex)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local ok, reason = Combat.play(run.combat, uid, targetIndex)
    if ok and Combat.outcome(run.combat) then M.finishCombat(run) end
    return ok, reason
end

function M.endTurn(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local ok, reason = Combat.endTurn(run.combat)
    if ok and Combat.outcome(run.combat) then M.finishCombat(run) end
    return ok, reason
end

return M
