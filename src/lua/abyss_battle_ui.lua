-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
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
        self.canvasWidth, self.canvasHeight = width, height
        if options.embedded then return end -- The host owns the single canvas scale.
        local k = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        stage:SetLocalScale(k, k, 1)
        root:GetChild("backdrop"):SetSizeDelta(width, height)
    end
    local function unit(box, actor, portrait, icon, width, selected)
        local bh = L.hpBar.size[2]
        for _, name in ipairs({"plate", "border", "portrait"}) do
            local delta = name == "border" and S.border * 2 or name == "portrait" and -S.l or 0
            box:GetChild(name):SetSizeDelta(portrait + delta, portrait + delta)
        end
        if box.name ~= "hero" then box:GetChild("hit"):SetSizeDelta(portrait, portrait) end
        picture(box:GetChild("portrait"), icon)
        tint(box:GetChild("portrait"), box.name == "hero" and C.geo or C.text)
        tint(box:GetChild("border"), selected and C.goldBright or C.line)
        box:GetChild("name").text = actor.name or "旅行者"
        box:GetChild("name"):SetAnchoredPosition(0, -portrait / 2 - S.m)
        box:GetChild("name"):SetSizeDelta(width, L.nativeText.lineHeight)
        for _, name in ipairs({"hpBorder", "hpTrack", "hpFill", "hp"}) do
            local part = box:GetChild(name)
            part:SetAnchoredPosition(0, -portrait / 2 - S.xxl - bh / 2)
            local height = name == "hp" and L.nativeText.lineHeight or bh + (name == "hpBorder" and S.border * 2 or 0)
            part:SetSizeDelta(width + (name == "hpBorder" and S.border * 2 or 0), height)
        end
        tint(box:GetChild("hpBorder"), actor.block > 0 and C.block or C.line)
        box:GetChild("hpFill").fillAmount = math.max(0, math.min(1, actor.hp / actor.maxHp))
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
        box:SetAnchoredPosition(distance * spacing, math.max(floor, L.hand.y - math.abs(distance) * L.hand.arcDrop) + (selected and Theme.motion.hoverLift or 0))
        local scale = selected and Theme.motion.hoverScale or 1
        box:SetLocalScale(scale, scale, 1)
        box.localRotationZ = selected and 0 or angle
        box:GetChild("glow"):SetVisible(selected)
        box:SetAsLastSibling()
    end
    function self:render()
        local run = self.run
        if self.viewRun ~= run then
            self.viewRun, self.target, self.selected = run, 1, nil
            self.potionRun, self.potionBattle, self.potionSlots = nil, nil, nil
        end
        local fighting = run and run.phase == "combat"
        local battle = fighting and run.combat
        local reward = run and run.phase == "reward"
        local active = self.active and fighting and battle.phase == "player" and not self.busy
        local potions = fighting and Run.potionView(run) or {}
        self.potionTargetAvailable = false
        for _, item in ipairs(potions) do
            if active and item.canUse and item.needTarget then self.potionTargetAvailable = true break end
        end
        show("start", not options.embedded and (not run or run.phase == "defeat"))
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
        label("statuses", fighting and (battle.phase == "player" and "我方回合 " .. battle.turn or "敌方行动中") or "")
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
            box:SetVisible(enemy ~= nil and enemy ~= false and enemy.hp > 0)
            if enemy then
                local step = count > 1 and (L.enemyRow.xTo - L.enemyRow.xFrom) / (count - 1) or 0
                local width = math.min(L.hpBar.size[1], count > 1 and step - S.s or L.hpBar.size[1])
                local portrait = enemy.tier == "boss" and L.enemyRow.bossPortrait or math.min(L.enemyRow.portrait, width)
                box:SetAnchoredPosition(count == 1 and (L.enemyRow.xFrom + L.enemyRow.xTo) / 2 or L.enemyRow.xFrom + (i - 1) * step, L.enemyRow.y)
                local targetable = active and pendingTarget and Combat.canPlay(battle, self.selected, i)
                local potionTarget = self.potionTargetAvailable and not pendingTarget and self.target == i and enemy.hp > 0
                unit(box, enemy, portrait, Theme.icon.enemy[enemy.definitionId], width, targetable == true or potionTarget)
                local value, kind = intentText(battle, i)
                box:GetChild("intent").text = value
                box:GetChild("intent"):SetAnchoredPosition(S.l, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                box:GetChild("intentIcon"):SetAnchoredPosition(-S.xl, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                picture(box:GetChild("intentIcon"), Theme.icon.intent[kind] or Theme.icon.intent.unknown)
                tint(box:GetChild("intentIcon"), intentColors[kind] or C.textDim)
            end
        end
        local rewards = reward and Run.rewardOptions(run) or {}
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
                placeCard(box, fighting and #battle.hand or #rewards, i - 1, selected == true)
                if selected then selectedBox = box end
            end
        end
        if selectedBox then selectedBox:SetAsLastSibling() end
        button("endTurn", active == true, not playable)
        button("skip", self.active and reward == true and not self.busy, false)
        button("continue", self.active and run and run.phase == "map" and not self.busy, true)
        -- Keep physical slots fixed for the encounter: consuming slot one must not
        -- move slot two underneath a queued second click on the same button.
        if fighting and (self.potionBattle ~= battle or self.potionRun ~= run) then
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
        notice("点选卡牌，再点敌人；无需目标的牌再点一次确认。") refresh(true)
        print("ABYSS_UI combat_started")
    end
    function self:playSelected(target)
        if not self.active or not self.selected or self.busy or not self.run or self.run.phase ~= "combat" then return end
        local ok, reason = Run.play(self.run, self.selected, target)
        if ok then self.selected = nil end
        notice(ok and "出牌完成。" or reasons[reason] or "当前无法使用这张牌。") refresh(ok)
    end
    function self:playSlot(index)
        local run = self.run
        if not self.active or not run or self.busy then return end
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
        if not self.active or not self.run or self.busy or self.run.phase ~= "combat" or self.run.combat.phase ~= "player" then return end
        self.busy, self.selected = true, nil
        self:render() -- Controls are disabled before the synchronous core command.
        local ok = Run.endTurn(self.run)
        self.busy = false
        if ok then notice("新回合：查看敌人意图，规划能量与格挡。") end
        refresh(ok)
    end
    function self:usePotion(index)
        if not self.active or self.busy or not self.run or self.run.phase ~= "combat" then return false end
        local binding = self.potionSlots and self.potionSlots[index]
        if not binding or self.potionRun ~= self.run or self.potionBattle ~= self.run.combat
            or self.run.potions[binding.slot] ~= binding.id then return false end
        local ok, reason = Run.usePotion(self.run, binding.slot, self.target)
        if ok then
            self.potionSlots[index] = nil
            for _, other in pairs(self.potionSlots) do if other.slot > binding.slot then other.slot = other.slot - 1 end end
        end
        notice(ok and "药水已生效。" or reasons[reason] or "当前无法使用此药水。")
        refresh(ok)
        return ok, reason
    end
    local function bind(name, fn) child(name):AddCursorEventListener(clickEvent, fn) end
    bind("start", function() if not self.run or self.run.phase == "defeat" then self:start() end end)
    bind("endTurn", function() self:endTurn() end)
    bind("skip", function() if self.active and self.run and not self.busy and Run.claimCardReward(self.run, 0) then notice("已跳过卡牌奖励。") refresh(true) end end)
    bind("continue", function() if self.active and not options.embedded and not self.busy and self.run and self.run.phase == "map" then assert(Run.startCombat(self.run, "cultist_solo")) refresh(true) end end)
    for i = 1, 3 do local slot = i bind("potion" .. i, function() self:usePotion(slot) end) end
    for i = 1, 10 do local slot = i child("card" .. i):GetChild("hit"):AddCursorEventListener(clickEvent, function() self:playSlot(slot) end) end
    for i = 1, 5 do local target = i child("enemy" .. i):GetChild("hit"):AddCursorEventListener(clickEvent, function()
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
