-- Host for the same-run map, node and battle controllers. Only commands change rules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Nodes = require("abyss_nodes")
local BattleUI = require("abyss_battle_ui")
local MapUI = require("abyss_map_ui")
local NodeUI = require("abyss_node_ui")
local DeckUI = require("abyss_deck_ui")
local PotionDiscardUI = require("abyss_potion_discard_ui")
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local Bgm = require("abyss_bgm")
local CharacterSelect = require("abyss_character_select")
local CharacterView = require("abyss_character_select_view")
local Controller = require("abyss_controller")
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
    local speed=menu:GetChild('battleSpeed')
    local exitPanel, exitEntry = child("exitPanel"), child("exitEntry")
    local runMenu = child("runMenu")
    local exitGeneration, menuGeneration = 0, 0
    local codeVersion = assert(menu:GetChild('codeVersion'), 'missing game menu codeVersion')
    codeVersion.text = Narrative.codeVersion or '未知'
    local characterPanel = child("characterPanel")
    self.characterSelection=CharacterSelect.new(data,presentation)
    self.fastMode=false
    self.setFastMode=function(_,enabled)
        if type(enabled)~='boolean' or self.disabled or self.battleUI and self.battleUI.busy then return false end
        if self.mode~='menu' or self.characterOpen or self.exitOpen
            or (self.deckUI and self.deckUI.visible)
            or (self.potionUI and self.potionUI.visible) or (self.choiceUI and self.choiceUI.visible)
            or self.settlementRequested or self.settlementBusy then return false end
        self.fastMode=enabled
        if self.battleUI then self.battleUI.fastMode=enabled;self.battleUI.feedback:setFastMode(enabled)end
        if speed then speed:GetChild('label').text=enabled and '战斗速度：快速' or '战斗速度：普通'end
        return true
    end
    local menuRun, menuMode
    local requestSettlement
    local ready = false
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
        return not self.disabled and run~=nil and self.run==run and not self.exitOpen and not self.deckUI.visible
            and not (self.choiceUI and self.choiceUI.visible)
            and not self.battleUI.busy and not self.settlementBusy and not self.settlementRequested
            and (self.mode=="map" or self.mode=="battle" or self.mode=="node")
            and (run.phase=="map" or run.phase=="node" or run.phase=="reward" or run.phase=="combat")
    end
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
    -- Old authored prologue controls may exist in previously built layouts.
    -- Keep them inert; every new run enters the existing Neow/map path.
    local prologuePanel = root:GetChild("prologuePanel")
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
        if self.disabled or self.characterOpen or self.choiceUI and self.choiceUI.visible or self.exitOpen or self.potionUI.visible or not self.run or self.battleUI.busy or self.settlementBusy or self.settlementRequested
            or (self.mode ~= "map" and self.mode ~= "battle" and self.mode ~= "node") then return false end
        if pileKind then
            if self.mode~='battle' or not self.deckUI:openPile(self.run,pileKind)then return false end
        elseif not self.deckUI:open(self.run)then return false end
        self.battleUI.selected = nil
        self:refresh()
        return true
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

    -- Menu/result presentation reads stats the run already records. Motion only moves and
    -- scales controls; it never hides them or gates input.
    local L, C, T = Theme.layout.nativeMenu, Theme.color, Theme.motion
    local R = L.reveal
    local result = menu:GetChild("result")
    local emblem, start, settlement = menu:GetChild("emblem"), menu:GetChild("start"), menu:GetChild("settle")
    local vista = menu:GetChild("vista")
    local risers = { { menu:GetChild("title"), L.title }, { menu:GetChild("tagline"), L.tagline },
        { result:GetChild("subtitle"), L.subtitle } }
    local cards = {}
    for i, key in ipairs({ "floor", "victories", "time", "deck" }) do cards[i] = result:GetChild("stat_" .. key) end
    local function colour(c) return platform.color(c.r, c.g, c.b, c.a) end
    local function clamp(value) return math.max(0, math.min(1, value)) end
    local function easeOut(p) return 1 - (1 - p) ^ 3 end
    local function overshoot(p) return 1 + 2.7 * (p - 1) ^ 3 + 1.7 * (p - 1) ^ 2 end
    local function clock(seconds)
        seconds = math.floor(seconds)
        return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    self.motion = { t = 0, settleX = L.settle[1] }
    local function pose()
        local m = self.motion
        local p = easeOut(clamp(m.t / T.slow))
        local grow = R.emblemFrom + (1 - R.emblemFrom) * overshoot(clamp(m.t / T.slow))
        local breathe = 1 + R.breatheScale * math.sin(2 * math.pi * math.max(0, m.t - T.slow) / R.breathe)
        emblem:SetLocalScale(grow, grow, 1)
        emblem:GetChild("glow"):SetLocalScale(breathe, breathe, 1)
        for _, riser in ipairs(risers) do riser[1]:SetAnchoredPosition(riser[2][1], riser[2][2] - R.rise * (1 - p)) end
        for i, card in ipairs(cards) do
            local q = easeOut(clamp((m.t - i * R.stagger) / T.slow))
            local scale = R.cardFrom + (1 - R.cardFrom) * q
            card:SetLocalScale(scale, scale, 1)
            card:SetAnchoredPosition(L.stats.origin[1] + (i - 1) * L.stats.step, L.stats.origin[2] - R.rise * (1 - q))
        end
        local x = m.settleX
        if m.slide then x = m.slide.from + (m.slide.to - m.slide.from) * easeOut(clamp(m.slide.t / T.base)) end
        if m.shake then
            local s = clamp(m.shake / T.shake)
            x = x + T.shakeAmplitude * math.sin(s * math.pi * 4) * (1 - s)
        end
        settlement:SetAnchoredPosition(x, L.settle[2])
        -- Title vista: embers drift up past the ruins and the seal breathes; nothing here takes input.
        local V = Theme.layout.vista
        for i, at in ipairs(V.motes) do
            local rise = (m.t * V.drift + i * 53) % 220
            local mote = vista:GetChild("mote" .. i)
            mote:SetAnchoredPosition(at[1] + 10 * math.sin(m.t + i), at[2] + rise)
            mote.imageColor = colour({ r = C.goldBright.r, g = C.goldBright.g, b = C.goldBright.b,
                a = math.floor(180 * math.sin(math.pi * rise / 220)) })
        end
        local seal = 1 + 0.03 * math.sin(2 * math.pi * m.t / V.breathe)
        vista:GetChild("seal"):SetLocalScale(seal, seal, 1)
    end
    local function present()
        local mode, run, m = self.mode, self.run, self.motion
        if mode ~= "menu" and mode ~= "defeat" and mode ~= "victory" then m.mode = nil return end
        local victory, defeat = mode == "victory", mode == "defeat"
        local outcome = victory or defeat
        if m.mode ~= mode then m.t, m.mode = 0, mode end
        local rules = data.rules.map
        emblem:GetChild("icon").imageColor = colour(defeat and C.danger or C.geo)
        emblem:GetChild("glow").imageColor = colour(defeat and C.danger or C.goldBright)
        -- The distant seal answers the outcome: broken red after a defeat, settled gold otherwise.
        vista:GetChild("seal"):GetChild("heart").imageColor = colour(defeat and C.danger or C.goldBright)
        vista:GetChild("seal"):GetChild("ring").imageColor = colour(defeat and C.danger or C.gold)
        local title = menu:GetChild("title")
        title.text = victory and (run.ending=='two_act_complete' and '双幕挑战完成' or run.ending=='true_victory' and '真结局 · 深渊已被封印' or "深渊已被封印") or defeat and "旅途在此中断" or "杀戮原塔2"
        title.fontColor = colour(victory and C.goldBright or defeat and C.text or C.gold)
        menu:GetChild("tagline"):SetVisible(not outcome)
        menu:GetChild("summary"):SetVisible(false)
        result:SetVisible(outcome)
        local startFrame = outcome and L.resultRestart or L.start
        start:SetAnchoredPosition(startFrame[1], startFrame[2])
        start:SetVisible(not self.settlementRequested and not self.settlementBusy)
        start:GetChild("label").text = run and "重新启程" or "启程"
        settlement:SetVisible(outcome)
        local available = type(platform.settle) == "function"
        local enabled = outcome and available and not self.settlementRequested and not self.settlementBusy
        settlement:GetChild("normal"):SetVisible(enabled == true)
        settlement:GetChild("disabled"):SetVisible(not enabled and not self.settlementBusy)
        settlement:GetChild("selected"):SetVisible(self.settlementBusy == true)
        settlement:GetChild("border").imageColor = colour(enabled and C.gold or C.line)
        local label = settlement:GetChild("label")
        label.text = self.settlementRequested and "已发送结算请求" or "结束并结算"
        label.fontColor = colour(enabled and C.gold or C.textDim)
        -- With the request sent, restart is gone and the remaining button settles to centre.
        local targetX = self.settlementRequested and 0 or L.settle[1]
        if targetX ~= m.settleX then m.slide, m.settleX = { from = m.settleX, to = targetX, t = 0 }, targetX end
        if not outcome then
            -- The title screen names the chapter only; the opening story belongs to the cinematic.
            menu:GetChild("tagline").text = Narrative.title
            menu:GetChild("summary").text = ""
        else
            local floor = self.map.floor
            result:GetChild("subtitle").text = victory and run.ending=='two_act_complete'
                and '第一幕与第二幕已完成。本局挑战到此结束。' or victory and run.ending=='true_victory'
                and '腐化之心已击败。真结局已达成。' or Narrative.flow[mode].full
            local finalFloor=Acts.isCompetition(run) and Acts.get(2).last or victory and run.ending=='true_victory' and (self.map.terminalFloor or rules.floors) or rules.floors
            local values = { floor .. " / " .. finalFloor, tostring(run.victories), clock(run.elapsedSeconds), tostring(#run.deck) }
            for i, name in ipairs({ "抵达层数", "战斗胜场", "用时", "卡组张数" }) do
                cards[i]:GetChild("label").text, cards[i]:GetChild("value").text = name, values[i]
            end
            cards[1]:GetChild("value").fontColor = colour(victory and C.goldBright or C.text)
            local hp = run.phase == "defeat" and 0 or run.hp
            result:GetChild("detail").text = "生命 " .. number(hp) .. " / " .. number(run.maxHp) .. " · 金币 " .. number(run.gold)
                .. " · 遗物 " .. #run.relics .. " 件"
            local status, ink = "「结束并结算」提交本局结果并进入平台结算；「重新启程」不会提交", C.textMuted
            if self.settlementRequested then status, ink = "结算请求已发送，等待平台结算界面", C.positive
            elseif self.settlementError then status, ink = "结算请求失败，请重试", C.danger
            elseif not available then status = "平台结算暂不可用，可重新启程" end
            local line = result:GetChild("status")
            line.text, line.fontColor = status, colour(ink)
        end
        pose()
    end
    self.animate = function(_, dt)
        local m = self.motion
        if not m.mode then return end
        m.t = m.t + dt
        if m.slide then m.slide.t = m.slide.t + dt; if m.slide.t >= T.base then m.slide = nil end end
        if m.shake then m.shake = m.shake + dt; if m.shake >= T.shake then m.shake = nil end end
        pose()
    end

    function self.syncController(_)
        if not controller then return end
        local scope=self.mode
        if self.disabled or self.settlementRequested or self.settlementBusy then scope='blocked'
        elseif self.exitOpen then scope='exit'
        elseif self.characterOpen then scope='characters'
        elseif self.choiceUI and self.choiceUI.visible then scope='choice'
        elseif self.deckUI.visible then scope='deck'
        elseif self.potionUI.visible then scope='potions'
        elseif self.mode=='battle' and self.battleUI.potionMenu then scope='battlePotion'
        elseif self.mode=='battle' and self.battleUI.info then scope='battleInfo'
        elseif self.mode=='battle' and (self.battleUI.selected or self.battleUI.potionAim) then scope='aim' end
        controller:sync(scope,function()
            if scope=='exit' then return self:closeExit()
            elseif scope=='characters' then return self:closeCharacters()
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
        child("combatRewards"):SetVisible(returnAvailable)
        child("deckEntry"):SetVisible(not ending and not inMenu and not deckOpen and not potionOpen and not blocked and not covering)
        child("potionEntry"):SetVisible(not inCombat() and not ending and not inMenu and not deckOpen and not potionOpen and not blocked and not covering)
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
        if speed then speed:SetVisible(self.mode=='menu')end
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
    self.refresh = function(_)
        if self.disabled then return false,"ui_disabled" end
        local run = self.run
        finishRunFlow(run)
        local covering = false
        selectMode(run)
        local inMenu = self.mode == "menu" or self.mode == "defeat" or self.mode == "victory"
        syncMenuContext(run,inMenu)
        syncCardChoice(run)
        closeStaleDeck(run,inMenu)
        openCardChoice(run)
        local deckOpen = self.deckUI.visible
        if self.potionUI.visible and not canManagePotions(self.potionUI.run)then self.potionUI:close()end
        local potionOpen=self.potionUI.visible
        local blocked=overlaysBlocked()
        local returnAvailable=syncRewardReturn(run,deckOpen,potionOpen,blocked,covering)
        refreshUtilities(run,inMenu,deckOpen,potionOpen,blocked,covering,returnAvailable)
        refreshPageVisibility(run,inMenu,deckOpen,potionOpen,blocked)
        renderCurrentPage(run,deckOpen,potionOpen,blocked,covering)
        bgm:update(self.settlementRequested and "stop" or Bgm.scene(self.mode, run, self.battleUI.busy, bgm.cue))
        present()
        refreshForeground()
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
        if self.exitOpen or self.deckUI.visible or self.settlementRequested or self.settlementBusy then return false end
        if self.mode~='menu' and self.mode~='defeat' and self.mode~='victory' then return false end
        if self.characterOpen then return false,'character_choice_open' end
        self.characterOpen=true;self.characterSelection:clear()
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
        local explicitSeed = self.seed ~= nil
        local seed = explicitSeed and self.seed or newSeed()
        local rawSeed=RunSeed.normalize(seed)
        local selection=CharacterSelect.options(character)
        -- Native entry selects the competition profile; explicit full-source
        -- hosts retain future chapters without changing same-run ownership.
        if platform.campaign == true then
            selection = selection or {}
            selection.experimental, selection.campaign = true, true
            selection.campaignProfile=platform.campaignProfile
        end
        local run = Run.new(data,rawSeed,selection)
        local runPresentation = (selection and selection.character or run.data.colorlessCards) and require("abyss_character_presentation").prepare(presentation,run.data) or presentation
        local ending=EndingHistory.begin(endingHistory,run,{seedSet=explicitSeed,
            isDailyRun=platform.isDailyRun or false,isTrial=platform.isTrial or false})
        run.endingUnlocked,run.endingHistory=ending.unlocked,ending
        local context,contextReason=Run.freezeMapContext(run)
        if not context then return false,contextReason end
        local map = Map.generate(run.data,rawSeed,run.act or 1,context)
        local history,historyReason
        if not Acts.isCompetition(run) then history,historyReason=NeowHistory.read(neowHistory,run.character) end
        if history then
            local ok,why=Nodes.beginNeow(run,map,history);if not ok then return false,why end
            run.neowHistorySource=history.source
        else
            run.neowStatus=Acts.isCompetition(run) and 'disabled' or 'unavailable'
            run.neowUnavailableReason=historyReason
        end
        self.characterOpen=false;exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
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
        self:refresh()
        return true
    end
    self.confirmCharacter = function(_)
        if not self.characterOpen or self.starting or self.disabled or self.exitOpen
            or self.settlementRequested or self.settlementBusy then return false,'character_choice_unavailable' end
        local info=self.characterSelection.info
        if not info then return false,'character_required' end
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
        if self.characterOpen then return false, "character_choice_open" end
        if self.exitOpen then return false, "exit_open" end
        if self.deckUI.visible then return false, "deck_open" end
        if self.mode ~= "victory" and self.mode ~= "defeat" then return false, "not_result" end
        return requestSettlement(self.mode == "victory")
    end
    requestSettlement = function(victory)
        if self.disabled then return false,"ui_disabled" end
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
        if run and run.phase ~= "defeat" and self.mode ~= "victory" and self.mode ~= "defeat"
            then
            local elapsed = run.elapsedSeconds + dt
            if elapsed == math.huge then return false, "invalid_delta" end
            run.elapsedSeconds = elapsed
        end
        self:animate(dt)
        self.battleUI:update(dt)
        self.nodeUI:update(dt)
        self.deckUI:update(dt)
        local updated=self.mapUI:update(dt)
        self:syncController()
        return updated
    end
    self.disable = function(_)
        if self.disabled then return false end
        self.disabled=true
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
        local menuAction = kind == "start" or kind == "settle" or kind == "battleSpeed"
        local rewardAction = kind == "combatRewards"
        local characterAction = kind:match("^character_")~=nil
        local cursor = platform.cursorEvents or {}
        local runMenuAction = kind:sub(1, 4) == 'run_'
        local function available()
            if self.disabled or self.settlementRequested or self.settlementBusy then return false end
            if kind == 'routeClose' then return self.exitOpen and self.routeOpen == true end
            if kind == 'helpClose' then return self.exitOpen and self.controlsOpen == true end
            if self.controlsOpen then return false end
            if runMenuAction then return self.exitOpen and self.menuOpen == true and not self.routeOpen and (not enabled or enabled()) end
            if self.menuOpen or self.routeOpen then return false end
            if kind=='battleSpeed' then return self.mode=='menu' and not self.characterOpen and not self.exitOpen and not self.deckUI.visible end
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
    if speed then bindCommand(speed,'battleSpeed',function()return self:setFastMode(not self.fastMode)end)end
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
    end, function() return self.run ~= nil and self.map ~= nil and not self.characterOpen end)
    bindCommand(child('mapPanel'):GetChild('previewBack'), 'routeClose', function() return self:closeExit() end)
    characterPanel.disableCursorEventPassthrough=true
    characterPanel:GetChild("blocker"):AddCursorEventListener(clickEvent,function()return true end)
    bindCommand(characterPanel:GetChild("cancel"),"character_cancel",function() return self:closeCharacters() end,nil,90)
    bindCommand(characterPanel:GetChild('confirm'),'character_confirm',function()return self:confirmCharacter()end,
        function()return self.characterSelection.info~=nil end,100)
    for i,id in ipairs(CharacterSelect.characters)do
        local box=characterPanel:GetChild(i==5 and 'traveler' or 'character'..i)
        bindCommand(box,'character_'..i,function()return self:selectCharacter(id)end,nil,i,'characters',
            function()if Controller.isController(controller)then return self:selectCharacter(id)end end)
    end
    for i,id in ipairs(CharacterSelect.elements)do
        bindCommand(characterPanel:GetChild('elements'):GetChild('element'..i),'character_element'..i,
            function()return self:selectElement(id)end,function()return self.characterSelection.character=='traveler'end,
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
