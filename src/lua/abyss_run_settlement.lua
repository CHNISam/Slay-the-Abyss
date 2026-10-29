-- Settlement responsibility for the same-run API.
local Combat = require("abyss_combat")
local EventRandom = require("abyss_sts_random")
local PotionRewards = require("abyss_potion_rewards")
local CardPool = require("abyss_card_pool")
local GoldRewards = require("abyss_gold_rewards")
local RunSeed = require("abyss_run_seed")
local RelicRewards=require('abyss_relic_rewards')
local EventCombat=require('abyss_event_combat')
local EmeraldRewards=require('abyss_emerald_rewards')
local RelicHooks = require('abyss_relic_hooks')

local M = {}

function M.install(Run, shared)
    local find,amount=shared.find,shared.amount
    local endingQualified,endingRoom=shared.endingQualified,shared.endingRoom
    local function combatEndHealing(run)
        for _,id in ipairs(run.relics)do
            local relic=find(run.data.relics.relics,id)
            if relic and relic.trigger=='combat_end'then
                for _,effect in ipairs(relic.effects)do if effect.op=='heal'then Run.heal(run,effect.value)end end
            end
        end
    end

    local function heartBattle(run,battle)
        if run.act~=4 or run.floor~=55 or not endingQualified(run)or run.encounterTier~='boss'
            or run.encounterId~='ending_heart'or run.encounterSource~='The Heart' then return false end
        if type(battle)~='table'or battle.encounterSource~='The Heart'
            or battle.roomSeed~=RunSeed.forFloor(run.runSeed,55)or battle.combatGeneration~=run.combatGeneration
            or type(run.combatGeneration)~='number'or run.combatGeneration%1~=0 or run.combatGeneration<1 then return false end
        return true
    end

    local function heartFlow(run,flow)
        if type(flow)~='table'or getmetatable(flow)~=nil or flow.type~='boss'or flow.floor~=55 or flow.complete~=false
            or flow.encounterId~=run.encounterId or flow.encounterSource~='The Heart'
            or type(flow.id)~='string'or flow.id==''or flow.mapSeed~=run.runSeed
            or type(flow.mapSignature)~='string'or flow.mapSignature==''then return false end
        return true
    end

    local function heartEnemyList(battle)
        local enemies=battle.enemies
        if type(enemies)~='table'or getmetatable(enemies)~=nil or #enemies~=1 then return false end
        for key in pairs(enemies)do if key~=1 then return false end end
        return enemies
    end

    local function heartEnemy(battle)
        local enemies=heartEnemyList(battle)
        if not enemies then return false end
        local enemy=enemies[1]
        if type(enemy)~='table'or enemy.definitionId~='corrupt_heart'or enemy.id~='corrupt_heart_1'
            or enemy.sourceId~='CorruptHeart'or enemy.tier~='boss'or not enemy.ai or enemy.ai.kind~='corrupt_heart' then return false end
        if enemy.escaped or type(enemy.hp)~='number'or enemy.hp>0 then return false end
        return true
    end

    local function heartOwner(run)
        local battle,flow=run.combat,run.nodeFlow
        if not heartBattle(run,battle) then return false end
        if not heartFlow(run,flow) then return false end
        if not heartEnemy(battle) then return false end
        if Combat.outcome(battle)~='victory'or not amount(battle.player.hp)or battle.player.hp<=0
            or not amount(run.hp)or run.hp<=0 or run.hp>run.maxHp then return false end
        for _,key in ipairs({'cardActions','queuedCards','actionQueue','pendingPlay','pendingChoice','pendingScry',
            'pendingHandChoice','pendingDiscard','pendingPileChoice','pendingPotionChoice','cardInUse',
            'resolvingCard','resolvingEffects','drainingCardActions'})do if battle[key]then return false end end
        return endingRoom(run,'boss')
    end
    local function finishHeart(run)
        if not heartOwner(run)then return false,'ending_combat_owner_mismatch'end
        -- AbstractRoom constructs this inaccessible GOLD item before excluding
        -- TheEnding Boss from dropReward/Potion/CombatRewardScreen. Spend the draw
        -- without offering money, cards, potions, relics or a boss chest.
        local _,stream,nextRng=GoldRewards.prepare('boss',run)
        run[stream]=nextRng
        run.endingProceed={version=1,runSeed=run.runSeed,act=4,floor=55,
            encounterId=run.encounterId,combatGeneration=run.combatGeneration}
        run.rewards,run.pendingCombatRewards,run.phase=nil,nil,'ending_proceed'
        run.victories=run.victories+1
        return true
    end
    local function prepareGold(run, allEscaped)
        local gold, goldStream, nextGoldRng
        if run.combat.roomSeed then
            gold, goldStream, nextGoldRng = GoldRewards.prepare(run.encounterTier, run, {allEscaped=allEscaped})
        else
            -- Historical explicit-ID fixtures retain their fixed reward contract;
            -- only the actual source-room path claims the source gold RNG boundary.
            gold = run.data.rules.rewards[run.encounterTier .. "Gold"]
            assert(type(gold) == "number", "unknown encounter reward tier")
            if allEscaped then gold = 0 end
        end
        gold=GoldRewards.offerAmount(gold,run)
        return gold, goldStream, nextGoldRng
    end

    local function offerCombatRewards(run, allEscaped, gold, goldStream, relicReward, emerald)
        local stolen = run.combat.stolenGoldReward or 0
        -- Source room rewards already contain GOLD, stolen GOLD, elite RELICs and
        -- the independent key here. Card rewards are added after the potion roll.
        local rewardCount=(goldStream and 1 or 0)+(stolen>0 and 1 or 0)
            +(relicReward and #relicReward or 0)+(emerald and 1 or 0)
        local potion,potionRng,potionModifier
        if run.combat.roomSeed then
            potion,potionRng,potionModifier=PotionRewards.prepare(run,rewardCount,{allEscaped=allEscaped})
            PotionRewards.commit(run,potionRng,potionModifier)
        end
        local choices,nextCardRng,offset,cardUpgrades=CardPool.prepareRewards(run)
        run.cardRng,run.cardRarityOffset=nextCardRng,offset
        if not run.combat.roomSeed then
            potion,potionRng,potionModifier=PotionRewards.prepare(run,2,{allEscaped=allEscaped})
            PotionRewards.commit(run,potionRng,potionModifier)
        end
        run.rewards, run.phase = { cards = choices, cardUpgrades = cardUpgrades, gold = gold, goldClaimed = gold == 0, potion = potion,
            cardResolved = false, manualContinue = true }, "reward"
        if relicReward then run.rewards.relics=relicReward end
        if emerald then run.rewards.emeraldKey=emerald end
        RelicHooks.previewCardReward(run,run.rewards,true)
        if stolen > 0 then
            run.rewards.stolenGold = {type="STOLEN_GOLD", amount=stolen, claimed=false}
            run.rewards.cardResolved, run.rewards.manualContinue = false, true
        end
    end

    local function publishBattleResult(run, result)
        if run.combat.miscRng then
            EventRandom.snapshot(run.miscRng) -- An invalid permanent owner must still refuse.
            run.miscRng=EventRandom.cloneState(run.combat.miscRng)
        end
        if run.combat.cardRng then run.cardRng=EventRandom.cloneState(run.combat.cardRng)end
        run.hp, run.seed, run.gold = run.combat.player.hp, run.combat.seed, run.combat.player.gold
        run.maxHp=run.combat.player.maxHp
        run.relicCounters=Combat.copy(run.combat.relicCounters or {})
        local allEscaped = Combat.allEnemiesEscaped(run.combat)
        run.lastResult = { outcome = result, turn = run.combat.turn, encounterId = run.encounterId, allEnemiesEscaped = allEscaped, mugged = run.combat.mugged }
        return allEscaped
    end

    local function finishCombat(run)
        if run.phase ~= "combat" then return false, "not_in_combat" end
        local result = Combat.outcome(run.combat)
        if not result then return false, "battle_unfinished" end
        local allEscaped = publishBattleResult(run, result)
        if result == "defeat" then
            run.phase, run.rewards = "defeat", nil
            run.endingProceed=nil
            return true
        end
        -- Combat-end relics apply once, before the reward transaction is offered.
        combatEndHealing(run)
        if run.act==4 and run.encounterTier=='boss'then return finishHeart(run)end
        if run.eventCombat then
            local rewards,why=EventCombat.finish(run);if not rewards then return false,why end
            run.rewards,run.phase=rewards,'reward';run.victories=run.victories+1
            return true
        end
        local gold, goldStream, nextGoldRng = prepareGold(run, allEscaped)
        local relicReward
        if run.combat.roomSeed and run.encounterTier=='elite' then
            local prepared,why=RelicRewards.elite(run);if not prepared then return false,why end
            relicReward=prepared.items;run.relicPool=prepared.relicPool
        end
        local emerald,emeraldReason=EmeraldRewards.offer(run,relicReward and #relicReward or 0)
        if emeraldReason then return false,emeraldReason end
        offerCombatRewards(run, allEscaped, gold, goldStream, relicReward, emerald)
        run.victories = run.victories + 1
        if goldStream then run[goldStream] = nextGoldRng end
        return true
    end

    local function applyCardChanges(battle, card)
        local changed=(battle.masterDeckChanges or {})[card.uid]
        if changed then
            assert(changed.uid==card.uid and changed.cardId==card.cardId,'invalid permanent card owner')
            local result=Combat.copy(changed)
            for key in pairs(card)do card[key]=nil end
            for key,value in pairs(result)do card[key]=value end
        end
        local growth=(battle.ritualDaggerGrowth or {})[card.uid]
        if card.cardId=='ritual_dagger' and growth then card.misc=(card.misc or 15)+growth end
        if changed or growth then
            for i,snapshot in ipairs(battle.masterDeck or {})do
                if snapshot.uid==card.uid then battle.masterDeck[i]=Combat.copy(card);break end
            end
        end
    end

    local function applyPermanentChanges(run)
        local battle=run.combat
        for _,card in ipairs(run.deck)do
            applyCardChanges(battle,card)
        end
        require('abyss_writhing_mass').syncMaster(run)
        battle.ritualDaggerGrowth,battle.masterDeckChanges=nil,nil
        if run.phase=='combat' and battle.miscRng then run.miscRng=EventRandom.cloneState(battle.miscRng)end
        if run.phase=='combat' and battle.cardRng then run.cardRng=EventRandom.cloneState(battle.cardRng)end
    end
    local function finishCombatTransaction(run)
        if run.phase ~= "combat" then return false, "not_in_combat" end
        if not run.combat.roomSeed then
            local ok,reason=finishCombat(run);if ok then applyPermanentChanges(run)end;return ok,reason
        end
        -- A formal reward is one transaction: invalid source RNG or a later potion
        -- failure must not publish healed HP, card/treasure progress or lastResult.
        local staged = {}
        for key, value in pairs(run) do staged[key] = value end
        staged.shopRng = run.shopRng and Combat.copy(run.shopRng)
        local ok, reason = finishCombat(staged)
        if not ok then return false, reason end
        applyPermanentChanges(staged)
        for key in pairs(run) do run[key] = staged[key] end
        for key, value in pairs(staged) do run[key] = value end
        return true
    end

    function Run.finishCombat(run)
        if run.phase~='combat'then return false,'not_in_combat'end
        local restore=require('abyss_snapshot').capture(run)
        local called,ok,reason=pcall(finishCombatTransaction,run)
        if not called then restore();error(ok,0)end
        if not ok then restore()end
        return ok,reason
    end

    function Run.proceedEnding(run,expectedOwner)
        -- Identity is checked before transaction cloning, and before metatables can
        -- be erased by copy. A stale UI callback cannot acquire a replacement owner.
        local owner=run.endingProceed
        if expectedOwner==nil or not rawequal(expectedOwner,owner)or type(owner)~='table'or getmetatable(owner)~=nil then
            return false,'ending_proceed_owner_mismatch'
        end
        local fields={version=true,runSeed=true,act=true,floor=true,encounterId=true,combatGeneration=true}
        for key in pairs(owner)do if not fields[key]then return false,'ending_proceed_owner_mismatch'end end
        if run.phase~='ending_proceed'or not heartOwner(run)then return false,'ending_proceed_unavailable'end
        return Run.transaction(run,function(staged)
            local pending=staged.endingProceed
            if staged.phase~='ending_proceed'or not heartOwner(staged)
                or pending.version~=1 or pending.runSeed~=staged.runSeed or pending.act~=4 or pending.floor~=55
                or pending.encounterId~=staged.encounterId or pending.combatGeneration~=staged.combatGeneration
                or staged.rewards~=nil or staged.pendingCombatRewards~=nil
                or not staged.lastResult or staged.lastResult.outcome~='victory'
                or staged.lastResult.encounterId~=staged.encounterId then return false,'ending_proceed_unavailable'end
            staged.phase,staged.ending,staged.endingProceed='victory','true_victory',nil
            staged.nodeFlow.complete,staged.nodeFlow.result=true,'true_victory'
            return true,'true_victory'
        end)
    end

    return {applyPermanentChanges=applyPermanentChanges, combatEndHealing=combatEndHealing}

end

return M
