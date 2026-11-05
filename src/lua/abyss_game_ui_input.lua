local Run = require("abyss_run")
local CharacterSelect = require("abyss_character_select")
local Controller = require("abyss_controller")
local M = {}

function M.dismissFromOutside(controller,self)
    return function()
            if Controller.pointerBlocked(controller) then return true end
            if self.settlementRequested or self.settlementBusy then return true end
            self:closeExit()
            return true
        end
end

function M.bindCommand(platform,self,canManagePotions,controller,clickEvent,owner)
    return function(box, kind, action, enabled, order, group, onFocus)
            local hit = box:GetChild("hit")
            local held, released, observed
            local menuAction = kind == "start" or kind == "settle" or kind=='egg_open'
            local rewardAction = kind == "combatRewards"
            local characterAction = kind:match("^character_")~=nil
            local resourceAction = kind:match('^resource_')~=nil
            local cursor = platform.cursorEvents or {}
            local runMenuAction = kind:sub(1, 4) == 'run_'
            local function eggAvailable()
                if self.easterEggOpen then return kind=='egg_close' end
                return kind=='egg_open' and self.easterEgg:refresh()
            end
            local function menuAvailable()
                if menuAction then
                    if self.exitOpen or self.deckUI.visible then return false end
                    return self.mode == "victory" or self.mode == "defeat"
                        or kind == "start" and self.mode == "menu"
                end
                return kind == "open" and not self.exitOpen or kind ~= "open" and self.exitOpen == true
            end
            local function resultAvailable()
                if rewardAction then
                    return self.rewardReturnAvailable == true and self.mode == "map" and self.run and self.run.phase == "map" and self.run.pendingCombatRewards ~= nil
                        and not self.exitOpen and not self.deckUI.visible and not self.potionUI.visible
                end
                return menuAvailable()
            end
            local function characterAvailable()
                if characterAction then
                    return self.characterOpen==true and not self.exitOpen and not self.starting
                        and (not enabled or enabled())
                        and (self.mode=="menu" or self.mode=="defeat" or self.mode=="victory")
                end
                -- The exit modal owns confirmation/cancellation above selection.
                if self.characterOpen and not self.exitOpen and kind ~= 'open' then return false end
                return resultAvailable()
            end
            local function runMenuAvailable()
                if runMenuAction then return self.exitOpen and self.menuOpen == true and not self.routeOpen and (not enabled or enabled()) end
                if self.menuOpen or self.routeOpen then return false end
                return characterAvailable()
            end
            local function modalAvailable()
                if menuAction and self.motion.deathReveal then return false end
                if kind == 'routeClose' then return self.exitOpen and self.routeOpen == true end
                if kind == 'helpClose' then return self.exitOpen and self.controlsOpen == true end
                if self.controlsOpen then return false end
                return runMenuAvailable()
            end
            local function available()
                if self.disabled or self.settlementRequested or self.settlementBusy then return false end
                if resourceAction then return not self.potionUI.visible and canManagePotions(self.run) and (not enabled or enabled()) end
                if self.easterEggOpen or kind=='egg_open' or kind=='egg_close' then return eggAvailable()end
                return modalAvailable()
            end
            local function current(token)
                return token and token.generation == owner.exitGeneration and token.run == self.run
                    and (not resourceAction or token.deckGeneration==self.deckUI.generation and token.mode==self.mode
                        and token.potionGeneration==self.potionUI.generation)
                    and (not menuAction and not characterAction or token.menuGeneration == owner.menuGeneration) and available()
                    and (not rewardAction or token.menuGeneration == owner.menuGeneration and token.pending == self.run.pendingCombatRewards
                        and token.rewardGeneration == self.rewardReturnGeneration)
            end
            local function touch(event) return event and event.touchId end
            if cursor.CursorDown and cursor.CursorUp then
                hit:AddCursorEventListener(cursor.CursorDown, function(event)
                    if held and not current(held) then held = nil end
                    if released and not current(released) then released = nil end
                    if held and held.touch ~= touch(event) then return end
                    observed, held, released = true, nil, nil
                    if available() then held = {generation=owner.exitGeneration,menuGeneration=owner.menuGeneration,run=self.run,touch=touch(event),
                        deckGeneration=self.deckUI.generation,potionGeneration=self.potionUI.generation,mode=self.mode,
                        pending=self.run and self.run.pendingCombatRewards,rewardGeneration=self.rewardReturnGeneration} end
                end)
                hit:AddCursorEventListener(cursor.CursorUp, function(event)
                    if not held or held.touch ~= touch(event) then return end
                    released = current(held) and held or nil
                    held = nil
                end)
                for _, event in pairs({cursor.CursorExit, cursor.CursorEndDrag}) do
                    if event then hit:AddCursorEventListener(event, function(pointer)
                        local pointerOwner = held or released
                        if not pointer or pointerOwner and pointerOwner.touch == touch(pointer) then held, released = nil, nil end
                    end) end
                end
            end
            Controller.bind(controller,hit,function()
                if kind=='egg_close' then return 'easterEgg'end
                if characterAction then return 'characters' end
                if runMenuAction or kind=='routeClose' or kind=='cancel' or kind=='confirm' or kind=='help' or kind=='helpClose' then return 'exit' end
                return self.mode
            end,action,available,order or (kind=='cancel' and 1 or kind=='open' and 200 or 100),group,onFocus)
            hit:AddCursorEventListener(clickEvent, function(event)
                if Controller.pointerBlocked(controller)then return false end
                if observed or cursor.CursorDown and cursor.CursorUp and touch(event) ~= nil then
                    local token = released
                    if not current(token) then
                        if not held or held.touch == touch(event) then held, released = nil, nil end
                        return false
                    end
                    if token.touch ~= touch(event) then return false end
                    held, released = nil, nil
                elseif not available() then return false end
                return action()
            end)
        end
