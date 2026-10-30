-- One stage-owned frozen landscape. GameUI owns pages; this bridge owns art only.
local Asset = require('abyss_menu_background_asset')
local M = {}
function M.new(stage, report)
    local host = assert(stage:GetChild('officialBackground'), 'missing official background host')
    local adapter = Asset.adapter.new(host, Asset.data, {imagePrefabId=Asset.imagePrefabId,batchSize=64})
    local self, covered, active, lastDiagnostic = {}, {}, false, nil
    for _, entry in ipairs({{'menuPanel','backdrop','vista','heroArt'}, {'characterPanel','veil','border','face'}}) do
        local panel = assert(stage:GetChild(entry[1]))
        for i=2,#entry do
            local control=panel:GetChild(entry[i])
            if control then covered[#covered+1]={control=control,visible=control.visible~=false} end
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
    end
    function self.status(_) return adapter:status() end
    function self.sync(_,mode, characterOpen, stopped)
        local wanted=not stopped and (mode=='menu' or characterOpen==true)
        if wanted and not active then
            active=true
            adapter:begin()
        elseif not wanted and active then self:release() end
        local state=diagnose()
        fallback(wanted and state.phase=='ready')
    end
    function self.tick(_)
        local state=adapter:status()
        if not active or state.phase~='building' then return end
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
