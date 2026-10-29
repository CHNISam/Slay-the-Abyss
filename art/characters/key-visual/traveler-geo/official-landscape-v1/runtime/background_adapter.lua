-- Narrow lifecycle wrapper for one frozen official-background candidate.
-- Native property sequence follows Primitive's MIT runtime (Copyright 2026 LiuL).
-- No renderer, fitting, timers, UI-root integration, or device-performance claim.
local M = {}
local SOURCE = 'fc0e4c50c0ed03a7a790731df5f5e10076d1418db615c41784210e9677c24ce3'
local owners = setmetatable({}, {__mode='k'})
local CANCELLED = {}
local function positiveInteger(n)
    return type(n)=='number' and n==n and n>0 and n<math.huge and n%1==0
end
function M.new(host, data, options)
    options=options or {}
    local batch=options.batchSize or 64
    assert(host~=nil, 'dedicated background host required')
    assert(positiveInteger(batch) and batch<=13201, 'batchSize must be an integer in 1..13201')
    assert(type(data)=='table' and data.sourceSha256==SOURCE and data.width==480 and data.height==270
        and type(data.rows)=='table' and #data.rows==13201, 'unexpected frozen background data')
    local previous=owners[host]
    if previous then return previous end
    local self={}
    local phase,generation,nextIndex='idle',0,1
    local created,working,pendingRelease,hiding={},false,false,false
    local reason,cleanupFailures=nil,0
    local prefab=options.imagePrefabId or 0
    local function current(token)
        return phase=='building' and generation==token and host.alive~=false
    end
    local function check(token)
        if not current(token) then error(CANCELLED,0) end
    end
    local function hide()
        if host.alive==false or phase=='destroyed' or hiding then return true end
        hiding=true
        local ok,err=pcall(host.SetVisible,host,false)
        hiding=false
        if not ok or err==false then reason=ok and 'native host hide rejected' or tostring(err);return false end
        return true
    end
    -- Called under the operation guard. A failed destroy retains its handle;
    -- all other handles are still attempted. Never claim failed reclamation.
    local function cleanup()
        local old=created;created={};cleanupFailures=0
        for i=#old,1,-1 do
            if phase=='destroyed' then created={};return true end
            local c=old[i]
            if c.alive~=false then
                local ok,err=pcall(game.DestroyClientUIControl,c)
                if not ok or err==false then
                    cleanupFailures=cleanupFailures+1;reason=ok and 'native destroy rejected' or tostring(err)
                    if c.alive~=false then created[#created+1]=c end
                end
            end
        end
        pendingRelease=false
        if #created>0 then phase='release_failed';return false end
        return cleanupFailures==0
    end
    local function fail(err)
        if phase=='destroyed' then created={};return end
        phase='failed';generation=generation+1;reason=tostring(err)
        hide();cleanup()
    end
    local function call(token,control,name,...)
        check(token)
        assert(type(control[name])=='function','missing native method '..name)
        assert(control[name](control,...)~=false,'native method rejected '..name)
        check(token)
    end
    local function write(token,c,r)
        assert(r[1]==100001,'unexpected image resource')
        call(token,c,'SetVisible',false)
        call(token,c,'SetImage',Enum.ImageSource.StaticReference,r[1])
        c.imageType=Enum.ImageType.Stretch;check(token)
        assert(c.imageType==Enum.ImageType.Stretch,'native imageType rejected')
        call(token,c,'SetAnchorMin',r[8],r[9]);call(token,c,'SetAnchorMax',r[10],r[11])
        call(token,c,'SetPivot',r[6],r[7]);call(token,c,'SetSizeDelta',r[4],r[5])
        call(token,c,'SetLocalScale',r[12],r[13],1);call(token,c,'SetLocalRotation',0,0,r[14])
        call(token,c,'SetAnchoredPosition',r[2],r[3])
        c.imageColor=Color.FromRGBA(r[15],r[16],r[17],r[18]);check(token)
        call(token,c,'SetAsLastSibling');call(token,c,'SetActive',true);call(token,c,'SetVisible',true)
    end
    function self:status()
        return {phase=phase,generation=generation,nextIndex=nextIndex,owned=#created,
            retained=phase=='release_failed' and #created or 0,working=working,
            batchSize=batch,reason=reason,cleanupFailures=cleanupFailures,sourceSha256=SOURCE}
    end
    function self:begin()
        if working then return false,'busy' end
        if host.alive==false then self:onEngineDestroy() end
        if phase=='destroyed' then return false,'destroyed' end
        if phase=='building' or phase=='ready' then return true,generation end
        if phase=='failed' or phase=='release_failed' then return false,'explicit retry/release required' end
        if not positiveInteger(prefab) then phase='failed';reason='imagePrefabId is unbound';hide();return false,reason end
        assert(#created==0,'old background controls remain')
        generation=generation+1;nextIndex=1;phase='building';reason=nil;pendingRelease=false
        local token=generation;working=true
        local ok,err=pcall(function()
            call(token,host,'SetVisible',false);call(token,host,'SetActive',true)
            call(token,host,'SetAnchorMin',.5,.5);call(token,host,'SetAnchorMax',.5,.5)
            call(token,host,'SetPivot',.5,.5);call(token,host,'SetSizeDelta',480,270)
            call(token,host,'SetLocalScale',8/3,8/3,1);call(token,host,'SetLocalRotation',0,0,0)
            call(token,host,'SetAnchoredPosition',0,0)
        end)
        if not ok and err~=CANCELLED then fail(err) end
        if pendingRelease then cleanup() end
        working=false
        return ok and current(token),token
    end
    function self:tick(token)
        if host.alive==false then self:onEngineDestroy() end
        if working or not current(token) then return false,'inactive or stale' end
        working=true
        local ok,err=pcall(function()
            local last=math.min(#data.rows,nextIndex+batch-1)
            while nextIndex<=last do
                check(token)
                local c=game.InstantiateClientUIControl(prefab,host)
                -- Registration precedes checking cancellation and writing setters.
                if c~=nil then created[#created+1]=c end
                check(token);assert(c~=nil,'image template unavailable')
                write(token,c,data.rows[nextIndex]);nextIndex=nextIndex+1
            end
            if nextIndex>#data.rows then
                call(token,host,'SetVisible',true);phase='ready'
            end
        end)
        if not ok and err~=CANCELLED then fail(err) end
        if phase=='destroyed' then created={}
        elseif pendingRelease then cleanup() end
        working=false
        return ok and generation==token and (phase=='building' or phase=='ready'),reason
    end
    function self:release()
        if phase=='destroyed' then return true end
        if pendingRelease then return true,'pending cleanup' end
        local wasWorking=working;working=true
        generation=generation+1;phase='released';pendingRelease=true
        local hidden=hide()
        if wasWorking then return hidden,'pending cleanup' end
        local cleaned=cleanup();working=false
        return hidden and cleaned,reason
    end
    function self:retry()
        if working or phase=='destroyed' or host.alive==false then return false,'inactive or busy' end
        if phase=='building' or phase=='ready' then return self:begin() end
        local ok=self:release();if not ok then return false,reason end
        return self:begin()
    end
    function self:onEngineDestroy()
        generation=generation+1;phase='destroyed';pendingRelease=false
        created={}
        -- Keep a weak-key tombstone: engine callback can precede alive=false.
        -- A second factory request for the same host must not resurrect it.
        -- Engine owns subtree destruction here. Do not call Destroy or setters.
    end
    owners[host]=self
    return self
end
return M
