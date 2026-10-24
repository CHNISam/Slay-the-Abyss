-- Host entropy only. Rule modules keep their deterministic, private RNG state.
-- The native client permits os.time and os.clock (7.1 client Lua documentation).
-- CPU time adds subsecond variation across script recreation; serial also mixes
-- accepted starts within one module lifetime. This is not a PC STS seed oracle.
local M = {}
local serial = 0
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 9007199254740991
end
function M.fromTime(wall, cpu, ordinal)
    assert(finite(wall) and wall % 1 == 0, "new-run wall time unavailable")
    assert(finite(cpu) and cpu >= 0, "new-run CPU time unavailable")
    assert(finite(ordinal) and ordinal % 1 == 0, "invalid new-run ordinal")
    local sample = string.format("%.0f/%.6f/%.0f", wall, cpu, ordinal)
    local seed = 0
    for i = 1, #sample do
        -- Below 2^31 on both native Lua and the 32-bit Fengari test runtime.
        seed = (seed * 25173 + sample:byte(i)) % 65536
    end
    return seed
end
function M.next()
    local wall, cpu = os.time(), os.clock()
    local nextSerial = (serial + 1) % 65536
    local seed = M.fromTime(wall, cpu, nextSerial)
    serial = nextSerial
    return seed
end
return M
