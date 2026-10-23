-- Effect interpreter for the core-supported operations.
local M = {}
local Actors = require("abyss_actor")

local coreOps = { damage = true, damageAll = true, block = true, draw = true, energy = true,
    applyStatus = true, applyStatusAll = true, gainStatus = true }

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
        elseif op == "block" then combat.block(state, source, value)
        elseif op == "draw" then combat.draw(state, value)
        elseif op == "energy" then state.energy = state.energy + value
        elseif op == "gainStatus" then Actors.status(state, source, effect.status, value, source)
        elseif op == "applyStatus" then
            if target and target.hp > 0 then Actors.status(state, target, effect.status, value, source) end
        elseif op == "applyStatusAll" then
            for _, victim in ipairs(targets(state, source)) do
                if victim.hp > 0 then Actors.status(state, victim, effect.status, value, source) end
            end
        else error("unsupported effect: " .. tostring(op)) end
    end
    return dealt
end

return M
