-- Opening cinematic shown once per session between the title screen and the first map.
-- Presentation only: it never creates or changes a Run. The host asks opaque()/covering()
-- to keep other pages hidden or inert, and onPhase() to refresh when the map is uncovered.
-- Motion uses the same OnUpdate setter interpolation as combat feedback (no Tween callbacks).
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local M = {}
local Controller = require('abyss_controller')
local P, V, C, F = Theme.layout.prologue, Theme.layout.vista, Theme.color, Theme.font

-- Splits approved copy after each 。 or …… without changing, adding or dropping a character.
function M.beats(text)
    local beats, start, i = {}, 1, 1
    while i <= #text do
        local stop
        if text:sub(i, i + 2) == "。" then stop = i + 2
        elseif text:sub(i, i + 5) == "……" then stop = i + 5 end
        if stop then
            beats[#beats + 1] = text:sub(start, stop)
            start, i = stop + 1, stop + 1
        else i = i + 1 end
    end
    if start <= #text then beats[#beats + 1] = text:sub(start) end
    return beats
end
function M.chars(text)
    local list = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do list[#list + 1] = ch end
    return list
end

local function clamp(value) return math.max(0, math.min(1, value)) end
local function easeOut(p) return 1 - (1 - p) ^ 3 end
local function easeInOut(p) return p < 0.5 and 4 * p ^ 3 or 1 - (-2 * p + 2) ^ 3 / 2 end
local function lerp(a, b, p) return a + (b - a) * p end

-- options.clickEvent, options.cursorEvents, options.color, options.sound,
-- options.blocked() (exit/settlement overlays own input), options.onPhase(phase).
function M.new(panel, options)
    options = options or {}
    local self = { playing = false, beats = M.beats(Narrative.flow.intro.full), generation = 0 }
    local vista, hero = panel:GetChild("vista"), panel:GetChild("hero")
    local seal, line = vista:GetChild("seal"), panel:GetChild("line")
    local half = Theme.canvas.base[2] / 2
    local function colour(c, alpha)
        if not options.color then return nil end
        return options.color(c.r, c.g, c.b, math.floor((c.a or 255) * clamp(alpha or 1) + 0.5))
    end
    local function tint(control, c, alpha) if options.color then control.imageColor = colour(c, alpha) end end
    local function ink(control, c, alpha) if options.color then control.fontColor = colour(c, alpha) end end
    local function sound(cue)
        if options.sound then pcall(options.sound, cue) end
    end
    local function blocked() return options.blocked and options.blocked() end
    local function phaseChanged()
        if options.onPhase then options.onPhase(self.phase) end
    end
    local scenery = { "vista", "vignette", "hero", "flash", "barTop", "barBottom", "chapter", "line",
        "dot1", "dot2", "dot3", "hint", "skip" }

    local function camera(index)
        local shot = P.cameras[index]
        return shot.to, shot.from
    end
    local function startBeat(index)
        local to, from = camera(index)
        local pose = self.shot or from or to
        self.beat = { index = index, t = 0, shown = 0, hold = 0, chars = M.chars(self.beats[index]),
            from = { pose[1], pose[2], pose[3] }, to = to, slow = index == 1 }
        sound(index == 1 and "prologue_rumble" or index == 2 and "prologue_crack" or "prologue_rise")
    end
    local function finish()
        if self.phase ~= "beats" then return false end
        self.generation = self.generation + 1
        self.phase, self.t = "outro", 0
        return true
    end

    function self:play()
        self.generation = self.generation + 1
        self.playing, self.phase, self.t, self.clock, self.shot = true, "beats", 0, 0, nil
        for _, name in ipairs(scenery) do panel:GetChild(name):SetVisible(true) end
        panel:GetChild("flash"):SetVisible(false)
        hero:SetVisible(false)
        panel:GetChild("fade"):SetVisible(true)
        panel:GetChild("chapter").text = "序 · " .. Narrative.title
        panel:SetVisible(true)
        startBeat(1)
        self:pose()
        return true
    end
    function self:cancel()
        if not self.playing then return false end
        self.generation = self.generation + 1
        self.playing, self.phase, self.beat = false, nil, nil
        panel:SetVisible(false)
        return true
    end
    function self:opaque() return self.playing and self.phase ~= "reveal" end
    function self:covering() return self.playing end

    -- Tap: first reveals the whole sentence, then moves on. Too-early taps are ignored so
    -- one press can never both finish a line and skip the next.
    function self:advance()
        local beat = self.beat
        if not self.playing or self.phase ~= "beats" or blocked() or beat.t < P.minBeat then return false end
        if beat.shown < #beat.chars then beat.shown = #beat.chars self:pose() return true end
        if beat.index >= #self.beats then return finish() end
        startBeat(beat.index + 1)
        self:pose()
        return true
    end
    function self:skip()
        if not self.playing or blocked() then return false end
        return finish()
    end

    local function fade(alpha)
        local plate = panel:GetChild("fade")
        plate:SetVisible(alpha > 0)
        tint(plate, C.vista.shade, alpha)
    end
    function self:pose()
        if not self.playing then return end
        -- Once the map is uncovered only the black frame remains; nothing else may reappear.
        if self.phase == "reveal" then fade(1 - clamp(self.t / P.reveal)) return end
        local beat, clock = self.beat, self.clock
        -- Letterbox slides in with the opening fade and stays for the whole cinematic.
        local bars = easeOut(clamp(clock / P.fadeIn))
        local h = P.barHeight
        panel:GetChild("barTop"):SetAnchoredPosition(0, half + h / 2 - h * bars)
        panel:GetChild("barBottom"):SetAnchoredPosition(0, -half - h / 2 + h * bars)
        -- Camera: the first shot is a slow dolly across its whole beat; later shots ease to the next framing.
        local p = beat.slow and clamp(beat.t / (P.hold + P.move * 2)) or easeInOut(clamp(beat.t / P.move))
        local x, y, s = lerp(beat.from[1], beat.to[1], p), lerp(beat.from[2], beat.to[2], p), lerp(beat.from[3], beat.to[3], p)
        self.shot = { x, y, s }
        local shakeX, shakeY = 0, 0
        if beat.index == 1 and beat.t < P.shake then
            local fall = 1 - beat.t / P.shake
            shakeX = P.shakeAmplitude * math.sin(beat.t * 61) * fall
            shakeY = P.shakeAmplitude * 0.5 * math.sin(beat.t * 47) * fall
        end
        vista:SetAnchoredPosition(x + shakeX, y + shakeY)
        vista:SetLocalScale(s, s, 1)
        -- Seal: steady glow, then flickers and swells as it breaks, then quietens behind the traveller.
        local pulse = 1 + 0.03 * math.sin(clock * 2 * math.pi / V.breathe)
        local cracked = beat.index >= 2
        if beat.index == 2 then pulse = 1 + 0.1 * math.abs(math.sin(beat.t * 5)) * (1 - clamp(beat.t / 3)) + 0.04 end
        seal:SetLocalScale(pulse, pulse, 1)
        local flicker = cracked and beat.index == 2 and (math.sin(beat.t * 23) > 0.2) and C.danger or C.gold
        tint(seal:GetChild("ring"), flicker, beat.index == 3 and 0.5 or 0.85)
        tint(seal:GetChild("core"), C.goldBright, beat.index == 3 and 0.3 or 0.55 + 0.15 * math.sin(clock * 3))
        tint(seal:GetChild("heart"), cracked and C.danger or C.goldBright, beat.index == 3 and 0.6 or 1)
        for i, frame in ipairs(V.shards) do
            local shard = vista:GetChild("shard" .. i)
            local dx, dy = frame[1] - V.seal[1], frame[2] - V.seal[2]
            local burst = cracked and easeOut(clamp((beat.index == 2 and beat.t or 3) / 2.4)) or 0
            local float = 3 * math.sin(clock * 1.7 + i)
            shard:SetAnchoredPosition(frame[1] + dx * 1.6 * burst, frame[2] + dy * 0.6 * burst - 120 * burst ^ 2 + float)
            tint(shard, C.goldDim, 1 - 0.8 * burst)
        end
        local flash = panel:GetChild("flash")
        local flashing = beat.index == 2 and beat.t < P.flash
        flash:SetVisible(flashing)
        if flashing then tint(flash, C.goldBright, 0.35 * (1 - beat.t / P.flash)) end
        for i, at in ipairs(V.motes) do
            local rise = (clock * V.drift + i * 53) % 220
            local mote = vista:GetChild("mote" .. i)
            mote:SetAnchoredPosition(at[1] + 10 * math.sin(clock + i), at[2] + rise)
            tint(mote, C.goldBright, 0.7 * math.sin(math.pi * rise / 220))
        end
        -- The traveller's Geo mark rises with the last sentence.
        hero:SetVisible(beat.index == 3)
        if beat.index == 3 then
            local q = easeOut(clamp(beat.t / (P.move * 0.8)))
            hero:SetAnchoredPosition(P.hero[1], P.hero[2] - P.heroRise * (1 - q))
            local grow = 0.8 + 0.2 * q
            hero:SetLocalScale(grow, grow, 1)
            local breathe = 1 + 0.05 * math.sin(clock * 2 * math.pi / V.breathe)
            hero:GetChild("glow"):SetLocalScale(breathe, breathe, 1)
            tint(hero:GetChild("glow"), C.geo, 0.55 * q)
            tint(hero:GetChild("icon"), C.geo, q)
            tint(hero:GetChild("ring"), C.gold, q)
            tint(hero:GetChild("disc"), C.panelSunken, q)
        end
        -- Typed line keeps a fixed left edge; CJK glyphs are one font size wide.
        local count = math.min(#beat.chars, math.floor(beat.shown))
        line.text = table.concat(beat.chars, "", 1, count)
        local width = math.min(P.line[3], #beat.chars * F.title)
        line:SetAnchoredPosition(P.line[1] + P.line[3] / 2 - width / 2, P.line[2])
        ink(line, C.text, clamp(beat.t / 0.25))
        local complete = count >= #beat.chars
        local hint = panel:GetChild("hint")
        hint:SetVisible(complete and self.phase == "beats")
        hint.text = Controller.isController(options.controller)
            and (beat.index>=#self.beats and '确认进入遗迹 · 返回跳过' or '确认继续 · 返回跳过')
            or (beat.index >= #self.beats and "点击进入遗迹" or "点击继续")
        ink(hint, C.textDim, 0.55 + 0.45 * math.sin(clock * 3.4))
        for i = 1, 3 do tint(panel:GetChild("dot" .. i), i == beat.index and C.goldBright or C.goldDim, i <= beat.index and 1 or 0.5) end
        fade(self.phase == "outro" and clamp(self.t / P.fadeOut) or 1 - clamp(clock / P.fadeIn))
    end

    function self:update(dt)
        if not self.playing or blocked() then return end
        self.clock, self.t = self.clock + dt, self.t + dt
        local beat = self.beat
        if self.phase == "beats" then
            beat.t = beat.t + dt
            if beat.shown < #beat.chars then beat.shown = math.min(#beat.chars, beat.shown + dt * P.typeRate)
            else
                beat.hold = beat.hold + dt
                -- Unattended playback keeps the film moving; the last line waits for a tap.
                if beat.hold >= P.hold and beat.index < #self.beats then startBeat(beat.index + 1) end
            end
        elseif self.phase == "outro" and self.t >= P.fadeOut then
            -- Uncover the map behind a black frame that fades out; the map stays inert until done.
            self.phase, self.t = "reveal", 0
            for _, name in ipairs(scenery) do panel:GetChild(name):SetVisible(false) end
            phaseChanged()
        elseif self.phase == "reveal" and self.t >= P.reveal then
            self.generation = self.generation + 1
            self.playing, self.phase, self.beat = false, nil, nil
            panel:SetVisible(false)
            phaseChanged()
            return
        end
        self:pose()
    end

    -- A tap must start and end inside the cinematic of the same generation; an interrupted
    -- touch or a press left over from the title screen is ignored.
    local cursor = options.cursorEvents or {}
    local function bind(hit, action)
        Controller.bind(options.controller,hit,'prologue',action,function()return self.playing and not blocked()end)
        local armed
        if cursor.CursorDown and cursor.CursorUp then
            hit:AddCursorEventListener(cursor.CursorDown, function() armed = self.playing and self.generation or nil end)
            for _, event in pairs({ cursor.CursorExit, cursor.CursorEndDrag }) do
                if event then hit:AddCursorEventListener(event, function() armed = nil end) end
            end
        end
        hit:AddCursorEventListener(options.clickEvent, function()
            if Controller.pointerBlocked(options.controller)then return false end
            if cursor.CursorDown and cursor.CursorUp and armed ~= self.generation then armed = nil return false end
            armed = nil
            return action()
        end)
    end
    bind(panel:GetChild("advance"), function() return self:advance() end)
    bind(panel:GetChild("skip"):GetChild("hit"), function() return self:skip() end)
    panel:SetVisible(false)
    return self
end
return M
