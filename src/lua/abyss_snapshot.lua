-- Short-lived rollback closures stay on the call stack, never in saved state.
-- Restore contents of original tables so external card/pile references survive.
local M={}
-- Opaque, call-stack-only capabilities. A nested command may reuse the exact
-- complete parent preimage, never an immutable-subtree shortcut or stale save.
local owners=setmetatable({},{__mode='k'})
function M.capture(root,target)
    assert(type(root)=='table','snapshot requires a table')
    local saved,pending={[root]={}},{root}
    local top,kind=1,type
    while top>0 do
        local original=pending[top];pending[top]=nil;top=top-1
        local values=saved[original]
        for k,v in next,original do
            values[k]=v
            if kind(k)=='table' and not saved[k] then
                saved[k]={};top=top+1;pending[top]=k
            end
            if kind(v)=='table' and not saved[v] then
                saved[v]={};top=top+1;pending[top]=v
            end
        end
    end
    local function restore()
        for original,values in next,saved do
            for k in next,original do rawset(original,k,nil) end
            for k,v in next,values do rawset(original,k,v) end
        end
    end
    if target~=nil then
        assert(type(target)=='table' and saved[target],'snapshot target is not captured')
        owners[restore]=target
        return restore,restore
    end
    return restore
end
function M.ownedRestore(owner,target)
    local captured=type(owner)=='function' and owners[owner]
    if captured and rawequal(captured,target)then
        owners[owner]=nil -- one nested play only; never a reusable savepoint
        return owner
    end
end
function M.release(owner)
    if type(owner)~='function' or owners[owner]==nil then return false end
    owners[owner]=nil;return true
end
return M
