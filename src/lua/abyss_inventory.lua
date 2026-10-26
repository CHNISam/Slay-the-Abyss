-- Inventory effects use combat actors and data, with fixed potion/relic damage and block.
-- Callers execute on an uncommitted battle: a refusal may discard this candidate safely.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local RelicHooks = require('abyss_relic_hooks')
local M = {}
local supported = { classPotion=true, silentGhost=true, silentShivs=true, generatePotions=true, discover=true, channelOrb=true, makeMiracle=true, damage = true, damageAll = true, upgradeHand = true, healPercent = true, increaseMaxHp = true, block = true, draw = true, energy = true,
    exhaustMany=true,discardRedraw=true,discardToHand=true,randomizeHandCost=true,escape=true,playTopCards=true,
    gainStatus = true, applyStatus = true, gainTemporaryStrength = true, gainTemporaryDexterity = true }
local maximum = 2147483647
local bossRelics = { black_blood = true, slavers_collar = true, sozu = true }

function M.bossEligible(relic, owned)
    if relic.rarity ~= "boss" or not bossRelics[relic.id] then return false end
    local prerequisite = relic.replaces == nil
    for _, id in ipairs(owned) do
        if id == relic.id then return false end
        if id == relic.replaces then prerequisite = true end
    end
    return prerequisite
end

-- These two relics modify the prepared energy master, not a queued opening
-- energy action (Lantern). Give Combat its own adjusted rules copy per battle.
function M.energyBonus(definitions, owned, tier)
    local bonus = 0
    for _, id in ipairs(owned) do
        local relic
        for _, entry in ipairs(definitions) do if entry.id == id then relic = entry; break end end
        if not relic then return nil, "unknown_relic" end
        if relic.trigger == "turn_start" then
            if id ~= "sozu" and id ~= "slavers_collar" then return nil, "unsupported_turn_relic:" .. id end
            local eligible = not relic.encounterTiers
            for _, allowed in ipairs(relic.encounterTiers or {}) do if tier == allowed then eligible = true end end
            if eligible then
                for _, effect in ipairs(relic.effects) do
                    if effect.op ~= "energy" or type(effect.value) ~= "number" or effect.value < 0
                        or effect.value % 1 ~= 0 or bonus + 0.0 + effect.value > maximum then
                        return nil, "invalid_relic_energy"
                    end
                    bonus = bonus + effect.value
                end
            end
        end
    end
    return bonus
end

-- Source-defined hook/queue positions, not effect values. New relics need their
-- own ordering evidence before entering this supported opening set.
local openingPosition = { ring_of_the_snake="battle_bottom", cracked_core="pre_battle", pure_water="pre_draw", lantern = "turn_top", vajra = "battle_top",
    oddly_smooth_stone = "battle_top", bronze_scales = "battle_top",
    anchor = "battle_bottom", bag_of_preparation = "battle_bottom" }

