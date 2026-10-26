-- Pure graph copy shared by combat and detached definition builders.
local M = {}
function M.copy(value, seen)
    -- assert(value, message) returns both arguments on success. Legacy callers
    -- pass that expression directly, so only an explicit table is a memo.
    seen=type(seen)=='table' and seen or {}
    local function visit(v)
        if type(v)~="table" then return v end
        if seen[v] then return seen[v] end
        local result={};seen[v]=result
        for k,entry in pairs(v) do result[k]=visit(entry) end
        return result
    end
    return visit(value)
end
return M
