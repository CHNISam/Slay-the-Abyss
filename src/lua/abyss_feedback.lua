-- Presentation only. Core commands have already committed before this runs.
-- Reuses native controls and OnUpdate; no coroutine, timers, assets or Tween callbacks.
local Theme = require("abyss_theme")
local EnemyView=require('abyss_battle_enemy_view')
local UnitView=require('abyss_battle_unit_view')
local Actors=require('abyss_actor')
local ActorMotion=require('abyss_actor_motion')
local SkillFeedback=require('abyss_skill_feedback')
local ActorPainter=require("abyss_feedback_actor_painter")
local MonsterArt=require('abyss_monster_art')
local Escape=require('abyss_monster_escape')
local CardFlow=require('abyss_card_flow')
local M = {}
local T, C, L, S = Theme.motion, Theme.color, Theme.layout, Theme.space
local ROW = (L.enemyRow.xFrom + L.enemyRow.xTo) / 2
-- Curve shapes, not tunables: pop overshoot, gentle swell and peak portrait flash strength.
local OVERSHOOT, SWELL = 1 / 3, 1 / 6
-- Fixed action waits from DamageAction / DamageAllEnemiesAction at sts@319009d5.
-- Theme hit-stop belongs to the independent VFX clock, never the action gate.
local DAMAGE_DURATION, AREA_DURATION, POST_ATTACK_WAIT = 0.1, 0.25, 0.1
local skipDamageWait = {brilliance = true, flechettes = true, barrage = true}
local function n(value) return string.format("%.0f", value or 0) end
local function clamp(x) return x < 0 and 0 or x > 1 and 1 or x end
local function easeOut(x) x = clamp(x) return 1 - (1 - x) * (1 - x) end
local function easeIn(x) x = clamp(x) return x * x end
local function hurts(kind) return kind == "damage" or kind == "hp_loss" or kind == "status_damage" end
local banners = {enemy_turn = true, player_turn = true, victory = true, defeat = true}
local timedLossNames = {lose_strength="回合末失去力量", lose_dexterity="回合末失去敏捷"}
local function skillContext(entry,catalog)
    local d=type(entry.detail)=='table' and entry.detail or {}
    if entry.kind=='play' then return {effects=catalog.cards[d.cardId].effects} end
    for _,unit in ipairs(entry.frame and entry.frame.enemies or {})do
        if unit.id==d.enemy then
            for _,intent in ipairs(unit.intents or {})do
                if intent.id==d.id then return {enemyId=unit.definitionId,intentId=d.id,intentKind=intent.kind,effects=intent.effects} end
            end
        end
    end
    return {}
