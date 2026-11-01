-- Numeric-only LCG shared by deterministic rules modules. No math.random/global RNG.
local M = {}
local function integer(value)
    return type(value) == "number" and value == value and math.abs(value) <= 9007199254740991
        and value % 1 == 0
end

function M.new(seed)
    if seed == nil then seed = 1 end
    assert(integer(seed), "seed must be a finite safe integer")
    return { seed = seed % 65536 }
end

function M.next(state, maximum)
    assert(type(state) == "table" and integer(state.seed) and state.seed >= 0 and state.seed < 65536,
        "invalid random state")
    assert(integer(maximum) and maximum >= 1 and maximum <= 65536, "invalid random range")
    -- Product remains below 2^31, including Fengari's 32-bit integer arithmetic.
    state.seed = (state.seed * 25173 + 13849) % 65536
    return state.seed % maximum + 1
end

return M
