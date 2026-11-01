-- Transition responsibility for the same-run API.
local EventRandom = require("abyss_sts_random")
local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local EncounterQueue = require("abyss_encounter_queue")
local EmeraldRewards=require('abyss_emerald_rewards')
local Acts = require('abyss_acts')

local M = {}

function M.install(Run)
    local function hasEndingKeys(staged)
        return staged.endingUnlocked==true and type(staged.keys)=='table'
            and staged.keys.ruby==true and staged.keys.emerald==true and staged.keys.sapphire==true
    end

    local function validateTransitionBoundary(staged, act)
        local chapter=Acts.get(act)
        if staged.phase~='act_transition' or staged.pendingAct~=act+1
            or staged.floor~=chapter.last or not staged.nodeFlow or not staged.nodeFlow.complete
            or staged.nodeFlow.floor~=chapter.last then return false,'act_transition_unavailable' end
        return true
    end

    local function validateTransitionRoom(staged,act)
        if act<=2 and (staged.nodeFlow.roomKind~='boss_treasure' or staged.nodeFlow.result~='boss_treasure_complete') then
            return false,'boss_treasure_pending'
        end
        if act==3 and (staged.nodeFlow.roomKind~='ending' or staged.nodeFlow.result~='ending_door') then
            return false,'ending_door_required'
        end
        if act==3 and not hasEndingKeys(staged) then
            return false,'ending_keys_required'
        end
        return true
    end

    local function validateTransition(staged)
        if staged.campaign~=true then return false,'campaign_unavailable' end
        local act=staged.act
        if Acts.isCompetition(staged) and act~=1 then return false,'competition_act_limit' end
        if act~=1 and act~=2 and act~=3 then return false,'invalid_act_transition' end
        if type(staged.encounters)~='table' or (staged.encounters.act or 1)~=act
            or staged.encounters.rawSeed~=staged.runSeed then return false,'encounter_act_mismatch' end
        local valid,why=validateTransitionBoundary(staged,act)
        if not valid then return false,why end
        return validateTransitionRoom(staged,act)
    end

    function Run.advanceAct(run)
        return Run.transaction(run,function(staged)
            local valid,why=validateTransition(staged)
            if not valid then return false,why end
            local act=staged.act
            local counter=EventRandom.snapshot(staged.cardRng).counter
            local target=counter>0 and counter<250 and 250 or counter>250 and counter<500 and 500
                or counter>500 and counter<750 and 750 or counter
            for _=counter+1,target do EventRandom.randomBoolean(staged.cardRng) end
            local nextAct=act+1
            local queue=EncounterQueue.new(staged.runSeed,nextAct,staged.encounters.monsterRng)
            staged.bossInitialization,staged.encounters=EncounterQueue.initializeBoss(queue,staged.bossHistory)
            EventPool.nextAct(staged.unknown.pools,nextAct)
            local tinyChest=staged.unknown.chances.tinyChestCount
            staged.unknown.chances=Unknown.newPc()
            staged.unknown.chances.tinyChestCount=tinyChest
            Run.heal(staged,staged.maxHp)
            staged.act,staged.phase,staged.floor=nextAct,'map',Acts.get(nextAct).first-1
            staged.nodeFlow,staged.pendingAct,staged.pendingCombatRewards,staged.rewards=nil,nil,nil,nil
            staged.combat,staged.lastResult=nil,nil
            staged.emeraldCombat=nil
            local context,contextReason=EmeraldRewards.freezeMapContext(staged)
            if not context then return false,contextReason end
            staged.potionChanceModifier=0
            return true
        end)
    end

end

return M
