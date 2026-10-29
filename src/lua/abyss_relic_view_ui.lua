-- TASK-4.7 owned-relic art slots: a top-bar disc row plus a read-only detail
-- overlay. Each entry is icon disc + Chinese name + status chip + effect text.
-- Icons bind Theme.icon.relic[id]; placeholder ids are swapped by data only.
local Theme=require('abyss_theme')
local Controller=require('abyss_controller')
local Hooks=require('abyss_relic_hooks')
local Rewards=require('abyss_relic_rewards')
local M={}
local function iconId(value)if type(value)=='table'then value=value.id end return type(value)=='number' and value or nil end
function M.icon(id)
    local local_=Hooks.localId(id)
    return iconId(Theme.icon.relic[local_]) or iconId(Theme.icon.relic[id]) or iconId(Theme.icon.node.treasure)
end
-- Counter meanings differ per relic, so only well-understood ones get wording.
function M.status(run,id)
    local local_=Hooks.localId(id)
    local counters=run.relicCounters or {}
    local v=counters[local_]; if v==nil then v=counters[id] end
    if type(v)~='number' then return nil end
    if local_=='neows_lament' then return v==-2 and '已耗尽' or ('剩余 '..v..' 场') end
    if local_=='maw_bank' then return v==-2 and '已失效' or nil end
    if local_=='ancient_tea_set' then return v==-2 and '已蓄能' or nil end
    if v==-2 then return '已耗尽' end
    if v>=0 then return '计数 '..v end
    return nil
end
local function perPage()return #Theme.layout.relicView.rows*#Theme.layout.relicView.columns end
function M.new(root,bar,clickEvent,platform,describe,onClose,onSlot,barScope)
    local self={root=root,bar=bar,visible=false,page=1}
    local function child(name)return assert(root:GetChild(name),'missing relic control '..name)end
    local function picture(control,id)if platform.imageSource then control:SetImage(platform.imageSource,id)end end
    function self.entry(_,run,i)
        local id=run.relics[i]
        local definition=Rewards.definition(run,id)
        local description=definition and describe(run,definition.id) or ''
        return {id=id,name=definition and definition.name or '未识别遗物',icon=M.icon(id),
            status=M.status(run,id),description=description~='' and description or '效果说明待补充。'}
    end
    function self.pages()return math.max(1,math.ceil(#(self.run and self.run.relics or {})/perPage()))end
    function self.render(_)
        local run,n=self.run,perPage()
        child('title').text='持有遗物 · '..#run.relics..' 件'
        self.rows={}
        for slot=1,n do
            local row=child('row'..slot)
            local i=(self.page-1)*n+slot
            if i<=#run.relics then
                local e=self:entry(run,i);self.rows[slot]=e
                picture(row:GetChild('slot'):GetChild('icon'),e.icon)
                row:GetChild('name').text=e.name
                row:GetChild('description').text=e.description
                row:GetChild('chip'):SetVisible(e.status~=nil)
                row:GetChild('chip'):GetChild('label').text=e.status or ''
                row:SetVisible(true)
            else row:SetVisible(false) end
        end
        local many=self:pages()>1
        for _,name in ipairs({'previous','next','pageHint'})do child(name):SetVisible(many)end
        child('pageHint').text=many and ('第 '..self.page..'/'..self:pages()..' 页') or ''
        child('placeholder'):SetVisible(#run.relics==0)
    end
    function self.open(_,run,index)
        if self.visible or not run then return false end
        self.visible,self.run=true,run
        self.page=index and math.floor((index-1)/perPage())+1 or 1
        root:SetVisible(true);root:SetAsLastSibling()
        self:render();return true
    end
    function self.close(_)
        if not self.visible then return false end
        self.visible,self.run,self.rows=false,nil,nil
        root:SetVisible(false);return true
    end
    function self.turn(_,step)
        if not self.visible or self:pages()<2 then return false end
        self.page=(self.page-1+step)%self:pages()+1;self:render();return true
    end
    -- Owned-only row like the prototype topBar(); overflow is reached via the
    -- existing 遗物 N button and the paginated overlay.
    function self.refreshBar(_,run,visible)
        bar:SetVisible(visible and run~=nil)
        for i=1,Theme.layout.relicView.bar.count do
            local slot=bar:GetChild('slot'..i)
            local id=run and run.relics[i]
            slot:SetVisible(id~=nil)
            if id then picture(slot:GetChild('icon'),M.icon(id))end
        end
    end
    root.disableCursorEventPassthrough=true
    child('blocker'):AddCursorEventListener(clickEvent,function()return true end)
    local actions={close=function()return onClose()end,previous=function()return self:turn(-1)end,next=function()return self:turn(1)end}
    for name,action in pairs(actions)do
        local hit=child(name):GetChild('hit')
        hit:AddCursorEventListener(clickEvent,function()return action()end)
        Controller.bind(platform.controller,hit,'deck',action,function()return self.visible end)
    end
    for i=1,Theme.layout.relicView.bar.count do
        local hit=bar:GetChild('slot'..i):GetChild('hit')
        hit:AddCursorEventListener(clickEvent,function()return onSlot(i)end)
        Controller.bind(platform.controller,hit,barScope,function()return onSlot(i)end)
    end
    return self
end
return M
