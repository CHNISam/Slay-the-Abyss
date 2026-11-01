-- Optional victory artwork: loading starts only after an explicit player action.
local M={}
function M.new(root,options)
    local panel=assert(root:GetChild('victoryEasterEgg'),'missing victory egg overlay')
    local button=assert(root:GetChild('menuPanel'):GetChild('result'):GetChild('viewEasterEgg'))
    local self={panel=panel,button=button}
    local opened,ended,art,reason=false,false,nil,nil
    panel.disableCursorEventPassthrough=true
    local function eligible()return not ended and options.canOpen()==true end
    local function invoke(name,...)
        if not art then return false end
        local ok,value=pcall(art[name],art,...)
        if not ok then reason=tostring(value) end
        return ok,value
    end
    local function paint()
        if reason then panel:GetChild('status').text='彩蛋暂时无法显示，请返回结算。';return end
        local ok,state=invoke('status')
        if not ok then return end
        if state.phase=='ready' then panel:GetChild('status').text='';return end
        if state.phase=='failed' or state.phase=='release_failed' then
            panel:GetChild('status').text='彩蛋暂时无法显示，请返回结算。';return
        end
        local total=state.total or 0
        local done=math.max(0,(state.nextIndex or 1)-1)
        local progress=total>0 and math.min(99,math.floor(done/total*100)) or 0
        panel:GetChild('status').text='正在载入彩蛋… '..progress..'%'
    end
    function self.isOpen(_)return opened end
    function self.status(_)return {open=opened,created=art~=nil,reason=reason}end
    function self.open(_)
        if opened or not eligible()then return false end
        opened=true
        if not art then
            local ok,value=pcall(options.createArt)
            if ok and type(value)=='table' then art=value else reason=tostring(value)end
        end
        if art then invoke('sync','menu',false,false)end
        panel:SetVisible(true);panel:SetAsLastSibling();button:SetVisible(false)
        if options.onVisibility then options.onVisibility(true)end
        paint();return true
    end
    function self.close(_)
        if not opened or ended then return false end
        opened=false
        if art then invoke('sync','node',false,true)end
        panel:SetVisible(false)
        if options.onVisibility then options.onVisibility(false)end
        button:SetVisible(eligible());return true
    end
    function self.release(_)
        if not ended then
            self:close()
            ended=true;button:SetVisible(false)
        end
        if art then
            local released,why=art:release()
            assert(released,why or 'victory artwork release failed')
            art=nil
        end
        return true
    end
    function self.refresh(_)
        if ended then return false end
        local allowed=eligible()
        if not allowed and opened then self:close()end
        button:SetVisible(allowed and not opened)
        if opened then panel:SetAsLastSibling()end
        return allowed
    end
    function self.tick(_)
        if not opened or ended then return false end
        if not eligible()then self:close();return false end
        if art and not reason then invoke('tick')end
        paint();return true
    end
    function self.onEngineDestroy(_)
        ended=true;opened=false
        if art then invoke('onEngineDestroy')end
        art=nil
    end
    panel:SetVisible(false);button:SetVisible(false)
    return self
end
return M
