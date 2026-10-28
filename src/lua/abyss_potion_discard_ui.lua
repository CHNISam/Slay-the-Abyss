-- Physical slots follow capacity; outside-combat use and discard are explicit.
local Run=require('abyss_run')
local Theme=require('abyss_theme')
local integer=require('abyss_numbers').integer
local M={}
local Controller=require('abyss_controller')
local function find(entries,id)for _,entry in ipairs(entries)do if entry.id==id then return entry end end end
-- Read-only shared entry paint. Keep the existing management button and its
-- binding; a slot silhouette never consumes a potion or changes selection.
function M.refreshEntry(hit,run,platform)
    local capacity=run and Run.potionCapacity(run) or 0
    for _,state in ipairs({'normal','hover','pressed','disabled'})do
        local variant=hit:GetChild(state)
        variant:GetChild('label').text=run and '药水 '..Run.potionCount(run)..'/'..capacity or '药水'
        for i=1,Theme.layout.battlePotions.count do
            local slot=variant:GetChild('slot'..i)
            local id=i<=capacity and run.potions[i] or nil
            slot:SetVisible(i<=capacity)
            slot:GetChild('emptyShell'):SetVisible(id==nil)
            slot:GetChild('filledShell'):SetVisible(id~=nil and id~='fire_potion')
            slot:GetChild('fireShell'):SetVisible(id=='fire_potion')
            slot:GetChild('selectedShell'):SetVisible(false)
            local bottle=slot:GetChild('bottle')
            bottle:SetVisible(id~=nil)
            if id then
                bottle:SetImage(platform.imageSource,Theme.icon.potion[id] or Theme.icon.intent.unknown)
                local colour=(id=='fire_potion' and Theme.color.potionShell.fire or Theme.color.potionShell.normal).ink
                bottle.imageColor=platform.color(colour.r,colour.g,colour.b,colour.a)
            end
        end
    end
