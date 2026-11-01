-- Pure graph copy shared by combat and detached definition builders.
local M = {}
local kind,entries=type,pairs
local function visit(value,seen)
    if seen[value] then return seen[value] end
    local result={};seen[value]=result
    for key,entry in entries(value)do
        if kind(entry)=='table'then result[key]=visit(entry,seen)
        else result[key]=entry end
    end
    return result
end
function M.copy(value, seen)
    if kind(value)~='table'then return value end
    -- assert(value, message) returns both arguments on success. Legacy callers
    -- pass that expression directly, so only an explicit table is a memo.
    return visit(value,kind(seen)=='table'and seen or {})
end
return M
