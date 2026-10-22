-- Effect interpreter for the core-supported operations.
local M = {}

local coreOps = { damage = true, damageAll = true, block = true, draw = true, energy = true,
    applyStatus = true, applyStatusAll = true, gainStatus = true, doubleBlock = true, noDrawThisTurn = true,
    loseHp = true }

function M.supported(effects)
    for _, effect in ipairs(effects) do if not coreOps[effect.op] then return false, effect.op end end
    return true
end

local function targets(state, source)
    if source == state.player then return state.enemies end
    return { state.player }
end

function M.apply(combat, state, effects, source, target)
    local dealt = 0
    for _, effect in ipairs(effects) do
        if source.hp <= 0 then break end
        local op, value = effect.op, effect.value
        if op == "damage" or op == "damageAll" then
            local selected = op == "damageAll" and targets(state, source) or { target }
            for _ = 1, effect.times or 1 do
                for _, victim in ipairs(selected) do
                    dealt = dealt + combat.damage(state, source, victim, value)
                end
                if combat.outcome(state) then break end
            end
        elseif op == "loseHp" then
            -- HP payment is not an attack or a status tick. The next effect's
            -- source-alive guard stops the card when this payment is lethal.
            source.hp = math.max(0, source.hp - value)
        elseif op == "block" then combat.block(state, source, value)
        elseif op == "doubleBlock" then combat.block(state, source, source.block, true)
        elseif op == "draw" then combat.draw(state, value)
        elseif op == "noDrawThisTurn" then source.noDraw = true
        elseif op == "energy" then state.energy = state.energy + value
        elseif op == "gainStatus" then combat.addStatus(source, effect.status, value)
        elseif op == "applyStatus" then
            if target and target.hp > 0 then combat.addStatus(target, effect.status, value) end
        elseif op == "applyStatusAll" then
            for _, victim in ipairs(targets(state, source)) do
                if victim.hp > 0 then combat.addStatus(victim, effect.status, value) end
            end
        else error("unsupported effect: " .. tostring(op)) end
    end
    return dealt
end

return M
