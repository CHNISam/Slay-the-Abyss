-- Host for the same-run map, node and battle controllers. Only commands change rules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Nodes = require("abyss_nodes")
local BattleUI = require("abyss_battle_ui")
local MapUI = require("abyss_map_ui")
local NodeUI = require("abyss_node_ui")
local DeckUI = require("abyss_deck_ui")
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local Bgm = require("abyss_bgm")
local M = {}

function M.new(root, data, presentation, clickEvent, platform)
    local self = { root = root, data = data, seed = 1, mode = "menu" }
    local bgm = Bgm.new(platform.music)
    local function child(name) return assert(root:GetChild(name), "missing game panel " .. name) end
    local menu = child("menuPanel")
    local ready = false
    local function changed() if ready then self:refresh() end end
    self.battleUI = BattleUI.new(child("battlePanel"), data, presentation, clickEvent,
        platform, { embedded = true, onChange = changed })
    self.mapUI = MapUI.new(child("mapPanel"), Map.generate(data, self.seed), function(node)
        if not self.run or self.mode ~= "map" or self.deckUI and self.deckUI.visible then return false, "not_on_map" end
        local ok, reason = Nodes.enter(self.run, self.map, node.id)
        if ok then changed() end
        return ok, reason
    end, clickEvent, { embedded = true, color = platform.color, imageSource = platform.imageSource })
    self.nodeUI = NodeUI.new(child("nodePanel"), Run.new(data, self.seed), self.mapUI.map,
        presentation, clickEvent, changed, { color = platform.color, imageSource = platform.imageSource })
    self.deckUI = DeckUI.new(child("deckPanel"), presentation, clickEvent, platform, function() return self:closeDeck() end)

    function self:openDeck()
        if not self.run or self.battleUI.busy or self.settlementBusy or self.settlementRequested
            or (self.mode ~= "map" and self.mode ~= "battle" and self.mode ~= "node") then return false end
        if not self.deckUI:open(self.run) then return false end
        self.battleUI.selected = nil
        self:refresh()
        return true
    end
    function self:closeDeck()
        if not self.deckUI:close() then return false end
        -- The cancelled gesture no longer owns a release/click. A subsequent
        -- tap starts a fresh selection, so ordinary point-and-click still works.
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
        local title = menu:GetChild("title")
        title.text = victory and "深渊已被封印" or defeat and "旅途在此中断" or "杀戮深渊"
        title.fontColor = colour(victory and C.goldBright or defeat and C.text or C.gold)
        menu:GetChild("tagline"):SetVisible(not outcome)
        menu:GetChild("summary"):SetVisible(not outcome)
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
            menu:GetChild("tagline").text = Narrative.flow.intro.compact
            menu:GetChild("summary").text = "规划 " .. rules.generatedRows .. " 层岔路，构筑卡组，第 "
                .. rules.bossFloor .. " 层迎战首领。\n" .. self.battleUI.instructions
        else
            local floor = self.map.floor
            result:GetChild("subtitle").text = Narrative.flow[mode].compact
            local values = { floor .. " / " .. rules.bossFloor, tostring(run.victories), clock(run.elapsedSeconds), tostring(#run.deck) }
            for i, name in ipairs({ "抵达层数", "战斗胜场", "用时", "卡组张数" }) do
                cards[i]:GetChild("label").text, cards[i]:GetChild("value").text = name, values[i]
            end
            cards[1]:GetChild("value").fontColor = colour(victory and C.goldBright or C.text)
            local hp = run.phase == "defeat" and 0 or run.hp
            result:GetChild("detail").text = "生命 " .. hp .. " / " .. run.maxHp .. " · 金币 " .. run.gold
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
        local run = self.run
        if run and run.phase == "map" and run.nodeFlow and not run.nodeFlow.complete then
            Nodes.completeCombat(run, self.map)
        end
        if self.battleUI.busy then self.mode = "battle"
        elseif not run then self.mode = "menu"
        elseif run.phase == "defeat" then self.mode = "defeat"
        elseif run.nodeFlow and run.nodeFlow.complete and run.nodeFlow.result == "boss_victory" then self.mode = "victory"
        elseif run.phase == "combat" or run.phase == "reward" then self.mode = "battle"
        elseif run.phase == "node" then self.mode = "node"
        -- Camp/event results stay on screen until the player presses 继续.
        elseif self.nodeUI.run == run and self.nodeUI:holding() then self.mode = "node"
        else self.mode = "map" end
        local inMenu = self.mode == "menu" or self.mode == "defeat" or self.mode == "victory"
        if self.deckUI.visible and (inMenu or self.battleUI.busy or self.deckUI.run ~= run) then self.deckUI:close() end
        local deckOpen = self.deckUI.visible
        child("deckEntry"):SetVisible(not inMenu and not deckOpen)
        child("deckEntry"):GetChild("open"):GetChild("hit").interactable = not self.battleUI.busy
        menu:SetVisible(inMenu)
        self.battleUI:setActive(self.mode == "battle" and not deckOpen)
        child("battlePanel"):SetVisible(self.mode == "battle")
        self.mapUI:setVisible(self.mode == "map" and not deckOpen)
        child("mapPanel"):SetVisible(self.mode == "map")
        self.nodeUI:setVisible(self.mode == "node" and not deckOpen)
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
                    and Narrative.flow.bossEntrance.compact or self.battleUI.instructions
            end
        elseif self.mode == "map" then
            self.mapUI:setNavigationEnabled(not deckOpen and #Nodes.available(run, self.map) > 0)
        elseif self.mode == "node" then self.nodeUI:render() end
        bgm:update(self.settlementRequested and "stop" or Bgm.scene(self.mode, run, self.battleUI.busy, bgm.cue))
        present()
    end
    function self:start()
        if self.deckUI.visible then return false end
        if self.settlementRequested or self.settlementBusy then return false end
        if self.mode ~= "menu" and self.mode ~= "defeat" and self.mode ~= "victory" then return false end
        self.run, self.map = Run.new(data, self.seed), Map.generate(data, self.seed)
        self.settlementRequested, self.settlementBusy, self.settlementError = false, false, nil
        self.seed = (self.seed + 1) % 65536
        self.battleUI.run, self.battleUI.target = self.run, 1
        self.mapUI.map = self.map
        self.nodeUI.run, self.nodeUI.map = self.run, self.map
        self:refresh()
        return true
    end
    function self:settle()
        if self.deckUI.visible then return false, "deck_open" end
        if self.mode ~= "victory" and self.mode ~= "defeat" then return false, "not_result" end
        if self.settlementRequested or self.settlementBusy then return false, "settlement_already_requested" end
        if type(platform.settle) ~= "function" then return false, "settlement_unavailable" end
        self.settlementBusy = true
        local called, accepted = pcall(platform.settle, self.mode == "victory")
        self.settlementBusy = false
        if not called or accepted == false then
            self.settlementError, self.motion.shake = true, 0
            self:refresh()
            return false, "settlement_request_failed"
        end
        self.settlementRequested, self.settlementError = true, nil
        self:refresh()
        return true, "settlement_requested"
    end
    function self:resize(width, height)
        self.battleUI:resize(width, height)
        self.mapUI:resize(width, height)
    end
    function self:update(dt)
        if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then
            return false, "invalid_delta"
        end
        -- Count client update time within this run; menus/results never extend it.
        -- The terminal rule state can precede the last feedback animation.
        local run = self.run
        if run and run.phase ~= "defeat" and self.mode ~= "victory" and self.mode ~= "defeat" then
            local elapsed = run.elapsedSeconds + dt
            if elapsed == math.huge then return false, "invalid_delta" end
            run.elapsedSeconds = elapsed
        end
        self:animate(dt)
        self.battleUI:update(dt)
        self.deckUI:update()
        return self.mapUI:update(dt)
    end
    start:GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:start() end)
    settlement:GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:settle() end)
    child("deckEntry"):GetChild("open"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:openDeck() end)
    ready = true
    self:refresh()
    return self
end
return M
