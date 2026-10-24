-- Keep integer resources readable without hiding invalid fractional state.
local M = {}
function M.integer(value)
    assert(type(value) == "number" and value == value and math.abs(value) < math.huge
        and value % 1 == 0, "display requires a finite integer")
    return string.format("%.0f", value)
end
return M