function M.opening(definitions, owned, persistentCounters, context)
    local turnTop, battleTop, bottom, preBattle, preDraw = {}, {}, {}, {}, {}
    for _, id in ipairs(owned) do
        local relic
        for _, entry in ipairs(definitions) do if entry.id == id then relic = entry; break end end
        if not relic then return nil, "unknown_relic" end
        if id=='blood_vial' or id=='akabeko' then
            table.insert(battleTop,1,{{op='relic_hook',id=id}})
        elseif id=='bag_of_marbles' or id=='pen_nib' or id=='red_skull' or id=='red_mask' then
            bottom[#bottom+1]={{op='relic_hook',id=id}}
        elseif relic.trigger == "combat_start" then
            local position = openingPosition[id]
            if not position then return nil, "unsupported_opening_relic:" .. tostring(id) end
            if position == "pre_battle" then preBattle[#preBattle + 1] = relic.effects
            elseif position == "pre_draw" then preDraw[#preDraw + 1] = relic.effects
            elseif position == "turn_top" then table.insert(turnTop, 1, relic.effects)
            elseif position == "battle_top" then table.insert(battleTop, 1, relic.effects)
            else bottom[#bottom + 1] = relic.effects end
        end
    end
    -- Turn-start hooks are dispatched after battle-start hooks, so their TOP
    -- actions execute first. BOTTOM actions retain the held-list order.
    for _, effects in ipairs(battleTop) do turnTop[#turnTop + 1] = effects end
    turnTop.relics=owned
    turnTop.relicCounters=persistentCounters
    turnTop.relicContext=context
    local opening = {beforeDraw=turnTop, afterDraw=bottom}
    if #preBattle > 0 then opening.preBattle = preBattle end
    if #preDraw > 0 then opening.preDraw = preDraw end
    return opening
end

function M.applyOpening(state, groups)
    if groups.relics then
        RelicHooks.bindBattle(state,groups.relics,groups.relicCounters)
        RelicHooks.preBattle(state,groups.relicContext)
    end
    for _, effects in ipairs(groups) do
        if effects[1] and effects[1].op=='relic_hook' then RelicHooks.battleStart(state,effects[1].id)
        else
            local ok, reason = M.apply(state, effects)
            if not ok then return false, reason end
        end
    end
    return true
end

local function integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
        and value >= 0 and value <= maximum
end

function M.needTarget(effects)
    for _, effect in ipairs(effects) do
        if effect.op == "damage" or effect.op == "applyStatus" then return true end
    end
    return false
end

local function validate(state, effects, targetIndex)
    if M.needTarget(effects) then
        if not integer(targetIndex) or not Actors.isActive(state.enemies[targetIndex]) then
            return false, "invalid_target"
        end
    end
    for _, effect in ipairs(effects) do
        if not supported[effect.op] then return false, "unsupported_effect:" .. tostring(effect.op) end
        if effect.op=='classPotion'and not require('abyss_class_potions').validate(effect)then return false,'invalid_class_potion'end
        if effect.op == 'upgradeHand' then
            if effect.all ~= true then return false, 'invalid_potion_upgrade' end
        elseif not integer(effect.value) then return false, "invalid_effect_value" end
        if effect.op == "gainTemporaryStrength" or effect.op == "gainTemporaryDexterity" then
            local expected = effect.op == "gainTemporaryStrength" and "strength" or "dexterity"
            if effect.status ~= expected then return false, "invalid_temporary_status" end
            if effect.value == 0 then return false, "invalid_effect_value" end
        elseif effect.op == "channelOrb" and (not state.orbs or effect.orb ~= "lightning" or effect.value ~= 1) then
            return false, "unsupported_starting_orb"
        end
        if effect.op == "makeMiracle" then
            if effect.value ~= 1 or not state.catalog.cards.miracle
                or not integer(state.nextUid) or state.nextUid < 1 or state.nextUid >= maximum
                or (state.player.statuses.master_reality or 0) ~= 0 then return false, "unsupported_starting_card" end
        end
        if effect.op == "gainStatus" or effect.op == "applyStatus" then
            local actor = effect.op == "gainStatus" and state.player or state.enemies[targetIndex]
            if not actor.statusDefinitions[effect.status] then return false, "unknown_status:" .. tostring(effect.status) end
        end
    end
    return true
end

function M.apply(state, effects, targetIndex, run, deferDrain)
    local ok, reason = validate(state, effects, targetIndex)
    if not ok then return false, reason end
    local target = state.enemies[targetIndex]
    for _, effect in ipairs(effects) do
        local op, value = effect.op, effect.value
        if op=='classPotion'then require('abyss_card_actions').enqueue(state,effect)
        elseif op=='silentShivs'then require('abyss_card_actions').enqueue(state,{op='silentFinal',kind='potionShivs',value=value})
        elseif op=='silentGhost'then require('abyss_card_actions').enqueue(state,{op='gainStatus',status='intangible',value=value})
        elseif op=='generatePotions' then
            local ids,rng=require('abyss_potion_generation').prepare(run,true)
            state.potionRandomRng=rng;state.potionRng=require('abyss_sts_random').cloneState(rng)
            state.generatedPotionOffers={}
            for _,id in ipairs(ids)do
                require('abyss_card_actions').enqueue(state,{op='obtainPotion',id=id,
                    unavailable=not require('abyss_potion_generation').available(run,id)})
            end
        elseif op == "channelOrb" then
            require("abyss_orbs").channel(state, effect.orb, Combat)
        elseif op == "makeMiracle" then
            local pile = #state.hand < state.rules.player.maxHand and state.hand or state.discard
            pile[#pile + 1] = {uid=state.nextUid,cardId="miracle",upgraded=false}
            state.nextUid = state.nextUid + 1
            require("abyss_events").emit(state,"cards_created",{cardId="miracle",amount=1})
        elseif op == "damage" then
            Combat.damage(state, state.player, target, value, true)
        elseif op == "damageAll" then
            -- Explosive Potion: pure matrix, null owner, NORMAL damage.
            -- A missing owner prevents Curl Up, Angry, Plated Armor and Thorns
            -- callbacks, rather than misclassifying the hit as Fire/THORNS.
            local reactions = {}
            for _, enemy in ipairs(state.enemies) do
                if Actors.isActive(enemy) then Combat.damage(state, nil, enemy, value, false, reactions, value) end
            end
            Actors.resolveDamageReactions(state, reactions)
        elseif op == "block" then
            if state.player.block + 0.0 + value > maximum then return false, "effect_overflow" end
            Combat.block(state, state.player, value, true)
        elseif op == 'healPercent' then
            -- BloodPotion.use adds the raw binary32 percentage to BOT.
            -- Relics and the missing-HP cap apply when HealAction runs.
            local calculation={hp=0,maxHp=state.player.maxHp}
            local called,healing=require('abyss_potion_health').apply(calculation,op,value,nil,true)
            if not called then return false,healing end
            require('abyss_card_actions').enqueue(state,{op='heal',value=healing},state.player)
        elseif op == 'increaseMaxHp' then
            -- FruitJuice.use changes max HP and heals immediately, before the
            -- post-use relic actions. This heal can end Red Skull's bloodied
            -- state just like a queued Blood Potion heal.
            local beforeHp=state.player.hp
            local called, amount = require('abyss_potion_health').apply(state.player,op,value,run and run.relics,true)
            if not called then return false, amount end
            if state.originalV4 then
                state.player.hp=beforeHp
                local actual=require('abyss_original_v4_health').heal(state,state.player,amount,nil,'increaseMaxHp')
                if actual==0 then RelicHooks.hpChanged(state,state.player,beforeHp)end
            else
            require('abyss_events').emit(state,'heal',{target=state.player.id,amount=amount})
            RelicHooks.hpChanged(state,state.player,beforeHp)
            end
        elseif op == 'discover' or op == 'draw' or op == 'randomizeHandCost' then
            -- Potion.use queues every initial action before any action runs.
            -- Draw hooks append behind already queued actions such as Snecko
            -- costs and the caller's post-use relic heal.
            local Actions=require('abyss_card_actions')
            Actions.enqueue(state,effect)
        elseif op=='escape' then state.smoked=true
        elseif op=='playTopCards' then
            local Actions=require('abyss_card_actions')
            local pool={}
            for i,enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then pool[#pool+1]=i end end
            -- Potion.use constructs all PlayTopCardActions and their targets
            -- before any action runs, even if a later action has no card.
            for _=1,value do
                local chosenTarget=#pool>0 and pool[Combat.cardRandom(state,#pool)] or nil
                Actions.enqueue(state,{op='playTop',targetIndex=chosenTarget,exhaustCards=false,append=true})
            end
        elseif op == 'upgradeHand' then
            for _, card in ipairs(state.hand) do
                if Combat.canUpgrade(state, card) then Combat.upgrade(state, card) end
            end
        elseif op=='exhaustMany' or op=='discardRedraw' or op=='discardToHand' then
            local Actions=require('abyss_card_actions')
            Actions.enqueue(state,effect)
        elseif op == "gainTemporaryStrength" then Actors.addTemporaryStrength(state.player, value, state)
        elseif op == "gainTemporaryDexterity" then Actors.addTemporaryDexterity(state.player, value, state)
        elseif op == "energy" then
            if state.energy + 0.0 + value > maximum then return false, "effect_overflow" end
            state.energy = state.energy + 0.0 + value
        elseif op == "gainStatus" or op == "applyStatus" then
            local actor = op == "gainStatus" and state.player or target
            if (actor.statuses[effect.status] or 0) + 0.0 + value > maximum
                and not Actors.artifactBlocksPower(actor, effect.status, value) then return false, "effect_overflow" end
            -- Artifact blocking is a resolved application, not a rejected use.
            Actors.applyPower(state, actor, effect.status, value, state.player)
        end
    end
    if not deferDrain then require('abyss_card_actions').drain(Combat,state) end
    return true
end

return M
