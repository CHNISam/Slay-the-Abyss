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
local Prologue = require("abyss_prologue")
local M = {}
local number = require("abyss_numbers").integer
local RunSeed = require("abyss_run_seed")

function M.new(root, data, presentation, clickEvent, platform)
    -- A seed is an explicit replay/test override. Normal runs sample at Start,
    -- never while constructing the title-screen preview or refreshing the UI.
    local self = { root = root, data = data, seed = platform.seed, mode = "menu" }
    local previewSeed = self.seed or 1
    local newSeed = platform.newSeed or function() return require("abyss_new_run_seed").next() end
    local bgm = Bgm.new(platform.music)
    local function child(name) return assert(root:GetChild(name), "missing game panel " .. name) end
    local menu = child("menuPanel")
    local exitPanel, exitEntry = child("exitPanel"), child("exitEntry")
    local exitGeneration, menuGeneration = 0, 0
    local experimental = platform.experimentalCharacters == true
    local characterPanel = root:GetChild("characterPanel")
    local originalCharacters=platform.originalCharacters==true and characterPanel and characterPanel:GetChild('traveler')~=nil or false
    local selectable=experimental or originalCharacters
    if selectable then assert(characterPanel and root:GetChild("choicePanel"), "experimental class layout required") end
    local characterIds = originalCharacters and {"hutao","arlecchino","furina","raiden"} or {"ironclad", "silent", "defect", "watcher"}
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
        platform, { embedded = true, onChange = changed })
    self.mapUI = MapUI.new(child("mapPanel"), Map.generate(data, previewSeed), function(node)
        if self.disabled or not self.run or self.mode ~= "map" or self.deckUI and self.deckUI.visible then return false, "not_on_map" end
        local ok, reason = Nodes.enter(self.run, self.map, node.id)
        if ok then changed() end
        return ok, reason
    end, clickEvent, { embedded = true, color = platform.color, imageSource = platform.imageSource,
        cursor = platform.cursorEvents })
    self.nodeUI = NodeUI.new(child("nodePanel"), Run.new(data, previewSeed), self.mapUI.map,
        presentation, clickEvent, changed, { color = platform.color, imageSource = platform.imageSource,
            cursorEvents = platform.cursorEvents, sound = platform.sound,
            onInspectCard=function(definition,upgraded)
                if not self.run or self.disabled or self.mode~='node' or self.exitOpen
                    or self.deckUI.visible or self.potionUI.visible or self.settlementRequested then return false end
                if not self.deckUI:inspect(self.run,definition,upgraded) then return false end
                self:refresh();return true
            end })
    self.deckUI = DeckUI.new(child("deckPanel"), presentation, clickEvent, platform, function() return self:closeDeck() end)
    if selectable then
        self.choiceUI = require("abyss_choice_ui").new(child("choicePanel"),presentation,clickEvent,platform,
            function(kind,uids,token,generation)
                return self.battleUI:chooseCards(kind,uids,token,generation)
            end)
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
    function self:openPotions()
        if not self.potionUI:open(self.run)then return false end
        self.battleUI.selected=nil;self:refresh();return true
    end
    function self:closePotions()
        if not self.potionUI:close()then return false end
        self.battleUI.suppressClick=false;self:refresh();return true
    end
    -- The opening cinematic plays once per session, from the title screen only; hosts
    -- without the panel, or with platform.prologue == false, go straight to the map.
    local prologuePanel = root:GetChild("prologuePanel")
    if prologuePanel and platform.prologue ~= false then
        self.prologue = Prologue.new(prologuePanel, { clickEvent = clickEvent, cursorEvents = platform.cursorEvents,
            color = platform.color, sound = platform.sound,
            blocked = function() return self.exitOpen or self.settlementRequested or self.settlementBusy end,
            onPhase = changed })
    elseif prologuePanel then prologuePanel:SetVisible(false) end

    function self:openExit()
        if self.disabled or self.characterOpen or self.exitOpen or self.settlementRequested or self.settlementBusy then return false end
        exitGeneration = exitGeneration + 1
        self.potionUI:close()
        self.exitOpen, self.exitError = true, nil
        self.battleUI.selected = nil
        self:refresh()
        return true
    end
    function self:closeExit()
        if not self.exitOpen or self.settlementRequested or self.settlementBusy then return false end
        exitGeneration = exitGeneration + 1
        self.exitOpen, self.exitError = false, nil
        self.battleUI.suppressClick = false
        self:refresh()
        return true
    end
    function self:confirmExit()
        if self.disabled then return false,"ui_disabled" end
        if not self.exitOpen then return false, "exit_not_open" end
        -- Voluntary departure never changes combat HP, awards a victory, or
        -- fakes a defeated Run. An already-earned victory keeps its outcome.
        return requestSettlement(self.mode == "victory")
    end

    function self:openDeck()
        if self.disabled or self.characterOpen or self.choiceUI and self.choiceUI.visible or self.exitOpen or self.potionUI.visible or not self.run or self.battleUI.busy or self.settlementBusy or self.settlementRequested
            or (self.mode ~= "map" and self.mode ~= "battle" and self.mode ~= "node") then return false end
        if not self.deckUI:open(self.run) then return false end
        self.battleUI.selected = nil
        self:refresh()
        return true
    end
    function self:closeDeck()
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
        title.text = victory and "深渊已被封印" or defeat and "旅途在此中断" or "杀戮原塔2"
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
            result:GetChild("subtitle").text = Narrative.flow[mode].full
            local values = { floor .. " / " .. rules.floors, tostring(run.victories), clock(run.elapsedSeconds), tostring(#run.deck) }
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
    function self:animate(dt)
        local m = self.motion
        if not m.mode then return end
        m.t = m.t + dt
        if m.slide then m.slide.t = m.slide.t + dt; if m.slide.t >= T.base then m.slide = nil end end
        if m.shake then m.shake = m.shake + dt; if m.shake >= T.shake then m.shake = nil end end
        pose()
    end

    function self:refresh()
        if self.disabled then return false,"ui_disabled" end
        local run = self.run
        if not self.exitOpen and not self.settlementRequested and run and run.phase == "map" and run.nodeFlow and not run.nodeFlow.complete then
            Nodes.completeCombat(run, self.map)
        end
        local prologue = self.prologue
        if prologue and prologue:covering() and (not run or self.settlementRequested) then prologue:cancel() end
        local covering = prologue and prologue:covering() or false
        if self.battleUI.busy then self.mode = "battle"
        elseif not run then self.mode = "menu"
        elseif prologue and prologue:opaque() then self.mode = "prologue"
        elseif run.phase == "defeat" then self.mode = "defeat"
        elseif run.phase == "victory" then self.mode = "victory"
        elseif run.phase == "combat" or run.phase == "reward" then self.mode = "battle"
        elseif run.phase == "node" or run.phase == 'act_transition' then self.mode = "node"
        -- Camp/event results stay on screen until the player presses 继续.
        elseif self.nodeUI.run == run and self.nodeUI:holding() then self.mode = "node"
        else self.mode = "map" end
        if menuRun ~= run or menuMode ~= self.mode then
            menuGeneration = menuGeneration + 1
            menuRun, menuMode = run, self.mode
        end
        local inMenu = self.mode == "menu" or self.mode == "defeat" or self.mode == "victory"
        if self.characterOpen and (not inMenu or self.settlementRequested or self.settlementBusy) then
            self.characterOpen=false;exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
        end
        if self.choiceUI then
            self.choiceUI:refresh(run,not self.battleUI.busy and not self.exitOpen and not self.settlementRequested
                and not self.settlementBusy and not self.deckUI.visible and not self.potionUI.visible)
        end
        if self.deckUI.visible and (inMenu or self.battleUI.busy or self.deckUI.run ~= run) then self.deckUI:close() end
        if run and run.phase=="combat" and run.combat.pendingChoice and not self.battleUI.busy
            and not self.deckUI.visible and not self.exitOpen then
            self.deckUI:open(run,run.combat.pendingChoice,function(token,uid)
                self.battleUI:chooseCard(token,uid)
                self:refresh()
            end)
        end
        local deckOpen = self.deckUI.visible
        if self.potionUI.visible and not canManagePotions(self.potionUI.run)then self.potionUI:close()end
        local potionOpen=self.potionUI.visible
        local blocked = self.exitOpen or self.settlementRequested or self.settlementBusy or self.characterOpen
            or self.choiceUI and self.choiceUI.visible
        local returnAvailable = self.mode == "map" and run and run.pendingCombatRewards ~= nil
            and not deckOpen and not potionOpen and not blocked and not covering or false
        if self.rewardReturnAvailable ~= returnAvailable then
            self.rewardReturnAvailable = returnAvailable
            self.rewardReturnGeneration = (self.rewardReturnGeneration or 0) + 1
        end
        child("combatRewards"):SetVisible(returnAvailable)
        child("deckEntry"):SetVisible(not inMenu and not deckOpen and not potionOpen and not blocked and not covering)
        child("potionEntry"):SetVisible(not inMenu and not deckOpen and not potionOpen and not blocked and not covering)
        local potionHit=child("potionEntry"):GetChild("open"):GetChild("hit")
        potionHit.interactable=canManagePotions(run)
        for _,state in ipairs({"normal","hover","pressed","disabled"})do
            potionHit:GetChild(state):GetChild("label").text=run and "药水 "..Run.potionCount(run).."/"..Run.potionCapacity(run) or "药水"
        end
        child("nodePanel"):GetChild("potions"):SetVisible(false)
        if potionOpen then self.potionUI:render()end
        local deckHit = child("deckEntry"):GetChild("open"):GetChild("hit")
        deckHit.interactable = not self.battleUI.busy
        -- The shared deck button carries the deck size, so no screen repeats it as loose text.
        for _, state in ipairs({ "normal", "hover", "pressed", "disabled" }) do
            local variant = deckHit:GetChild(state)
            if variant then variant:GetChild("label").text = run and "卡组 " .. #run.deck or "卡组" end
        end
        menu:SetVisible(inMenu)
        self.battleUI:setActive(self.mode == "battle" and not deckOpen and not potionOpen and not blocked)
        child("battlePanel"):SetVisible(self.mode == "battle")
        self.mapUI:setVisible(self.mode == "map" and not deckOpen and not potionOpen and not blocked)
        child("mapPanel"):SetVisible(self.mode == "map")
        if run then
            local resources = child("mapPanel"):GetChild("resources")
            resources:GetChild("hp").text = number(run.hp) .. "/" .. number(run.maxHp)
            resources:GetChild("gold").text = number(run.gold)
        end
        self.nodeUI:setVisible(self.mode == "node" and not deckOpen and not potionOpen and not blocked)
        child("nodePanel"):SetVisible(self.mode == "node")
        if self.mode == "battle" then
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
        elseif self.mode == "map" then
            -- While the cinematic's last fade uncovers the map, the map is visible but inert.
            self.mapUI:setNavigationEnabled(not deckOpen and not potionOpen and not blocked and not covering and #Nodes.available(run, self.map) > 0)
        elseif self.mode == "node" then self.nodeUI:render() end
        bgm:update(self.settlementRequested and "stop" or Bgm.scene(self.mode, run, self.battleUI.busy, bgm.cue))
        present()
        if characterPanel then
            characterPanel:SetVisible(self.characterOpen==true)
            if self.characterOpen then characterPanel:SetAsLastSibling() end
        end
        if self.choiceUI and self.choiceUI.visible then self.choiceUI.root:SetAsLastSibling() end
        -- Shared utilities stay above the deck overlay; the confirmation stays
        -- above every page, including an in-flight battle presentation.
        exitEntry:SetVisible(not self.exitOpen and not self.settlementRequested and not self.settlementBusy)
        exitEntry:SetAsLastSibling()
        exitPanel:SetVisible(self.exitOpen == true)
        if self.exitOpen then
            exitPanel:SetAsLastSibling()
            local message = self.run and "确认退出本局？本局进度不会保留。\n将进入平台结算，随后可选择离开。"
                or "确认结束当前关卡？\n将进入平台结算，随后可选择离开。"
            if self.mode == "victory" then message = "确认结束本局并结算胜利？\n随后可在平台结算页选择离开。" end
            exitPanel:GetChild("message").text = message
            exitPanel:GetChild("status").text = self.settlementRequested and "结算请求已发送，等待平台结算界面。"
                or self.exitError and "退出请求失败，请重试或继续游戏。" or ""
            local enabled = not self.settlementRequested and not self.settlementBusy
            for _, name in ipairs({"cancel", "confirm"}) do
                exitPanel:GetChild(name):GetChild("hit").interactable = enabled
            end
        end
    end
    function self:closeCharacters()
        if not self.characterOpen then return false end
        self.characterOpen=false;exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
        self:refresh();return true
    end
    function self:start(character)
        if self.disabled then return false,"ui_disabled" end
        if self.exitOpen or self.deckUI.visible then return false end
        if self.settlementRequested or self.settlementBusy then return false end
        if self.mode ~= "menu" and self.mode ~= "defeat" and self.mode ~= "victory" then return false end
        if selectable and character==nil then
            if self.characterOpen then return false end
            self.characterOpen=true;exitGeneration=exitGeneration+1;menuGeneration=menuGeneration+1
            self:refresh();return true, "character_choice"
        end
        if character~=nil and not selectable then return false, "experimental_characters_disabled" end
        if selectable then
            local valid=originalCharacters and character=='traveler';for _,id in ipairs(characterIds) do if id==character then valid=true end end
            if not valid then return false, "unknown_character" end
        end
        -- Restarting from a result goes straight back to the map: the story is told once.
        local opening = self.mode == "menu" and not self.prologueSeen
        local explicitSeed = self.seed ~= nil
        local seed = explicitSeed and self.seed or newSeed()
        local rawSeed=RunSeed.normalize(seed)
        local selection=character~='traveler' and character~=nil and {experimental=experimental,character=character} or nil
        -- Explicit development opt-in only. Incomplete later content remains
        -- guarded by the normal Nodes/Run entry commands, never substituted.
        if platform.campaign == true then
            selection = selection or {}
            selection.experimental, selection.campaign = true, true
        end
        local run = Run.new(data,rawSeed,selection)
        local runPresentation = selection and selection.character and require("abyss_character_presentation").prepare(presentation,run.data) or presentation
        local map = Map.generate(run.data,rawSeed)
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
        if opening and self.prologue then
            self.prologueSeen = true
            self.prologue:play()
        end
        self:refresh()
        return true
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
    function self:settle()
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
        exitGeneration = exitGeneration + 1
        self:refresh()
        return true, "settlement_requested"
    end
    function self:resize(width, height)
        exitGeneration = exitGeneration + 1
        menuGeneration = menuGeneration + 1
        if self.choiceUI then self.choiceUI:resize() end
        local closed=self.potionUI:close()
        self.battleUI:resize(width, height)
        self.mapUI:resize(width, height)
        self.nodeUI:resize(width, height)
        if closed then self:refresh()end
    end
    function self:update(dt)
        if self.disabled then return false,"ui_disabled" end
        if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then
            return false, "invalid_delta"
        end
        if self.exitOpen or self.settlementBusy then return true end
        if self.settlementRequested then self:animate(dt); return true end
        -- Count client update time within this run; menus/results never extend it.
        -- The terminal rule state can precede the last feedback animation.
        local run = self.run
        if run and run.phase ~= "defeat" and self.mode ~= "victory" and self.mode ~= "defeat"
            and not (self.prologue and self.prologue:covering()) then
            local elapsed = run.elapsedSeconds + dt
            if elapsed == math.huge then return false, "invalid_delta" end
            run.elapsedSeconds = elapsed
        end
        self:animate(dt)
        if self.prologue then self.prologue:update(dt) end
        self.battleUI:update(dt)
        self.nodeUI:update(dt)
        self.deckUI:update()
        return self.mapUI:update(dt)
    end
    function self:disable()
        if self.disabled then return false end
        self.disabled=true
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
        if self.prologue then self.prologue:cancel() end
        self.battleUI.feedback:cancel()
        return true
    end
    child("deckEntry"):GetChild("open"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:openDeck() end)
    child("potionEntry"):GetChild("open"):GetChild("hit"):AddCursorEventListener(clickEvent,function()return self:openPotions()end)
    exitPanel.disableCursorEventPassthrough = true
    exitPanel:GetChild("blocker"):AddCursorEventListener(clickEvent, function() return true end)
    local function bindCommand(box, kind, action)
        local hit = box:GetChild("hit")
        local held, released, observed
        local resultAction = kind == "start" or kind == "settle"
        local rewardAction = kind == "combatRewards"
        local characterAction = kind == "character_cancel" or kind:match("^character_%d$")~=nil
        local cursor = platform.cursorEvents or {}
        local function available()
            if self.disabled or self.settlementRequested or self.settlementBusy then return false end
            if characterAction then
                return selectable and self.characterOpen==true and not self.exitOpen
                    and (self.mode=="menu" or self.mode=="defeat" or self.mode=="victory")
            end
            if self.characterOpen then return false end
            if rewardAction then
                return self.rewardReturnAvailable == true and self.mode == "map" and self.run and self.run.phase == "map" and self.run.pendingCombatRewards ~= nil
                    and not self.exitOpen and not self.deckUI.visible and not self.potionUI.visible
            end
            if resultAction then
                if self.exitOpen or self.deckUI.visible then return false end
                return self.mode == "victory" or self.mode == "defeat"
                    or kind == "start" and self.mode == "menu"
            end
            return kind == "open" and not self.exitOpen or kind ~= "open" and self.exitOpen == true
        end
        local function current(token)
            return token and token.generation == exitGeneration and token.run == self.run
                and (not resultAction and not characterAction or token.menuGeneration == menuGeneration) and available()
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
        hit:AddCursorEventListener(clickEvent, function(event)
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
    -- Result actions use the same pointer ownership as exit actions, and also
    -- expire whenever their menu/run context is hidden or replaced.
    bindCommand(start, "start", function() return self:start() end)
    bindCommand(settlement, "settle", function() return self:settle() end)
    bindCommand(child("combatRewards"), "combatRewards", function()
        local ok, reason = Run.reopenCombatRewards(self.run)
        if ok then self:refresh() end
        return ok, reason
    end)
    bindCommand(exitEntry:GetChild("open"), "open", function() return self:openExit() end)
    bindCommand(exitPanel:GetChild("cancel"), "cancel", function() return self:closeExit() end)
    bindCommand(exitPanel:GetChild("confirm"), "confirm", function() return self:confirmExit() end)
    if characterPanel then
        characterPanel.disableCursorEventPassthrough=true
        characterPanel:GetChild("blocker"):AddCursorEventListener(clickEvent,function()return true end)
        bindCommand(characterPanel:GetChild("cancel"),"character_cancel",function() return self:closeCharacters() end)
        if originalCharacters then bindCommand(characterPanel:GetChild('traveler'),'character_5',function()return self:start('traveler')end) end
        for i,id in ipairs(characterIds) do
            bindCommand(characterPanel:GetChild("character"..i),"character_"..i,function()
                if not self.characterOpen then return false end
                return self:start(id)
            end)
        end
    end
    ready = true
    self:refresh()
    return self
end
return M
