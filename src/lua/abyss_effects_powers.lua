-- Synchronous powers operations. No continuation-queue ownership is transferred here.
local Actors=require('abyss_actor')
local EnemyRandom=require('abyss_enemy_random')
local M={}
function M.gainExhaustPower(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local value=context.effect.value
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
end

function M.gainDevotion(context)
    local state=context.state
    local source=context.source
    local value=context.effect.value
    assert(source==state.player and state.player.stance,"stance mechanics not enabled")
    require("abyss_mantra").applyDevotion(state,value)
end

function M.gainMantra()
    error("Mantra requires the continuation queue")
end
M.applyMantra=M.gainMantra
M.removeMantra=M.gainMantra

function M.multiplyPoison(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local target=context.target
    local op=context.effect.op
    local value=context.effect.value
    assert(source == state.player, "player poison only")
    if not combat.outcome(state) then
        local Poison = require("abyss_poison")
        if op == "multiplyPoison" then Poison.multiply(state, target, value, combat)
        else Poison.flask(state, value, combat) end
    end
end
M.bouncingPoison=M.multiplyPoison

function M.gainOrbSlots(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local op=context.effect.op
    local value=context.effect.value
    assert(source == state.player and state.orbs, "orb mechanics not enabled")
    if not combat.outcome(state) then
        local Orbs = require("abyss_orbs")
        if op == "gainOrbSlots" then Orbs.gainSlots(state, value) else Orbs.loseSlots(state, value) end
    end
end
M.loseOrbSlots=M.gainOrbSlots

function M.applyBias(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local value=context.effect.value
    assert(source == state.player and state.orbs and value == 1, "unsupported Bias application")
    if not combat.outcome(state) then
        if Actors.applyPower(state,state.player,"bias",value,state.player) then
            require("abyss_orb_powers").recordApplied(state,"bias")
        end
    end
end

function M.gainOrbPower(context)
    local state=context.state
    local effect=context.effect
    local source=context.source
    local value=context.effect.value
    assert(source==state.player and state.orbs,"orb mechanics not enabled")
    require("abyss_orb_powers").apply(state,effect.status,value)
end

function M.gainFocus(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local value=context.effect.value
    assert(source == state.player and state.orbs, "orb mechanics not enabled")
    assert(type(value) == "number" and value % 1 == 0 and value >= -2147483647 and value <= 2147483647,
                "invalid Focus increment")
    if not combat.outcome(state) then Actors.applyPower(state, state.player, "focus", value, state.player) end
end

function M.gainStancePower(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local value=context.effect.value
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
end

function M.innerPeace(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local value=context.effect.value
    assert(source == state.player and state.player.stance, "stance mechanics not enabled")
    assert(value == 3 or value == 4, "unsupported Inner Peace draw")
    if not combat.outcome(state) then
        if state.player.stance == "Calm" then combat.draw(state, value)
        else require("abyss_stances").change(state, "Calm") end
    end
end

function M.changeStance(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    assert(source == state.player and state.player.stance, "stance mechanics not enabled")
    if not combat.outcome(state) then
        require("abyss_stances").change(state, effect.stance)
    end
end

function M.channelOrb(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local op=context.effect.op
    local value=context.effect.value
    assert(source == state.player and state.orbs, "orb mechanics not enabled")
    assert(value == 1, "unsupported orb repetition")
    if not combat.outcome(state) then
        local Orbs = require("abyss_orbs")
        if op == "channelOrb" then Orbs.channel(state, effect.orb, combat)
        elseif op == "dualcastOrb" then Orbs.dualcast(state, combat)
        else Orbs.darkImpulse(state) end
    end
end
M.dualcastOrb=M.channelOrb
M.darkImpulseOrb=M.channelOrb

local function blockAllAllies(context)
    local combat,state,source,value=context.combat,context.state,context.source,context.effect.value
    assert(source~=state.player and source.ai and source.ai.kind=='act3_boss' and source.ai.policy=='deca','Deca group Block only')
    for _,ally in ipairs(state.enemies)do if Actors.isActive(ally)then combat.block(state,ally,value,true)end end
end
local function blockAutomaton(context)
    local combat,state,source,value=context.combat,context.state,context.source,context.effect.value
    assert(source.ai and source.ai.policy=='orb','Bronze support only')
    for _,ally in ipairs(state.enemies)do
        if ally.definitionId=='automaton' and Actors.isActive(ally)then combat.block(state,ally,value,true);break end
    end
end
local function blockRandomAlly(context)
    local combat,state,source,value=context.combat,context.state,context.source,context.effect.value
    assert(source ~= state.player, "random ally Block requires an enemy")
    local candidates, member = {}, false
    for _, ally in ipairs(state.enemies) do
        if ally == source then member = true
        elseif Actors.isActive(ally) and ally.intents[ally.intentIndex].kind ~= "escape" then
            candidates[#candidates + 1] = ally
        end
    end
    assert(member, "random ally Block source is not in the encounter")
    -- Even one candidate spends a draw; the empty fallback spends none.
    local recipient = #candidates > 0 and candidates[EnemyRandom.integer(state, #candidates, combat.random)] or source
    combat.block(state, recipient, value, true)
end
local blockTargets={all_allies=blockAllAllies,automaton=blockAutomaton,random_ally=blockRandomAlly}
function M.block(context)
    local handler=blockTargets[context.effect.target]
    if handler then return handler(context)end
    local combat,state,source,effect=context.combat,context.state,context.source,context.effect
    combat.block(state,source,effect.value,effect.fixed,effect.blockCallbackAmount)
end

function M.doubleBlock(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    combat.block(state, source, source.block, true)
end

function M.noDrawThisTurn(context)
    local state=context.state
    local source=context.source
    Actors.applyNoDraw(state, source)
end

function M.gainStatus(context)
    local state=context.state
    local effect=context.effect
    local source=context.source
    local value=context.effect.value
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
end

function M.gainTemporaryStrength(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local value=context.effect.value
    combat.addTemporaryStrength(source, value, state)
end

function M.applyStatus(context)
    local state=context.state
    local effect=context.effect
    local source=context.source
    local target=context.target
    local value=context.effect.value
    if Actors.isActive(target) then Actors.applyPower(state, target, effect.status, value, source,nil,effect.poisonBonus) end
end

function M.applyStatusAll(context)
    local state=context.state
    local effect=context.effect
    local source=context.source
    local value=context.effect.value
    local effects=context.effects
    local index=context.index
    local groupStart=context.groupStart
    local targets=context.targets
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
end

return M