end

function M.installUtilities(self,child,clickEvent,controller,inCombat,exitPanel,runMenu)
    child("deckEntry"):GetChild("open"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:openDeck() end)
    child("relicEntry"):GetChild("open"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:openRelics() end)
    Controller.bind(controller,child('relicEntry'):GetChild('open'):GetChild('hit'),function()return self.mode end,
        function()return self:openRelics()end)
    child("potionEntry"):GetChild("open"):GetChild("hit"):AddCursorEventListener(clickEvent,function()if inCombat() then return false end;return self:openPotions()end)
    Controller.bind(controller,child('deckEntry'):GetChild('open'):GetChild('hit'),function()return self.mode end,
        function()return self:openDeck()end)
    Controller.bind(controller,child('potionEntry'):GetChild('open'):GetChild('hit'),function()return self.mode end,
        function()if inCombat() then return false end;return self:openPotions()end)
    exitPanel.disableCursorEventPassthrough = true
    exitPanel:GetChild("blocker"):AddCursorEventListener(clickEvent, function() return true end)
    runMenu.disableCursorEventPassthrough = true
    -- TASK-4.16 AC#1：点菜单/说明外的空白 = 非破坏性返回（继续游戏 / 回到菜单），
    -- 永不触发放弃本局；点击被吞掉，不会穿透到后台战斗或地图。
    local dismissFromOutside = M.dismissFromOutside(controller,self)
    runMenu:GetChild('blocker'):AddCursorEventListener(clickEvent, function()
        if self.exitOpen and self.menuOpen and not self.controlsOpen and not self.routeOpen then return dismissFromOutside() end
        return true
    end)
    runMenu:GetChild('catch'):AddCursorEventListener(clickEvent, function() return true end)
    return dismissFromOutside
end

function M.installMenu(self,child,clickEvent,resourceHint,bindCommand,start,settlement,exitEntry,exitPanel)
    for _,entry in ipairs({{'battlePanel','battle'},{'mapPanel','map'}})do
        local panel,mode=entry[1],entry[2]
        for _,kind in ipairs({'hp','gold'})do
            bindCommand(child(panel):GetChild('resourceHints'):GetChild(kind),'resource_'..kind,
                function()return resourceHint(kind)end,function()return self.mode==mode end,20)
        end
    end
    -- Source menu actions use the same pointer ownership as exit actions, and also
    -- expire whenever their menu/run context is hidden or replaced.
    bindCommand(start, "start", function() return self:start() end)
    bindCommand(settlement, "settle", function() return self:settle() end)
    if self.easterEgg then
        local egg=self.easterEgg
        egg.panel:GetChild('blocker'):AddCursorEventListener(clickEvent,function()return true end)
        bindCommand(egg.button,'egg_open',function()return egg:open()end)
        bindCommand(egg.panel:GetChild('close'),'egg_close',function()return egg:close()end)
    end
    bindCommand(child("combatRewards"), "combatRewards", function()
        local ok, reason = Run.reopenCombatRewards(self.run)
        if ok then self:refresh() end
        return ok, reason
    end)
    bindCommand(exitEntry:GetChild("open"), "open", function() return self:openMenu() end)
    bindCommand(exitPanel:GetChild("cancel"), "cancel", function() return self:closeExit() end)
    bindCommand(exitPanel:GetChild("confirm"), "confirm", function() return self:confirmExit() end)
