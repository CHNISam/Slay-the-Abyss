-- One stage-owned frozen landscape. GameUI owns pages; this bridge owns art only.
local Asset = require('abyss_menu_background_asset')
local Theme=require('abyss_theme')
local M = {}
function M.new(stage, report, createController, makeColor, options)
    options=options or {}
    local host = assert(stage:GetChild('officialBackground'), 'missing official background host')
    local native=Asset.renderProfile=='native-v2' or Asset.renderProfile=='background-budget-v1'
    local compact=Asset.renderProfile=='compact-v1' or native
    local adapter
    if compact then
        assert(Asset.data.count==#Asset.data.rows and Asset.data.count<=13201,'background capacity exceeded')
        adapter=assert(createController,'compact background requires native controller factory')(host,Asset.data,1280,
            {imagePrefabId=Asset.imagePrefabId,containerPrefabId=Asset.containerPrefabId})
        adapter.tick=function(_)
            local start=os.clock()
            local batch=Asset.renderProfile=='background-budget-v1' and 256 or 64
            for i=1,batch do
                local advanced,kind=adapter:step()
                if not advanced or kind=='reveal' or i%8==0 and os.clock()-start>=.008 then break end
            end
        end
        adapter.onEngineDestroy=adapter.destroy
    else adapter=Asset.adapter.new(host, Asset.data, {imagePrefabId=Asset.imagePrefabId,batchSize=64})end
    local self, covered, active, lastDiagnostic = {}, {}, false, nil
    for _, entry in ipairs(options.standalone and {} or {{'menuPanel','backdrop','vista','heroArt'}, {'characterPanel','veil','border','face'}}) do
        local panel = assert(stage:GetChild(entry[1]))
        for i=2,#entry do
            local control=panel:GetChild(entry[i])
            local keepVeil=native and (entry[i]=='backdrop' or entry[i]=='veil')
            if control and not keepVeil then covered[#covered+1]={control=control,visible=control.visible~=false} end
        end
    end
    local function diagnose()
        local s=adapter:status()
        local message='ABYSS_BACKGROUND phase='..s.phase..' owned='..s.owned..' reason='..tostring(s.reason)
        if message~=lastDiagnostic and s.phase~='building' then
            lastDiagnostic=message
            if report then pcall(report,message) end
        end
        return s
    end
    local function fallback(ready)
        for _,entry in ipairs(covered) do
            if entry.control.alive~=false then entry.control:SetVisible(not ready and entry.visible) end
        end
        if native and makeColor and not options.standalone then
            local c=ready and Theme.color.backdropVeil or Theme.color.backdrop
            local backdrop=stage:GetChild('menuPanel'):GetChild('backdrop')
            backdrop.imageColor=makeColor(c.r,c.g,c.b,c.a);backdrop:SetVisible(true)
        end
    end
    function self.status(_)
        local status=adapter:status();status.total=#Asset.data.rows;return status
    end
    function self.sync(_,mode, characterOpen, stopped)
        local wanted=not stopped and (mode=='menu' or characterOpen==true)
        if wanted and not active then
            active=true
            adapter:begin()
        elseif not wanted and active then
            if compact then active=false;adapter:pause()else self:release()end
        end
        local state=diagnose()
        fallback(wanted and state.phase=='ready')
    end
    function self.tick(_)
        local state=adapter:status()
        if not active or (state.phase~='building' and state.phase~='revealing')then return end
        adapter:tick(state.generation)
        state=diagnose()
        if state.phase~='building' then fallback(state.phase=='ready') end
    end
    function self.release(_)
        active=false
        local ok,reason=adapter:release()
        fallback(false);diagnose()
        return ok,reason
    end
    function self.onEngineDestroy(_)
        active=false
        adapter:onEngineDestroy();covered={};diagnose()
    end
    return self
end
return M
