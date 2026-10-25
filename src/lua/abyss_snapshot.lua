-- Short-lived rollback closures stay on the call stack, never in saved state.
-- Restore contents of original tables so external card/pile references survive.
local M={}
function M.capture(root)
    assert(type(root)=='table','snapshot requires a table')
    local saved,pending={},{root}
    while #pending>0 do
        local original=table.remove(pending)
        if not saved[original] then
            local values={};saved[original]=values
            for k,v in next,original do
                values[k]=v
                if type(k)=='table' then pending[#pending+1]=k end
                if type(v)=='table' then pending[#pending+1]=v end
            end
        end
    end
    return function()
        for original,values in next,saved do
            for k in next,original do rawset(original,k,nil) end
            for k,v in next,values do rawset(original,k,v) end
        end
    end
end
return M
