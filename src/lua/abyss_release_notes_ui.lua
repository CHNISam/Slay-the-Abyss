-- Offline presentation only. Source version history comes from CHANGELOG;
-- only receipt-confirmed versions may claim a platform publication date.
local Theme = require('abyss_theme')
local Controller = require('abyss_controller')
local M = {}
local sections = {{'added','新增'},{'improved','优化'},{'fixed','修复'}}
local function appendBullet(result,label,bullet)
    local prefix=label..' · '
    -- Same UTF-8 codepoint pattern as the existing cinematic, without assuming
    -- the native sandbox exposes Lua's optional utf8 library.
    local row,used=prefix,5
    local limit=Theme.layout.releaseNotes.rowCharacters
    for character in bullet:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if used==limit then result[#result+1]=row;row,used='　',1 end
        row=row..character;used=used+1
    end
    result[#result+1]=row
end
local function lines(notice)
    local result = {}
    for _,section in ipairs(sections) do
        for _,bullet in ipairs(notice[section[1]] or {}) do appendBullet(result,section[2],bullet) end
    end
    if #result==0 then result[1]='暂无更新条目' end
    return result
end
function M.new(panel,entry,version,notes,clickEvent,platform,changed)
    local self={root=panel,visible=false,allowed=false,generation=0,view='history',index=1,page=1}
    notes=notes or {build={},history={}}
    local history=notes.history or {}
    local build=notes.build or {}
    local buildLine='代码版本 '..(build.version or '未知')..' · 来源 '..(build.sourceCommit and build.sourceCommit:sub(1,7) or '未知')
    if build.sourceDirty then buildLine=buildLine..' · 本地修改' end
    version.text=buildLine
    panel:GetChild('build').text=buildLine
    panel.disableCursorEventPassthrough=true
    panel:GetChild('blocker'):AddCursorEventListener(clickEvent,function()return true end)
    local function enabled(kind)
        if kind=='entry' then return self.allowed and not self.visible end
        if not self.visible or not self.allowed then return false end
        if kind=='history' then return self.view~='history' end
        if kind=='current' then return notes.currentNotice~=nil and self.view~='current' end
        if kind=='newer' then return self.view=='history' and self.index>1 end
        if kind=='older' then return self.view=='history' and self.index<#history end
        if kind=='previous' then return self.page>1 end
        if kind=='next' then return self.page<(self.pages or 1) end
        return kind=='close'
    end
    self.invalidate=function(_)self.generation=self.generation+1 end
    self.render=function(_)
        panel:SetVisible(self.visible)
        entry:SetVisible(self.allowed and not self.visible)
        if not self.visible then return end
        panel:SetAsLastSibling()
        local notice=self.view=='current' and notes.currentNotice or history[self.index]
        local content
        if notice then
            content=lines(notice)
            panel:GetChild('version').text=notice.version
            if self.view=='current' then
                panel:GetChild('date').text='说明日期 '..notice.notesDate..' · 本次版本说明，不代表已发布'
            elseif notice.publishedDate then
                panel:GetChild('date').text='发布日期 '..notice.publishedDate..' · 发布记录 '..self.index..' / '..#history
            else
                panel:GetChild('date').text='版本日期 '..(notice.versionDate or '未知')..' · 版本记录 '..self.index..' / '..#history
            end
        else
            content={'暂无版本记录'}
            if not notes.currentNotice then content[2]='当前为代码基线，暂无随附版本说明' end
            panel:GetChild('version').text='版本记录'
            panel:GetChild('date').text=''
        end
        local rows=Theme.layout.releaseNotes.rows
        self.pages=math.max(1,math.ceil(#content/rows))
        self.page=math.min(self.page,self.pages)
        for i=1,rows do panel:GetChild('row'..i).text=content[(self.page-1)*rows+i] or '' end
        panel:GetChild('page').text='第 '..self.page..' / '..self.pages..' 页'
        panel:GetChild('current'):SetVisible(notes.currentNotice~=nil)
        panel:GetChild('newer'):SetVisible(self.view=='history' and #history>0)
        panel:GetChild('older'):SetVisible(self.view=='history' and #history>0)
        for _,kind in ipairs({'history','current','newer','older','previous','next','close'}) do
            panel:GetChild(kind):GetChild('hit').interactable=enabled(kind)
        end
    end
    self.open=function(_)
        if not enabled('entry') then return false end
        self.visible,self.view,self.index,self.page=true,(notes.currentNotice and 'current' or 'history'),1,1
        self:invalidate();changed();return true
    end
    self.close=function(_)
        if not self.visible then return false end
        self.visible=false;self:invalidate();changed();return true
    end
    self.press=function(_,kind)
        if not enabled(kind) then return false end
        if kind=='entry' then return self:open() end
        if kind=='close' then return self:close() end
        if kind=='history' or kind=='current' then self.view,self.index,self.page=kind,1,1
        elseif kind=='newer' or kind=='older' then self.index,self.page=self.index+(kind=='newer' and -1 or 1),1
        else self.page=self.page+(kind=='previous' and -1 or 1) end
        self:invalidate();changed();return true
    end
    self.sync=function(_,allowed,epoch)
        if self.ownerEpoch~=epoch then self.ownerEpoch=epoch;self:invalidate() end
        self.allowed=allowed
        if not allowed and self.visible then self.visible=false;self:invalidate() end
        self:render()
    end
    self.disable=function(_)
        self.allowed,self.visible=false,false;self:invalidate();self:render()
    end
    local cursor=platform.cursorEvents or {}
    local paired=cursor.CursorDown and cursor.CursorUp
    local function bind(box,kind,order)
        local hit=box:GetChild('hit')
        local held,released
        local function touch(event)return event and event.touchId end
        local function current(token)return token and token.generation==self.generation and enabled(kind) end
        if paired then
            hit:AddCursorEventListener(cursor.CursorDown,function(event)
                if held and not current(held) then held=nil end
                if held and held.touch~=touch(event) then return end
                held,released=nil,nil
                if enabled(kind) then held={generation=self.generation,touch=touch(event)} end
            end)
            hit:AddCursorEventListener(cursor.CursorUp,function(event)
                if not held or held.touch~=touch(event) then return end
                released=current(held) and held or nil;held=nil
            end)
            for _,event in pairs({cursor.CursorExit,cursor.CursorEndDrag}) do
                if event then hit:AddCursorEventListener(event,function(pointer)
                    local owner=held or released
                    if not pointer or owner and owner.touch==touch(pointer) then held,released=nil,nil end
                end) end
            end
        end
        hit:AddCursorEventListener(clickEvent,function(event)
            if Controller.pointerBlocked(platform.controller) then return false end
            if paired then
                local token=released
                if not current(token) then
                    if not held or held.touch==touch(event) then held,released=nil,nil end
                    return false
                end
                if token.touch~=touch(event) then return false end
                held,released=nil,nil
            end
            return self:press(kind)
        end)
        Controller.bind(platform.controller,hit,kind=='entry' and 'menu' or 'releaseNotes',
            function()return self:press(kind)end,function()return enabled(kind)end,order)
    end
    bind(entry,'entry',110)
    for i,kind in ipairs({'close','history','current','newer','older','previous','next'}) do bind(panel:GetChild(kind),kind,i) end
    self:render()
    return self
end
return M
