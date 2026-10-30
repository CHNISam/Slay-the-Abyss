-- Host for the same-run map, node and battle controllers. Only commands change rules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Nodes = require("abyss_nodes")
local BattleUI = require("abyss_battle_ui")
local MapUI = require("abyss_map_ui")
local NodeUI = require("abyss_node_ui")
local DeckUI = require("abyss_deck_ui")
local PotionDiscardUI = require("abyss_potion_discard_ui")
local Narrative = require("abyss_narrative")
local Bgm = require("abyss_bgm")
local CharacterSelect = require("abyss_character_select")
local CharacterView = require("abyss_character_select_view")
local Controller = require("abyss_controller")
local MenuView=require("abyss_game_ui_menu_view")
local M = {}
local number = require("abyss_numbers").integer
local RunSeed = require("abyss_run_seed")
local NeowHistory=require('abyss_neow_history')
local EndingHistory=require('abyss_ending_history')
local Acts=require('abyss_acts')

function M.new(root, data, presentation, clickEvent, platform)
    -- A seed is an explicit replay/test override. Normal runs sample at Start,
    -- never while constructing the title screen or refreshing the UI.
    local self = { root = root, data = data, seed = platform.seed, mode = "menu" }
    local neowHistory=NeowHistory.new(platform.readNeowHistory)
    local endingHistory=EndingHistory.new({read=platform.readEndingHistory,write=platform.writeEndingHistory})
    local controller = Controller.new(platform.controllerApi,root)
    self.controller = controller
    platform.controller = controller
    local newSeed = platform.newSeed or function() return require("abyss_new_run_seed").next() end
    local bgm = Bgm.new(platform.music)
    local function child(name) return assert(root:GetChild(name), "missing game panel " .. name) end
    local menu = child("menuPanel")
    local exitPanel, exitEntry = child("exitPanel"), child("exitEntry")
    local runMenu = child("runMenu")
    local exitGeneration, menuGeneration = 0, 0
    local codeVersion = assert(menu:GetChild('codeVersion'), 'missing game menu codeVersion')
    codeVersion.text = Narrative.codeVersion or '未知'
    local characterPanel = child("characterPanel")
    self.characterSelection=CharacterSelect.new(data,presentation,platform.campaignProfile or platform.characterProfile)
    self.fastMode=false
    self.setFastMode=function(_,enabled)
        if type(enabled)~='boolean' or self.disabled or self.battleUI and self.battleUI.busy then return false end
        if self.mode~='menu' or self.characterOpen or self.exitOpen
            or (self.deckUI and self.deckUI.visible)
            or (self.potionUI and self.potionUI.visible) or (self.choiceUI and self.choiceUI.visible)
            or self.settlementRequested or self.settlementBusy then return false end
        self.fastMode=enabled
        if self.battleUI then self.battleUI.fastMode=enabled;self.battleUI.feedback:setFastMode(enabled)end
        return true
    end
    local menuRun, menuMode
    local requestSettlement
    local ready = false
    local function openingCovered()return self.prologue and self.prologue:covering() or false end
    local function canViewRoute()
        return self.run~=nil and self.map~=nil and not self.characterOpen and not openingCovered()
            and not self.disabled and not self.settlementRequested and not self.settlementBusy
    end
    local function changed(_, reason)
        if not ready then return end
        if self.run and self.run.phase == 'act_transition' and (reason == 'continue' or reason == 'complete') then
            return self:advanceAct()
        end
        self:refresh()
    end
    self.battleUI = BattleUI.new(child("battlePanel"), data, presentation, clickEvent,
        platform, { embedded = true, onChange = changed, onPile=function(kind)return self:openDeck(kind)end })
    self.mapUI = MapUI.new(child("mapPanel"), nil, function(node)
        if self.disabled or not self.run or self.mode ~= "map" or self.deckUI and self.deckUI.visible then return false, "not_on_map" end
        local ok, reason = Nodes.enter(self.run, self.map, node.id)
        if ok then changed() end
        return ok, reason
    end, clickEvent, { embedded = true, color = platform.color, imageSource = platform.imageSource,
        cursor = platform.cursorEvents, controller = controller })
    self.nodeUI = NodeUI.new(child("nodePanel"), nil, nil,
        presentation, clickEvent, changed, { color = platform.color, imageSource = platform.imageSource,
            imageTypes = platform.imageTypes,
            cursorEvents = platform.cursorEvents, sound = platform.sound, controller = controller, touchScreen = platform.touchScreen,
            enhancedRooms=true,
            onInspectCard=function(definition,upgraded)
                if not self.run or self.disabled or self.mode~='node' or self.exitOpen
                    or self.deckUI.visible or self.potionUI.visible or self.settlementRequested then return false end
                if not self.deckUI:inspect(self.run,definition,upgraded) then return false end
                self:refresh();return true
            end })
    self.deckUI = DeckUI.new(child("deckPanel"), presentation, clickEvent, platform, function() return self:closeDeck() end)
    do
        self.choiceUI = require("abyss_choice_ui").new(child("choicePanel"),presentation,clickEvent,platform,
            function(kind,uids,token,generation,battle)
                return self.battleUI:chooseCards(kind,uids,token,generation,battle)
            end)
    end
    local function inCombat()
        return self.mode=="battle" and self.run~=nil and self.run.phase=="combat"
    end
    local function canManagePotions(run)
        return not openingCovered() and not self.disabled and run~=nil and self.run==run and not self.exitOpen and not self.deckUI.visible
            and not (self.choiceUI and self.choiceUI.visible)
            and not self.battleUI.busy and not self.settlementBusy and not self.settlementRequested
            and (self.mode=="map" or self.mode=="battle" or self.mode=="node")
            and (run.phase=="map" or run.phase=="node" or run.phase=="reward" or run.phase=="combat")
    end
    self.relicUI=require('abyss_relic_view_ui').new(child('relicPanel'),child('relicBar'),clickEvent,platform,
        function(run,id)return self.nodeUI:describeRelic(run,id)end,function()return self:closeDeck()end,
        function(i)return self:openRelics(i)end,function()return self.mode end)
    self.potionUI=PotionDiscardUI.new(child("potionPanel"),clickEvent,platform,canManagePotions,changed,
        function()return self:closePotions()end)
    self.openPotions = function(_)
        if not self.potionUI:open(self.run)then return false end
        self.battleUI.selected=nil;self:refresh();return true
    end
    self.closePotions = function(_)
        if not self.potionUI:close()then return false end
        self.battleUI.suppressClick=false;self:refresh();return true
    end
    local prologuePanel = root:GetChild("prologuePanel")
    -- The cinematic camera and its skip control were cancelled. Keep the panel
    -- hidden so it cannot mask Neow or leave an old click target.
    self.prologue=nil
    if prologuePanel then prologuePanel:SetVisible(false) end

    self.openExit = function(_)
        if self.disabled or self.characterOpen or self.exitOpen or self.settlementRequested or self.settlementBusy then return false end
        exitGeneration = exitGeneration + 1
        self.potionUI:close()
        self.exitOpen, self.exitError = true, nil
        self.battleUI.selected = nil
        self:refresh()
        return true
    end
    self.openMenu = function(_)
        if self.disabled or self.exitOpen or self.settlementRequested or self.settlementBusy then return false end
        exitGeneration = exitGeneration + 1
        self.exitOpen, self.menuOpen, self.exitError = true, true, nil
        self:refresh()
        return true
    end
    self.closeExit = function(_)
        if not self.exitOpen or self.settlementRequested or self.settlementBusy then return false end
        exitGeneration = exitGeneration + 1
        if self.routeOpen then
            self.routeOpen = false
            self:refresh()
            return true
        end
        if self.controlsOpen then
            self.controlsOpen = false
            exitPanel:GetChild('guide'):SetVisible(false)
            self:refresh()
            return true
        end
        self.exitOpen, self.menuOpen, self.exitError = false, false, nil
        self.battleUI.suppressClick = false
        self:refresh()
        return true
    end
    self.confirmExit = function(_)
        if self.disabled then return false,"ui_disabled" end
        if self.controlsOpen or self.menuOpen or self.routeOpen then return false,"menu_open" end
        if not self.exitOpen then return false, "exit_not_open" end
        -- Voluntary departure never changes combat HP, awards a victory, or
        -- fakes a defeated Run. An already-earned victory keeps its outcome.
        return requestSettlement(self.mode == "victory")
    end

    self.openDeck = function(_,pileKind)
        if openingCovered() or self.disabled or self.characterOpen or self.choiceUI and self.choiceUI.visible or self.exitOpen or self.potionUI.visible or not self.run or self.battleUI.busy or self.settlementBusy or self.settlementRequested
            or (self.mode ~= "map" and self.mode ~= "battle" and self.mode ~= "node") then return false end
        if pileKind then
            if self.mode~='battle' or not self.deckUI:openPile(self.run,pileKind)then return false end
        elseif not self.deckUI:open(self.run)then return false end
        self.battleUI.selected = nil
        self:refresh()
        return true
    end
    -- TASK-4.7 owned relics: icon-disc slots, not a text dump. Opening rides
    -- the deck gate so it stays read-only for battle, map, camp and chest.
    self.openRelics = function(_,index)
        if self.deckUI.visible or not self:openDeck() then return false end
        self.deckUI:close()
        if not self.deckUI:inspectRelics(self.run,self.relicUI,index) then return false end
        self:refresh();return true
    end
    self.closeDeck = function(_)
        if self.exitOpen or self.settlementRequested then return false end
        if self.deckUI.choiceToken then return false,"card_choice_pending" end
        if not self.deckUI:close() then return false end
        -- Resume click-only hosts; pointer-capable card input still requires its
        -- own fresh Down/Up identity. Closing an overlay cannot revive old clicks.
        self.battleUI.suppressClick = false
        self:refresh()
        return true
    end

    local menuView = MenuView.new(self,menu,data,platform)
    local start,settlement=menuView.start,menuView.settlement
    local function present() MenuView.present(menuView) end
    self.animate=function(_,dt) MenuView.animate(menuView,dt) end

    function self.syncController(_)
        if not controller then return end
        local scope=self.mode
        if self.disabled or self.settlementRequested or self.settlementBusy then scope='blocked'
        elseif self.exitOpen then scope='exit'
        elseif self.motion.deathReveal then scope='blocked'
        elseif self.characterOpen then scope='characters'
        elseif openingCovered() then scope='blocked'
        elseif self.choiceUI and self.choiceUI.visible then scope='choice'
        elseif self.deckUI.visible then scope='deck'
        elseif self.potionUI.visible then scope='potions'
        elseif self.mode=='battle' and self.battleUI.potionMenu then scope='battlePotion'
        elseif self.mode=='battle' and self.battleUI.info then scope='battleInfo'
        elseif self.mode=='battle' and (self.battleUI.selected or self.battleUI.potionAim) then scope='aim' end
        controller:sync(scope,function()
            if scope=='exit' then return self:closeExit()
            elseif scope=='characters' then return self:closeCharacters()
            elseif scope=='blocked' and openingCovered() then return false
            elseif scope=='deck' then
                if self.deckUI.choiceToken then return false end
                return self.deckUI:back()
            elseif scope=='choice' then return false -- mandatory core selections cannot be dismissed
            elseif scope=='potions' then return self:closePotions()
            elseif scope=='battlePotion' or scope=='battleInfo' or scope=='aim' then return self.battleUI:controllerBack()
            elseif scope=='node' and self.nodeUI.mode=='picker' then return self.nodeUI:press('back')
            elseif scope=='battle' and self.run and self.run.phase=='reward' and self.battleUI.rewardScreen=='cards' then
                return self.battleUI:controllerBack()
            elseif scope~='blocked' then return self:openMenu() end
            return false
        end)
    end
    local function finishRunFlow(run)
        if run and (run.phase=='victory' or run.phase=='defeat')then NeowHistory.finish(neowHistory,run,run.phase)end
        if run and EndingHistory.finish(endingHistory,run,self.map)then run.endingHistoryResult=EndingHistory.read(endingHistory)end
        if not self.exitOpen and not self.settlementRequested and run and run.phase == "map" and run.nodeFlow and not run.nodeFlow.complete then
            Nodes.completeCombat(run, self.map)
        end
    end
    local function selectMode(run)
        if self.battleUI.busy then self.mode = "battle"
        elseif not run then self.mode = "menu"
        elseif run.phase == "defeat" then self.mode = "defeat"
        elseif run.phase == "victory" then self.mode = "victory"
        elseif run.phase == "combat" or run.phase == "reward" then self.mode = "battle"
        elseif run.phase == "node" or run.phase == 'act_transition' or run.phase=='ending_proceed' then self.mode = "node"
        -- Camp/event results stay on screen until the player presses 继续.
        elseif self.nodeUI.run == run and self.nodeUI:holding() then self.mode = "node"
        else self.mode = "map" end
    end
    local function syncMenuContext(run,inMenu)
        if menuRun ~= run or menuMode ~= self.mode then
            menuGeneration = menuGeneration + 1
            menuRun, menuMode = run, self.mode
        end
        if self.characterOpen and (not inMenu or self.settlementRequested or self.settlementBusy) then
            self.characterOpen=false;exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
        end
    end
    local function syncCardChoice(run)
        if self.choiceUI then
            self.choiceUI:refresh(run,not self.battleUI.busy and not self.exitOpen and not self.settlementRequested
                and not self.settlementBusy and not self.deckUI.visible and not self.potionUI.visible)
        end
    end
    local function closeStaleDeck(run,inMenu)
        if self.deckUI.visible and (inMenu or run and run.phase=='ending_proceed' or self.battleUI.busy or self.deckUI.run ~= run
        or self.deckUI.pileKind and (run.phase~='combat' or run.combat~=self.deckUI.battle))then self.deckUI:close()end
    end
    local function openCardChoice(run)
        if run and run.phase=="combat" and run.combat.pendingChoice and not self.battleUI.busy
            and not self.deckUI.visible and not self.exitOpen then
            self.deckUI:open(run,run.combat.pendingChoice,function(token,uid)
                self.battleUI:chooseCard(token,uid)
                self:refresh()
            end)
        end
    end
    local function syncRewardReturn(run,deckOpen,potionOpen,blocked,covering)
        local returnAvailable = self.mode == "map" and run and run.pendingCombatRewards ~= nil
            and not deckOpen and not potionOpen and not blocked and not covering or false
        if self.rewardReturnAvailable ~= returnAvailable then
            self.rewardReturnAvailable = returnAvailable
            self.rewardReturnGeneration = (self.rewardReturnGeneration or 0) + 1
        end
        return returnAvailable
    end
    local function refreshPotionEntry(run)
        local potionHit=child("potionEntry"):GetChild("open"):GetChild("hit")
        potionHit.interactable=not inCombat() and canManagePotions(run);potionHit.raycastTarget=potionHit.interactable
        PotionDiscardUI.refreshEntry(potionHit,run,platform)
    end
    local function refreshDeckEntry(run)
        local deckHit = child("deckEntry"):GetChild("open"):GetChild("hit")
        deckHit.interactable = not self.battleUI.busy;deckHit.raycastTarget=deckHit.interactable
        -- The shared deck button carries the deck size, so no screen repeats it as loose text.
        for _, state in ipairs({ "normal", "hover", "pressed", "disabled" }) do
            local variant = deckHit:GetChild(state)
            if variant then
                variant:GetChild("label").text = run and "卡组 " .. #run.deck or "卡组"
                variant:GetChild('count').text=run and number(#run.deck) or ''
            end
        end
    end
    local function refreshUtilities(run,inMenu,deckOpen,potionOpen,blocked,covering,returnAvailable)
        local ending=run and run.phase=='ending_proceed'
        local utilitiesVisible=not ending and not inMenu and not deckOpen and not potionOpen and not blocked and not covering
        child("combatRewards"):SetVisible(returnAvailable)
        child("deckEntry"):SetVisible(utilitiesVisible)
        child("relicEntry"):SetVisible(utilitiesVisible)
        self.relicUI:refreshBar(run,utilitiesVisible)
        for _,state in ipairs({'normal','hover','pressed','disabled'})do
            child('relicEntry'):GetChild('open'):GetChild('hit'):GetChild(state):GetChild('label').text=run and '遗物 '..#run.relics or '遗物'
        end
        child("potionEntry"):SetVisible(not inCombat() and utilitiesVisible)
        refreshPotionEntry(run)
        child("nodePanel"):GetChild("potions"):SetVisible(false)
        if potionOpen then self.potionUI:render()end
        refreshDeckEntry(run)
    end
    local function refreshMapResources(run)
        if run then
            local resources = child("mapPanel"):GetChild("resources")
            resources:GetChild("hp").text = number(run.hp) .. "/" .. number(run.maxHp)
            resources:GetChild("gold").text = number(run.gold)
        end
    end
    local function refreshPageVisibility(run,inMenu,deckOpen,potionOpen,blocked)
        menu:SetVisible(inMenu)
        self.battleUI:setActive(self.mode == "battle" and not deckOpen and not potionOpen and not blocked)
        child("battlePanel"):SetVisible(self.mode == "battle")
        self.mapUI:setVisible(self.mode == "map" and not deckOpen and not potionOpen and not blocked)
        child("mapPanel"):SetVisible(self.mode == "map")
        refreshMapResources(run)
        self.nodeUI:setVisible(self.mode == "node" and not deckOpen and not potionOpen and not blocked)
        child("nodePanel"):SetVisible(self.mode == "node")
    end
    local function renderBattlePage(run)
        self.battleUI:render()
        if run.phase == "combat" and self.presentedBattle ~= run.combat then
            self.presentedBattle = run.combat
            local guardian = false
            for _, enemy in ipairs(run.combat.enemies) do
                if enemy.definitionId == "guardian" then guardian = true end
            end
            child("battlePanel"):GetChild("notice").text = guardian
                and Narrative.flow.bossEntrance.full or ""
        end
    end
    local function renderMapPage(run,deckOpen,potionOpen,blocked,covering)
        -- While the cinematic's last fade uncovers the map, the map is visible but inert.
        self.mapUI:setNavigationEnabled(not deckOpen and not potionOpen and not blocked and not covering and #Nodes.available(run, self.map) > 0)
        if run.neowStatus=='unavailable' and self.map.floor==0 and not self.mapUI.entryError then
            self.mapUI.entryError='开局恩赐暂不可用：未取得上一局历史；本次保持原开局资源。'
            self.mapUI:render()
        end
    end
    local function renderCurrentPage(run,deckOpen,potionOpen,blocked,covering)
        if self.mode == "battle" then
            renderBattlePage(run)
        elseif self.mode == "map" then
            renderMapPage(run,deckOpen,potionOpen,blocked,covering)
        elseif self.mode == "node" then self.nodeUI:render() end
    end
    local function exitDialogOwnsForeground()
        return self.exitOpen == true and not self.routeOpen and (not self.menuOpen or self.controlsOpen == true)
    end
    local function refreshExitDialog()
        if exitDialogOwnsForeground() then
            exitPanel:SetAsLastSibling()
            local message = self.run and "确认退出本局？目前无法保存进度，退出后本局结束。\n将进入平台结算，随后可选择离开。"
                or "确认结束当前关卡？\n将进入平台结算，随后可选择离开。"
            if self.mode == "victory" then message = "确认结束本局并结算胜利？\n随后可在平台结算页选择离开。" end
            exitPanel:GetChild("message").text = message
            -- Lv.4 局内存档未开放：仅在进行中的一局里，用一行小字说明原因。
            local why = self.run ~= nil and self.mode ~= "victory"
            exitPanel:GetChild("whyText"):SetVisible(why)
            exitPanel:GetChild("whyText").text = why and "存档功能需作者达到创作者 4 级后开放，喜欢的话欢迎点赞支持。" or ""
            exitPanel:GetChild("status").text = self.settlementRequested and "结算请求已发送，等待平台结算界面。"
                or self.exitError and "退出请求失败，请重试或继续游戏。" or ""
            local enabled = not self.settlementRequested and not self.settlementBusy
            for _, name in ipairs({"cancel", "confirm"}) do
                local hit=exitPanel:GetChild(name):GetChild("hit");hit.interactable,hit.raycastTarget=enabled,enabled
            end
        end
    end
    local function refreshForeground()
        codeVersion:SetVisible(self.mode=='menu')
        if characterPanel then
            characterPanel:SetVisible(self.characterOpen==true)
            if self.characterOpen then
                CharacterView.render(characterPanel,self.characterSelection,platform)
                characterPanel:SetAsLastSibling()
            end
        end
        if self.choiceUI and self.choiceUI.visible then self.choiceUI.root:SetAsLastSibling() end
        -- Shared utilities stay above the deck overlay; the confirmation stays
        -- above every page, including an in-flight battle presentation.
        exitEntry:SetVisible(not self.exitOpen and not self.settlementRequested and not self.settlementBusy)
        exitEntry:SetAsLastSibling()
        exitPanel:SetVisible(exitDialogOwnsForeground())
        runMenu:SetVisible(self.exitOpen == true and self.menuOpen == true and not self.controlsOpen and not self.routeOpen)
        local routeHit=runMenu:GetChild('map'):GetChild('hit')
        local routeEnabled=canViewRoute()
        routeHit.interactable,routeHit.raycastTarget=routeEnabled,routeEnabled
        for _,state in ipairs({'normal','hover','pressed','disabled'})do
            routeHit:GetChild(state):GetChild('label').text=routeEnabled and '查看地图' or '查看地图（启程后可用）'
        end
        if runMenu.visible then runMenu:SetAsLastSibling() end
        local back = child('mapPanel'):GetChild('previewBack')
        back:SetVisible(self.routeOpen == true)
        if self.routeOpen then
            self.mapUI.map = self.map
            self.mapUI:setVisible(true)
            self.mapUI:setNavigationEnabled(false)
            child('mapPanel'):SetAsLastSibling()
        end
        refreshExitDialog()
    end
    local function overlaysBlocked()
        local blocked = self.exitOpen or self.settlementRequested or self.settlementBusy or self.characterOpen
            or self.choiceUI and self.choiceUI.visible
        return blocked
    end
    local function syncOpening(run)
        if self.prologue and (self.settlementRequested or run and (run.phase=='defeat' or run.phase=='victory')) then self.prologue:cancel() end
        return openingCovered()
    end
    local function openingForeground(covering)
        if self.prologue and self.prologue:opaque() then
            child('mapPanel'):SetVisible(false);child('nodePanel'):SetVisible(false)
        end
        if not covering then return end
        prologuePanel:SetAsLastSibling();child('exitEntry'):SetAsLastSibling()
        if self.menuOpen then runMenu:SetAsLastSibling()
        elseif self.exitOpen then exitPanel:SetAsLastSibling() end
    end
    self.refresh = function(_)
        if self.disabled then return false,"ui_disabled" end
        local run = self.run
        finishRunFlow(run)
        local covering = syncOpening(run)
        selectMode(run)
        local inMenu = self.mode == "menu" or self.mode == "defeat" or self.mode == "victory"
        syncMenuContext(run,inMenu)
        syncCardChoice(run)
        closeStaleDeck(run,inMenu)
        openCardChoice(run)
        local deckOpen = self.deckUI.visible
        if self.potionUI.visible and not canManagePotions(self.potionUI.run)then self.potionUI:close()end
        local potionOpen=self.potionUI.visible
        local blocked=overlaysBlocked() or covering
        local returnAvailable=syncRewardReturn(run,deckOpen,potionOpen,blocked,covering)
        refreshUtilities(run,inMenu,deckOpen,potionOpen,blocked,covering,returnAvailable)
        refreshPageVisibility(run,inMenu,deckOpen,potionOpen,blocked)
        renderCurrentPage(run,deckOpen,potionOpen,blocked,covering)
        bgm:update(self.settlementRequested and "stop" or Bgm.scene(self.mode, run, self.battleUI.busy, bgm.cue))
        present()
        refreshForeground()
        openingForeground(covering)
        self:syncController()
    end
    local function selectionChanged()
        exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
        self:refresh()
    end
    self.closeCharacters = function(_)
        if not self.characterOpen or self.starting then return false end
        self.characterOpen=false;self.characterSelection:clear()
        selectionChanged();return true
    end
    self.selectCharacter = function(_,id)
        if not self.characterOpen or self.starting or self.disabled then return false end
        local ok,reason=self.characterSelection:select(id)
        if ok then selectionChanged()end
        return ok,reason
    end
    self.selectElement = function(_,id)
        if not self.characterOpen or self.starting or self.disabled then return false end
        local ok,reason=self.characterSelection:selectElement(id)
        if ok then selectionChanged()end
        return ok,reason
    end
    self.start = function(_,character)
        if self.disabled or self.starting then return false,"ui_disabled" end
        if self.motion.deathReveal then return false,"result_revealing" end
        if self.exitOpen or self.deckUI.visible or self.settlementRequested or self.settlementBusy then return false end
        if self.mode~='menu' and self.mode~='defeat' and self.mode~='victory' then return false end
        if self.characterOpen then return false,'character_choice_open' end
        self.characterOpen=true;self.characterSelection:clear()
        -- Production keeps the select page, but the only open role is already showing.
        if self.characterSelection.profile~='full-source' then self.characterSelection:select('traveler') end
        selectionChanged()
        if character then
            for _,id in ipairs(CharacterSelect.elements)do if id==character then
                self:selectCharacter('traveler');return self:selectElement(id)
            end end
            return self:selectCharacter(character)
        end
        return true,'character_choice'
    end
    local function beginRun(character)
        local selection=CharacterSelect.options(character)
        -- Native entry selects the competition profile; explicit full-source
        -- hosts retain future chapters without changing same-run ownership.
        if platform.campaign == true then
            selection = selection or {}
            selection.experimental, selection.campaign = true, true
            selection.campaignProfile=platform.campaignProfile
        end
        if not require('abyss_run_admission').accepts(data,selection)then return false,'competition_character_unavailable'end
        local explicitSeed = self.seed ~= nil
        local seed = explicitSeed and self.seed or newSeed()
        local rawSeed=RunSeed.normalize(seed)
        local run = Run.new(data,rawSeed,selection)
        local runPresentation = (selection and selection.character or run.data.colorlessCards) and require("abyss_character_presentation").prepare(presentation,run.data) or presentation
        local ending=EndingHistory.begin(endingHistory,run,{seedSet=explicitSeed,
            isDailyRun=platform.isDailyRun or false,isTrial=platform.isTrial or false})
        run.endingUnlocked,run.endingHistory=ending.unlocked,ending
        local context,contextReason=Run.freezeMapContext(run)
        if not context then return false,contextReason end
        local map = Map.generate(run.data,rawSeed,run.act or 1,context)
        local history,historyReason
        history,historyReason=NeowHistory.read(neowHistory,run.character,Acts.isCompetition(run))
        if not history and Acts.isCompetition(run) then history={bossCount=0,source='fresh-start'} end
        if history then
            local ok,why=Nodes.beginNeow(run,map,history);if not ok then return false,why end
            run.neowHistorySource=history.source
        else
            run.neowStatus=Acts.isCompetition(run) and 'disabled' or 'unavailable'
            run.neowUnavailableReason=historyReason
        end
        self.characterOpen=false;exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
        self.battleUI.feedback:cancel()
        self.battleUI:setData(run.data,runPresentation)
        self.nodeUI.presentation=runPresentation
        self.deckUI:setPresentation(runPresentation)
        if self.choiceUI then self.choiceUI:close();self.choiceUI:setPresentation(runPresentation) end
        self.run, self.map, self.runSeed = run, map, rawSeed
        self.settlementRequested, self.settlementBusy, self.settlementError = false, false, nil
        if explicitSeed then self.seed = type(seed)=='number' and (seed + 1) % 65536 or RunSeed.increment(rawSeed) end
        print("ABYSS_RUN seed=" .. rawSeed
            .. " source=" .. (explicitSeed and "explicit" or "clock"))
        self.battleUI.run, self.battleUI.target = self.run, 1
        self.mapUI.map = self.map
        self.nodeUI.run, self.nodeUI.map = self.run, self.map
        self.nodeUI:render()
        if prologuePanel then prologuePanel:SetVisible(false) end
        self:refresh()
        return true
    end
    self.confirmCharacter = function(_)
        if not self.characterOpen or self.starting or self.disabled or self.exitOpen
            or self.settlementRequested or self.settlementBusy then return false,'character_choice_unavailable' end
        local info=self.characterSelection.info
        if not info then return false,'character_required' end
        if not self.characterSelection:canConfirm()then return false,'competition_character_unavailable'end
        self.starting=true
        -- Latch before seed generation and Run.new; a native duplicate cannot re-enter.
        local ok,accepted,reason=pcall(beginRun,info.id)
        self.starting=false
        if not ok then error(accepted)end
        return accepted,reason
    end
    self.advanceAct = function()
        if self.disabled or not self.run or self.run.phase ~= 'act_transition' then return false,'act_transition_unavailable' end
        if self.exitOpen or self.deckUI.visible or self.potionUI.visible or self.battleUI.busy
            or self.settlementRequested or self.settlementBusy then return false,'ui_busy' end
        local ok, reason = Nodes.advanceAct(self.run, self.map)
        if ok then
            self.nodeUI.result, self.nodeUI.notice = nil, ''
            self.battleUI.selected, self.battleUI.target = nil, 1
            self.presentedBattle = nil
            if self.choiceUI then self.choiceUI:close() end
        else
            self.nodeUI.notice = '暂时无法前往下一幕，请重试。'
        end
        self:refresh()
        return ok, reason
    end
    self.settle = function(_)
        if self.disabled then return false,"ui_disabled" end
        if self.motion.deathReveal then return false,"result_revealing" end
        if self.characterOpen then return false, "character_choice_open" end
        if self.exitOpen then return false, "exit_open" end
        if self.deckUI.visible then return false, "deck_open" end
        if self.mode ~= "victory" and self.mode ~= "defeat" then return false, "not_result" end
        return requestSettlement(self.mode == "victory")
    end
    requestSettlement = function(victory)
        if self.disabled then return false,"ui_disabled" end
        if self.motion.deathReveal or self.run and self.run.phase == "defeat" and self.battleUI.busy then return false,"result_revealing" end
        if self.settlementRequested or self.settlementBusy then return false, "settlement_already_requested" end
        if type(platform.settle) ~= "function" then
            self.exitError = self.exitOpen == true
            self:refresh()
            return false, "settlement_unavailable"
        end
        self.settlementBusy = true
        local called, accepted = pcall(platform.settle, victory)
        self.settlementBusy = false
        if not called or accepted == false then
            self.settlementError, self.motion.shake = true, 0
            self.exitError = self.exitOpen == true
            self:refresh()
            return false, "settlement_request_failed"
        end
        self.settlementRequested, self.settlementError, self.exitError = true, nil, nil
        if self.prologue then self.prologue:cancel() end
        if self.run then
            local phase=self.run.phase
            NeowHistory.finish(neowHistory,self.run,(phase=='victory' or phase=='defeat')and phase or 'abandon')
        end
        exitGeneration = exitGeneration + 1
        self:refresh()
        return true, "settlement_requested"
    end
    self.resize = function(_, width, height)
        exitGeneration = exitGeneration + 1
        menuGeneration = menuGeneration + 1
        if self.choiceUI then self.choiceUI:resize() end
        local closed=self.potionUI:close()
        self.battleUI:resize(width, height)
        self.mapUI:resize(width, height)
        self.nodeUI:resize(width, height)
        if closed then self:refresh()end
    end
    self.update = function(_, dt)
        if self.disabled then return false,"ui_disabled" end
        if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then
            return false, "invalid_delta"
        end
        if controller then controller:tick() end
        if self.exitOpen or self.settlementBusy then self:syncController();return true end
        if self.settlementRequested then self:animate(dt); return true end
        -- Count client update time within this run; menus/results never extend it.
        -- The terminal rule state can precede the last feedback animation.
        local run = self.run
        if run and not openingCovered() and run.phase ~= "defeat" and self.mode ~= "victory" and self.mode ~= "defeat"
            then
            local elapsed = run.elapsedSeconds + dt
            if elapsed == math.huge then return false, "invalid_delta" end
            run.elapsedSeconds = elapsed
        end
        self:animate(dt)
        if self.prologue then self.prologue:update(dt) end
        if openingCovered() then self:syncController();return true end
        self.battleUI:update(dt)
        if self.battleUI.busy and self.battleUI.feedback.deaths.player then bgm:update("defeat") end
        self.nodeUI:update(dt)
        self.deckUI:update(dt)
        local updated=self.mapUI:update(dt)
        self:syncController()
        return updated
    end
    self.disable = function(_)
        if self.disabled then return false end
        self.disabled=true
        if self.prologue then self.prologue:cancel() end
        if controller then controller:disable() end
        exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
        self.characterOpen=false
        if characterPanel then characterPanel:SetVisible(false) end
        -- Set every controller inert before cancelling feedback: cancellation
        -- invokes its completion callback synchronously, which now cannot refresh.
        self.battleUI.active=false
        self.mapUI:setVisible(false)
        self.nodeUI:setVisible(false)
        if self.choiceUI then self.choiceUI:close() end
        self.potionUI:close();self.deckUI:close()
        self.battleUI.feedback:cancel()
        return true
    end
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
    runMenu:GetChild('blocker'):AddCursorEventListener(clickEvent, function() return true end)
    local function bindCommand(box, kind, action, enabled, order, group, onFocus)
        local hit = box:GetChild("hit")
        local held, released, observed
        local menuAction = kind == "start" or kind == "settle"
        local rewardAction = kind == "combatRewards"
        local characterAction = kind:match("^character_")~=nil
        local cursor = platform.cursorEvents or {}
        local runMenuAction = kind:sub(1, 4) == 'run_'
        local function available()
            if self.disabled or self.settlementRequested or self.settlementBusy then return false end
            if menuAction and self.motion.deathReveal then return false end
            if kind == 'routeClose' then return self.exitOpen and self.routeOpen == true end
            if kind == 'helpClose' then return self.exitOpen and self.controlsOpen == true end
            if self.controlsOpen then return false end
            if runMenuAction then return self.exitOpen and self.menuOpen == true and not self.routeOpen and (not enabled or enabled()) end
            if self.menuOpen or self.routeOpen then return false end
            if characterAction then
                return self.characterOpen==true and not self.exitOpen and not self.starting
                    and (not enabled or enabled())
                    and (self.mode=="menu" or self.mode=="defeat" or self.mode=="victory")
            end
            if self.characterOpen and kind ~= 'open' then return false end
            if rewardAction then
                return self.rewardReturnAvailable == true and self.mode == "map" and self.run and self.run.phase == "map" and self.run.pendingCombatRewards ~= nil
                    and not self.exitOpen and not self.deckUI.visible and not self.potionUI.visible
            end
            if menuAction then
                if self.exitOpen or self.deckUI.visible then return false end
                return self.mode == "victory" or self.mode == "defeat"
                    or kind == "start" and self.mode == "menu"
            end
            return kind == "open" and not self.exitOpen or kind ~= "open" and self.exitOpen == true
        end
        local function current(token)
            return token and token.generation == exitGeneration and token.run == self.run
                and (not menuAction and not characterAction or token.menuGeneration == menuGeneration) and available()
                and (not rewardAction or token.menuGeneration == menuGeneration and token.pending == self.run.pendingCombatRewards
                    and token.rewardGeneration == self.rewardReturnGeneration)
        end
        local function touch(event) return event and event.touchId end
        if cursor.CursorDown and cursor.CursorUp then
            hit:AddCursorEventListener(cursor.CursorDown, function(event)
                if held and not current(held) then held = nil end
                if released and not current(released) then released = nil end
                if held and held.touch ~= touch(event) then return end
                observed, held, released = true, nil, nil
                if available() then held = {generation=exitGeneration,menuGeneration=menuGeneration,run=self.run,touch=touch(event),
                    pending=self.run and self.run.pendingCombatRewards,rewardGeneration=self.rewardReturnGeneration} end
            end)
            hit:AddCursorEventListener(cursor.CursorUp, function(event)
                if not held or held.touch ~= touch(event) then return end
                released = current(held) and held or nil
                held = nil
            end)
            for _, event in pairs({cursor.CursorExit, cursor.CursorEndDrag}) do
                if event then hit:AddCursorEventListener(event, function(pointer)
                    local owner = held or released
                    if not pointer or owner and owner.touch == touch(pointer) then held, released = nil, nil end
                end) end
            end
        end
        Controller.bind(controller,hit,function()
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
    -- Source menu actions use the same pointer ownership as exit actions, and also
    -- expire whenever their menu/run context is hidden or replaced.
    bindCommand(start, "start", function() return self:start() end)
    bindCommand(settlement, "settle", function() return self:settle() end)
    bindCommand(child("combatRewards"), "combatRewards", function()
        local ok, reason = Run.reopenCombatRewards(self.run)
        if ok then self:refresh() end
        return ok, reason
    end)
    bindCommand(exitEntry:GetChild("open"), "open", function() return self:openMenu() end)
    bindCommand(exitPanel:GetChild("cancel"), "cancel", function() return self:closeExit() end)
    bindCommand(exitPanel:GetChild("confirm"), "confirm", function() return self:confirmExit() end)
    local guide = exitPanel:GetChild('guide')
    if guide then
        bindCommand(exitPanel:GetChild('help'), 'help', function()
            exitGeneration = exitGeneration + 1
            self.controlsOpen = true
            guide:SetVisible(true)
            self:refresh()
            return true
        end)
        bindCommand(guide:GetChild('close'), 'helpClose', function() return self:closeExit() end)
    end
    bindCommand(runMenu:GetChild('help'), 'run_help', function()
        exitGeneration = exitGeneration + 1
        self.controlsOpen = true
        guide:SetVisible(true)
        self:refresh()
        return true
    end)
    bindCommand(runMenu:GetChild('resume'), 'run_resume', function() return self:closeExit() end)
    bindCommand(runMenu:GetChild('abandon'), 'run_abandon', function()
        exitGeneration = exitGeneration + 1
        self.menuOpen = false
        self:refresh()
        return true
    end)
    bindCommand(runMenu:GetChild('map'), 'run_map', function()
        exitGeneration = exitGeneration + 1
        self.routeOpen = true
        self:refresh()
        return true
    end, canViewRoute)
    bindCommand(child('mapPanel'):GetChild('previewBack'), 'routeClose', function() return self:closeExit() end)
    characterPanel.disableCursorEventPassthrough=true
    characterPanel:GetChild("blocker"):AddCursorEventListener(clickEvent,function()return true end)
    bindCommand(characterPanel:GetChild("cancel"),"character_cancel",function() return self:closeCharacters() end,nil,90)
    bindCommand(characterPanel:GetChild('confirm'),'character_confirm',function()return self:confirmCharacter()end,
        function()return self.characterSelection:canConfirm()end,100)
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
    ready = true
    if controller then
        controller.beforeAction=function()self.battleUI:cancelControllerPointers()end
        controller.onChange=function()self:syncController()end
    end
    self:refresh()
    self:syncController()
    return self
end
return M
