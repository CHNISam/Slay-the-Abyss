-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local Events = require("abyss_events")
local Feedback = require("abyss_feedback")
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space
local reasons = { insufficient_energy = "能量不足", invalid_target = "请选择存活的敌人",
    card_not_in_hand = "这张牌已离开手牌", not_player_turn = "敌方行动中",
    advanced_card_not_enabled = "此牌效果尚未接入", not_in_combat = "战斗已经结束",
    empty_potion_slot = "此药水已使用", invalid_potion_slot = "请选择有效药水",
    effect_overflow = "当前状态已达上限" }
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态" }
local intentColors = { attack = C.danger, defend = C.block, buff = C.buff, debuff = C.debuff }
local function number(value) return string.format("%.0f", value) end
local function statuses(actor)
    local result = {}
    for _, entry in ipairs(Combat.statusView(actor)) do result[#result + 1] = entry.name .. " " .. number(entry.amount) end
    return table.concat(result, " · ")
end
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
local function potionText(item, battle)
    local effects = {}
    for _, effect in ipairs(item.effects) do
        local value = number(effect.value)
        if effect.op == "damage" then effects[#effects + 1] = "固定伤害 " .. value
        elseif effect.op == "block" then effects[#effects + 1] = "格挡 " .. value
        elseif effect.op == "energy" then effects[#effects + 1] = "能量 ＋" .. value
        elseif effect.op == "draw" then effects[#effects + 1] = "抽牌 " .. value
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            effects[#effects + 1] = assert(battle.catalog.statuses[effect.status]).name .. " " .. value
        end
    end
    return item.name .. "\n" .. table.concat(effects, "，")
end
local function intentText(state, index, detailed)
    local intent = Combat.intent(state, index)
    if not intent then return "已击败", "unknown" end
    local result, compact = {}, {}
    local enemy, player = Combat.copy(state.enemies[index]), Combat.copy(state.player)
    for _, effect in ipairs(intent.effects) do
        local value = effect.value and number(effect.value) or ""
        if effect.op == "damage" then
            local amount = number(Combat.attackAmount(state, enemy, player, effect.value))
                .. ((effect.times or 1) > 1 and "×" .. effect.times or "")
            compact.attack = compact.attack or amount
            result[#result + 1] = amount .. " 点伤害（已计入当前状态）"
        elseif effect.op == "block" then
            local amount = number(Combat.blockAmount(state, enemy, effect.value))
            compact.defend = compact.defend or amount
            result[#result + 1] = "格挡 " .. amount
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            result[#result + 1] = assert(state.catalog.statuses[effect.status]).name .. " " .. value
            compact.buff, compact.debuff = compact.buff or value, compact.debuff or value
            Combat.addStatus(effect.op == "gainStatus" and enemy or player, effect.status, effect.value)
        else result[#result + 1] = "未知" end
    end
    return detailed and table.concat(result, " / ") or compact[intent.kind] or compact.attack or "?", intent.kind
end

function M.new(root, data, presentation, clickEvent, platform, options)
    options = options or {}
    local self = { root = root, data = data, presentation = presentation, target = 1, seed = 1, busy = false, active = true }
    local stage = options.embedded and root or assert(root:GetChild("stage"), "missing stage")
    local function child(name) return assert(stage:GetChild(name), "missing UI control " .. name) end
    local function show(name, value) child(name):SetVisible(value == true) end
    local function label(name, value) child(name).text = value end
    local function colour(value) return platform.color(value.r, value.g, value.b, value.a) end
    local function tint(control, value) control.imageColor = colour(value) end
    local function ink(control, value) control.fontColor = colour(value) end
    local function picture(control, id) control:SetImage(platform.imageSource, id) end
    local function notice(value) label("notice", value) end
    local cursor = platform.cursorEvents
    self.dragEnabled = cursor and cursor.CursorDown and cursor.CursorDrag and cursor.CursorUp and cursor.CursorEndDrag
    self.instructions = self.dragEnabled and "拖牌至金线以上松手出牌；攻击牌拖至敌人。也可点选出牌。"
        or "点选卡牌，再点敌人；无需目标的牌再点一次确认。"
    local function dragReady(g)
        return self.active and not self.busy and self.run == g.run and self.run.phase == "combat"
            and self.run.combat == g.battle and g.battle.phase == "player" and g.battle.turn == g.turn
    end
    local function contains(x, y, frame)
        return math.abs(x-frame[1]) <= frame[3]/2 and math.abs(y-frame[2]) <= frame[4]/2
    end
    local function dragTarget(g)
        if not dragReady(g) then return false end
        local battle = g.battle
        local ok, reason = Combat.canPlay(battle,g.uid,nil)
        if ok then return contains(g.x,g.y,L.cardDrag.playArea), nil end
        if reason ~= "invalid_target" then return false end
        local count = #battle.enemies
        for i, enemy in ipairs(battle.enemies) do
            local step = count > 1 and (L.enemyRow.xTo-L.enemyRow.xFrom)/(count-1) or 0
            local width = math.min(L.hpBar.size[1],count > 1 and step-S.s or L.hpBar.size[1])
            local portrait = enemy.tier == "boss" and L.enemyRow.bossPortrait or math.min(L.enemyRow.portrait,width)
            local x = count == 1 and (L.enemyRow.xFrom+L.enemyRow.xTo)/2 or L.enemyRow.xFrom+(i-1)*step
            if contains(g.x,g.y,{x,L.enemyRow.y,portrait,portrait}) and Combat.canPlay(battle,g.uid,i) then return true,i end
        end
        return false
    end
    local function button(name, enabled, primary, caption)
        local box = child(name)
        box.interactable = enabled == true
        for _, state in ipairs({"normal", "hover", "pressed", "disabled"}) do
            local part = box:GetChild(state)
            if caption then part:GetChild("label").text = caption end
            if state == "normal" or state == "hover" then
                tint(part:GetChild("plate"), primary and (state == "hover" and C.goldBright or C.geo) or C.panelRaised)
                ink(part:GetChild("label"), primary and C.textOnLight or C.goldBright)
            end
        end
    end
    function self:resize(width, height)
        local cancelled = self.gesture ~= nil
        if cancelled then self.gesture, self.selected, self.suppressClick = nil, nil, true end
        self.canvasWidth, self.canvasHeight = width, height
        local k = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        child("dragLayer"):GetChild("hit"):SetSizeDelta(width/k,height/k)
        if not options.embedded then -- The host owns the single canvas scale.
            stage:SetLocalScale(k, k, 1)
            root:GetChild("backdrop"):SetSizeDelta(width, height)
        end
        if cancelled then self:render() end
    end
    local function unit(box, actor, portrait, icon, width, selected)
        local bh = L.hpBar.size[2]
        for _, name in ipairs({"plate", "border", "portrait"}) do
            local delta = name == "border" and S.border * 2 or name == "portrait" and -S.l or 0
            box:GetChild(name):SetSizeDelta(portrait + delta, portrait + delta)
        end
        if box.name ~= "hero" then box:GetChild("hit"):SetSizeDelta(portrait, portrait) end
        box:GetChild("impact"):SetSizeDelta(portrait, portrait)
        box:GetChild("shield"):SetSizeDelta(portrait, portrait)
        box:GetChild("floating"):SetSizeDelta(width + S.xl, L.nativeText.lineHeight * 2)
        picture(box:GetChild("portrait"), icon)
        tint(box:GetChild("portrait"), box.name == "hero" and C.geo or C.text)
        tint(box:GetChild("border"), selected and C.goldBright or C.line)
        box:GetChild("name").text = actor.name or "旅行者"
        box:GetChild("name"):SetAnchoredPosition(0, -portrait / 2 - S.m)
        box:GetChild("name"):SetSizeDelta(width, L.nativeText.lineHeight)
        for _, name in ipairs({"hpBorder", "hpTrack", "hpGhost", "hpFill", "hp"}) do
            local part = box:GetChild(name)
            part:SetAnchoredPosition(0, -portrait / 2 - S.xxl - bh / 2)
            local height = name == "hp" and L.nativeText.lineHeight or bh + (name == "hpBorder" and S.border * 2 or 0)
            part:SetSizeDelta(width + (name == "hpBorder" and S.border * 2 or 0), height)
        end
        tint(box:GetChild("hpBorder"), actor.block > 0 and C.block or C.line)
        box:GetChild("hpFill").fillAmount = math.max(0, math.min(1, actor.hp / actor.maxHp))
        box:GetChild("hpGhost").fillAmount = box:GetChild("hpFill").fillAmount
        box:GetChild("hp").text = number(actor.hp) .. "/" .. number(actor.maxHp)
        for _, name in ipairs({"blockIcon", "block"}) do
            box:GetChild(name):SetVisible(actor.block > 0)
            local compact = width < L.hpBar.size[1]
            local shield = compact and L.statusIcon.size or S.xxl
            box:GetChild(name):SetSizeDelta(shield, name == "block" and L.nativeText.lineHeight or shield)
            box:GetChild(name):SetAnchoredPosition(-width / 2 + (compact and shield / 2 or -S.l), -portrait / 2 - S.xxl - bh / 2)
        end
        box:GetChild("block").text = number(actor.block)
        box:GetChild("statuses").text = statuses(actor)
        box:GetChild("statuses"):SetAnchoredPosition(0, -portrait / 2 - S.xxl - bh - S.l)
        box:GetChild("statuses"):SetSizeDelta(width, L.nativeText.lineHeight)
    end
    local function placeCard(box, count, index, selected)
        local w, h = L.card.size[1], L.card.size[2]
        local spacing = count <= 1 and 0 or math.max(L.hand.spacingMin, math.min(L.hand.spacingMax, (L.hand.maxWidth - w) / (count - 1)))
        local distance = index - (count - 1) / 2
        local angle = -distance * L.hand.arcDegrees
        local radians = math.abs(angle) * math.pi / 180
        local halfHeight = (h * math.cos(radians) + w * math.sin(radians)) / 2
        local floor = -Theme.canvas.base[2] / 2 + Theme.canvas.safe.y + halfHeight
        local x, y = distance * spacing, math.max(floor, L.hand.y - math.abs(distance) * L.hand.arcDrop) + (selected and Theme.motion.hoverLift or 0)
        box:SetAnchoredPosition(x, y)
        local scale = selected and Theme.motion.hoverScale or 1
        box:SetLocalScale(scale, scale, 1)
        box.localRotationZ = selected and 0 or angle
        box:GetChild("glow"):SetVisible(selected)
        box:SetAsLastSibling()
        return {x, y}
    end
    function self:render()
        local run = self.run
        if self.gesture and not dragReady(self.gesture) then
            self.gesture, self.selected, self.suppressClick = nil, nil, true
        end
        if self.busy and self.feedback and (self.feedbackRun ~= run or self.feedbackBattle ~= (run and run.combat)) then
            self.feedback:cancel() return
        end
        if self.viewRun ~= run then
            self.viewRun, self.target, self.selected = run, 1, nil
            self.potionRun, self.potionBattle, self.potionSlots = nil, nil, nil
        end
        local fighting = self.displayBattle ~= nil or run and run.phase == "combat"
        local battle = self.displayBattle or fighting and run.combat
        local reward = not self.busy and run and run.phase == "reward"
        local active = self.active and fighting and battle.phase == "player" and not self.busy
        -- Validation stages potion transactions; do it once while input is available,
        -- never copy the event journal once per animation step.
        local potions = self.busy and self.potionViewCache or fighting and Run.potionView(run) or {}
        if not self.busy then self.potionViewCache = potions end
        self.potionTargetAvailable = false
        for _, item in ipairs(potions) do
            if active and item.canUse and item.needTarget then self.potionTargetAvailable = true break end
        end
        show("start", not self.busy and not options.embedded and (not run or run.phase == "defeat"))
        button("start", self.active, true, run and "重新启程" or "启程")
        show("endTurn", fighting)
        show("skip", reward)
        show("continue", not options.embedded and run and run.phase == "map")
        show("result", not fighting) show("resultPlate", not fighting)
        show("hero", fighting)
        local player = battle and battle.player
        label("player", "生命 " .. number(player and player.hp or run and run.hp or data.rules.player.maxHp) .. "/" .. number(run and run.maxHp or data.rules.player.maxHp))
        label("piles", "金币 " .. number(run and run.gold or 0) .. " · 牌组 " .. (run and #run.deck or 0) .. (battle and " · 消耗 " .. #battle.exhaust or ""))
        label("energy", number(battle and battle.energy or 0) .. "/" .. number(data.rules.player.energyPerTurn))
        tint(child("energyDisc"), battle and battle.energy > 0 and C.energy or C.energyEmpty)
        label("draw", battle and tostring(#battle.draw) or "0") label("discard", battle and tostring(#battle.discard) or "0")
        label("statuses", fighting and (self.busy and "行动演出中" or battle.phase == "player" and "我方回合 " .. battle.turn or "敌方行动中") or "")
        if fighting then unit(child("hero"), player, L.player.portrait, Theme.icon.player, L.hpBar.size[1], false) end
        if not run then label("result", "战斗演练\n点击启程，试用旅行者的初始牌组")
        elseif reward then label("result", "战斗胜利 · 金币 ＋" .. run.rewards.gold .. "\n选择一张牌加入牌组，或跳过")
        elseif run.phase == "defeat" then label("result", "旅途暂歇\n重新启程，重建牌组")
        elseif run.phase == "map" then label("result", "奖励已处理 · 牌组 " .. #run.deck .. " 张\n可再次挑战，检查新增卡牌") end
        ink(child("result"), run and run.phase == "defeat" and C.danger or C.goldBright)
        local count = fighting and #battle.enemies or 0
        local pendingTarget = false
        if fighting and self.selected then
            for _, instance in ipairs(battle.hand) do
                if instance.uid == self.selected then pendingTarget = needsTarget(battle, instance) break end
            end
        end
        for i = 1, 5 do
            local box = child("enemy" .. i)
            local enemy = fighting and battle.enemies[i]
            box:SetVisible(enemy ~= nil and enemy ~= false and (enemy.hp > 0 or self.busy and not self.feedback.deaths[enemy.id]))
            if enemy then
                local step = count > 1 and (L.enemyRow.xTo - L.enemyRow.xFrom) / (count - 1) or 0
                local width = math.min(L.hpBar.size[1], count > 1 and step - S.s or L.hpBar.size[1])
                local portrait = enemy.tier == "boss" and L.enemyRow.bossPortrait or math.min(L.enemyRow.portrait, width)
                box:SetAnchoredPosition(count == 1 and (L.enemyRow.xFrom + L.enemyRow.xTo) / 2 or L.enemyRow.xFrom + (i - 1) * step, L.enemyRow.y)
                local targetable = active and pendingTarget and Combat.canPlay(battle, self.selected, i)
                if self.gesture and self.gesture.moving then
                    local valid, hovered = dragTarget(self.gesture)
                    targetable = valid and hovered == i
                end
                local potionTarget = self.potionTargetAvailable and not pendingTarget and self.target == i and enemy.hp > 0
                unit(box, enemy, portrait, Theme.icon.enemy[enemy.definitionId], width, targetable == true or potionTarget or self.acting == enemy.id)
                local value, kind = intentText(battle, i)
                box:GetChild("intent").text = value
                box:GetChild("intent"):SetAnchoredPosition(S.l, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                box:GetChild("intentIcon"):SetAnchoredPosition(-S.xl, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                picture(box:GetChild("intentIcon"), Theme.icon.intent[kind] or Theme.icon.intent.unknown)
                tint(box:GetChild("intentIcon"), intentColors[kind] or C.textDim)
            end
        end
        local rewards = reward and Run.rewardOptions(run) or {}
        self.cardPositions = {}
        local playable, selectedBox = false, nil
        for i = 1, 10 do
            local box = child("card" .. i)
            local instance = fighting and battle.hand[i]
            local id = instance and instance.cardId or rewards[i]
            box:SetVisible(id ~= nil and id ~= false)
            if id then
                local definition = instance and Combat.cardDefinition(battle, instance)
                if not definition then for _, card in ipairs(data.cards.cards) do if card.id == id then definition = card break end end end
                local display = assert(presentation[id], "missing card presentation " .. id)
                local enabled = reward or active and Combat.canPlay(battle, instance.uid, self.target)
                playable = playable or enabled
                local selected = instance and instance.uid == self.selected
                box:GetChild("name").text = display.name .. (instance and instance.upgraded and "＋" or "")
                ink(box:GetChild("name"), instance and instance.upgraded and C.positive or enabled and C.text or C.textMuted)
                local text = instance and instance.upgraded and display.upgradeText or display.text
                local combatText = instance and (instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText)
                if combatText then
                    -- The core already applied upgrade and this instance's combat growth.
                    text = combatText:gsub("{effects%.0%.value}", number(definition.effects[1].value))
                end
                box:GetChild("label").text = text
                ink(box:GetChild("label"), enabled and C.text or C.textMuted)
                box:GetChild("type").text = typeNames[definition.type] or definition.type
                box:GetChild("cost").text = definition.costMode == "all_energy" and "X" or tostring(definition.cost)
                ink(box:GetChild("cost"), enabled and C.textOnLight or C.danger)
                tint(box:GetChild("costDisc"), enabled and C.energy or C.energyEmpty)
                tint(box:GetChild("border"), selected and C.goldBright or enabled and (C.rarity[definition.rarity] or C.line) or C.line)
                tint(box:GetChild("artPlate"), enabled and (C.cardType[definition.type] or C.panelRaised) or C.panelSunken)
                picture(box:GetChild("art"), Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
                local pose = placeCard(box, fighting and #battle.hand or #rewards, i - 1, selected == true)
                if instance then self.cardPositions[instance.uid] = pose end
                if selected then selectedBox = box end
            end
        end
        if selectedBox then selectedBox:SetAsLastSibling() end
        local g = self.gesture
        show("dragLayer", g ~= nil and g.moving == true)
        if g and g.moving then
            local box = child("card" .. g.slot)
            box:SetAnchoredPosition(g.origin[1]+g.x-g.sx,g.origin[2]+g.y-g.sy)
            box:SetLocalScale(Theme.motion.hoverScale,Theme.motion.hoverScale,1)
            box.localRotationZ = 0
            local valid, target = dragTarget(g)
            local layer = child("dragLayer")
            tint(layer:GetChild("line"),valid and C.goldBright or C.line)
            layer:GetChild("hint").text = valid and "松手出牌" or needsTarget(g.battle,{uid=g.uid}) and "拖至存活的敌人，松手出牌" or "拖至金线以上；移回手牌区取消"
            layer:SetAsLastSibling()
        end
        button("endTurn", active == true, not playable)
        button("skip", self.active and reward == true and not self.busy, false)
        button("continue", self.active and run and run.phase == "map" and not self.busy, true)
        -- Keep physical slots fixed for the encounter: consuming slot one must not
        -- move slot two underneath a queued second click on the same button.
        if fighting and not self.busy and (self.potionBattle ~= battle or self.potionRun ~= run) then
            self.potionBattle, self.potionRun, self.potionSlots = battle, run, {}
            for i, id in ipairs(run.potions) do self.potionSlots[i] = {slot = i, id = id} end
        end
        for i = 1, 3 do
            show("potion" .. i, fighting)
            local binding = self.potionSlots and self.potionSlots[i]
            local item = binding and potions[binding.slot]
            if item and item.id ~= binding.id then item = nil end
            button("potion" .. i, active and item and item.canUse, false, item and potionText(item, battle) or "空药水槽")
        end
    end
    local function refresh(changed)
        if self.run and self.run.phase == "combat" then
            local battle, found = self.run.combat, false
            if not battle.enemies[self.target] or battle.enemies[self.target].hp <= 0 then
                for i, enemy in ipairs(battle.enemies) do if enemy.hp > 0 then self.target = i break end end
            end
            for _, card in ipairs(battle.hand) do if card.uid == self.selected then found = true break end end
            if not found then self.selected = nil end
        else self.selected = nil end
        self:render()
        if changed and options.onChange then options.onChange(self) end
    end
    self.feedback = Feedback.new(stage, platform, function(battle, acting)
        self.displayBattle, self.acting = battle, acting
        self:render()
    end, function(failure)
        self.busy, self.displayBattle, self.acting = false, nil, nil
        if self.feedbackRun == self.run and self.feedbackBattle == (self.run and self.run.combat)
            and #self.feedbackBattle.events == self.feedbackLast then
            -- UI is the event consumer. Release consumed frames; the event table identity stays stable.
            for i = #self.feedbackBattle.events, 1, -1 do self.feedbackBattle.events[i] = nil end
        end
        notice(failure and "演出已恢复，可继续行动。" or "查看敌人意图，规划下一步行动。")
        refresh(failure ~= "cancelled")
    end)
    local function perform(command, origin)
        local battle = self.run.combat
        local before, first = Events.frame(battle), #battle.events + 1
        self.busy, self.feedbackRun, self.feedbackBattle = true, self.run, battle
        self.displayBattle = {catalog = battle.catalog, rules = battle.rules}
        for k, v in pairs(before) do self.displayBattle[k] = v end
        local shown, failure = pcall(self.render, self)
        if not shown then
            self.busy, self.displayBattle = false, nil
            print("ABYSS_FEEDBACK prepare_failed " .. tostring(failure))
            pcall(refresh)
            return false, "presentation_unavailable"
        end
        local called, ok, reason = pcall(command)
        if not called or not ok then
            self.busy, self.displayBattle = false, nil
            if not called then print("ABYSS_FEEDBACK command_failed " .. tostring(ok)) end
            refresh()
            return false, called and reason or "command_failed"
        end
        -- No core callback is retained by playback. The committed result is immutable to it.
        self.feedbackLast = #battle.events
        self.feedback:begin(before, battle, first, presentation, origin)
        return ok, reason
    end
    function self:update(dt)
        if self.feedbackRun and (self.feedbackRun ~= self.run or self.feedbackBattle ~= (self.run and self.run.combat)) then
            self.feedback:cancel()
            self.feedbackRun, self.feedbackBattle = nil, nil
            self:render() return
        end
        self.feedback:update(dt)
    end
    function self:setActive(active)
        assert(type(active) == "boolean", "active must be boolean")
        self.active = active
        root:SetVisible(active)
        self:render()
    end
    function self:start()
        if not self.active or options.embedded or self.busy then return false end
        self.run = Run.new(data, self.seed)
        self.seed = (self.seed + 1) % 65536
        assert(Run.startCombat(self.run, "cultist_solo"))
        self.target, self.selected = 1, nil
        notice(self.instructions) refresh(true)
        print("ABYSS_UI combat_started")
    end
    function self:playSelected(target)
        if not self.active or not self.selected or self.busy or not self.run or self.run.phase ~= "combat" then return end
        local uid, origin = self.selected, self.cardPositions[self.selected]
        local ok, reason = perform(function() return Run.play(self.run, uid, target) end, origin)
        if ok then self.selected = nil end
        notice(ok and "正在出牌。" or reasons[reason] or "当前无法使用这张牌。")
        if reason ~= "presentation_unavailable" then refresh() end
    end
    function self:playSlot(index)
        local run = self.run
        if not self.active or not run or self.busy or self.gesture or self.suppressClick then return end
        if run.phase == "reward" then
            local ok = Run.claimCardReward(run, index)
            if ok then notice("卡牌已加入牌组。") end
            refresh(ok) return
        elseif run.phase == "combat" then
            local instance = run.combat.hand[index]
            if not instance then return end
            local ok, reason = Combat.canPlay(run.combat, instance.uid, self.target)
            if not ok then notice(reasons[reason] or "当前无法使用这张牌。") refresh() return end
            if self.selected == instance.uid and not needsTarget(run.combat, instance) then self:playSelected(self.target) return end
            self.selected = instance.uid
            notice(needsTarget(run.combat, instance) and "点选一个敌人；点另一张牌可更换选择。" or "再次点击这张牌确认出牌。")
        end
        refresh()
    end
    function self:endTurn()
        if not self.active or not self.run or self.busy or self.gesture or self.suppressClick or self.run.phase ~= "combat" or self.run.combat.phase ~= "player" then return end
        self.selected = nil
        perform(function() return Run.endTurn(self.run) end)
    end
    function self:usePotion(index)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        local binding = self.potionSlots and self.potionSlots[index]
        if not binding or self.potionRun ~= self.run or self.potionBattle ~= self.run.combat
            or self.run.potions[binding.slot] ~= binding.id then return false end
        local ok, reason = perform(function() return Run.usePotion(self.run, binding.slot, self.target) end)
        if ok then
            self.potionSlots[index] = nil
            for _, other in pairs(self.potionSlots) do if other.slot > binding.slot then other.slot = other.slot - 1 end end
        end
        notice(ok and "药水已生效。" or reasons[reason] or "当前无法使用此药水。")
        if reason ~= "presentation_unavailable" then refresh() end
        return ok, reason
    end
    local function point(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local x,y = event:GetUIPos()
        if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then return end
        local width,height = self.canvasWidth or Theme.canvas.base[1],self.canvasHeight or Theme.canvas.base[2]
        local k = math.min(width/Theme.canvas.base[1],height/Theme.canvas.base[2])
        return (x-width/2)/k,(y-height/2)/k
    end
    local function down()
        if not self.gesture then self.suppressClick = false end
    end
    local function move(event)
        local g = self.gesture
        if not g or not event or event.touchId ~= g.touch then return end
        local x,y = point(event)
        if not x then return end
        g.x,g.y = x,y
        if (x-g.sx)^2+(y-g.sy)^2 >= L.cardDrag.threshold^2 then g.moving = true end
        if g.moving then
            self.suppressClick,self.selected = true,g.uid
            self:render()
        end
    end
    local function release(event)
        local g = self.gesture
        if not g or not event or event.touchId ~= g.touch then return end
        move(event)
        -- move/render may have cancelled a gesture belonging to an old battle.
        if self.gesture ~= g then return end
        local x,y = point(event)
        local valid,target = false,nil
        if x and g.moving then valid,target = dragTarget(g) end
        self.gesture = nil -- consume before invoking the command or any rendering callback
        if not g.moving then return end -- ordinary taps still receive CursorClick
        self.suppressClick,self.selected = true,valid and g.uid or nil
        self:render()
        if valid then self:playSelected(target)
        else notice("已取消出牌。" .. self.instructions) end
    end
    local function listen(control, fn, card)
        control:AddCursorEventListener(clickEvent,function(...) if not self.suppressClick and not self.gesture then return fn(...) end end)
        if self.dragEnabled and not card then control:AddCursorEventListener(cursor.CursorDown,down) end
    end
    local function bind(name, fn) listen(child(name),fn) end
    bind("start", function() if not self.run or self.run.phase == "defeat" then self:start() end end)
    bind("endTurn", function() self:endTurn() end)
    bind("skip", function() if self.active and self.run and not self.busy and Run.claimCardReward(self.run, 0) then notice("已跳过卡牌奖励。") refresh(true) end end)
    bind("continue", function() if self.active and not options.embedded and not self.busy and self.run and self.run.phase == "map" then assert(Run.startCombat(self.run, "cultist_solo")) refresh(true) end end)
    for i = 1, 3 do local slot = i bind("potion" .. i, function() self:usePotion(slot) end) end
    for i = 1, 10 do
        local slot,hit = i,child("card" .. i):GetChild("hit")
        listen(hit,function() self:playSlot(slot) end,true)
        if self.dragEnabled then
            hit:AddCursorEventListener(cursor.CursorDown,function(event)
                down()
                if self.gesture or not self.active or self.busy or not self.run or self.run.phase ~= "combat" then return end
                local battle = self.run.combat
                local instance = battle.hand[slot]
                local x,y = point(event)
                if not instance or not x then return end
                local ok,reason = Combat.canPlay(battle,instance.uid,nil)
                if not ok and reason ~= "invalid_target" then return end
                self.gesture = {uid=instance.uid,slot=slot,run=self.run,battle=battle,turn=battle.turn,
                    touch=event.touchId,sx=x,sy=y,x=x,y=y,origin=self.cardPositions[instance.uid]}
            end)
            hit:AddCursorEventListener(cursor.CursorDrag,move)
            hit:AddCursorEventListener(cursor.CursorUp,release)
            hit:AddCursorEventListener(cursor.CursorEndDrag,release)
        end
    end
    if self.dragEnabled then
        local layer = child("dragLayer")
        layer.disableCursorEventPassthrough = true
        local hit = layer:GetChild("hit")
        hit:AddCursorEventListener(cursor.CursorDrag,move)
        hit:AddCursorEventListener(cursor.CursorUp,release)
        hit:AddCursorEventListener(cursor.CursorEndDrag,release)
    end
    for i = 1, 5 do local target = i listen(child("enemy" .. i):GetChild("hit"),function()
        if self.active and self.run and not self.busy and self.run.phase == "combat" and self.run.combat.enemies[target] and self.run.combat.enemies[target].hp > 0 then
            self.target = target
            local selected
            for _, instance in ipairs(self.run.combat.hand) do
                if instance.uid == self.selected then selected = instance break end
            end
            if selected and needsTarget(self.run.combat, selected) then self:playSelected(target)
            else
                local prefix = self.potionTargetAvailable and "药水目标：" .. self.run.combat.enemies[target].name .. "；" or ""
                notice(prefix .. "意图：" .. intentText(self.run.combat, target, true)) refresh()
            end
        end
    end) end
    refresh()
    return self
end
return M
