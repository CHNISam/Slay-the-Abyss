-- 商店商人演出，移植自 STS ShopScreen.createSpeech/updateSpeech、Merchant 与 ShopSpeechBubble
-- （反编译源码见 docs/SHOP_PARITY.md 所引 ButterflyGame@fc379c8）。仅表现层：台词全部是已批准的
-- Lore v2 商人文案，只在节点 UI 已完成/拒绝交易后反应，从不阻塞、延迟或替代商店输入。
-- STS 时序：进店 speechTimer=1.5s；无气泡且计时到 0 时重置为 random(40,60)，首次说欢迎、之后说闲置话；
-- 购买成功/金币不足都把计时重置为 random(40,60) 并立即换上新气泡。气泡 4s，前 0.3s 由 0.5 倍
-- swingIn 弹入，透明度按 12/s 趋近、最后 0.3s 淡出，sin(t*4) 上下浮动，投影按 4/s 偏移；
-- 悬停（触屏为点按）气泡会把剩余时长缩到 0.3s。气泡随机左右翻转，锚在商人身旁。
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local Prologue = require("abyss_prologue")
local M = {}
local L, C = Theme.layout.merchant, Theme.color
local copy = Narrative.merchant
local lines = { welcome = copy.greet, buy = copy.purchaseSuccess, poor = copy.insufficientGold,
    leave = copy.leave, idle = copy.originHint }
local cues = { buy = "merchant_buy", poor = "merchant_deny" }

local function clamp(value) return math.max(0, math.min(1, value)) end
local function lerp(a, b, t) return a + (b - a) * clamp(t) end
-- libGDX Interpolation.swingIn (scale 2): a^2 * ((s+1)a - s).
local function swingIn(from, to, a) return from + (to - from) * (a * a * (3 * a - 2)) end

