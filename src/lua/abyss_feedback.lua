-- Presentation only. Core commands have already committed before this runs.
-- Reuses native controls and OnUpdate; no coroutine, timers, assets or Tween callbacks.
local Theme = require("abyss_theme")
local M = {}
local T, C, L, S = Theme.motion, Theme.color, Theme.layout, Theme.space
local ROW = (L.enemyRow.xFrom + L.enemyRow.xTo) / 2
-- Curve shapes, not tunables: pop overshoot, gentle swell and peak portrait flash strength.
local OVERSHOOT, SWELL, FLASH = 1 / 3, 1 / 6, 0.85
local function n(value) return string.format("%.0f", value or 0) end
local function clamp(x) return x < 0 and 0 or x > 1 and 1 or x end
local function easeOut(x) x = clamp(x) return 1 - (1 - x) * (1 - x) end
local function easeIn(x) x = clamp(x) return x * x end
local function mix(a, b, w) return {r = a.r + (b.r - a.r) * w, g = a.g + (b.g - a.g) * w, b = a.b + (b.b - a.b) * w, a = a.a} end
local function hurts(kind) return kind == "damage" or kind == "hp_loss" or kind == "status_damage" end
local banners = {enemy_turn = true, player_turn = true, victory = true, defeat = true}

-- Shape of each hit, read from the committed card/intent and the actual event amounts only.
-- form: single | multi | area | dot | self; weight: light | normal | heavy.
local function classify(queue, catalog)
    local styles, context = {}, nil
    for i, entry in ipairs(queue) do
        local d = type(entry.detail) == "table" and entry.detail or {}
        if entry.kind == "play" or entry.kind == "intent" or banners[entry.kind] or entry.kind == "potion" then
            local area = false
            if entry.kind == "play" then
                for _, effect in ipairs(catalog.cards[d.cardId].effects) do area = area or effect.op == "damageAll" end
            end
            context = {kind = entry.kind, area = area, hits = {}}
            styles[i] = {context = context}
        else
            local style = {context = context}
            styles[i] = style
            if entry.kind == "damage" and context then context.hits[#context.hits + 1] = style end
            if entry.kind == "status_damage" then style.form = "dot"
            elseif entry.kind == "hp_loss" then style.form = "self" end
            local total = (d.amount or 0) + (d.blocked or 0)
            style.weight = total >= T.heavyHitDamage and "heavy" or "normal"
            local victim = entry.frame and d.target
            if victim then
                for _, a in ipairs(entry.frame.enemies) do
                    if a.id == victim and a.hp <= 0 then style.lethal = true end
                end
                if victim == "player" and entry.frame.player.hp <= 0 then style.lethal = true end
            end
            if entry.kind == "damage" and (d.amount or 0) > 0 then
                style.stop = (style.weight == "heavy" or style.lethal) and T.hitStopHeavy or T.hitStop
            end
        end
    end
    for _, style in pairs(styles) do
        local hits = style.context and style.context.hits
        if hits and not style.form and #hits > 0 then
            for k, hit in ipairs(hits) do
                if hit == style then
                    style.form = style.context.area and "area" or #hits > 1 and "multi" or "single"
                    style.hit, style.hits = k, #hits
                end
            end
        end
    end
    return styles
end

local function duration(entry, style)
    local kind = entry.kind
    if kind == "play" then return T.base end
    if banners[kind] then return T.banner end
    if kind == "intent" then return T.enemyActionGap end
    if kind == "enemy_escape" then return T.enemyEscape end
    if kind == "gold_stolen" then return T.base end
    if kind == "death" then return entry.detail.chained and 0 or T.slow end
    -- Area hits land on consecutive rendered frames: one shockwave rippling across the row.
    if kind == "damage" and style.form == "area" and style.hit < style.hits then return 0 end
    if kind == "damage" then return T.base + (style.stop or 0) end
    if hurts(kind) or kind == "block" or kind == "status" or kind == "heal" then return T.base end
    return 0
end

-- Piecewise pose: {time, x, scale} keys with smooth in/out between them.
local function pose(keys, age)
    if age >= keys[#keys][1] then return keys[#keys][2], keys[#keys][3], true end
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if age < b[1] then
            local p = b[1] > a[1] and (age - a[1]) / (b[1] - a[1]) or 1
            p = p * p * (3 - 2 * p)
            return a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p, false
        end
    end
end

function M.new(stage, platform, present, complete)
    local self = { busy = false, effects = {}, deaths = {}, dying = {}, poses = {}, escaping = {} }
    local overlay = stage:GetChild("feedback")
    local function colour(c, alpha) return platform.color(c.r, c.g, c.b, math.floor((c.a or 255) * (alpha or 1))) end
    local function tint(box, c, alpha) box.imageColor = colour(c, alpha) end
    local function actor(id)
        if id == "player" then return self.shadow.player, stage:GetChild("hero"), L.player.position[1], L.player.position[2] end
        local count = #self.shadow.enemies
        for i, a in ipairs(self.shadow.enemies) do
            if a.id == id then
                local x = count == 1 and ROW or L.enemyRow.xFrom + (i - 1) * (L.enemyRow.xTo - L.enemyRow.xFrom) / (count - 1)
                return a, stage:GetChild("enemy" .. i), x, L.enemyRow.y
            end
        end
    end
    local function banner(text, danger)
        local label = overlay:GetChild("banner")
        self.bannerInk = danger and C.danger or C.goldBright
        label.text, label.fontColor = text, colour(self.bannerInk)
        label:SetVisible(true) overlay:GetChild("bannerPlate"):SetVisible(true)
    end
    -- Steps keep the sweep and a landing card; reset and finish clear everything.
    local function hideOverlay(landing, all)
        if not landing then self.dissolve = nil end
        if all then self.sweep = nil end
        local names = {"banner", "bannerPlate"}
        if not landing then names[#names + 1] = "playedCard" end
        if all then names[#names + 1] = "sweep" end
        for _, name in ipairs(names) do pcall(function() overlay:GetChild(name):SetVisible(false) end) end
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
        hideOverlay(false, true)
        for _, name in ipairs({"banner", "bannerPlate"}) do
            pcall(function() local part = overlay:GetChild(name) part:SetAnchoredPosition(0, S.xxl) part:SetLocalScale(1, 1, 1) end)
        end
        for _, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
            local box = stage:GetChild(name)
            for _, part in ipairs({"impact", "shield", "floating"}) do pcall(function() box:GetChild(part):SetVisible(false) end) end
            for _, part in ipairs({"portrait", "impact", "shield", "blockEdge", "blockIcon", "block"}) do
                pcall(function() local c = box:GetChild(part) c:SetLocalScale(1, 1, 1) if not part:find("^block") then c:SetAnchoredPosition(0, 0) end end)
            end
            tint(box:GetChild("portrait"), name == "hero" and C.geo or C.text)
        end
        self.effects, self.deaths, self.dying, self.poses, self.sweep, self.escaping = {}, {}, {}, {}, nil, {}
    end
    local function finish(failure)
        local wasBusy = self.busy
        self.busy, self.queue, self.current = false, nil, nil
        -- Cleanup errors are isolated so input always releases, even if an effect control failed.
        if failure then pcall(self.reset, self) end
        hideOverlay(false, true)
        if failure then print("ABYSS_FEEDBACK recovered " .. tostring(failure)) end
        if wasBusy then complete(failure) end
    end
    function self:cancel()
        if self.busy then finish("cancelled") else self:reset() end
    end
    -- Attacker body language: pull back, strike, recover. Enemies face the traveler (−x).
    local function strike(id, stop)
        local reach = id == "player" and S.l or -S.l
        self.poses[id] = {age = 0, keys = {{0, reach, 1}, {stop, reach, 1}, {stop + T.slow, 0, 1}}}
    end
    local function step(entry, style)
        local old = self.shadow
        local nextView = {catalog = old.catalog, rules = old.rules}
        for k, v in pairs(entry.frame or old) do nextView[k] = v end
        -- The played card stays for the contact frame and dissolves into the strike.
        local landing = self.current and self.current.kind == "play" and entry.kind ~= "play"
        if self.current and self.current.kind == "enemy_escape" then self.escaping[self.current.detail.enemy] = nil end
        if entry.kind == "enemy_escape" then self.escaping[entry.detail.enemy] = true end
        self.shadow, self.current, self.style, self.elapsed = nextView, entry, style, 0
        hideOverlay(landing)
        if landing then
            local card = overlay:GetChild("playedCard")
            card:SetAnchoredPosition(self.flight.tx, self.flight.ty) card:SetLocalScale(0.5, 0.5, 1)
            self.dissolve = 0
        end
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
            local targetsEnemy, area, attack = false, false, false
            for _, effect in ipairs(definition.effects) do
                targetsEnemy = targetsEnemy or effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "applyStatus"
                area = area or effect.op == "damageAll" or effect.op == "applyStatusAll"
                attack = attack or effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "damageAll"
            end
            local target = (targetsEnemy or area) and self.shadow.enemies[d.target or 1]
            local _, _, x, y = actor(target and target.id or "player")
            if area then x = ROW end
            self.flight = { x = self.origin and self.origin[1] or 0, y = self.origin and self.origin[2] or L.hand.y, tx = x, ty = y }
            card:SetAnchoredPosition(self.flight.x, self.flight.y) card:SetLocalScale(1, 1, 1)
            card:SetVisible(true) overlay:SetAsLastSibling() sound("card_play")
            -- The traveler draws back while the card lifts, then leans in as it lands.
            local lift = T.base * T.anticipation
            self.poses.player = {age = 0, keys = attack
                and {{0, 0, 1}, {lift, -S.s, 1}, {T.base, S.l, 1}, {T.base + T.slow, 0, 1}}
                or {{0, 0, 1}, {T.base, 0, 1 + SWELL}, {T.base + T.slow, 0, 1}}}
        elseif banners[kind] then
            if kind == "enemy_turn" then banner("敌方回合") sound("turn")
            elseif kind == "player_turn" then banner("我方回合 " .. n(self.shadow.turn)) sound("turn")
            elseif kind == "victory" then banner(d.allEnemiesEscaped and "敌人已逃跑" or "战斗胜利") sound("victory")
            else banner("旅途暂歇", true) sound("defeat") end
        elseif kind == "intent" then
            local a = actor(d.enemy)
            stage:GetChild("notice").text = (a and a.name or "敌人") .. " · 正在行动"
            -- Windup fills the existing action gap; non-attacks rise instead of pulling back.
            local gather = T.enemyActionGap * (1 - T.anticipation)
            self.poses[d.enemy] = {age = 0, keys = style.attacks
                and {{0, 0, 1}, {gather, S.m, 1 + SWELL}, {T.enemyActionGap, S.m, 1 + SWELL}}
                or {{0, 0, 1}, {gather, 0, 1 + OVERSHOOT}, {T.enemyActionGap + T.slow, 0, 1}}}
        elseif kind == "enemy_escape" then
            local a = actor(d.enemy)
            stage:GetChild("notice").text = (a and a.name or "敌人") .. "正在逃离，已窃取的金币不会返还。"
            -- Dedicated escape hold. No death collapse, death cue or death flag.
            self.poses[d.enemy] = nil
        elseif kind == "death" then
            self.deaths[d.target] = true
            local _, box = actor(d.target)
            box:SetVisible(true)
            self.dying[d.target] = {age = 0}
            box:GetChild("impact"):SetImage(platform.imageSource, Theme.image.diamond)
            if not d.quiet then
                local victim = actor(d.target)
                sound(Theme.deathSound[victim and victim.definitionId] or "enemy_die")
            end
        elseif d.target then
            local a, box = actor(d.target)
            if box then
                local previous = old.player
                if d.target ~= "player" then for _, value in ipairs(old.enemies) do if value.id == d.target then previous = value break end end end
                local text, ink = "", C.goldBright
                if hurts(kind) then
                    text, ink = n(d.amount), C.danger
                    if (d.blocked or 0) > 0 then text = "格挡 " .. n(d.blocked) .. ((d.amount or 0) > 0 and "\n−" .. n(d.amount) or "") ink = C.block end
                    if d.status then
                        local status = self.shadow.catalog.statuses[d.status]
                        text = (status and status.name or d.status)
                            .. ((d.blocked or 0) > 0 and " 格挡 " .. n(d.blocked) or "")
                            .. ((d.amount or 0) > 0 and " −" .. n(d.amount) or "")
                        ink = (d.blocked or 0) > 0 and C.block or C.debuff
                    end
                    -- One cue per contact; an area ripple shares the first target's cue.
                    if style.form ~= "area" or style.hit == 1 then
                        if (d.amount or 0) > 0 then
                            sound(d.target == "player" and "hurt" or style.weight == "heavy" and "hit_heavy" or "hit")
                        elseif (d.blocked or 0) > 0 then sound("block_hit") end
                    end
                    if kind == "damage" and d.source and d.source ~= d.target then strike(d.source, style.stop or 0) end
                    if style.form == "area" and style.hit == 1 then self.sweep = {age = 0} end
                elseif kind == "block" then text, ink = "格挡 ＋" .. n(d.amount), C.block sound("block_gain")
                elseif kind == "status" then
                    local status = self.shadow.catalog.statuses[d.status]
                    text = (status and status.name or d.status) .. (d.amount >= 0 and " ＋" or " ") .. n(d.amount)
                    ink = status and status.kind == "buff" and C.buff or C.debuff
                    sound("status")
                elseif kind == "heal" then
                    text, ink = "＋" .. n(d.amount), C.positive
                    if (d.amount or 0) > 0 then sound("heal") end
                elseif kind == "gold_stolen" then text, ink = "失金 −" .. n(d.amount), C.goldBright end
                if text ~= "" then
                    local floating = box:GetChild("floating")
                    floating.text, floating.fontColor = text, colour(ink)
                    local icon = (kind == "status" or kind == "status_damage") and Theme.icon.status[d.status]
                    box:GetChild("impact"):SetImage(platform.imageSource, icon or Theme.image.diamond)
                    self.effects[d.target] = {kind = kind, age = 0, detail = d, ink = ink, style = style,
                        icon = icon and true or false, stop = style.stop or 0, dir = d.target == "player" and -1 or 1,
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
        local previous, area, pending = before, false, {}
        local function flush()
            -- Deaths read the latest frame so a deferred fade never rewinds later hits.
            -- Simultaneous kills collapse together: chained deaths start on consecutive frames, one cue.
            for i, id in ipairs(pending) do
                self.queue[#self.queue + 1] = {kind = "death", detail = {target = id, chained = i < #pending, quiet = i > 1}, frame = previous}
            end
            pending = {}
        end
        for i = first, #battle.events do
            local entry = battle.events[i]
            if entry.kind ~= "damage" then flush() end
            if entry.kind == "play" then
                area = false
                for _, effect in ipairs(battle.catalog.cards[entry.detail.cardId].effects) do area = area or effect.op == "damageAll" end
            elseif entry.kind ~= "damage" then area = false end
            self.queue[#self.queue + 1] = entry
            if entry.frame then
                local priorActors = {}
                for _, a in ipairs(previous.enemies) do priorActors[a.id] = a end
                for _, a in ipairs(entry.frame.enemies) do
                    local prior = priorActors[a.id]
                    if prior and prior.hp > 0 and a.hp <= 0 then pending[#pending + 1] = a.id end
                end
                previous = entry.frame
            end
            -- A single-target kill fades at once; an area sweep finishes the row first.
            if not area then flush() end
        end
        flush()
        self.styles = classify(self.queue, battle.catalog)
        for i, entry in ipairs(self.queue) do
            if entry.kind == "intent" then
                for j = i + 1, #self.queue do
                    local later = self.queue[j]
                    if later.kind == "intent" or banners[later.kind] then break end
                    if later.kind == "damage" and type(later.detail) == "table" and later.detail.source == entry.detail.enemy then
                        self.styles[i].attacks = true break
                    end
                end
            end
        end
        if #self.queue == 0 then finish() return end
        self.index = 1 step(self.queue[1], self.styles[1])
    end
    -- Per-actor composition: attacker pose + victim knockback/flash + death collapse, applied once.
    local function paint(id, dt, shakes)
        local a, box = actor(id)
        if not box then self.effects[id], self.poses[id], self.dying[id] = nil, nil, nil return end
        local base = id == "player" and C.geo or C.text
        local x, y, sx, sy, ink, flash, alpha = 0, 0, 1, 1, base, 0, 1
        local posed = self.poses[id]
        if posed then
            posed.age = posed.age + dt
            local px, ps, done = pose(posed.keys, posed.age)
            x, sx, sy = px, ps, ps
            if done then self.poses[id] = nil end
        end
        local effect = self.effects[id]
        if effect then
            effect.age = effect.age + dt
            local age, d, style, kind = effect.age, effect.detail, effect.style, effect.kind
            local after = math.max(0, age - effect.stop)
            local frozen = age < effect.stop
            local lost = hurts(kind) and (d.amount or 0) > 0
            local heavy = style.weight == "heavy"
            local impact, shield = box:GetChild("impact"), box:GetChild("shield")
            -- Knockback snaps out on contact, holds through the hit-stop, then eases home.
            if lost and kind == "damage" then
                local reach = heavy and S.l or style.form == "area" and S.s or S.m
                local out = frozen and 1 or 1 - easeOut(after / T.base)
                x = x + effect.dir * reach * out
                if style.form == "multi" then y = y + (style.hit % 2 == 0 and S.xs or -S.xs) * out end
            elseif lost and style.form == "dot" and d.status ~= "poison" then
                x = x + effect.dir * S.xs * (1 - easeOut(age / T.fast))
            end
            if lost then
                flash = frozen and 1 or math.max(0, 1 - after / T.fast)
                ink = kind == "damage" and (id == "player" and C.danger or C.goldBright) or kind == "hp_loss" and C.danger or C.debuff
                if id == "player" or heavy or style.lethal then
                    local scale = math.min(1, ((d.amount or 0) + (d.blocked or 0)) / T.heavyHitDamage)
                    local amplitude = T.shakeAmplitude * (id == "player" and (scale + 1) / 2 or scale / 2)
                    if age < T.shake then shakes[#shakes + 1] = amplitude * (1 - age / T.shake) * math.sin(age / T.shake * math.pi * 4) end
                end
            elseif kind == "status" or kind == "heal" then
                flash = math.max(0, 1 - age / T.fast) / 2
                ink = effect.ink
            end
            -- Geo shard: one diamond image, shaped by non-uniform scale per attack form.
            local window = effect.icon and T.slow or heavy and T.base or T.fast
            local e = frozen and 0 or easeOut(after / window)
            local show = (lost or kind == "status") and age < effect.stop + window
            impact:SetVisible(show)
            if show then
                local ix, iy, iy0 = 1, 1, 0
                if effect.icon then
                    local stamp = kind == "status" and 1 + (1 - easeOut(age / T.fast)) * OVERSHOOT * 2 or 1 - OVERSHOOT + e * OVERSHOOT
                    ix, iy = stamp, stamp
                    if kind == "status" then iy0 = (effect.ink == C.buff and 1 or -1) * S.m * easeOut((age - T.fast) / (T.slow - T.fast)) end
                elseif heavy then ix, iy = 1 + e, 1 + e
                elseif style.form == "area" then ix, iy = 1.5 + e / 2, 0.2
                elseif style.form == "multi" and style.hit % 2 == 0 then ix, iy = 0.3 * (1 - e) + 0.1, 1.2 + e / 2
                else ix, iy = 1.2 + e / 2, 0.3 * (1 - e) + 0.1 end
                impact:SetLocalScale(ix, iy, 1)
                impact:SetAnchoredPosition(0, iy0)
                local shardInk = effect.icon and effect.ink or id == "player" and C.text or C.geo
                tint(impact, shardInk, effect.icon and kind == "status" and math.min(1, 2 - 2 * easeIn(age / T.slow)) or 1 - e)
            end
            -- Shield: crystallises in on gain, shudders when it holds, shatters when it breaks.
            local blocked = (d.blocked or 0) > 0
            local guard = kind == "block" or blocked
            shield:SetVisible(guard and age < T.slow)
            if guard and age < T.slow then
                local scale, wobble, fade = 1, 0, 1
                if kind == "block" then
                    scale = 1 + (1 - easeOut(age / T.fast)) * OVERSHOOT
                    fade = age < T.fast and easeOut(age / T.fast) or 1 - easeIn((age - T.fast) / (T.slow - T.fast))
                elseif lost then
                    scale, fade = 1 + easeOut(age / T.fast) / 2, math.max(0, 1 - age / T.fast)
                else
                    wobble = S.xs * math.sin(age / T.fast * math.pi * 3) * math.max(0, 1 - age / T.fast)
                    fade = 1 - easeIn(age / T.slow)
                end
                shield:SetLocalScale(scale, scale, 1) shield:SetAnchoredPosition(wobble, 0)
                tint(shield, C.block, fade)
                local pop = 1 + (1 - easeOut(age / T.base)) * OVERSHOOT
                -- Keep the badge inside its reserved horizontal lane beside HP and neighbouring units.
                for _, part in ipairs({"blockEdge", "blockIcon", "block"}) do box:GetChild(part):SetLocalScale(1, pop, 1) end
            end
            -- Number: pops on contact, holds through the hit-stop, settles, rises and fades.
            local p = clamp(age / T.damagePop)
            local floating = box:GetChild("floating")
            floating:SetVisible(p < 1)
            local drift = style.form == "multi" and (style.hit % 2 == 1 and -S.m or S.m) or 0
            floating:SetAnchoredPosition(drift, L.enemyRow.portrait / 2 + S.xl * easeOut(p))
            floating.fontColor = colour(effect.ink, p < 0.5 and 1 or 2 - 2 * p)
            local peak = heavy and lost and 2 or lost and 1.5 or 1.25
            local scale = frozen and peak or 1 + (peak - 1) * (1 - easeOut(after / T.fast))
            floating:SetLocalScale(scale, scale, 1)
            local ghost = clamp((age - T.hpGhostDelay) / T.hpGhost)
            box:GetChild("hpGhost").fillAmount = effect.oldHp + (effect.hp - effect.oldHp) * ghost
            if age >= math.max(T.damagePop, T.hpGhostDelay + T.hpGhost, effect.stop + window) then
                self.effects[id] = nil
                for _, part in ipairs({"blockEdge", "blockIcon", "block"}) do box:GetChild(part):SetLocalScale(1, 1, 1) end
                box:GetChild("impact"):SetLocalScale(1, 1, 1)
            end
        end
        local dying = self.dying[id]
        if dying then
            -- Gleam, then the figure crumbles into the ground as a shard burst disperses.
            dying.age = dying.age + dt
            local p = clamp(dying.age / T.slow)
            ink, flash, alpha = C.goldBright, 1 - easeOut(p), 1 - easeIn(p)
            sx, sy = sx * (1 + p * OVERSHOOT), sy * (1 - easeIn(p) / 2)
            y = y - S.m * easeIn(p)
            local impact = box:GetChild("impact")
            impact:SetVisible(p < 1) impact:SetAnchoredPosition(0, 0)
            impact:SetLocalScale(1 + easeOut(p), 1 + easeOut(p), 1)
            tint(impact, C.geo, (1 - p) * 0.8)
            box:SetVisible(p < 1)
            if p >= 1 then self.dying[id] = nil end
        end
        local portrait = box:GetChild("portrait")
        portrait:SetAnchoredPosition(x, y)
        portrait:SetLocalScale(sx, sy, 1)
        tint(portrait, flash > 0 and mix(base, ink, flash * FLASH) or base, alpha)
    end
    function self:update(dt)
        if not self.busy and next(self.effects) == nil and next(self.poses) == nil and next(self.dying) == nil and not self.sweep and not self.dissolve then return end
        local ok, failure = pcall(function()
            assert(type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge, "invalid frame delta")
            self.elapsed = self.elapsed + dt
            -- At most one visible step per update: a stalled frame cannot skip an enemy turn.
            if self.busy and self.elapsed >= duration(self.current, self.style) then
                self.index = self.index + 1
                local entry = self.queue[self.index]
                if not entry then finish() return end
                step(entry, self.styles[self.index])
            end
            if self.busy and self.current.kind == "play" then
                -- Lift and gather, then accelerate into the target: arrival is the contact frame.
                local p, lift = clamp(self.elapsed / T.base), T.anticipation
                local card, f = overlay:GetChild("playedCard"), self.flight
                if p < lift then
                    local q = easeOut(p / lift)
                    card:SetAnchoredPosition(f.x, f.y + S.l * q)
                    card:SetLocalScale(1 + q * OVERSHOOT, 1 + q * OVERSHOOT, 1)
                else
                    local q = easeIn((p - lift) / (1 - lift))
                    local s = (1 + OVERSHOOT) * (1 - q) + q / 2
                    card:SetAnchoredPosition(f.x + (f.tx - f.x) * q, f.y + S.l + (f.ty - f.y - S.l) * q)
                    card:SetLocalScale(s, s, 1)
                end
            end
            if self.busy and banners[self.current.kind] then
                -- Slide in, hold, slide out; the plate wipes open before the text arrives.
                local age, travel = self.elapsed, S.xxl * 2
                local enter, exit = easeOut(age / T.fast), easeIn((age - T.banner + T.fast) / T.fast)
                local label, plate = overlay:GetChild("banner"), overlay:GetChild("bannerPlate")
                label:SetAnchoredPosition(-travel * (1 - enter) + travel * exit, S.xxl)
                label.fontColor = colour(self.bannerInk, enter * (1 - exit))
                plate:SetLocalScale(1, enter * (1 - exit), 1)
            end
            if self.dissolve then
                self.dissolve = self.dissolve + dt
                local p, card = clamp(self.dissolve / T.fast), overlay:GetChild("playedCard")
                card:SetVisible(p < 1)
                card:SetLocalScale((1 - easeOut(p)) / 2, (1 - easeOut(p)) / 2, 1)
                if p >= 1 then self.dissolve = nil end
            end
            if self.sweep then
                self.sweep.age = self.sweep.age + dt
                local p = clamp(self.sweep.age / T.base)
                local sweep = overlay:GetChild("sweep")
                sweep:SetVisible(p < 1)
                sweep:SetLocalScale(easeOut(p), 1 - p / 2, 1)
                tint(sweep, C.geo, 1 - easeIn(p))
                if p >= 1 then self.sweep = nil end
            end
            local shakes, ids = {}, {}
            for id in pairs(self.poses) do ids[id] = true end
            for id in pairs(self.effects) do ids[id] = true end
            for id in pairs(self.dying) do ids[id] = true end
            for id in pairs(ids) do paint(id, dt, shakes) end
            local shake = 0
            for _, value in ipairs(shakes) do if math.abs(value) > math.abs(shake) then shake = value end end
            stage:SetAnchoredPosition(shake, 0)
        end)
        if not ok then finish(failure) end
    end
    -- Called only after the rule transaction; even start/control failure must unlock.
    function self:begin(...)
        -- Own completion before reset/queue preparation can fail or find no events.
        self.busy = true
        local ok, failure = pcall(self.start, self, ...)
        if not ok then finish(failure) end
    end
    return self
end
return M
