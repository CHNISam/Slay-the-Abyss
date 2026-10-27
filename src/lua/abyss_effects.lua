-- Effect interpreter for the core-supported operations.
local M = {}
local Actors = require("abyss_actor")
local CardActions = require("abyss_card_actions")
local extensionOps={defectFinal=true,gainMantra=true,applyMantra=true,removeMantra=true,gainDevotion=true,gainExhaustPower=true,gainOrbPower=true,
    gainEnergyIfDiscard=true,calculatedGamble=true}
for op in pairs(require('abyss_build_actions').ops) do extensionOps[op]=true end
for op in pairs(require('abyss_flow_actions').ops) do extensionOps[op]=true end
for op in pairs(require('abyss_watcher_final_cards').ops) do extensionOps[op]=true end

local coreOps = { timeEater=true, awakenedVoid=true, handChoice=true, whirlwind=true, reaperDamage=true, scry=true, multiplyPoison=true, bouncingPoison=true, gainOrbSlots=true, loseOrbSlots=true, applyBias=true, gainFocus=true, gainStancePower=true, innerPeace=true, requestDiscard=true, channelOrb=true, dualcastOrb=true, darkImpulseOrb=true, changeStance=true, generateShivs = true, damage = true, damageAll = true, block = true, draw = true, energy = true,
    applyStatus = true, applyStatusAll = true, gainStatus = true, doubleBlock = true, noDrawThisTurn = true,
    loseHp = true, gainTemporaryStrength = true, damageEqualToBlock = true, addCardToDiscard = true,
    increaseDamageThisCombat = true, makeTempCardInDiscard = true }

-- Source-verified queued actions removed by clearPostCombatActions. Its
-- exceptions are specific GainBlock/Heal/UseCard actions and DAMAGE actions,
-- not every action with BLOCK type (DoubleYourBlock is removed).
-- The conditional ABI contains only Dropkick's queued energy/draw tail.
local clearedAfterDamage = { timeEater=true, draw=true, energy=true, applyStatus=true, applyStatusAll=true,
    gainStatus=true, doubleBlock=true, noDrawThisTurn=true, gainTemporaryStrength=true,
    addCardToDiscard=true, increaseDamageThisCombat=true, makeTempCardInDiscard=true, conditional=true }
local clearsOnFinalDamage = { damage=true, damageAll=true, damageEqualToBlock=true, loseHp=true }

-- Only the opt-in Weak/Vulnerable pair is target-first. Discover markers in
-- the entire input before any effect, including holes and unreachable branches.
-- Unmarked inputs deliberately keep their old validation/error timing.
coreOps.reptomancerSummon=true
coreOps.daggerSacrifice=true
coreOps.enemyHealAll=true
coreOps.enemyStrengthAll=true
coreOps.enemyCleanse=true
coreOps.enemyVampireDamage=true
coreOps.enemyRally=true
coreOps.enemyEncourage=true
coreOps.enemyTorchSpawn=true
coreOps.enemyTorchRevive=true
coreOps.enemyBronzeSpawn=true
coreOps.enemyStasis=true
coreOps.enemyBurnBoth=true
clearedAfterDamage.enemyBurnBoth=true
coreOps.enemyDazedDraw=true
clearedAfterDamage.enemyDazedDraw=true
clearedAfterDamage.awakenedVoid=true

