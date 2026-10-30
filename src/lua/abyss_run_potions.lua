-- Potions responsibility for the same-run API.
local Combat = require("abyss_combat")
local EventRandom = require("abyss_sts_random")
local EventCombat=require('abyss_event_combat')
local PotionCandidate=require('abyss_run_potion_candidate')

local M = {}

function M.install(Run, shared)
    local find=shared.find
    local applyPermanentChanges,combatEndHealing=shared.applyPermanentChanges,shared.combatEndHealing
    function Run.potionCapacity(run)
        return run.potionSlots or run.data.rules.player.potionSlots
    end
    function Run.potionCount(run)
        local count = 0
        for slot = 1, Run.potionCapacity(run) do
            if run.potions[slot] then count = count + 1 end
        end
        return count
    end

    function Run.obtainPotion(run, id)
        if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
        for _, owned in ipairs(run.relics) do
            local relic = find(run.data.relics.relics, owned)
            if relic and relic.blocksPotions then return false, "potion_blocked_by_sozu" end
        end
        for slot = 1, Run.potionCapacity(run) do
            if not run.potions[slot] then
                run.potions[slot] = id
                if run.phase=='combat' and run.combat then run.combat.potionInventory=Combat.copy(run.potions) end
                return true, slot
            end
        end
        return false, "potion_slots_full"
    end

    local potionEventRestricted=PotionCandidate.eventRestricted
    -- Discard never executes a potion effect and does not require a player turn.
    function Run.discardPotion(run, slot)
        if run.phase=='combat'and run.combat and run.combat.pendingPotionChoice then return false,'potion_choice_pending'end
        if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Run.potionCapacity(run) then
            return false, "invalid_potion_slot"
        end
        local id = run.potions[slot]
        if not id then return false, "empty_potion_slot" end
        if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
        if potionEventRestricted(run)then return false,'potion_event_restricted' end
        -- Like usePotion, a destructive transaction expires old physical gestures,
        -- even if the same bottle ID is immediately acquired in the vacant slot.
        run.potions = Combat.copy(run.potions)
        run.potions[slot] = nil
        if run.phase=='combat' and run.combat then run.combat.potionInventory=Combat.copy(run.potions) end
        return true
    end

    local function potionCandidate(run, slot, targetIndex, afterPotionActions)
        return PotionCandidate.prepare(run,slot,targetIndex,afterPotionActions,Run.potionCapacity)
    end

    local function commitOutsidePotion(run, battle, slot)
        if battle.outside then
            run.hp,run.maxHp=battle.hp,battle.maxHp
            if run.combat then run.combat.player.hp,run.combat.player.maxHp=run.hp,run.maxHp end
            run.potions=Combat.copy(battle.potionInventory or run.potions)
            if not battle.potionInventory then run.potions[slot]=nil end
            if battle.potionRandomRng then
                run.shopRng=run.shopRng and Combat.copy(run.shopRng) or {merchant=EventRandom.fromSeed(run.runSeed)}
                run.shopRng.potion=battle.potionRandomRng
            end
            if battle.generatedPotionOffers then run.lastPotionGeneration=Combat.copy(battle.generatedPotionOffers)end
            return true
        end
    end

    local function stagePotionBattle(run, battle)
        local candidate = {}
        for key, value in pairs(run) do candidate[key] = value end
        candidate.combat, candidate.potions, candidate.gold = battle, Combat.copy(battle.potionInventory), battle.player.gold
        candidate.deck=(battle.ritualDaggerGrowth or battle.masterDeckChanges or battle.masterDeckObtains) and Combat.copy(run.deck) or run.deck
        candidate.hp,candidate.maxHp=battle.player.hp,battle.player.maxHp
        candidate.relicCounters=Combat.copy(battle.relicCounters)
        if battle.generatedPotionOffers then candidate.lastPotionGeneration=Combat.copy(battle.generatedPotionOffers)end
        if battle.potionRandomRng then
            candidate.shopRng=run.shopRng and Combat.copy(run.shopRng) or {merchant=EventRandom.fromSeed(run.runSeed)}
            candidate.shopRng.potion=EventRandom.cloneState(battle.potionRng or battle.potionRandomRng)
            battle.potionRandomRng=nil
        end
        if battle.potionRngChanged then
            candidate.shopRng=candidate.shopRng and Combat.copy(candidate.shopRng)or {merchant=EventRandom.fromSeed(run.runSeed)}
            candidate.shopRng.potion=EventRandom.cloneState(battle.potionRng);battle.potionRngChanged=nil
        end
        return candidate
    end

    local function escapePotionBattle(run, candidate, battle)
        if battle.smoked then
            candidate.emeraldCombat=nil
            battle.phase='escaped'
            local reopened=false
            if candidate.eventCombat then
                if battle.miscRng then candidate.miscRng=EventRandom.cloneState(battle.miscRng)end
                if battle.cardRng then candidate.cardRng=EventRandom.cloneState(battle.cardRng)end
                candidate.shopRng=candidate.shopRng and Combat.copy(candidate.shopRng)
                local called,accepted,status=pcall(function()
                    combatEndHealing(candidate)
                    return EventCombat.escape(candidate)
                end)
                if not called or not accepted then return false,'potion_effect_failed'end
                reopened=status=='event_reopened'
            end
            if reopened then candidate.rewards,candidate.pendingCombatRewards=nil,nil
            else candidate.phase,candidate.rewards,candidate.pendingCombatRewards='map',nil,nil end
            candidate.lastResult={outcome='escaped',turn=battle.turn,encounterId=run.encounterId}
        end
        return true
    end

    function Run.usePotion(run, slot, targetIndex, afterPotionActions)
        if afterPotionActions~=nil and type(afterPotionActions)~='function' then return false,'invalid_potion_hook' end
        local battle, reason = potionCandidate(run, slot, targetIndex,afterPotionActions)
        if not battle then return false, reason end
        if battle.outside then return commitOutsidePotion(run,battle,slot) end
        require("abyss_events").emit(battle, "potion", { slot = slot, id = run.potions[slot], target = targetIndex })
        local outcome = Combat.outcome(battle)
        if outcome then
            battle.phase = outcome
            require("abyss_events").emit(battle, outcome, {allEnemiesEscaped=Combat.allEnemiesEscaped(battle), mugged=battle.mugged})
        end
        -- Stage the complete transaction, including rewards and their RNG, before committing.
        -- Persistent deck UIDs are owned by Run and are never regenerated from combat instances.
        local candidate = stagePotionBattle(run, battle)
        local escaped,why=escapePotionBattle(run,candidate,battle)
        if not escaped then return false,why end
        if outcome then
            -- Reward preparation commits the continuous potion stream. Do not let
            -- an exception mutate a table still owned by the live run.
            candidate.shopRng = run.shopRng and Combat.copy(run.shopRng)
            local called, ok = pcall(Run.finishCombat, candidate)
            if not called or not ok then return false, "potion_effect_failed" end
        end
        applyPermanentChanges(candidate)
        local root = run.combat
        for key in pairs(root) do root[key] = nil end
        for key, value in pairs(battle) do root[key] = value end
        candidate.combat = root
        run.eventCombat,run.rewards,run.pendingCombatRewards=candidate.eventCombat,candidate.rewards,candidate.pendingCombatRewards
        run.emeraldCombat=candidate.emeraldCombat
        for key, value in pairs(candidate) do run[key] = value end
        return true
    end

    -- Detached UI description. A targeted bottle is usable if at least one legal target exists;
    -- usePotion still validates the selected target when the command arrives.
    -- Indexed by physical slot, with nil vacancies; do not iterate/count with ipairs/#.
    local function potionAvailability(run, slot, needTarget)
                local candidate, reason
                if needTarget and run.combat then
                    for index, enemy in ipairs(run.combat.enemies) do
                        if require("abyss_actor").isActive(enemy) then
                            candidate, reason = potionCandidate(run, slot, index)
                            if candidate then break end
                        end
                    end
                end
                if not candidate and not reason then candidate, reason = potionCandidate(run, slot) end
        return candidate, reason
    end

    function Run.potionView(run)
        local result = {}
        for slot = 1, Run.potionCapacity(run) do
            local id = run.potions[slot]
            if id then
                local potion = find(run.data.potions.potions, id)
                local needTarget = potion and potion.targetPolicy == "enemy_one" or false
        local candidate, reason = potionAvailability(run, slot, needTarget)
                result[slot] = { slot = slot, id = id, name = potion and potion.name or id,
                    targetPolicy = potion and potion.targetPolicy,
                    effects = potion and Combat.copy(potion.effects) or {}, needTarget = needTarget,
                    canUse = candidate ~= nil, canDiscard=not potionEventRestricted(run), reason = reason }
            end
        end
        return result
    end

end

return M
