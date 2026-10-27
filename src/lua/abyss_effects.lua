-- Effect interpreter for the core-supported operations.
local M = {}
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local CardActions = require("abyss_card_actions")
local EnemyRandom = require("abyss_enemy_random")
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

function M.apply(combat, state, effects, source, target, playedCard, queuedEnemyAction)
    local groupStart, invalid = targetGroup(effects)
    assert(not invalid and (not groupStart or (source == state.player and not queuedEnemyAction)),
        "invalid_target_group")
    local dealt = 0
    local cleared = combat.outcome(state)=="victory"
    for index, effect in ipairs(effects) do
        -- Defeat stops the action manager, unlike victory's selective clear.
        -- Keep current damage reactions, but never start another queued effect.
        if state.player.hp <= 0 or source.escaped then break end
        if source.hp <= 0 and (not queuedEnemyAction or combat.outcome(state)) then break end
        local op, value = effect.op, effect.value
        -- The adjacent second member is already consumed. Victory cancels only
        -- still-queued mapped actions; retained Block/HP-loss and card disposal
        -- keep their existing owners.
        local consumed = groupStart and index == groupStart + 1
        local cancelled = cleared and (clearedAfterDamage[op] or op=="gainEnergyIfDiscard")
        if not consumed and not cancelled then
        if source.hp <= 0 and op ~= "makeTempCardInDiscard" and op~='enemyBurnBoth' and op~='awakenedVoid' then
            assert(coreOps[op] or op == "conditional", "unsupported effect: " .. tostring(op))
            -- ApplyPower guards its target, not its dead source. Only the
            -- source-verified single-player queued status path is enabled.
            -- Later damage, dead-owner Block/buffs and unverified ops stay off.
            if op == "applyStatus" and target == state.player and target.hp > 0 then
                Actors.applyPower(state, target, effect.status, value, source)
            end
        elseif op=='awakenedVoid'then require('abyss_awakened_one').void(state,source)
        elseif CardActions.supports(op) then
            CardActions.apply(combat,state,{effect=effect,source=source,target=target,instance=playedCard})
        elseif op == "damage" or op == "damageAll" then
            local selected = op == "damageAll" and targets(state, source) or { target }
            for _ = 1, effect.times or 1 do
                local retaliation = op == "damageAll" and {} or nil
                for _, victim in ipairs(selected) do
                    -- Both callers capture NORMAL output; retain the older
                    -- per-target resolved ABI alongside class queue snapshots.
                    local snapshot=effect.normalAmount
                    if snapshot==nil and effect.normalAmounts then snapshot=effect.normalAmounts[victim.id] end
                    if snapshot==nil and effect.resolved then snapshot=effect.resolved[victim.id] end
                    dealt = dealt + combat.damage(state, source, victim, value, effect.fixed, retaliation,snapshot)
                end
                -- Angry, Thorns and death powers add reactions to the top:
                -- finish this area hit, then resolve in reverse target order.
                if retaliation then
                    Actors.resolveDamageReactions(state, retaliation, combat.retaliate)
                end
                if combat.outcome(state) then break end
            end
        elseif op=="gainEnergyIfDiscard" then
            assert(source==state.player,"player discard refund only")
            require("abyss_silent_discard_cards").gainEnergyIfDiscard(state,value)
        elseif op=="calculatedGamble" then
            error("Gamble requires the continuation queue")
        elseif op=="gainExhaustPower" then
            assert(source==state.player,"player exhaust power only")
            local id=effect.status
            if id=="corruption" then require("abyss_corruption").apply(state,value)
            else
                assert(id=="feel_no_pain" or id=="dark_embrace","unsupported exhaust power")
                assert(type(value)=="number" and value%1==0 and value>0 and value<=2147483647,"invalid exhaust power amount")
                if not combat.outcome(state) then
                    Actors.applyPower(state,state.player,id,value,state.player)
                    require("abyss_exhaust").rememberPower(state,id)
                end
            end
        elseif op == "gainDevotion" then
            assert(source==state.player and state.player.stance,"stance mechanics not enabled")
            require("abyss_mantra").applyDevotion(state,value)
        elseif op=="gainMantra" or op=="applyMantra" or op=="removeMantra" then
            error("Mantra requires the continuation queue")
        elseif op == "handChoice" or op == "whirlwind" or op == "reaperDamage" then
            error("effect requires the continuation queue")
        elseif op == "scry" then
            error("scry requires the continuation queue")
        elseif op == "multiplyPoison" or op == "bouncingPoison" then
            assert(source == state.player, "player poison only")
            if not combat.outcome(state) then
                local Poison = require("abyss_poison")
                if op == "multiplyPoison" then Poison.multiply(state, target, value, combat)
                else Poison.flask(state, value, combat) end
            end
        elseif op == "gainOrbSlots" or op == "loseOrbSlots" then
            assert(source == state.player and state.orbs, "orb mechanics not enabled")
            if not combat.outcome(state) then
                local Orbs = require("abyss_orbs")
                if op == "gainOrbSlots" then Orbs.gainSlots(state, value) else Orbs.loseSlots(state, value) end
            end
        elseif op == "applyBias" then
            assert(source == state.player and state.orbs and value == 1, "unsupported Bias application")
            if not combat.outcome(state) then
                if Actors.applyPower(state,state.player,"bias",value,state.player) then
                    require("abyss_orb_powers").recordApplied(state,"bias")
                end
            end
        elseif op=="gainOrbPower" then
            assert(source==state.player and state.orbs,"orb mechanics not enabled")
            require("abyss_orb_powers").apply(state,effect.status,value)
        elseif op == "gainFocus" then
            assert(source == state.player and state.orbs, "orb mechanics not enabled")
            assert(type(value) == "number" and value % 1 == 0 and value >= -2147483647 and value <= 2147483647,
                "invalid Focus increment")
            if not combat.outcome(state) then Actors.applyPower(state, state.player, "focus", value, state.player) end
        elseif op == "gainStancePower" then
            assert(source == state.player and state.player.stance, "stance mechanics not enabled")
            assert(effect.status == "rushdown" or effect.status == "mental_fortress", "unsupported stance power")
            assert(type(value) == "number" and value % 1 == 0 and value > 0, "invalid stance power")
            if not combat.outcome(state) then
                Actors.applyPower(state, state.player, effect.status, value, state.player)
                state.stancePowerOrder = state.stancePowerOrder or {}
                local found = false
                for _, id in ipairs(state.stancePowerOrder) do if id == effect.status then found = true end end
                if not found then state.stancePowerOrder[#state.stancePowerOrder + 1] = effect.status end
            end
        elseif op == "innerPeace" then
            assert(source == state.player and state.player.stance, "stance mechanics not enabled")
            assert(value == 3 or value == 4, "unsupported Inner Peace draw")
            if not combat.outcome(state) then
                if state.player.stance == "Calm" then combat.draw(state, value)
                else require("abyss_stances").change(state, "Calm") end
            end
        elseif op == "requestDiscard" then
            assert(source == state.player and not queuedEnemyAction, "player discard only")
            if not combat.outcome(state) then
                local ok, reason = require("abyss_discard").begin(state, value)
                assert(ok, reason)
            end
        elseif op == "changeStance" then
            assert(source == state.player and state.player.stance, "stance mechanics not enabled")
            if not combat.outcome(state) then
                require("abyss_stances").change(state, effect.stance)
            end
        elseif op == "channelOrb" or op == "dualcastOrb" or op == "darkImpulseOrb" then
            assert(source == state.player and state.orbs, "orb mechanics not enabled")
            assert(value == 1, "unsupported orb repetition")
            if not combat.outcome(state) then
                local Orbs = require("abyss_orbs")
                if op == "channelOrb" then Orbs.channel(state, effect.orb, combat)
                elseif op == "dualcastOrb" then Orbs.dualcast(state, combat)
                else Orbs.darkImpulse(state) end
            end
        elseif op == "generateShivs" then
            assert(source == state.player and not queuedEnemyAction, "player generation only")
            if not combat.outcome(state) then
                assert(effect.upgraded==nil or type(effect.upgraded)=='boolean','invalid generated Shiv upgrade')
                require("abyss_silent").generateShivs(state, value, effect.upgraded==true)
            end
        elseif op == "damageEqualToBlock" then
            -- Current block is the attack base, not a payment or fixed damage.
            dealt = dealt + combat.damage(state, source, target, source.block,nil,nil,effect.resolved and effect.resolved[target.id])
        elseif op == "conditional" then
            -- Damage leaves the target's statuses intact, even on a lethal hit.
            -- The outer source-alive guard still stops thorns-killed attackers.
            assert(effect["if"] == "target_vulnerable" or effect['if']=='target_poison', "unsupported condition")
            local status=effect['if']=='target_poison' and 'poison' or 'vulnerable'
            if target and (target.statuses[status] or 0) > 0 then
                dealt = dealt + M.apply(combat, state, effect["then"], source, target, playedCard)
            end
        elseif op == "increaseDamageThisCombat" then
            assert(type(playedCard) == "table", "growth requires played card")
            assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0, "invalid card damage growth")
            -- Double Tap's makeSameInstanceOf shares the original UUID. Its
            -- queued copy, resolving instance and all matching combat piles
            -- grow together; stat-equivalent copies have a fresh UID instead.
            local seen={}
            local function grow(c)
                if not c or (c.uuid or c.uid)~=(playedCard.uuid or playedCard.uid) or seen[c] then return end
                seen[c]=true
                local previous=c.damageBonus or 0
                local bonus=previous+0.0+value
                assert(bonus<math.huge and (value==0 or bonus>previous),"card damage growth cannot advance")
                c.damageBonus=bonus
            end
            grow(playedCard);grow(state.cardInUse)
            for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust}) do for _,c in ipairs(pile) do grow(c) end end
            for _,queued in ipairs(state.queuedCards or {}) do grow(queued.card) end
        elseif op == "makeTempCardInDiscard" then
            -- Bounded action ABI: fresh catalog copies, never the Run deck or
            -- a copy of the resolving card (Anger has a separate operation).
            -- A queued MakeTempCard action has no owner-death guard. The outer
            -- gate still rejects dead public sources and final-combat tails.
            assert(type(effect.card) == "string" and state.catalog.cards[effect.card], "unknown temporary card")
            assert(type(value) == "number" and value % 1 == 0 and value >= 0 and value <= 5, "invalid temporary card count")
            local uid = state.nextUid
            assert(type(uid) == "number" and uid > 0 and uid < math.huge and uid % 1 == 0, "invalid nextUid")
            local nextUid = uid + 0.0 + value
            -- Check each increment as well as the batch before mutating piles;
            -- binary64 may round a batch into duplicate/nonadvancing UIDs.
            for i = 1, value do
                assert(uid + 0.0 + i > uid + 0.0 + (i - 1), "nextUid cannot advance")
            end
            assert(nextUid < math.huge and nextUid - uid == value, "nextUid cannot advance")
            for i = 0, value - 1 do
                local generated={uid = uid + 0.0 + i, cardId = effect.card, upgraded = effect.upgraded==true}
                require('abyss_watcher_final_cards').created(combat,state,generated)
                state.discard[#state.discard + 1] = generated
            end
            state.nextUid = nextUid
            if value > 0 then Events.emit(state, "cards_created", {source = source.id, cardId = effect.card, amount = value, pile = "discard"}) end
        elseif op == "addCardToDiscard" then
            -- This operation copies the resolving card, not its catalog default.
            -- New combat-only instances must never mutate Run's permanent deck.
            assert(type(playedCard) == "table", "copy requires played card")
            assert(type(effect.card) == "string" and state.catalog.cards[effect.card], "unknown copy card")
            assert(effect.card == playedCard.cardId, "copy must match played card")
            local uid = state.nextUid
            assert(type(uid) == "number" and uid > 0 and uid % 1 == 0, "invalid nextUid")
            local nextUid = uid + 1.0 -- do not wrap signed 32-bit Fengari integers
            assert(nextUid > uid and nextUid < math.huge, "nextUid cannot advance")
            -- Anger uses a stat-equivalent copy, including combat damage and
            -- costForTurn. The new identity remains independent of its source.
            local created = combat.copy(playedCard)
            created.uid = uid
            require('abyss_watcher_final_cards').created(combat,state,created)
            state.discard[#state.discard + 1] = created
            state.nextUid = nextUid
        elseif op == "loseHp" then
            -- HP payment is not an attack or a status tick. The next effect's
            -- source-alive guard stops the card when this payment is lethal.
            local before = source.hp
            if (source.statuses.intangible or 0)>0 then value=math.min(value,1) end
            value=require('abyss_defect_final_cards').incoming(state,source,value)
            if source==state.player then value=require('abyss_relic_hooks').onLoseHpLast(state,value) end
            source.hp = math.max(0, source.hp - value)
            Events.emit(state, "hp_loss", {source = source.id, target = source.id, amount = before - source.hp, blocked = 0})
            -- Actor owns the single HP-loss notification for either queue.
            Actors.hpLostFromCard(state,source,before-source.hp)
            require('abyss_relic_hooks').hpChanged(state,source,before)
        elseif op=='reptomancerSummon'then
            require('abyss_reptomancer').summon(combat,state,source)
        elseif op=='daggerSacrifice'then
            Actors.sacrificeDagger(state,source,assert(value,'missing captured Dagger HP'))
        elseif op=='enemyBurnBoth' then
            require('abyss_act3_powers').burnBoth(state,source)
        elseif op=='enemyDazedDraw' then
            require('abyss_act3_powers').dazedDraw(state,source)
        elseif op=='enemyStasis' then
            require('abyss_act2_stasis').apply(combat,state,source)
        elseif op=='enemyBronzeSpawn' then
            assert(source.ai and source.ai.policy=='automaton','Automaton spawn only')
            require('abyss_act2_summons').bronze(combat,state)
        elseif op=='enemyTorchSpawn' or op=='enemyTorchRevive' then
            assert(source.ai and source.ai.policy=='collector','Collector summon only')
            require('abyss_act2_summons').torches(combat,state,source,op=='enemyTorchRevive')
        elseif op=='enemyRally' then
            assert(source.ai and source.ai.policy=='leader','Leader summon only')
            require('abyss_act2_summons').rally(combat,state,source)
        elseif op=='enemyEncourage' then
            assert(source.ai and source.ai.policy=='leader','Leader Encourage only')
            for _,ally in ipairs(state.enemies)do if Actors.isActive(ally) then
                Actors.applyPower(state,ally,'strength',value,source)
                if ally~=source then Actors.block(state,ally,6,true) end
            end end
        elseif op=='enemyVampireDamage' then
            assert(source~=state.player and source.ai and source.ai.policy=='parasite','Parasite attack only')
            local reactions={}
            local lost=combat.damage(state,source,target,value,false,reactions)
            dealt=dealt+lost
            -- Vampire queues TOP Heal(lastDamageTaken) above onAttacked's
            -- reactions. The captured loss precedes Fairy's revival; a fatal
            -- non-Fairy hit opens the death screen before either queued action.
            if state.player.hp>0 then
                if lost>0 and Actors.isActive(source) then
                    local healed=math.min(lost,source.maxHp-source.hp);source.hp=source.hp+healed
                    Events.emit(state,'heal',{source=source.id,target=source.id,amount=healed})
                end
                Actors.resolveDamageReactions(state,reactions,combat.retaliate)
            end
        elseif op=='timeEater'then
            require('abyss_time_eater').execute(combat,state,effect,source,CardActions)
        elseif op=='enemyCleanse' then
            assert(source~=state.player and source.ai and source.ai.kind=='act2','Act2 cleanse only')
            local ids={}
            for id,n in pairs(source.statuses)do
                if source.statusDefinitions[id].kind=='debuff' or (id=='strength' or id=='dexterity' or id=='focus') and n<0 then ids[#ids+1]=id end
            end
            table.sort(ids)
            for _,id in ipairs(ids)do
                local n=source.statuses[id]
                require('abyss_power_schedule').remove(state,source,id)
                source.statuses[id]=nil
                local order={};for _,old in ipairs(source.powerOrder or {})do if old~=id then order[#order+1]=old end end
                source.powerOrder=order
                Events.emit(state,'status',{source=source.id,target=source.id,status=id,amount=-n})
            end
        elseif op=='enemyHealAll' or op=='enemyStrengthAll' then
            assert(source~=state.player and source.ai and (source.ai.kind=='act2' or op=='enemyStrengthAll' and source.ai.kind=='act3_boss' and source.ai.policy=='donu'),'unsupported enemy group action')
            -- takeTurn queues one action per then-active monster reference.
            -- Resolve that fixed group, rechecking each target but not the caster.
            local recipients={}
            for _,ally in ipairs(state.enemies)do
                if Actors.isActive(ally)then recipients[#recipients+1]=ally end
            end
            for _,ally in ipairs(recipients)do
                if Actors.isActive(ally)then
                    if op=='enemyHealAll' then
                        local healed=math.min(value,ally.maxHp-ally.hp)
                        ally.hp=ally.hp+healed
                        Events.emit(state,'heal',{source=source.id,target=ally.id,amount=healed})
                    else Actors.applyPower(state,ally,'strength',value,source) end
                end
            end
        elseif op == "block" then
            if effect.target=='all_allies' then
                assert(source~=state.player and source.ai and source.ai.kind=='act3_boss' and source.ai.policy=='deca','Deca group Block only')
                for _,ally in ipairs(state.enemies)do if Actors.isActive(ally)then combat.block(state,ally,value,true)end end
            elseif effect.target=='automaton' then
                assert(source.ai and source.ai.policy=='orb','Bronze support only')
                for _,ally in ipairs(state.enemies)do if ally.definitionId=='automaton' and Actors.isActive(ally)then combat.block(state,ally,value,true);break end end
            elseif effect.target == "random_ally" then
                assert(source ~= state.player, "random ally Block requires an enemy")
                local candidates, member = {}, false
                for _, ally in ipairs(state.enemies) do
                    if ally == source then member = true
                    elseif Actors.isActive(ally) and ally.intents[ally.intentIndex].kind ~= "escape" then
                        candidates[#candidates + 1] = ally
                    end
                end
                assert(member, "random ally Block source is not in the encounter")
                -- Source rooms spend the AI stream even for one eligible ally;
                -- empty-list self fallback draws nothing. Legacy fixtures keep their adapter.
                local recipient = #candidates > 0 and candidates[EnemyRandom.integer(state, #candidates, combat.random)] or source
                combat.block(state, recipient, value, true)
            else combat.block(state, source, value, effect.fixed,effect.blockCallbackAmount) end
        elseif op == "doubleBlock" then combat.block(state, source, source.block, true)
        elseif op == "draw" then combat.draw(state, value)
        elseif op == "noDrawThisTurn" then Actors.applyNoDraw(state, source)
        elseif op == "energy" then state.energy = state.energy + value
        elseif op == "gainStatus" then
            if source==state.player and effect.status=="accuracy" then
                require("abyss_shivs").applyAccuracy(state,value)
            else
            -- Barricade.use does not queue another Power when already held.
            -- Match only the card's valid one-layer application; explicit zero,
            -- malformed amounts/old stacks and other definitions still take
            -- the original Actor validation path, not a generic no-op filter.
            local repeatBarricade = source == state.player and (effect.status == "barricade" or effect.status=="corruption")
                and value == 1 and source.statuses[effect.status] == 1
            if repeatBarricade then
                local definitions = source.statusDefinitions
                local definition = type(definitions) == "table" and definitions[effect.status]
                repeatBarricade = type(definition) == "table" and definition.stack == "none"
            end
            if not repeatBarricade then Actors.applyPower(state, source, effect.status, value, source) end
            if effect.status=="combust" then source.combustHpLoss=(source.combustHpLoss or 0)+1 end
            end
        elseif op == "gainTemporaryStrength" then
            combat.addTemporaryStrength(source, value, state)
        elseif op == "applyStatus" then
            if Actors.isActive(target) then Actors.applyPower(state, target, effect.status, value, source,nil,effect.poisonBonus) end
        elseif op == "applyStatusAll" then
            if index == groupStart then
                for _, victim in ipairs(state.enemies) do
                    for member = groupStart, groupStart + 1 do
                        -- Recheck before each application, not just each target.
                        -- Keep Artifact consumption and independent event frames in Actor.
                        if not Actors.isActive(source) then break end
                        if Actors.isActive(victim) then
                            local status = effects[member]
                            Actors.applyPower(state, victim, status.status, status.value, source,nil,status.poisonBonus)
                        end
                    end
                    if not Actors.isActive(source) then break end
                end
            else
                for _, victim in ipairs(targets(state, source)) do
                    if Actors.isActive(victim) then Actors.applyPower(state, victim, effect.status, value, source,nil,effect.poisonBonus) end
                end
            end
        else error("unsupported effect: " .. tostring(op)) end
        end
        if clearsOnFinalDamage[op] and combat.outcome(state) == "victory" then cleared = true end
    end
    return dealt
end

return M
