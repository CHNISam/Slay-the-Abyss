-- Each current-entry case owns a native world. Fengari does not implement Lua
-- weak tables, so retain no cross-case mock world after real engine teardown.
local function dead()error('native control is destroyed')end
local tombstone={__index=function(_,key)
    if key=='alive' then return false end
    if key=='GetChild' or key=='RefreshItems' or key:match('^Set') or key:match('^Add')then return dead end
end,__newindex=dead}
return function()
    local F=dofile('tests/lua/support/game_ui_fixture.lua') -- unchanged strict producer-backed fixture
    local originalFixture,originalControl=F.fixture,F.control
    local worlds,hosts,finalizers={},{},{}
    local function track(root)worlds[root]=true end
    F.fixture=function(...)
        local host,root=originalFixture(...)
        hosts[host]=true;track(root.parent or root)
        return host,root
    end
    F.control=function(spec,parent)
        local box=originalControl(spec,parent)
        if not parent then track(box)end
        return box
    end
    function F.nativeWorld(onDestroy,nativeScript)
        finalizers[#finalizers+1]=function()
            local previous=script;script=nativeScript
            local ok,why=pcall(onDestroy)
            script=previous;assert(ok,why)
        end
    end
    function F.worldCount()local n=0;for _ in pairs(worlds)do n=n+1 end;return n end
    function F.close()
        local failure
        for _,finish in ipairs(finalizers)do
            local ok,why=pcall(finish);if not ok then failure=why end
        end
        finalizers={}
        for host in pairs(hosts)do
            local ok,why=pcall(host.onEngineDestroy,host)
            if not ok then failure=why end
            hosts[host]=nil
        end
        local function release(box)
            for _,child in pairs(box.children or {})do release(child)end
            for _,child in pairs(box.items or {})do release(child)end
            -- Native destruction frees its backing payload. Keep only an invalid
            -- handle; never clear a production cache or resurrect a stale control.
            for key in pairs(box)do rawset(box,key,nil)end
            setmetatable(box,tombstone)
        end
        local engine=F.monsterActors()
        for canvas in pairs(worlds)do
            engine.destroy(canvas)
            release(canvas);worlds[canvas]=nil
        end
        assert(not failure,failure)
    end
    return F
end
