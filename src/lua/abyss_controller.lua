-- Native focus/event adapter. Card-row wrapping follows STS1 CardRewardScreen's
-- updateControllerInput; engine calls use the official Miliastra Lua API.
local M = {}
local function visible(control)
    while control do
        if control.alive == false or control.visible == false or control.activeInHierarchy == false then return false end
        control = control.parent
    end
    return true
end
function M.new(api,root)
    if not api or not api.events or not api.getFocus or not api.setFocus then return nil end
    local manager = {api=api,records={},byControl={},memory={}}
    local function clear(control)
        control.canControllerFocus=false
        if control.GetChildren then for _,child in ipairs(control:GetChildren())do clear(child)end end
    end
    if root then clear(root) end
    function manager:eligible(record)
        if not record or self.byControl[record.control]~=record then return false end
        local scope=type(record.scope)=='function' and record.scope() or record.scope
        return not not (not self.disabled and scope==self.scope
            and visible(record.control) and record.control.raycastTarget~=false
            and (not record.enabled or record.enabled()))
    end
    function manager:focus(control)
        local record=self.byControl[control]
        if record and self:eligible(record) and self.api.isController() then
            self.api.setFocus(control);self.memory[self.scope]=control;return true
        end
        return false
    end
    function manager:sync(scope,cancel)
        local changed=self.scope~=scope
        if changed then
            local previous=self.api.getFocus()
            if previous and self.byControl[previous] then self.memory[self.scope or '']=previous end
            self.scope=scope
        end
        self.cancel=cancel
        local first,groups=nil,{}
        for _,record in ipairs(self.records) do
            local ok=self:eligible(record)
            if record.control.alive~=false and record.control.canControllerFocus~=ok then record.control.canControllerFocus=ok end
            if ok then
                if not first or record.order<first.order then first=record end
                if record.group then
                    local group=groups[record.group] or {};groups[record.group]=group;group[#group+1]=record
                end
            end
        end
        for _,group in pairs(groups) do
            table.sort(group,function(a,b)return a.order<b.order end)
            for i,record in ipairs(group) do
                for _,direction in ipairs({'Left','Right'}) do
                    local target=group[(i-1+(direction=='Left' and -1 or 1))%#group+1].control
                    record.links=record.links or {}
                    if record.links[direction]~=target then
                        record.control:SetControllerNavigation(self.api.directions[direction],self.api.modes.Specified,target)
                        record.links[direction]=target
                    end
                end
            end
        end
        local current=self.api.getFocus()
        local record=current and self.byControl[current]
        local using=self.api.isController()
        if not using then return end
        if changed or not record or not self:eligible(record) then
            local saved=self.memory[self.scope]
            if not (saved and self:focus(saved)) and first then self.api.setFocus(first.control) end
        end
    end
    function manager:tick()self.consumed=false end
    function manager:disable()
        self.disabled=true
        for _,record in ipairs(self.records)do if record.control.alive~=false then record.control.canControllerFocus=false end end
    end
    function manager:activate(control,fn,expected)
        local record=self.byControl[control]
        if expected and expected~=record then return false end
        if self.disabled or self.consumed or not self.api.isController()
            or self.api.getFocus()~=control or not self:eligible(record) then return false end
        self.consumed=true
        if self.beforeAction then self.beforeAction()end
        local result,reason=fn()
        if self.onChange then self.onChange() end
        return result,reason
    end
    return manager
end
-- Remove only one retired native handle; all card/hero records remain intact.
function M.unbind(manager,control,engineDestroyed)
    if not manager then return false end
    local record=manager.byControl[control]
    if not record then return false end
    manager.byControl[control]=nil
    for i=#manager.records,1,-1 do
        if manager.records[i]==record then table.remove(manager.records,i) end
    end
    for scope,saved in pairs(manager.memory)do if saved==control then manager.memory[scope]=nil end end
    for _,other in ipairs(manager.records)do
        if other.links then
            for direction,target in pairs(other.links)do if target==control then other.links[direction]=nil end end
        end
    end
    if not engineDestroyed and control.alive~=false then control.canControllerFocus=false end
    return true
end
function M.pointerBlocked(manager)
    return manager and manager.consumed and manager.api.isController() or false
end
function M.isController(manager)return manager and manager.api.isController() or false end
function M.bind(manager,control,scope,action,enabled,order,group,onFocus)
    if not manager then return action end
    assert(not manager.byControl[control],'duplicate controller binding')
    local record={control=control,scope=scope,enabled=enabled,order=order or 100,group=group}
    manager.byControl[control]=record;manager.records[#manager.records+1]=record
    control.canControllerFocus=false
    if manager.byControl[control]~=record then return action end
    control:AddNavigationEventListener(manager.api.events.Confirm,function()return manager:activate(control,action,record)end)
    if manager.byControl[control]~=record then return action end
    control:AddNavigationEventListener(manager.api.events.Cancel,function()
        return manager:activate(control,function()if manager.cancel then return manager.cancel()end return false end,record)
    end)
    if manager.byControl[control]~=record then return action end
    if onFocus and manager.api.events.Focus then
        control:AddNavigationEventListener(manager.api.events.Focus,function()
            if manager:eligible(record)then return onFocus()end
        end)
    end
    return action
end
return M