end

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
            context = {kind = entry.kind, area = area, cardId = d.cardId, hits = {}}
            local skill=skillContext(entry,catalog)
            context.family=SkillFeedback.resolve(entry.kind,d,skill)
            styles[i] = {context = context}
        else
            local style = {context = context}
            styles[i] = style
            if entry.kind == "damage" and context then
                style.target = d.target
                context.hits[#context.hits + 1] = style
            end
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
    for _, style in ipairs(styles) do
        local groupContext = style.context
        if groupContext and not groupContext.classified then
            groupContext.classified = true
            local rounds, round, targets = {}, {}, {}
            for _, hit in ipairs(groupContext.hits) do
                -- Repeated damageAll actions (Whirlwind) have one action wait
                -- and one contact cue per pass, not one for the entire card.
                if groupContext.area and targets[hit.target] then
                    rounds[#rounds + 1], round, targets = round, {}, {}
                end
                round[#round + 1], targets[hit.target] = hit, true
            end
            rounds[#rounds + 1] = round
            for _, group in ipairs(rounds) do for k, hit in ipairs(group) do
                hit.form = groupContext.area and "area" or #group > 1 and "multi" or "single"
                hit.hit, hit.hits = k, #group
            end
            end
        end
    end
    for i,entry in ipairs(queue)do
        local d=type(entry.detail)=='table' and entry.detail or {}
        local style=styles[i]
        local status=catalog.statuses[d.status]
        style.family=SkillFeedback.resolve(entry.kind,d,{family=style.context and style.context.family,
            weight=style.weight,statusKind=status and status.kind})
    end
    return styles
end

local function duration(entry, style, fastMode)
    local kind = entry.kind
    if kind == "action_wait" then
        return fastMode and math.min(entry.detail.seconds, 0.1) or entry.detail.seconds
    end
    if kind == "play" then return T.base end
    if kind == "player_death" then return T.playerDeath end
    if banners[kind] then return T.banner end
    if kind == "intent" then return T.enemyActionGap end
    if kind == "enemy_escape" then return Escape.actionDuration end
    if kind == "gold_stolen" then return T.base end
    -- AbstractMonster.die starts an independent creature timer, not an action wait.
    if kind == "death" then return 0 end
    -- Area hits land on consecutive rendered frames: one shockwave rippling across the row.
    if kind == "damage" and style.form == "area" and style.hit < style.hits then return 0 end
    if kind == "damage" then
        local context = style.context or {}
        local base = style.form == "area" and context.cardId ~= "whirlwind" and AREA_DURATION or DAMAGE_DURATION
        local skip = fastMode or skipDamageWait[context.cardId] and style.form ~= "area"
        return base + (not skip and POST_ATTACK_WAIT or 0)
    end
    if hurts(kind) or kind == "block" or kind == "status" or kind == "heal" then return T.base end
    return 0
end

function M.new(stage, platform, present, complete)
    local self = { busy = false, fastMode = false, effects = {}, deaths = {}, dying = {}, poses = {}, escaping = {}, escaped = {}, slotOwners = {}, tints = {} }
    local overlay = stage:GetChild("feedback")
    local surfaces=require('abyss_monster_surfaces').get(stage)
    function self.bindIdle(_owner,battle)
        local changing=self.idleBattle and self.idleBattle~=battle
            or battle and self.battle and self.battle~=battle
        if not self.busy and changing then self:reset(battle==nil) end
        self.idleBattle = battle
        if battle and not self.busy then self.shadow = battle end
    end
    self.cardFlow=CardFlow.new(stage,platform)
    local function colour(c, alpha) return platform.color(c.r, c.g, c.b, math.floor((c.a or 255) * (alpha or 1))) end
    local function tint(box, c, alpha) box.imageColor = colour(c, alpha) end
    local function actor(id)
        if id == "player" then
            local lift=UnitView.noticeLift(self.shadow.player,L.player.portrait,L.player.position[2],true)
            return self.shadow.player,stage:GetChild("hero"),L.player.position[1],L.player.position[2]+lift
        end
        if surfaces then
            local box=surfaces:find(id)
            for _,entry in ipairs(self.shadow.enemies)do if entry.id==id then
                local x,_,_,_,y=EnemyView.position(0,0,entry)
                return entry,box,x,y
            end end
        end
        local rows=self.busy and self.enemyRows or EnemyView.slots(self.shadow,self)
        for slot,entry in ipairs(rows)do if entry.id==id then
            local x,_,_,_,y=EnemyView.position(#rows,slot,entry.actor)
            return entry.actor,stage:GetChild('enemy'..slot),x,y
        end end
        for _,a in ipairs(self.shadow.enemies)do if a.id==id then return a end end
    end
    local painter = {state=self, actor=actor, platform=platform, surfaces=surfaces}
    local function banner(text, danger)
        local label = overlay:GetChild("banner")
        self.bannerInk = danger and C.danger or C.goldBright
        label.text, label.fontColor = text, colour(self.bannerInk)
        label:SetVisible(true) overlay:GetChild("bannerPlate"):SetVisible(true)
    end
    -- Steps keep the sweep and a landing card; reset and finish clear everything.
    local function hideOverlay(landing, all)
        if self.cast then overlay:GetChild('sweep'):SetVisible(false) end
        self.cast=nil
        if not landing then self.dissolve = nil end
        if all then self.sweep = nil end
        local names = {"banner", "bannerPlate"}
        if not landing then names[#names + 1] = "playedCard" end
        if all then names[#names + 1] = "sweep" names[#names + 1] = "deathShade" end
        for _, name in ipairs(names) do pcall(function() overlay:GetChild(name):SetVisible(false) end) end
    end
    local function sound(cue)
        -- IDs come from the platform catalogue. Candidate audibility still needs real playtest.
        if platform.sound then
            local ok, reason = pcall(platform.sound, cue)
            if not ok then print("ABYSS_AUDIO unavailable " .. cue .. " " .. tostring(reason)) end
        end
    end
    local function resetUnit(name,box)
        box=box or (surfaces and name~="hero" and surfaces:control(tonumber(name:match("%d+"))) or stage:GetChild(name))
        if not box then return end
        MonsterArt.clearBox(box)
        for _, part in ipairs({"impact", "shield", "floating"}) do pcall(function() box:GetChild(part):SetVisible(false) end) end
        for _, part in ipairs({"portrait", "impact", "shield", "blockEdge", "blockIcon", "block"}) do
            pcall(function() local c = box:GetChild(part) c:SetLocalScale(1, 1, 1) if not part:find("^block") then c:SetAnchoredPosition(0, 0) end end)
        end
        tint(box:GetChild("portrait"), name == "hero" and C.buttonPressedText or C.text)
        if name == "hero" and platform.portraits then platform.portraits:battlePose(0,0,1,1) end
    end
    function self.bindEnemySlot(slot,id)
        if self.slotOwners[slot]~=id then resetUnit('enemy'..slot) self.slotOwners[slot]=id end
    end
    function self.reset(_owner,retainHistory)
        -- Hiding/rewards retire visuals, but terminal death evidence still belongs
        -- to this battle. Cancellation and the next battle clear that history.
        local history=retainHistory and self.deaths or {}
        self.battle = retainHistory and (self.battle or self.idleBattle) or nil
        self.idleBattle, self.idleClock, self.shadow = nil, 0, nil
        self.cardFlow:reset()
        stage:SetAnchoredPosition(0, 0)
        self.stageShake = 0
        hideOverlay(false, true)
        for _, name in ipairs({"banner", "bannerPlate"}) do
            pcall(function() local part = overlay:GetChild(name) part:SetAnchoredPosition(0, S.xxl) part:SetLocalScale(1, 1, 1) end)
        end
        resetUnit('hero')
        if surfaces then surfaces:each(function(box)resetUnit('monster',box)end)
        else for i=1,5 do resetUnit('enemy'..i)end end
        self.slotOwners={}
        self.tints={}
        self.effects, self.deaths, self.dying, self.poses, self.sweep, self.escaping, self.escaped = {}, history, {}, {}, nil, {}, {}
    end
    local function finish(failure)
        local wasBusy = self.busy
        if not failure and self.battle and self.shadow then
            local ok,reason=pcall(function()
                self.cardFlow:sync(self.shadow,self.battle,nil,true)
                self.cardFlow:update(0,self.battle.catalog,self.presentation,self.fastMode)
            end)
            if not ok then failure=reason end
        end
        self.busy, self.queue, self.current = false, nil, nil
        -- Cleanup errors are isolated so input always releases, even if an effect control failed.
        if failure then pcall(self.reset, self) end
        hideOverlay(false, true)
        if failure then print("ABYSS_FEEDBACK recovered " .. tostring(failure)) end
        if wasBusy then complete(failure) end
    end
    function self.cancel()
        if self.busy then finish("cancelled") else self:reset() end
    end
    -- Attacker body language: pull back, strike, recover. Enemies face the traveler (−x).
    local function strike(id, stop)
        local reach = id == "player" and S.l or -S.l
        self.poses[id] = {age = 0, keys = {{0, reach, 1}, {stop, reach, 1}, {stop + T.slow, 0, 1}}}
    end
    local function cardShape(definition)
        local targetsEnemy, area, attack = false, false, false
        for _, effect in ipairs(definition.effects) do
            targetsEnemy = targetsEnemy or effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "applyStatus"
            area = area or effect.op == "damageAll" or effect.op == "applyStatusAll"
            attack = attack or effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "damageAll"
        end
        return targetsEnemy,area,attack
    end
    local function cardFlight(d,targetsEnemy,area)
        local target = (targetsEnemy or area) and self.shadow.enemies[d.target or 1]
        local _, _, x, y = actor(target and target.id or "player")
        if area then x = ROW end
        -- STS 式落点：攻击牌撞到敌人身前下沿即爆开，不贴在立绘脸上。
        self.flight = { x = self.origin and self.origin[1] or 0, y = self.origin and self.origin[2] or L.hand.y, tx = x, ty = y,
            stop = (target or area) and S.xxl * 1.5 or 0 }
    end
    local function contactSound(d,style)
        -- One cue per contact; an area ripple shares the first target's cue.
        if style.form ~= "area" or style.hit == 1 then
            if (d.amount or 0) > 0 then
                sound(d.target == "player" and "hurt" or style.weight == "heavy" and "hit_heavy" or "hit")
            elseif (d.blocked or 0) > 0 then sound("block_hit") end
        end
    end
    local function statusDamageLabel(d,text,ink)
        if d.status then
            local status = self.shadow.catalog.statuses[d.status]
            text = (status and status.name or d.status)
                .. ((d.blocked or 0) > 0 and " 格挡 " .. n(d.blocked) or "")
                .. ((d.amount or 0) > 0 and " −" .. n(d.amount) or "")
            ink = (d.blocked or 0) > 0 and C.block or C.debuff
        end
        return text,ink
    end
    local function damageLabel(d)
        local text,ink
        text, ink = n(d.amount), C.danger
        if (d.blocked or 0) > 0 then text = "格挡 " .. n(d.blocked) .. ((d.amount or 0) > 0 and "\n−" .. n(d.amount) or "") ink = C.block end
        text,ink=statusDamageLabel(d,text,ink)

        return text,ink
    end
    local function previousActor(old,d)
        local previous = old.player
        if d.target ~= "player" then for _, value in ipairs(old.enemies) do if value.id == d.target then previous = value break end end end
        return previous
    end
    local function playStep(d)
        local card = overlay:GetChild("playedCard")
        local definition = self.shadow.catalog.cards[d.cardId]
        local display = self.presentation[d.cardId]
        card:GetChild("name").text = display and display.name or definition.name
        tint(card:GetChild("plate"), C.cardType[definition.type] or C.panelRaised)
        card:GetChild("art"):SetImage(platform.imageSource, Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
        local targetsEnemy,area,attack=cardShape(definition)
        cardFlight(d,targetsEnemy,area)
        self.cardFlow:playing(d,self.flight)
        card:SetAnchoredPosition(self.flight.x, self.flight.y) card:SetLocalScale(1, 1, 1)
        card:SetVisible(true) overlay:SetAsLastSibling() sound("player_action")
        -- The traveler draws back while the card lifts, then leans in as it lands.
        local lift = T.base * T.anticipation
        self.poses.player = {age = 0, keys = attack
            and {{0, 0, 1}, {lift, -S.s, 1}, {T.base, S.l, 1}, {T.base + T.slow, 0, 1}}
            or {{0, 0, 1}, {T.base, 0, 1 + SWELL}, {T.base + T.slow, 0, 1}}}
    end
    local function bannerStep(d, kind)
        if kind == "enemy_turn" then banner("敌方回合") sound("turn")
        elseif kind == "player_turn" then banner("我方回合 " .. n(self.shadow.turn)) sound("turn")
        elseif kind == "victory" then banner(d.allEnemiesEscaped and "敌人已逃跑" or "战斗胜利") sound("victory")
        else
            banner("旅途暂歇", true)
            local shade = overlay:GetChild("deathShade")
            tint(shade, C.backdrop, 0)
            shade:SetVisible(true)
            if not self.deaths.player then sound("defeat") end
        end
    end
    local function silentIntent(a,d)
        local silent = not a or a.hp <= 0
        for _, intent in ipairs(a and a.intents or {}) do
            if intent.id == d.id then
                silent = silent or intent.kind == "sleep" or intent.kind == "stunned" or intent.kind == "escape"
                break
            end
        end
        return silent
    end
    local function intentStep(d, _kind, style)
        local a = actor(d.enemy)
        -- Actor identity belongs to the action, not each damage/status tick.
        local silent=silentIntent(a,d)
        local cue = a and a.definitionId and ("action_" .. a.definitionId)
        if not silent and Theme.sound[cue] then sound(cue) end
        stage:GetChild("notice").text = (a and a.name or "敌人") .. " · 正在行动"
        -- Windup fills the existing action gap; non-attacks rise instead of pulling back.
        local gather = T.enemyActionGap * (1 - T.anticipation)
        self.poses[d.enemy] = {age = 0, keys = style.attacks
            and {{0, 0, 1}, {gather, S.m, 1 + SWELL}, {T.enemyActionGap, S.m, 1 + SWELL}}
            or {{0, 0, 1}, {gather, 0, 1 + OVERSHOOT}, {T.enemyActionGap + T.slow, 0, 1}}}
    end
    local function escapeStep(d)
        local a = actor(d.enemy)
        stage:GetChild("notice").text = (a and a.name or "敌人") .. "正在逃离，已窃取的金币不会返还。"
        -- EscapeAction holds only its source .5s; the actor moves independently for3s.
        self.poses[d.enemy] = nil
    end
    local function contactDeathSound(id)
        -- Preserve the planned area-death group's single audible cue, but own
        -- it at lethal contact so a long frame cannot expire the visual first.
        for _,entry in ipairs(self.queue or {})do
            if entry.kind=='death' and entry.detail.target==id and entry.detail.quiet then return end
        end
        local victim=actor(id)
        sound(Theme.deathSound[victim and victim.definitionId] or 'enemy_die')
    end
    local function startMonsterDeath(id)
        if self.dying[id] then return self.dying[id] end
        if self.deaths[id] then return nil end
        local current=self.tints[id] or C.text
        local dying={age=0,alpha=1,lifetime=self.playbackFastMode and 1.0 or 1.8,
            tone={r=current.r,g=current.g,b=current.b,a=current.a}}
        self.deaths[id],self.dying[id]=true,dying
        return dying
    end
    local function deathStep(d)
        if d.target == "player" then
            self.deaths.player=true
            self.dying.player={age=0,alpha=1}
        else
            -- The lethal frame already started die(); a deferred cue cannot restart it.
            local newlyStarted=not self.deaths[d.target]
            local dying=startMonsterDeath(d.target)
            if not dying or dying.cued then return end
            dying.cued=true
            if newlyStarted then contactDeathSound(d.target)end
        end
        local _, box = actor(d.target)
        if box then
            box:SetVisible(true)
            box:GetChild("impact"):SetImage(platform.imageSource, Theme.image.diamond)
        end
        if d.target == "player" and not d.quiet then sound("defeat")end
        if d.target == "player" then self.poses.player = nil overlay:SetAsLastSibling() end
    end
    local function damageText(d,kind,style)
        local text,ink=damageLabel(d)
        contactSound(d,style)
        if kind == "damage" and d.source and d.source ~= d.target then strike(d.source, style.stop or 0) end
        if style.form == "area" and style.hit == 1 then self.sweep = {age = 0} end

        return text,ink
    end
    local function statusText(d)
        local text,ink
        local status = self.shadow.catalog.statuses[d.status]
        text = (status and status.name or d.status) .. (d.amount >= 0 and " ＋" or " ") .. n(d.amount)
        if d.blockedStatus then
            local blocked = self.shadow.catalog.statuses[d.blockedStatus]
            text = "人工制品抵挡\n未施加" .. (blocked and blocked.name or timedLossNames[d.blockedStatus] or d.blockedStatus)
        end
        ink = status and status.kind == "buff" and C.buff or C.debuff
        sound("status")

        return text,ink
    end
    local function targetText(d,kind,style)
        local text, ink = "", C.goldBright
        if hurts(kind) then
            text, ink = damageText(d,kind,style)
        elseif kind == "block" then text, ink = "格挡 ＋" .. n(d.amount), C.block sound("block_gain")
        elseif kind == "status" then
            text, ink = statusText(d)
        elseif kind == "heal" then
            text, ink = "＋" .. n(d.amount), C.positive
            if (d.amount or 0) > 0 then sound("heal") end
        elseif kind == "gold_stolen" then text, ink = "失金 −" .. n(d.amount), C.goldBright end
        return text,ink
    end
    local function targetStep(d, kind, style, old)
        local a, box = actor(d.target)
        if box then
            local previous=previousActor(old,d)
            local text,ink=targetText(d,kind,style)
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
    local function startCast(d,kind,style)
        local family=style.family
        if family~='projectile' and family~='poison' and family~='bind' then return end
        local source=kind=='intent' and d.enemy or 'player'
        for i=self.index+1,#self.queue do
            local entry=self.queue[i]
            if entry.kind=='play' or entry.kind=='intent' or banners[entry.kind] then break end
            local detail=type(entry.detail)=='table' and entry.detail or {}
            if detail.target and detail.target~=source then
                local _,_,sx,sy=actor(source)
                local _,_,tx,ty=actor(detail.target)
                if sx and tx then self.cast={family=family,sx=sx,sy=sy,tx=tx,ty=ty,kind=kind} end
                return
            end
        end
    end
    local function startContactDeaths(old,nextView)
        -- AbstractMonster.damage calls die at lethal contact, before the action wait.
        -- Compare only frames already presented, never the future committed battle.
        local priorActors,started={},{}
        for _,unit in ipairs(old.enemies) do priorActors[unit.id]=unit end
        for _,unit in ipairs(nextView.enemies) do
            local prior=priorActors[unit.id]
            if prior and Actors.isPresent(prior) and unit.hp<=0 and not Actors.isPresent(unit) and not self.deaths[unit.id] then
                startMonsterDeath(unit.id)
                started[#started+1]=unit.id
            end
        end
        return started
    end
    local function enterFrame(entry, style)
        local old = self.shadow
        local nextView = {catalog = old.catalog, rules = old.rules}
        for k, v in pairs(entry.frame or old) do nextView[k] = v end
        -- Hold the played UID at contact until a committed frame names its pile.
        local landing = self.current and self.current.kind == "play" and entry.kind ~= "play"
        if entry.kind == "enemy_escape" and not self.escaping[entry.detail.enemy] and not self.escaped[entry.detail.enemy] then self.escaping[entry.detail.enemy] = Escape.start()end
        self.shadow, self.current, self.style, self.elapsed = nextView, entry, style, 0
        local contactDeaths=startContactDeaths(old,nextView)
        self.cardFlow:sync(old,nextView,entry.kind)
        self.cardFlow:update(0,self.battle.catalog,self.presentation,self.fastMode)
        hideOverlay(landing or next(self.cardFlow.inPlay)~=nil)
        if landing then
            local card = overlay:GetChild("playedCard")
            card:SetAnchoredPosition(self.flight.tx, self.flight.ty - (self.flight.stop or 0)) card:SetLocalScale(0.5, 0.5, 1)
            -- 接触帧后立即收缩消散，命中闪光接管视觉焦点。
            self.dissolve = 0
        end
        self.acting = entry.kind == "intent" and entry.detail.enemy or self.acting
        if entry.kind == "player_turn" then self.acting = nil end
        self.enemyRows=EnemyView.slots(self.shadow,self)
        present(self.shadow, self.acting, self.deaths)
        return old,contactDeaths
    end
    local function step(entry, style)
        local old,contactDeaths=enterFrame(entry,style)
        local d, kind = type(entry.detail) == "table" and entry.detail or {}, entry.kind
        print("ABYSS_FEEDBACK " .. kind .. " source=" .. tostring(d.source or d.enemy or "-") .. " target=" .. tostring(d.target or "-") .. " amount=" .. n(d.amount))
        if kind == "play" then
            playStep(d,kind,style,old)
            startCast(d,kind,style)
        elseif banners[kind] then
            bannerStep(d,kind,style,old)
        elseif kind == "intent" then
            intentStep(d,kind,style,old)
            startCast(d,kind,style)
        elseif kind == "enemy_escape" then
            escapeStep(d,kind,style,old)
        elseif kind == "death" or kind == "player_death" then
            deathStep(d,kind,style,old)
        elseif d.target then
            targetStep(d,kind,style,old)
        end
        -- Keep hit/action sound order within the same lethal presentation frame.
        for _,id in ipairs(contactDeaths)do contactDeathSound(id)end
    end
    local function pendingMonsterExit()
        for id in pairs(self.dying)do if id~='player'then return true end end
        return next(self.escaping)~=nil
    end
    local function advanceQueue()
        repeat
            local entry=self.queue[self.index+1]
            if entry and entry.kind=='victory' and pendingMonsterExit()then return end
            self.index=self.index+1
            if not entry then finish();return end
            step(entry,self.styles[self.index])
            -- Source onModifyPower is a synchronous callback, never another action wait/frame.
        until entry.kind~='source_intent_powers'
    end
    function self.start(_owner,before, battle, first, presentation, origin)
        -- GameActionManager releases its action gate independently of the
        -- dungeon's effectList. A subsequent card in this battle must not erase
        -- a previous target's still-running number, HP ghost or recovery pose.
        -- Cancellation, failure and battle replacement retain full cleanup.
        if self.battle ~= battle then self:reset() end
        self.battle = battle
        self.playbackFastMode = self.fastMode
        self.presentation, self.origin, self.acting = presentation, origin, nil
        self.shadow = {catalog = battle.catalog, rules = battle.rules}
        for k, v in pairs(before) do self.shadow[k] = v end
        self.deaths = {}
        for _, a in ipairs(before.enemies) do
            if a.hp <= 0 and not Actors.isPresent(a)then self.deaths[a.id] = true
            else self.dying[a.id] = nil end
        end
        self.queue, self.index, self.elapsed = {}, 0, 0
        local previous, area, pending, preDamageWait = before, false, {}, nil
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
                -- Bludgeon.use queues zero-wait VFX, WaitAction(0.8), then damage.
                -- This is a presentation wait; committed core events stay untouched.
                preDamageWait = entry.detail.cardId == "bludgeon" and 0.8 or nil
            elseif entry.kind ~= "damage" then area = false end
            if entry.kind == "damage" and entry.detail.source == "player" and preDamageWait then
                self.queue[#self.queue + 1] = {kind = "action_wait", detail = {seconds = preDamageWait}, frame = previous}
                preDamageWait = nil
            end
            -- A committed defeat, not a transient zero-HP frame, owns player death.
            -- Revival can cross zero during damage without ending the battle.
            if entry.kind == "defeat" then
                self.queue[#self.queue + 1] = {kind = "player_death", detail = {target = "player"}, frame = previous}
            end
            self.queue[#self.queue + 1] = entry
            if entry.frame then
                local priorActors = {}
                for _, a in ipairs(previous.enemies) do priorActors[a.id] = a end
                for _, a in ipairs(entry.frame.enemies) do
                    local prior = priorActors[a.id]
                    if prior and Actors.isPresent(prior)and a.hp <= 0 and not Actors.isPresent(a)then pending[#pending + 1] = a.id end
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
        self.index=0;advanceQueue()
    end
    function self.update(_owner,dt)
        if not self.idleBattle and not self.busy and next(self.effects) == nil and next(self.poses) == nil and next(self.dying) == nil and next(self.escaping)==nil and not self.sweep and not self.dissolve and not self.cardFlow:busy() then return end
        local ok, failure = pcall(function()
            assert(type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge, "invalid frame delta")
            self.idleClock=ActorMotion.advance(self.idleClock or 0,dt,T.actorIdle)
            self.elapsed = (self.elapsed or 0) + dt
            ActorPainter.advanceDeaths(painter,dt)
            ActorPainter.advanceEscapes(painter,dt)
            if self.battle then self.cardFlow:update(dt,self.battle.catalog,self.presentation,self.fastMode)end
            -- At most one visible step per update: a stalled frame cannot skip an enemy turn.
            if self.busy and (self.current.kind=="enemy_escape" and Escape.actionDone(self.elapsed)
                or self.current.kind~="enemy_escape" and self.elapsed >= duration(self.current, self.style, self.playbackFastMode)) then
                advanceQueue()
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
                    card:SetAnchoredPosition(f.x + (f.tx - f.x) * q, f.y + S.l + (f.ty - (f.stop or 0) - f.y - S.l) * q)
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
                if self.current.kind == "defeat" then
                    tint(overlay:GetChild("deathShade"), C.backdrop, easeIn(age / T.banner))
                end
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
                sweep.localRotationZ=0
                sweep:SetAnchoredPosition(ROW,L.enemyRow.y)
                sweep:SetVisible(p < 1)
                sweep:SetLocalScale(easeOut(p), 1 - p / 2, 1)
                tint(sweep, C.geo, 1 - easeIn(p))
                if p >= 1 then self.sweep = nil end
            end
            if self.cast then
                local cast=self.cast
                local total=cast.kind=='play' and T.base or T.enemyActionGap
                local p=clamp(self.elapsed/total)
                local x,y,alpha=SkillFeedback.travel(cast.family,p,cast.sx,cast.sy,cast.tx,cast.ty)
                local sweep=overlay:GetChild('sweep')
                sweep:SetVisible(alpha>0)
                sweep:SetAnchoredPosition(x,y)
                sweep:SetLocalScale(S.xl/(L.enemyRow.xTo-L.enemyRow.xFrom+L.enemyRow.bossPortrait),0.5,1)
                sweep.localRotationZ=cast.family=='bind' and p*180 or 0
                tint(sweep,cast.family=='poison' and C.positive or cast.family=='bind' and C.debuff or C.block,alpha)
            end
            local shakes, ids = {}, {}
            if self.idleBattle and self.shadow then
                if self.shadow.player.hp>0 then ids.player=true end
                for _,unit in ipairs(self.shadow.enemies)do if Actors.isPresent(unit) then ids[unit.id]=true end end
            end
            for id in pairs(self.poses) do ids[id] = true end
            for id in pairs(self.effects) do ids[id] = true end
            for id in pairs(self.dying) do ids[id] = true end
            for id in pairs(self.escaping) do ids[id] = true end
            -- A newly entered player death starts now, not at the beginning of a stalled frame.
            local effectDt = self.current and self.current.kind == "player_death" and math.min(dt, self.elapsed) or dt
            for id in pairs(ids) do ActorPainter.paint(painter,id,effectDt,shakes) end
            local shake = 0
            for _, value in ipairs(shakes) do if math.abs(value) > math.abs(shake) then shake = value end end
            if self.stageShake ~= shake then
                stage:SetAnchoredPosition(shake, 0)
                self.stageShake = shake
            end
        end)
        if not ok then finish(failure) end
    end
    function self.setFastMode(owner, enabled)
        assert(type(enabled) == "boolean", "fast mode must be boolean")
        owner.fastMode = enabled
    end
    -- Called only after the rule transaction; even start/control failure must unlock.
    function self.begin(_owner,...)
        -- Own completion before reset/queue preparation can fail or find no events.
        self.busy = true
        local ok, failure = pcall(self.start, self, ...)
        if not ok then finish(failure) end
    end
    return self
end
return M
