-- Staged potion eligibility and effects. Run alone commits the resulting state.
local Combat=require('abyss_combat')
local Inventory=require('abyss_inventory')
local EventRandom=require('abyss_sts_random')
local RelicHooks=require('abyss_relic_hooks')
local M={}

function M.eventRestricted(run)
    local event=run.nodeFlow and run.nodeFlow.event
    local legacy=not run.nodeFlow and run.node
    return event and (event.id=='we_meet_again' or event.id=='WeMeetAgain' or event.originalId=='WeMeetAgain')
        or legacy and (legacy.eventId=='WeMeetAgain' or legacy.sourceEventId=='WeMeetAgain') or false
end

local function combatEligibility(run)
    if not run.combat or run.combat.phase~='player' then return 'not_player_turn' end
    if run.combat.pendingChoice or run.combat.cardActions or run.combat.pendingPotionChoice then return 'card_choice_pending' end
    if run.combat.pendingDiscard then return 'unsupported_potion_during_discard' end
    if run.combat.pendingScry or run.combat.pendingPlay then return 'unsupported_potion_during_selection' end
end

local outsidePotions={blood_potion=true,fruit_juice=true,entropic_brew=true}
local function eligibility(run,slot)
    if M.eventRestricted(run)then return 'potion_event_restricted' end
    if run.phase~='combat' and not outsidePotions[run.potions[slot]] then return 'not_in_combat' end
    if run.phase=='combat' then return combatEligibility(run)end
end

local function definition(run,slot,capacity)
    if type(slot)~='number' or slot%1~=0 or slot<1 or slot>capacity(run) then return nil,'invalid_potion_slot' end
    local id=run.potions[slot]
    if not id then return nil,'empty_potion_slot' end
    for _,potion in ipairs(run.data.potions.potions)do
        if potion.id==id then return potion end
    end
    return nil,'unknown_potion'
end

local function potionEffects(run,potion)
    local effects=Combat.copy(potion.effects)
    for _,effect in ipairs(effects)do effect.value=Inventory.potionValue(run,effect) end
    return effects
end

local function smokeRestriction(run,id)
    if id~='smoke_bomb' or not run.combat then return end
    for _,enemy in ipairs(run.combat.enemies)do
        local def=run.combat.catalog.enemies[enemy.definitionId]
        if def and def.tier=='boss' or (enemy.statuses.back_attack or 0)>0 then return 'smoke_not_allowed' end
    end
end

local function outsideGeneration(run,slot,candidate,capacity)
    local Generation=require('abyss_potion_generation')
    local called,ids,rng=pcall(Generation.prepare,run,false)
    if not called then return false,'potion_effect_failed' end
    candidate.potionInventory=Combat.copy(run.potions);candidate.potionInventory[slot]=nil
    candidate.potionRandomRng=rng
    candidate.generatedPotionOffers={}
    for _,generated in ipairs(ids)do
        local available=Generation.available(run,generated)
        candidate.generatedPotionOffers[#candidate.generatedPotionOffers+1]={id=generated,unavailable=not available}
        if available then Generation.obtain(candidate.potionInventory,capacity(run),generated,false)end
    end
    return true
end

local function outsideHealth(run,candidate,effects)
    for _,effect in ipairs(effects)do
        local ok,reason=require('abyss_potion_health').apply(candidate,effect.op,effect.value,run.relics,false)
        if not ok then return false,reason end
    end
    return true
end

local function outsideCandidate(run,slot,potion,effects,capacity)
    if not outsidePotions[potion.id] or (run.phase~='map' and run.phase~='node' and run.phase~='reward')then return nil,'not_in_combat' end
    local candidate={hp=run.hp,maxHp=run.maxHp,outside=true}
    local ok,reason
    if potion.id=='entropic_brew' then ok,reason=outsideGeneration(run,slot,candidate,capacity)
    else ok,reason=outsideHealth(run,candidate,effects)end
    if not ok then return nil,reason end
    candidate.relics=run.relics
    RelicHooks.onUsePotion(candidate)
    return candidate
end

local function combatCandidate(run,slot,targetIndex,potion,effects,afterPotionActions)
    local candidate=Combat.copy(run.combat)
    candidate.potionRng=run.shopRng and EventRandom.cloneState(run.shopRng.potion)or EventRandom.fromSeed(run.runSeed)
    candidate.potionInventory=Combat.copy(run.potions)
    local called,ok,reason=pcall(function()
        if potion.targetPolicy=='enemy_one'then Combat.faceTarget(candidate,candidate.enemies[targetIndex])end
        local applied,why=Inventory.apply(candidate,effects,targetIndex,run,true)
        if not applied then return false,why end
        -- Preserve Potion.use, hooks, slot release, caller actions, then one drain.
        RelicHooks.onUsePotion(run,candidate)
        candidate.potionInventory[slot]=nil
        if afterPotionActions then afterPotionActions(candidate)end
        require('abyss_card_actions').drain(Combat,candidate)
        return true
    end)
    if not called then return nil,'potion_effect_failed' end
    if not ok then return nil,reason end
    return candidate
end

function M.prepare(run,slot,targetIndex,afterPotionActions,capacity)
    local reason=eligibility(run,slot)
    if reason then return nil,reason end
    local potion
    potion,reason=definition(run,slot,capacity)
    if not potion then return nil,reason end
    if potion.id=='fairy_in_a_bottle' then return nil,'automatic_potion' end
    local effects=potionEffects(run,potion)
    reason=smokeRestriction(run,potion.id)
    if reason then return nil,reason end
    if run.phase~='combat' then return outsideCandidate(run,slot,potion,effects,capacity)end
    return combatCandidate(run,slot,targetIndex,potion,effects,afterPotionActions)
end
return M