local function targetGroup(effects)
    local found, misplaced, cyclic = false, false, false
    local seen, active = {}, {}
    local pending = {{value=effects}}
    while #pending > 0 do
        local visit = table.remove(pending)
        local value = visit.value
        if type(value) == "table" then
            if visit.leaving then active[value] = nil
            else
                if value.targetGroup ~= nil then
                    found = true
                    if not visit.topMember then misplaced = true end
                end
                if active[value] then cyclic = true
                elseif not seen[value] then
                    seen[value], active[value] = true, true
                    pending[#pending + 1] = {value=value, leaving=true}
                    for key, child in pairs(value) do
                        pending[#pending + 1] = {value=key}
                        pending[#pending + 1] = {value=child, topMember=value == effects and type(key) == "number"}
                    end
                end
            end
        end
    end
    if not found then return nil end
    if misplaced or cyclic then return nil, "invalid_target_group" end
    local count = 0
    for key in pairs(effects) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return nil, "invalid_target_group" end
        count = count + 1
    end
    local members = {}
    local allowed = { op=true, status=true, value=true, targetGroup=true }
    for i = 1, count do
        local effect = effects[i]
        if type(effect) ~= "table" then return nil, "invalid_target_group" end
        if effect.targetGroup ~= nil then
            if effect.targetGroup ~= "weak_then_vulnerable" or effect.op ~= "applyStatusAll"
                or type(effect.value) ~= "number" or effect.value < 1 or effect.value > 2147483647
                or effect.value % 1 ~= 0 then return nil, "invalid_target_group" end
            for key in pairs(effect) do if not allowed[key] then return nil, "invalid_target_group" end end
            members[#members + 1] = i
        end
    end
    if #members ~= 2 or members[2] ~= members[1] + 1 then return nil, "invalid_target_group" end
    local first, second = effects[members[1]], effects[members[2]]
    if first.status ~= "weak" or second.status ~= "vulnerable" or first.value ~= second.value then
        return nil, "invalid_target_group"
    end
    return members[1]
end

function M.requiresQueue(effects)
    for _,effect in ipairs(effects) do if type(effect)=='table' and effect.op=='defectFinal'then return true end
        if type(effect)=='table' and require('abyss_watcher_final_cards').ops[effect.op] then return true end
        if type(effect)=='table' and effect.op=='requestDiscard' then return true end
        if type(effect)=='table' and effect.op=='conditional' and effect['if']=='target_poison' then return true end
        if type(effect)=='table' and require('abyss_build_actions').ops[effect.op] then return true end
        if type(effect)=='table' and require('abyss_flow_actions').ops[effect.op] then return true end
        if type(effect)=="table" and (effect.op=="gainMantra" or effect.op=="applyMantra" or effect.op=="removeMantra"
            or effect.op=="gainExhaustPower" or effect.op=="calculatedGamble") then return true end
    end
    for _, effect in ipairs(effects) do if type(effect) == "table" and (effect.op == "scry" or effect.op == "handChoice" or effect.op == "whirlwind" or effect.op == "reaperDamage") then return true end end
    return false
end
function M.allowedAfterVictory(effect)
    if require('abyss_time_eater').retained(effect)then return true end
    if effect.op=='daggerSacrifice'then return true end
    if effect.op=='capturedSharpHide' then return true end
    if effect.op=='orbStart' then return effect.action.kind=='frost' end
    if effect.op=='engineEvokeRounds' or effect.op=='evokeOrb' or effect.op=='evokeWithoutRemovingOrb' then return true end
    return effect.op=='onUseReactions' or effect.op=='cardTriggerDamageAll' or effect.op=='xBlockRounds'
        or effect.op == "heal" or effect.op == "whirlwindRounds" or effect.op == "resolveCurlUp" or effect.op == "damageAllSnapshot" or effect.op == "block" or effect.op == "damage" or effect.op == "damageAll"
        or effect.op == "damageEqualToBlock" or effect.op == "loseHp"
end

local function supported(effects, branch)
    if type(effects) ~= "table" then return false, "invalid_effect" end
    -- Both levels must be nonempty dense arrays: ipairs alone would silently
    -- accept objects, empty branches or unknown operations after a hole.
    local count = 0
    for key in pairs(effects) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return false, "invalid_effect" end
        count = count + 1
    end
    if count == 0 then return false, "invalid_effect" end
    for i = 1, count do if effects[i] == nil then return false, "invalid_effect" end end
    local hasScry = false
    for _,effect in ipairs(effects) do if type(effect)=="table" and effect.op=="scry" then hasScry=true end end
    if hasScry then
        local allowed = {scry=true,damage=true,block=true,draw=true}
        for _, effect in ipairs(effects) do
            if type(effect) ~= "table" or not allowed[effect.op] then return false, "unsupported_scry_sequence" end
        end
    end
    local targetChecked = false
    for effectIndex, effect in ipairs(effects) do
        if type(effect) ~= "table" then return false, "invalid_effect" end
        local op = effect.op
        if type(op) ~= "string" then return false, "invalid_effect" end; if op=='defectFinal' and not require('abyss_defect_final_cards').supports(effect)then return false,'invalid_defect_final' end
        if op == "conditional" then
            -- Combat preflights top-level damage targets; never enable a
            -- conditional-only card or recursively hidden target requirement.
            if branch or not targetChecked or (effect["if"] ~= "target_vulnerable" and effect['if']~='target_poison')
                or effect["else"] ~= nil then return false, "conditional" end
            local ok, unsupported = supported(effect["then"], effect['if'])
            if not ok then return false, unsupported end
        elseif not (coreOps[op] or extensionOps[op] or CardActions.supports(op))
            or (branch and not (branch=='target_poison' and op=='damage') and op ~= "energy" and op ~= "draw") then
            return false, op or "invalid_effect"
        end
        if op == "requestDiscard" and (branch or effectIndex ~= count
            or type(effect.value) ~= "number" or effect.value % 1 ~= 0 or effect.value < 0 or effect.value > 10) then
            return false, "discard_must_end_card"
        end
        if op == "scry" and (type(effect.value) ~= "number" or effect.value % 1 ~= 0
            or effect.value < 0 or effect.value > 2147483647) then return false, "invalid_scry_amount" end
        if (op=="gainMantra" or op=="gainDevotion") and (type(effect.value)~="number" or effect.value%1~=0
            or effect.value<0 or effect.value>2147483647) then return false,"invalid_mantra_amount" end
        if effect.fixed ~= nil and (type(effect.fixed) ~= "boolean"
            or not (op=="block" or op=="damage" or op=="damageAll" or CardActions.supports(op))) then
            return false, "invalid_fixed_block"
        end
        if effect.target ~= nil and (op ~= "block" or effect.target ~= "random_ally" and effect.target~='automaton' and effect.target~='all_allies') then
            return false, "invalid_effect_target"
        end
        if op == "damage" then targetChecked = true end
    end
    return true
end

function M.supported(effects)
    local _, invalid = targetGroup(effects)
    if invalid then return false, invalid end
    return supported(effects, false)
end

local function targets(state, source)
    if source == state.player then return state.enemies end
    return { state.player }
end

local operationHandlers={}
for _,handlers in ipairs({require('abyss_effects_damage'),require('abyss_effects_cards'),
    require('abyss_effects_powers'),require('abyss_effects_enemy')})do
    for op,handler in pairs(handlers)do operationHandlers[op]=handler end
end

local function continueEffects(combat,state,source,queuedEnemyAction)
    -- Defeat/escape stops the owner. A dead enemy's captured payload can still
    -- resolve while the encounter continues, under its existing queue owner.
    if state.player.hp<=0 or source.escaped then return false end
    return not (source.hp<=0 and (not queuedEnemyAction or combat.outcome(state)))
end

local function applyOne(context)
    local effect,source,state=context.effect,context.source,context.state
    local op,value=effect.op,effect.value
    if source.hp<=0 and op~='makeTempCardInDiscard' and op~='enemyBurnBoth' and op~='awakenedVoid' then
        assert(coreOps[op] or op=='conditional','unsupported effect: '..tostring(op))
        if op=='applyStatus' and context.target==state.player and context.target.hp>0 then
            Actors.applyPower(state,context.target,effect.status,value,source)
        end
        return context.dealt
    end
    if op=='awakenedVoid'then
        -- This captured owner action precedes generic CardActions admission.
        operationHandlers.awakenedVoid(context)
        return context.dealt
    end
    if CardActions.supports(op) then
        CardActions.apply(context.combat,state,{effect=effect,source=source,target=context.target,instance=context.playedCard})
        return context.dealt
    end
    local handler=operationHandlers[op]
    assert(handler,'unsupported effect: '..tostring(op))
    return handler(context) or context.dealt
end

function M.apply(combat, state, effects, source, target, playedCard, queuedEnemyAction)
    local groupStart, invalid = targetGroup(effects)
    assert(not invalid and (not groupStart or (source == state.player and not queuedEnemyAction)),
        'invalid_target_group')
    local context={combat=combat,state=state,effects=effects,source=source,target=target,playedCard=playedCard,
        queuedEnemyAction=queuedEnemyAction,groupStart=groupStart,interpreter=M,targets=targets}
    local dealt=0
    local cleared=combat.outcome(state)=='victory'
    for index,effect in ipairs(effects)do
        if not continueEffects(combat,state,source,queuedEnemyAction)then break end
        local op=effect.op
        -- The paired target-first status action consumed its adjacent member.
        -- Victory clears only the mapped tail; retained actions keep ownership.
        local consumed=groupStart and index==groupStart+1
        local cancelled=cleared and (clearedAfterDamage[op] or op=='gainEnergyIfDiscard')
        if not consumed and not cancelled then
            context.index,context.effect,context.dealt=index,effect,dealt
            dealt=applyOne(context)
        end
        if clearsOnFinalDamage[op] and combat.outcome(state)=='victory'then cleared=true end
    end
    return dealt
end

return M