end
function M.new(root,clickEvent,platform,allowed,onChange,onClose)
    local self={root=root,visible=false,generation=0}
    local function child(name)return assert(root:GetChild(name),'missing potion control '..name)end
    local function caption(name,value)
        local hit=child(name):GetChild('hit')
        for _,state in ipairs({'normal','hover','pressed','disabled'})do hit:GetChild(state):GetChild('label').text=value end
    end
    local function currentSelection()
        local s=self.selected
        return s and s.slot<=Run.potionCapacity(self.run) and self.run.potions==s.inventory and self.run.potions[s.slot]==s.id
            and self.run.phase==s.phase and self.run.combat==s.battle
    end
    local function detail(definition) local special=require('abyss_potion_text').special(definition,self.run,true);if special then return definition.name..'；'..special end
        if definition.description then return definition.name..'；'..definition.description end
        local result={definition.name}
        for _,effect in ipairs(definition.effects)do
            local value=integer(effect.value or 0)
            if effect.op=='damage'then result[#result+1]='对一个敌人造成 '..value..' 点伤害'
            elseif effect.op=='block'then result[#result+1]='获得 '..value..' 点格挡'
            elseif effect.op=='energy'then result[#result+1]='获得 '..value..' 点能量'
            elseif effect.status then
                local status=find(self.run.data.statuses.statuses,effect.status)
                result[#result+1]=(effect.op=='applyStatus' and '使一个敌人获得 ' or '获得 ')..value..' 层'..(status and status.name or effect.status)
            end
        end
        return table.concat(result,'；')
    end
    function self:render()
        if not self.visible then return end
        self.generation=self.generation+1
        if not currentSelection()then self.selected=nil end
        local capacity=Run.potionCapacity(self.run)
        for slot=1,Theme.layout.battlePotions.count do
            local id=self.run.potions[slot]
            local definition=id and find(self.run.data.potions.potions,id)
            child('slot'..slot):SetVisible(slot<=capacity)
            caption('slot'..slot,'槽 '..slot..'\n'..(definition and definition.name or '空槽'))
            local hit=child('slot'..slot):GetChild('hit');hit.interactable=slot<=capacity and definition~=nil;hit.raycastTarget=hit.interactable
        end
        local selected=self.selected
        child('detail').text=selected and detail(find(self.run.data.potions.potions,selected.id)) or '尚未选择药水。'
        local view=selected and Run.potionView(self.run)[selected.slot]
        local discard=child('discard'):GetChild('hit');discard.interactable=view and view.canDiscard~=false or false;discard.raycastTarget=discard.interactable
        local use=child('use'):GetChild('hit');use.interactable=self.run.phase~='combat' and view and view.canUse or false;use.raycastTarget=use.interactable
        if view and view.reason=='potion_event_restricted' then
            child('detail').text=child('detail').text..'\n此事件中不能使用或丢弃药水。'
        end
    end
    function self:open(run)
        if self.visible or not allowed(run)then return false end
        self.visible,self.run,self.selected=true,run,nil
        root:SetVisible(true);root:SetAsLastSibling();self:render();return true
    end
    function self:close()
        if not self.visible then return false end
        self.visible,self.run,self.selected=false,nil,nil
        self.generation=self.generation+1;root:SetVisible(false);return true
    end
    local function bind(name,action)
        local hit=child(name):GetChild('hit')
        local held,released,observed
        local function valid(token)
            return self.visible and allowed(self.run) and hit.interactable
                and (not token or token.run==self.run and token.generation==self.generation
                    and token.phase==self.run.phase and token.battle==self.run.combat
                    and token.inventory==self.run.potions
                    and (not token.battle or token.turn==token.battle.turn and token.battlePhase==token.battle.phase))
        end
        local cursor=platform.cursorEvents or {}
        Controller.bind(platform.controller,hit,'potions',action,function()return valid()end,name=='cancel' and 100 or 10)
        if cursor.CursorDown and cursor.CursorUp then
            hit:AddCursorEventListener(cursor.CursorDown,function(event)
                observed=true;held,released=nil,nil
                if valid()then held={run=self.run,generation=self.generation,touch=event and event.touchId,
                    phase=self.run.phase,battle=self.run.combat,inventory=self.run.potions,
                    turn=self.run.combat and self.run.combat.turn,battlePhase=self.run.combat and self.run.combat.phase}end
            end)
            hit:AddCursorEventListener(cursor.CursorUp,function(event)
                released=held and held.touch==(event and event.touchId) and valid(held) and held or nil;held=nil
            end)
            if cursor.CursorEndDrag then hit:AddCursorEventListener(cursor.CursorEndDrag,function()held,released=nil,nil end)end
        end
        hit:AddCursorEventListener(clickEvent,function(event)
            if Controller.pointerBlocked(platform.controller)then return false end
            if observed then
                local token=released;released=nil
                if not token or token.touch~=(event and event.touchId) or not valid(token)then return false end
            elseif not valid()then return false end
            return action()
        end)
    end
    for i=1,Theme.layout.battlePotions.count do
        local slot=i
        bind('slot'..slot,function()
            self.selected={slot=slot,id=self.run.potions[slot],inventory=self.run.potions,phase=self.run.phase,battle=self.run.combat}
            self:render();return true
        end)
    end
    bind('discard',function()
        if not currentSelection()then self:render();return false end
        local ok,reason=Run.discardPotion(self.run,self.selected.slot)
        self.selected=nil;self:render();if ok then onChange()end;return ok,reason
    end)
    bind('use',function()
        if not currentSelection() or self.run.phase=='combat' then self:render();return false end
        local ok,reason=Run.usePotion(self.run,self.selected.slot)
        self.selected=nil;self:render();if ok then onChange()end;return ok,reason
    end)
    bind('cancel',onClose)
    root.disableCursorEventPassthrough=true
    child('blocker'):AddCursorEventListener(clickEvent,function()return true end)
    root:SetVisible(false)
    return self
end
return M
