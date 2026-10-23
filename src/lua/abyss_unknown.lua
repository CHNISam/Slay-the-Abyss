-- Basic StS1 unknown-room probability reducer, in integer percent units.
-- The caller owns entry transactions and eventRng. No RNG is consumed here.
-- Shop exclusions and special relics require separately verified adapters.
local M = {}
local keys = { 'monster', 'shop', 'treasure' }

local function integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

local function validBase(base)
    if type(base) ~= 'table' then return false end
    for _, key in ipairs(keys) do if not integer(base[key], 1, 100) then return false end end
    for key in pairs(base) do
        if key ~= 'monster' and key ~= 'shop' and key ~= 'treasure' then return false end
    end
    return true
end

local function validState(state, base)
    if type(state) ~= 'table' or state.version ~= 1 or not validBase(base) then return false end
    for _, key in ipairs(keys) do
        -- Keep addition within actual Lua/Fengari integer bounds, before mutation.
        if not integer(state[key], base[key], 2147483547) or state[key] % base[key] ~= 0 then return false end
    end
    for key in pairs(state) do
        if key ~= 'version' and key ~= 'monster' and key ~= 'shop' and key ~= 'treasure' then return false end
    end
    return true
end

function M.new(base)
    assert(validBase(base), 'invalid unknown-room base percentages')
    return { version = 1, monster = base.monster, shop = base.shop, treasure = base.treasure }
end

function M.snapshot(state)
    return { version = state.version, monster = state.monster, shop = state.shop, treasure = state.treasure }
end

function M.restore(snapshot, base)
    if not validState(snapshot, base) then return nil, 'invalid_unknown_snapshot' end
    return M.snapshot(snapshot)
end

function M.advance(state, roll, base)
    assert(validState(state, base), 'invalid unknown-room probability state')
    assert(type(roll) == 'number' and roll == roll and roll >= 0 and roll < 1, 'roll must be in [0,1)')
    local selected, cumulative = 'event', 0.0
    -- Accumulate integer percentages before dividing; .10+.03 floating drift
    -- must not move the supplied equality-boundary contract.
    for _, key in ipairs(keys) do
        cumulative = cumulative + state[key]
        if roll < cumulative / 100 then selected = key; break end
    end
    for _, key in ipairs(keys) do
        state[key] = selected == key and base[key] or state[key] + base[key]
    end
    return selected
end

return M
