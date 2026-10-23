-- Presentation only. Core commands have already committed before this runs.
-- Reuses native controls and OnUpdate; no coroutine, timers, assets or Tween callbacks.
local Events = require("abyss_events")
local Theme = require("abyss_theme")
local M = {}
local T, C, L, S = Theme.motion, Theme.color, Theme.layout, Theme.space
local function n(value) return string.format("%.0f", value or 0) end
local function duration(kind)
    if kind == "play" then return T.base end
    if kind == "enemy_turn" or kind == "player_turn" or kind == "victory" or kind == "defeat" then return T.banner end
    if kind == "intent" then return T.enemyActionGap end
    if kind == "death" then return T.slow end
    if kind == "damage" or kind == "status_damage" or kind == "block" or kind == "status" or kind == "heal" then return T.base end
    return 0
end

function M.new(stage, platform, present, complete)
    local self = { busy = false, effects = {}, deaths = {} }
    local overlay = stage:GetChild("feedback")
    local function colour(c, alpha) return platform.color(c.r, c.g, c.b, math.floor((c.a or 255) * (alpha or 1))) end
    local function tint(box, c, alpha) box.imageColor = colour(c, alpha) end
    local function actor(id)
        if id == "player" then return self.shadow.player, stage:GetChild("hero"), L.player.position[1], L.player.position[2] end
        local count = #self.shadow.enemies
        for i, a in ipairs(self.shadow.enemies) do
            if a.id == id then
                local x = count == 1 and (L.enemyRow.xFrom + L.enemyRow.xTo) / 2
                    or L.enemyRow.xFrom + (i - 1) * (L.enemyRow.xTo - L.enemyRow.xFrom) / (count - 1)
                return a, stage:GetChild("enemy" .. i), x, L.enemyRow.y
            end
        end
    end
    local function banner(text, danger)
        local label = overlay:GetChild("banner")
        label.text, label.fontColor = text, colour(danger and C.danger or C.goldBright)
        label:SetVisible(true) overlay:GetChild("bannerPlate"):SetVisible(true)
    end
    local function sound(cue)
        -- IDs come from the platform catalogue. Candidate audibility still needs real playtest.
        if platform.sound then
            local ok, reason = pcall(platform.sound, cue)
            if not ok then print("ABYSS_AUDIO unavailable " .. cue .. " " .. tostring(reason)) end
        end
    end
    function self:reset()
        stage:SetAnchoredPosition(0, 0)
        for _, name in ipairs({"playedCard", "banner", "bannerPlate"}) do pcall(function() overlay:GetChild(name):SetVisible(false) end) end
        for _, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
            local box = stage:GetChild(name)
            for _, part in ipairs({"impact", "shield", "floating"}) do pcall(function() box:GetChild(part):SetVisible(false) end) end
            box:GetChild("portrait"):SetAnchoredPosition(0, 0)
            tint(box:GetChild("portrait"), name == "hero" and C.geo or C.text)
        end
        self.effects, self.deaths = {}, {}
    end
    local function finish(failure)
        local wasBusy = self.busy
        self.busy, self.queue, self.current = false, nil, nil
        -- Cleanup errors are isolated so input always releases, even if an effect control failed.
        if failure then pcall(self.reset, self) end
        for _, name in ipairs({"playedCard", "banner", "bannerPlate"}) do pcall(function() overlay:GetChild(name):SetVisible(false) end) end
        if failure then print("ABYSS_FEEDBACK recovered " .. tostring(failure)) end
        if wasBusy then complete(failure) end
    end
    function self:cancel()
        if self.busy then finish("cancelled") else self:reset() end
    end
    local function step(entry)
        local old = self.shadow
        local nextView = {catalog = old.catalog, rules = old.rules}
        for k, v in pairs(entry.frame or old) do nextView[k] = v end
        self.shadow, self.current, self.elapsed = nextView, entry, 0
        overlay:GetChild("playedCard"):SetVisible(false)
        overlay:GetChild("banner"):SetVisible(false) overlay:GetChild("bannerPlate"):SetVisible(false)
        self.acting = entry.kind == "intent" and entry.detail.enemy or self.acting
        if entry.kind == "player_turn" then self.acting = nil end
        present(self.shadow, self.acting, self.deaths)
        local d, kind = type(entry.detail) == "table" and entry.detail or {}, entry.kind
        print("ABYSS_FEEDBACK " .. kind .. " source=" .. tostring(d.source or d.enemy or "-") .. " target=" .. tostring(d.target or "-") .. " amount=" .. n(d.amount))
        if kind == "play" then
            local card = overlay:GetChild("playedCard")
            local definition = self.shadow.catalog.cards[d.cardId]
            local display = self.presentation[d.cardId]
            card:GetChild("name").text = display and display.name or definition.name
            tint(card:GetChild("plate"), C.cardType[definition.type] or C.panelRaised)
            card:GetChild("art"):SetImage(platform.imageSource, Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
            local target = d.target and self.shadow.enemies[d.target]
            local _, _, x, y = actor(target and target.id or "player")
            self.flight = { x = self.origin and self.origin[1] or 0, y = self.origin and self.origin[2] or L.hand.y, tx = x, ty = y }
            card:SetAnchoredPosition(self.flight.x, self.flight.y) card:SetLocalScale(1, 1, 1)
            card:SetVisible(true) overlay:SetAsLastSibling() sound("card_play")
        elseif kind == "enemy_turn" then banner("敌方回合") sound("turn")
        elseif kind == "player_turn" then banner("我方回合 " .. n(self.shadow.turn)) sound("turn")
        elseif kind == "victory" then banner("战斗胜利") sound("victory")
        elseif kind == "defeat" then banner("旅途暂歇", true) sound("defeat")
        elseif kind == "intent" then
            local a = actor(d.enemy)
            stage:GetChild("notice").text = (a and a.name or "敌人") .. " · 正在行动"
        elseif kind == "death" then
            self.deaths[d.target] = true
            local _, box = actor(d.target)
            box:SetVisible(true)
            self.effects[d.target] = {kind = kind, age = 0}
            sound("enemy_die")
        elseif d.target then
            local a, box = actor(d.target)
            if box then
                local previous = old.player
                if d.target ~= "player" then for _, value in ipairs(old.enemies) do if value.id == d.target then previous = value break end end end
                local text, ink = "", C.goldBright
                if kind == "damage" or kind == "status_damage" then
                    text, ink = n(d.amount), C.danger
                    if (d.blocked or 0) > 0 then text = "格挡 " .. n(d.blocked) .. ((d.amount or 0) > 0 and "\n−" .. n(d.amount) or "") ink = C.block end
                    if d.status then
                        local status = self.shadow.catalog.statuses[d.status]
                        text = (status and status.name or d.status)
                            .. ((d.blocked or 0) > 0 and " 格挡 " .. n(d.blocked) or "")
                            .. ((d.amount or 0) > 0 and " −" .. n(d.amount) or "")
                        ink = (d.blocked or 0) > 0 and C.block or C.debuff
                    end
                    if (d.amount or 0) > 0 then sound(d.target == "player" and "hurt" or "hit")
                    elseif (d.blocked or 0) > 0 then sound("block_hit") end
                elseif kind == "block" then text, ink = "格挡 ＋" .. n(d.amount), C.block sound("block_gain")
                elseif kind == "status" then
                    local status = self.shadow.catalog.statuses[d.status]
                    text = (status and status.name or d.status) .. (d.amount >= 0 and " ＋" or " ") .. n(d.amount)
                    ink = status and status.kind == "buff" and C.buff or C.debuff
                    sound("status")
                elseif kind == "heal" then text, ink = "＋" .. n(d.amount), C.positive end
                if text ~= "" then
                    local floating = box:GetChild("floating")
                    floating.text, floating.fontColor = text, colour(ink)
                    box:GetChild("impact"):SetImage(platform.imageSource,
                        kind == "status" and Theme.icon.status[d.status] or Theme.image.diamond)
                    self.effects[d.target] = {kind = kind, age = 0, detail = d, ink = ink,
                        oldHp = previous.hp / previous.maxHp, hp = a.hp / a.maxHp}
                end
            end
        end
    end
    function self:start(before, battle, first, presentation, origin)
        self:reset()
        self.presentation, self.origin, self.acting = presentation, origin, nil
        self.shadow = {catalog = battle.catalog, rules = battle.rules}
        for k, v in pairs(before) do self.shadow[k] = v end
        for _, a in ipairs(before.enemies) do if a.hp <= 0 then self.deaths[a.id] = true end end
        self.queue, self.index, self.elapsed = {}, 0, 0
        local previous = before
        for i = first, #battle.events do
            local entry = battle.events[i]
            self.queue[#self.queue + 1] = entry
            if entry.frame then
                for j, a in ipairs(entry.frame.enemies) do
                    if previous.enemies[j].hp > 0 and a.hp <= 0 then
                        self.queue[#self.queue + 1] = {kind = "death", detail = {target = a.id}, frame = entry.frame}
                    end
                end
                previous = entry.frame
            end
        end
        if #self.queue == 0 then finish() return end
        self.busy = true
        self.index = 1 step(self.queue[1])
    end
    function self:update(dt)
        if not self.busy and next(self.effects) == nil then return end
        local ok, failure = pcall(function()
            assert(type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge, "invalid frame delta")
            self.elapsed = self.elapsed + dt
            -- At most one visible step per update: a stalled frame cannot skip an enemy turn.
            if self.busy and self.elapsed >= duration(self.current.kind) then
                self.index = self.index + 1
                local entry = self.queue[self.index]
                if not entry then finish() return end
                step(entry)
            end
            if self.busy and self.current.kind == "play" then
                local p = math.min(1, self.elapsed / T.base)
                local card, f = overlay:GetChild("playedCard"), self.flight
                card:SetAnchoredPosition(f.x + (f.tx - f.x) * p, f.y + (f.ty - f.y) * p)
                card:SetLocalScale(1 - p / 2, 1 - p / 2, 1)
            end
            local shake = 0
            for id, effect in pairs(self.effects) do
                effect.age = effect.age + dt
                local a, box = actor(id)
                if effect.kind == "death" then
                    local p = math.min(1, effect.age / T.slow)
                    box:SetVisible(p < 1) tint(box:GetChild("portrait"), C.text, 1 - p)
                    if p >= 1 then self.effects[id] = nil end
                else
                    local age, d = effect.age, effect.detail
                    local hit = (effect.kind == "damage" or effect.kind == "status_damage") and (d.amount or 0) > 0
                    local flash = age < T.fast
                    local status = effect.kind == "status" and age < T.slow
                    local impact = box:GetChild("impact")
                    impact:SetVisible(hit and flash or status)
                    box:GetChild("shield"):SetVisible((effect.kind == "block" or (d.blocked or 0) > 0) and age < T.slow)
                    tint(impact, effect.ink, math.max(0, 1 - age / (status and T.slow or T.fast)))
                    local kick = hit and age < T.shake and math.sin(age / T.shake * math.pi * 2) * S.s or 0
                    box:GetChild("portrait"):SetAnchoredPosition(kick, 0)
                    if hit and id == "player" and age < T.shake then shake = math.sin(age / T.shake * math.pi * 4) * T.shakeAmplitude end
                    local p = math.min(1, age / T.damagePop)
                    local floating = box:GetChild("floating")
                    floating:SetVisible(p < 1) floating:SetAnchoredPosition(0, L.enemyRow.portrait / 2 + S.xl * p)
                    floating.fontColor = colour(effect.ink, 1 - p)
                    local scale = 1 + math.max(0, 1 - age / T.fast) / 2
                    floating:SetLocalScale(scale, scale, 1)
                    local ghost = math.max(0, math.min(1, (age - T.hpGhostDelay) / T.hpGhost))
                    box:GetChild("hpGhost").fillAmount = effect.oldHp + (effect.hp - effect.oldHp) * ghost
                    if age >= math.max(T.damagePop, T.hpGhostDelay + T.hpGhost) then self.effects[id] = nil end
                end
            end
            stage:SetAnchoredPosition(shake, 0)
        end)
        if not ok then finish(failure) end
    end
    -- Called only after the rule transaction; even start/control failure must unlock.
    function self:begin(...)
        local ok, failure = pcall(self.start, self, ...)
        if not ok then finish(failure) end
    end
    return self
end
return M
