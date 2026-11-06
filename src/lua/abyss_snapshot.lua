-- Short-lived rollback closures stay on the call stack, never in saved state.
-- Restore contents of original tables so external card/pile references survive.
local M={}
-- Opaque, call-stack-only capabilities. A nested command may reuse the exact
-- complete parent preimage, never an immutable-subtree shortcut or stale save.
local owners=setmetatable({},{__mode='k'})
function M.capture(root,target)
    assert(type(root)=='table','snapshot requires a table')
    local seen,pending={[root]=true},{root}
    local originals,ends,entries={},{},{}
    local top,entryCount,kind=1,0,type
    local keyTables={}
    while top>0 do
        local original=pending[top];pending[top]=nil;top=top-1
        originals[#originals+1]=original
        for k,v in next,original do
            entries[entryCount+1]=k;entries[entryCount+2]=v;entryCount=entryCount+2
            local tableKey=keyTables[k]
            if tableKey==nil then tableKey=kind(k)=='table';keyTables[k]=tableKey end
            if tableKey and not seen[k] then
                seen[k]=true;top=top+1;pending[top]=k
            end
            if kind(v)=='table' and not seen[v] then
                seen[v]=true;top=top+1;pending[top]=v
            end
        end
        ends[#originals]=entryCount -- empty tables still have a boundary
    end
    local function restore()
        local first=1
        for i=1,#originals do
            local original=originals[i]
            for k in next,original do rawset(original,k,nil) end
            for j=first,ends[i],2 do rawset(original,entries[j],entries[j+1]) end
            first=ends[i]+1
        end
    end
    if target~=nil then
        assert(type(target)=='table' and seen[target],'snapshot target is not captured')
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