-- options.color, options.sound, options.random (0..1, presentation only). box = merchantControl().
function M.new(box, options)
    options = options or {}
    local seed = 0x2545F491
    local random = options.random or function()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    local function range(a, b) return a + (b - a) * random() end
    local self = { visible = false }
    local portrait, bubble = box:GetChild("portrait"), box:GetChild("bubble")
    local line, marker, shadow = bubble:GetChild("line"), bubble:GetChild("next"), bubble:GetChild("shadow")
    local function colour(c, alpha)
        return options.color(c.r, c.g, c.b, math.floor((c.a or 255) * clamp(alpha or 1) + 0.5))
    end
    local function tint(control, c, alpha) if options.color and control then control.imageColor = colour(c, alpha) end end
    local function ink(control, c, alpha) if options.color then control.fontColor = colour(c, alpha) end end
    local function pageEnd(s) return math.min(#s.chars, s.page * L.pageCharacters) end

    -- ShopScreen.createSpeech: new bubble replaces the old one (facing pinned right, see below).
    local function createSpeech(kind)
        self.speech = { kind = kind, chars = Prologue.chars(lines[kind]), shown = 0, page = 1,
            duration = kind == "leave" and math.huge or L.duration, scaleTimer = L.fade, alpha = 0, wavy = 0,
            shadow = 0, right = true }
        -- 偏离 STS 随机左右：本商店左侧紧贴药水货架与价签，气泡固定在立像右侧空地。
        if cues[kind] and options.sound then pcall(options.sound, cues[kind]) end
    end
    function self:enter(run)
        self.speechTimer, self.saidWelcome, self.speech = L.firstSpeech, false, nil
        self:pose()
    end
    function self:react(kind)
        if not lines[kind] then return false end
        if kind == "buy" then self.nod = 0 elseif kind == "poor" then self.shake = 0 end
        self.speechTimer = range(L.idleMin, L.idleMax)
        createSpeech(kind)
        self:pose()
        return true
    end
    -- Tap = STS bubble hover: finish typing / next page, otherwise shorten to the fade.
    function self:tap()
        local s = self.speech
        if not self.visible or not s then return false end
        if s.shown < pageEnd(s) then s.shown = pageEnd(s)
        elseif pageEnd(s) < #s.chars then s.page = s.page + 1
        elseif s.duration > L.fade and s.kind ~= "leave" then s.duration = L.fade
        else return false end
        self:pose()
        return true
    end
    function self:setVisible(value)
        self.visible = value == true
        box:SetVisible(self.visible)
        if self.visible then self:pose() end
    end

    function self:pose()
        if not self.visible then return end
        local clock = self.clock or 0
        local x, y = L.figure[1] - L.frame[1], L.figure[2] - L.frame[2]
        if self.nod then y = y - L.nodLift * math.sin(math.pi * clamp(self.nod / L.nod)) end
        if self.shake then
            local p = clamp(self.shake / L.shake)
            x = x + L.shakeAmplitude * math.sin(p * math.pi * 4) * (1 - p)
        end
        portrait:SetAnchoredPosition(x, y)
        tint(portrait:GetChild("lanternGlow"), C.merchant.lantern, 0.4 + 0.08 * math.sin(clock * 7) + 0.05 * math.sin(clock * 13))
        local s = self.speech
        bubble:SetVisible(s ~= nil)
        if not s then return end
        local side = s.right and 1 or -1
        bubble:SetAnchoredPosition(L.figure[1] - L.frame[1] + L.anchor[1] + side * L.adjust[1],
            L.figure[2] - L.frame[2] + L.anchor[2] + L.adjust[2] + s.wavy)
        local scale = swingIn(1, L.scaleFrom, s.scaleTimer / L.fade)
        bubble:SetLocalScale(scale, scale, 1)
        local tail = bubble:GetChild("tail")
        tail:SetAnchoredPosition(-side * (L.bubble[1] / 2 - 36), L.tail[2])
        tint(bubble:GetChild("border"), C.goldDim, s.alpha)
        tint(bubble:GetChild("panel"), C.parchment, s.alpha * 0.97)
        tint(tail, C.parchment, s.alpha * 0.97)
        tint(shadow, C.merchant.hood, s.alpha / 4)
        shadow:SetAnchoredPosition(s.shadow, -s.shadow)
        local count = math.min(pageEnd(s), math.floor(s.shown))
        line.text = table.concat(s.chars, "", (s.page - 1) * L.pageCharacters + 1, count)
        ink(line, C.panelSunken, s.alpha)
        local more = count >= pageEnd(s) and pageEnd(s) < #s.chars
        marker:SetVisible(more)
        if more then tint(marker, C.goldDim, s.alpha) end
    end

    function self:update(dt)
        if not self.visible then return end
        self.clock = (self.clock or 0) + dt
        local s = self.speech
        if s then -- ShopSpeechBubble.update / SpeechTextEffect
            s.scaleTimer = math.max(0, s.scaleTimer - dt)
            s.wavyClock = (s.wavyClock or 0) + dt * L.wavyRate
            s.wavy = math.sin(s.wavyClock) * L.wavy
            s.duration = s.duration - dt
            s.alpha = lerp(s.alpha, s.duration > L.fade and 1 or 0, dt * L.alphaRate)
            s.shadow = lerp(s.shadow, L.shadow, dt * 4)
            if s.shown < pageEnd(s) then s.shown = math.min(pageEnd(s), s.shown + dt * L.typeRate)
            elseif pageEnd(s) < #s.chars and s.duration < L.duration - 2.6 * s.page then s.page = s.page + 1 end
            if s.duration < 0 then self.speech = nil end
        end
        -- ShopScreen.updateSpeech idle cadence.
        self.speechTimer = (self.speechTimer or L.firstSpeech) - dt
        if not self.speech and self.speechTimer <= 0 then
            self.speechTimer = range(L.idleMin, L.idleMax)
            createSpeech(self.saidWelcome and "idle" or "welcome")
            self.saidWelcome = true
        end
        if self.nod then self.nod = self.nod + dt; if self.nod >= L.nod then self.nod = nil end end
        if self.shake then self.shake = self.shake + dt; if self.shake >= L.shake then self.shake = nil end end
        self:pose()
    end
    box:SetVisible(false)
    return self
end
return M