end

function M.installGuide(self,exitPanel,clickEvent,bindCommand,dismissFromOutside,runMenu,canViewRoute,child,owner)
    local guide = exitPanel:GetChild('guide')
    if guide then
        bindCommand(exitPanel:GetChild('help'), 'help', function()
            owner.exitGeneration = owner.exitGeneration + 1
            self.controlsOpen = true
            guide:SetVisible(true)
            self:refresh()
            return true
        end)
        bindCommand(guide:GetChild('close'), 'helpClose', function() return self:closeExit() end)
        guide:GetChild('blocker'):AddCursorEventListener(clickEvent, function()
            if self.exitOpen and self.controlsOpen then return dismissFromOutside() end
            return true
        end)
        guide:GetChild('catch'):AddCursorEventListener(clickEvent, function() return true end)
    end
    bindCommand(runMenu:GetChild('help'), 'run_help', function()
        owner.exitGeneration = owner.exitGeneration + 1
        self.controlsOpen = true
        guide:SetVisible(true)
        self:refresh()
        return true
    end)
    bindCommand(runMenu:GetChild('resume'), 'run_resume', function() return self:closeExit() end)
    bindCommand(runMenu:GetChild('abandon'), 'run_abandon', function()
        owner.exitGeneration = owner.exitGeneration + 1
        self.menuOpen = false
        self:refresh()
        return true
    end)
    bindCommand(runMenu:GetChild('map'), 'run_map', function()
        owner.exitGeneration = owner.exitGeneration + 1
        self.routeOpen = true
        self:refresh()
        return true
    end, canViewRoute)
    bindCommand(child('mapPanel'):GetChild('previewBack'), 'routeClose', function() return self:closeExit() end)
end

function M.installCharacters(self,characterPanel,clickEvent,bindCommand,selectionChanged,controller)
    characterPanel.disableCursorEventPassthrough=true
    characterPanel:GetChild("blocker"):AddCursorEventListener(clickEvent,function()return true end)
    bindCommand(characterPanel:GetChild("cancel"),"character_cancel",function() return self:closeCharacters() end,nil,90)
    bindCommand(characterPanel:GetChild('confirm'),'character_confirm',function()return self:confirmCharacter()end,
        function()return self.characterSelection:canConfirm() and not self.characterSelection.deckOpen end,100)
    -- 查看初始牌组（STS 式卡面网格）；返回/取消先关牌组再退选角。
    bindCommand(characterPanel:GetChild('details'):GetChild('deckOpen'),'character_deck',function()
        if not self.characterSelection.info then return false end
        self.characterSelection.deckOpen=true;selectionChanged();return true
    end,function()return self.characterSelection.info~=nil and not self.characterSelection.deckOpen end,95)
    local deckView=characterPanel:GetChild('deckView')
    deckView:GetChild('catch'):AddCursorEventListener(clickEvent,function()return true end)
    bindCommand(deckView:GetChild('close'),'character_deckClose',function()
        if not self.characterSelection.deckOpen then return false end
        self.characterSelection.deckOpen=false;selectionChanged();return true
    end,function()return self.characterSelection.deckOpen==true end,96)
    for i,id in ipairs(CharacterSelect.characters)do
        local box=characterPanel:GetChild(i==5 and 'traveler' or 'character'..i)
        bindCommand(box,'character_'..i,function()return self:selectCharacter(id)end,
            function()return self.characterSelection:allowsCharacter(id)end,i,'characters',
            function()if Controller.isController(controller)then return self:selectCharacter(id)end end)
    end
    for i,id in ipairs(CharacterSelect.elements)do
        bindCommand(characterPanel:GetChild('elements'):GetChild('element'..i),'character_element'..i,
            function()return self:selectElement(id)end,function()return self.characterSelection.character=='traveler'
                and self.characterSelection:allowsElement(id)end,
            10+i,'elements',function()if Controller.isController(controller)then return self:selectElement(id)end end)
    end
end

return M
