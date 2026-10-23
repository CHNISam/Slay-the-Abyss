-- Same-run deck and reward ownership. Platform/UI adapters issue these commands.
local Combat = require("abyss_combat")
local Effects = require("abyss_effects")
local Inventory = require("abyss_inventory")
local M = {}

local function find(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
end

function M.new(data, seed)
    seed = seed or 1
    assert(type(seed) == "number" and seed % 1 == 0, "seed must be an integer")
    local run = { version = data.rules.version, data = Combat.copy(data), seed = seed % 65536,
        phase = "map", floor = 1, hp = data.rules.player.maxHp, maxHp = data.rules.player.maxHp,
        elapsedSeconds = 0, victories = 0,
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
    local opening, reason = Inventory.opening(run.data.relics.relics, run.relics)
    if not opening then return false, reason end
    local battle
    battle, reason = Combat.new(run.data, { seed = run.seed, hp = run.hp, deck = run.deck, enemies = encounter.enemies,
        beforeOpeningDraw = function(state) return Inventory.applyOpening(state, opening.beforeDraw) end })
    if not battle then return false, reason end
    -- Queue-tail relics follow the ordinary draw, retaining their held order.
    local ok
    ok, reason = Inventory.applyOpening(battle, opening.afterDraw)
    if not ok then return false, reason end
    run.combat, run.encounterId, run.encounterTier = battle, encounter.id, encounter.tier
    run.phase = "combat"
    return true
end

local function rewardCandidates(run)
    local candidates = {}
    for _, card in ipairs(run.data.cards.cards) do
        if card.type ~= "status" and card.type ~= "curse"
            and card.rarity ~= "basic" and card.rarity ~= "special" and not card.condition and not card.costMode
            -- Boss rewards are rare-only; other tiers retain their current pool.
            and (run.encounterTier ~= "boss" or card.rarity == "rare")
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
    run.victories = run.victories + 1
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

-- Inventory slots are physical positions, not a packed list. Acquiring a bottle
-- fills the leftmost vacancy; reward/shop adapters still own eligibility/payment.
function M.potionCount(run)
    local count = 0
    for slot = 1, run.data.rules.player.potionSlots do
        if run.potions[slot] then count = count + 1 end
    end
    return count
end

function M.obtainPotion(run, id)
    if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
    for slot = 1, run.data.rules.player.potionSlots do
        if not run.potions[slot] then
            run.potions[slot] = id
            return true, slot
        end
    end
    return false, "potion_slots_full"
end

local function potionCandidate(run, slot, targetIndex)
    if run.phase ~= "combat" then return nil, "not_in_combat" end
    if not run.combat or run.combat.phase ~= "player" then return nil, "not_player_turn" end
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > run.data.rules.player.potionSlots then
        return nil, "invalid_potion_slot"
    end
    local id = run.potions[slot]
    if not id then return nil, "empty_potion_slot" end
    local potion = find(run.data.potions.potions, id)
    if not potion then return nil, "unknown_potion" end
    local candidate = Combat.copy(run.combat)
    local called, ok, reason = pcall(Inventory.apply, candidate, potion.effects, targetIndex)
    if not called then return nil, "potion_effect_failed" end
    if not ok then return nil, reason end
    return candidate
end

function M.usePotion(run, slot, targetIndex)
    local battle, reason = potionCandidate(run, slot, targetIndex)
    if not battle then return false, reason end
    require("abyss_events").emit(battle, "potion", { slot = slot, id = run.potions[slot], target = targetIndex })
    local outcome = Combat.outcome(battle)
    if outcome then
        battle.phase = outcome
        require("abyss_events").emit(battle, outcome)
    end
    -- Stage the complete transaction, including rewards and their RNG, before committing.
    -- Persistent deck UIDs are owned by Run and are never regenerated from combat instances.
    local candidate = {}
    for key, value in pairs(run) do candidate[key] = value end
    candidate.combat, candidate.potions = battle, Combat.copy(run.potions)
    candidate.potions[slot] = nil
    if outcome then
        local called, ok = pcall(M.finishCombat, candidate)
        if not called or not ok then return false, "potion_effect_failed" end
    end
    local root = run.combat
    for key in pairs(root) do root[key] = nil end
    for key, value in pairs(battle) do root[key] = value end
    candidate.combat = root
    for key, value in pairs(candidate) do run[key] = value end
    return true
end

-- Detached UI description. A targeted bottle is usable if at least one legal target exists;
-- usePotion still validates the selected target when the command arrives.
-- Indexed by physical slot, with nil vacancies; do not iterate/count with ipairs/#.
function M.potionView(run)
    local result = {}
    for slot = 1, run.data.rules.player.potionSlots do
        local id = run.potions[slot]
        if id then
            local potion = find(run.data.potions.potions, id)
            local needTarget = potion and Inventory.needTarget(potion.effects) or false
            local candidate, reason
            if needTarget and run.combat then
                for index, enemy in ipairs(run.combat.enemies) do
                    if enemy.hp > 0 then
                        candidate, reason = potionCandidate(run, slot, index)
                        if candidate then break end
                    end
                end
            end
            if not candidate and not reason then candidate, reason = potionCandidate(run, slot) end
            result[slot] = { slot = slot, id = id, name = potion and potion.name or id,
                effects = potion and Combat.copy(potion.effects) or {}, needTarget = needTarget,
                canUse = candidate ~= nil, reason = reason }
        end
    end
    return result
end

return M
