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
        -- Most definition fields are scalars. Copy them directly instead of
        -- entering the recursive Lua function once for every string/number.
        for k,entry in pairs(v) do
            result[k]=type(entry)=='table' and visit(entry) or entry
        end
        return result
    end
    return visit(value)
end
return M
