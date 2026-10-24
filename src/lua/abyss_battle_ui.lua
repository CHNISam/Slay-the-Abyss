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
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }
local intentColors = { attack = C.danger, defend = C.block, buff = C.buff, debuff = C.debuff }
local function number(value) return string.format("%.0f", value) end
-- One core preview entry: an exact value, or the range across living targets.
local function amount(preview)
    if preview.low == preview.high then return number(preview.low) end
    return number(preview.low) .. "~" .. number(preview.high)
end
-- Negative Strength/Dexterity are debuffs, as the core's Artifact gate treats them.
local function statusKind(entry) return entry.amount < 0 and "debuff" or entry.kind end
local kindNames = { buff = "增益", debuff = "减益" }
local function signed(value) return (value < 0 and "-" or "+") .. number(math.abs(value)) end
-- Text only: amounts come from statusView, percentages from the shared rules.
local function statusDetail(entry, rules)
    local n, c = number(entry.amount), rules.combat
    if entry.id == "strength" then
        return "攻击每段伤害 " .. signed(entry.amount) .. "。" .. (entry.temporary ~= 0
            and "其中 " .. number(entry.temporary) .. " 层在回合结束时移除。" or "")
    elseif entry.id == "dexterity" then return "获得的格挡 " .. signed(entry.amount) .. "。"
    elseif entry.id == "vulnerable" then return "受到的攻击伤害 +" .. number(c.vulnerablePercent - 100) .. "%，持续 " .. n .. " 回合。"
    elseif entry.id == "weak" then return "造成的攻击伤害 -" .. number(100 - c.weakPercent) .. "%，持续 " .. n .. " 回合。"
    elseif entry.id == "frail" then return "获得的格挡 -" .. number(100 - c.frailPercent) .. "%，持续 " .. n .. " 回合。"
    elseif entry.id == "poison" then return "回合开始时失去 " .. n .. " 点生命，然后层数 -1。"
    elseif entry.id == "regen" then return "回合结束时回复 " .. n .. " 点生命，然后层数 -1。"
    elseif entry.id == "thorns" then return "受到攻击时，对攻击者造成 " .. n .. " 点伤害。"
    elseif entry.id == "artifact" then return "抵挡接下来 " .. n .. " 次减益施加；不抵挡生成的状态牌。"
    end
    return entry.description .. (entry.stack == "none" and "" or "（当前 " .. n .. " 层）")
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
    if intent.kind == "charge" then return "蓄能", "unknown" end
    if intent.kind == "sleep" then return "沉睡", "sleep" end
    if intent.kind == "stunned" then return "苏醒中", "unknown" end
    if intent.kind == "split" then
        return detailed and "分裂为两只中型棘刺团，各自生命等于分裂时的当前生命。" or "分裂", "unknown"
    end
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
            local amount = number(Combat.blockAmount(state, enemy, effect.value, effect.target == "random_ally"))
            compact.defend = compact.defend or amount
            result[#result + 1] = (effect.target == "random_ally" and "随机队友格挡（无队友时自身） " or "格挡 ") .. amount
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            result[#result + 1] = assert(state.catalog.statuses[effect.status]).name .. " " .. value
            compact.buff, compact.debuff = compact.buff or value, compact.debuff or value
            Combat.addStatus(effect.op == "gainStatus" and enemy or player, effect.status, effect.value)
        elseif effect.op == "makeTempCardInDiscard" then
            local name = assert(state.catalog.cards[effect.card]).name
            compact.debuff = compact.debuff or name .. " " .. value
            result[#result + 1] = "将 " .. value .. " 张" .. name .. "置入弃牌堆"
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
    self.instructions = self.dragEnabled and "拖牌越过金线出牌，攻击牌拖向敌人；也可点选。"
        or "点选卡牌，再点敌人；无需目标的牌再点一次。"
    local function dragReady(g)
        return self.active and not self.busy and self.run == g.run and self.run.phase == "combat"
            and self.run.combat == g.battle and g.battle.phase == "player" and g.battle.turn == g.turn
    end
    -- A card click is the final event of one physical pointer sequence. Retain
    -- its original rule identity, not a global permission another Down can reset.
    local cardInputs, pointerObserved = {}, false
    local function cardReady(g)
        if not self.active or self.busy or self.run ~= g.run or self.run.phase ~= g.phase then return false end
        if g.phase == "combat" then
            local instance = g.battle.hand[g.slot]
            return dragReady(g) and instance ~= nil and instance.uid == g.uid
        end
        return g.phase == "reward" and self.run.rewards == g.rewards
            and Run.rewardOptions(self.run)[g.slot] == g.uid
    end
    local function cancelCardInputs()
        for _, input in ipairs(cardInputs) do input.held, input.released = nil, nil end
    end
    -- Potion controls may be click-only even when cards receive pointer events.
    -- Once a potion Down is observed, require its own one-shot release token.
    local potionInputs, potionPointerObserved = {}, false
    local function potionReady(g)
        return dragReady(g) and self.run.potions == g.inventory
            and self.run.potions[g.slot] == g.id
    end
    local function cancelPotionInputs()
        for _, input in ipairs(potionInputs) do input.held, input.released = nil, nil end
    end
    -- Action buttons have their own pointer capability: some hosts deliver
    -- card/potion pointers but only Click for these preset buttons.
    local actionInputs, actionPointerObserved = {}, false
    local function actionReady(g)
        local run = self.run
        if not self.active or self.busy or self.gesture or run ~= g.run then return false end
        if run and (run.phase ~= g.phase or run.combat ~= g.battle
            or g.battle and g.battle.turn ~= g.turn) then return false end
        if g.name == "start" then return not options.embedded and (not run or run.phase == "defeat") end
        if not run then return false end
        if g.name == "endTurn" then return dragReady(g) end
        if g.name == "skip" then return run.phase == "reward" and run.rewards == g.rewards end
        return g.name == "continue" and not options.embedded and run.phase == "map"
    end
    local function cancelActionInputs()
        for _, input in ipairs(actionInputs) do input.held, input.released = nil, nil end
    end
    -- Dynamic spawns can occupy an old enemy slot. Pointer ownership follows
    -- the actor object, battle and turn, never a reusable numeric slot alone.
    local enemyInputs, enemyPointerObserved = {}, false
    local function enemyReady(g)
        return not self.info and dragReady(g) and g.actor.hp > 0 and g.battle.enemies[g.slot] == g.actor
    end
    local D = L.cardDrag
    local function enemySlot(count, i, enemy)
        local step = count > 1 and (L.enemyRow.xTo-L.enemyRow.xFrom)/(count-1) or 0
        local width = math.min(L.hpBar.size[1],count > 1 and step-S.s or L.hpBar.size[1])
        local portrait = enemy.tier == "boss" and L.enemyRow.bossPortrait or math.min(L.enemyRow.portrait,width)
        return count == 1 and (L.enemyRow.xFrom+L.enemyRow.xTo)/2 or L.enemyRow.xFrom+(i-1)*step, width, portrait, step
    end
    -- Judge the card the player sees, not the pointer hidden under it: a quarter of
    -- the dragged card above the gold line (or the pointer itself) arms the play.
    local function dragPose(g)
        local origin, h = g.origin or {g.sx,g.sy}, L.card.size[2]*D.scale
        local x, y = origin[1]+g.x-g.sx, origin[2]+g.y-g.sy
        return x, y, y+h/2-D.commitOverlap*h >= D.lineY or g.y >= D.lineY, y < D.cancelY
    end
    -- Once armed, only pulling the card clearly back into the hand disarms it, so a
    -- wobble or release jitter near the line never turns an intended play into a cancel.
    local function arm(g)
        local _, _, crossed, back = dragPose(g)
        if crossed then g.armed = true elseif back then g.armed = false end
    end
    -- Returns valid, target, aiming. Armed targeted cards always aim: the pointer's
    -- column wins, otherwise the nearest living enemy. A locked enemy that falls
    -- mid-drag is never silently swapped; the player must aim at another column.
    local function dragTarget(g)
        if not dragReady(g) then return false end
        local battle = g.battle
        local ok, reason = Combat.canPlay(battle,g.uid,nil)
        if ok then return g.armed == true, nil end
        if reason ~= "invalid_target" then return false end
        if not g.armed then return false end
        local count, column, nearest, distance = #battle.enemies, nil, nil, math.huge
        for i, enemy in ipairs(battle.enemies) do
            local x, _, _, step = enemySlot(count,i,enemy)
            local reach = math.min(D.targetColumn,count > 1 and step or D.targetColumn)/2
            local d = math.abs(g.x-x)
            if Combat.canPlay(battle,g.uid,i) then
                if d <= reach then column = i end
                if d < distance then nearest, distance = i, d end
            end
        end
        local lost = g.lock and not (g.lock.hp > 0 and battle.enemies[g.lockIndex] == g.lock)
        local target = column or not lost and nearest or nil
        return target ~= nil, target, true
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
    local closeInfo -- defined with the detail panel below
    function self:resize(width, height)
        local cancelled = self.gesture ~= nil
        cancelCardInputs()
        cancelPotionInputs()
        cancelActionInputs()
        for _, input in ipairs(enemyInputs) do input.held, input.released = nil, nil end
        if cancelled then self.gesture, self.selected, self.suppressClick = nil, nil, true end
        if closeInfo() then cancelled = true end
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
        box:GetChild("hit"):SetSizeDelta(portrait, portrait)
        box:GetChild("impact"):SetSizeDelta(portrait, portrait)
        box:GetChild("shield"):SetSizeDelta(portrait, portrait)
        box:GetChild("floating"):SetSizeDelta(width + S.xl, L.nativeText.lineHeight * 2)
        picture(box:GetChild("portrait"), icon)
        tint(box:GetChild("portrait"), box.name == "hero" and C.geo or C.text)
        tint(box:GetChild("border"), selected and C.goldBright or C.line)
        box:GetChild("name").text = actor.name or "旅行者"
        box:GetChild("name"):SetAnchoredPosition(0, -portrait / 2 - S.m)
        box:GetChild("name"):SetSizeDelta(width, L.nativeText.lineHeight)
        -- The block chip never covers the bar: wide bars keep their size and the chip sits outside;
        -- narrow enemy columns hand the bar's left end to the chip.
        local blocked, chip, gap = actor.block > 0, L.blockBadge.size, L.blockBadge.gap
        local barWidth, barX, y = width, 0, -portrait / 2 - S.xxl - bh / 2
        if blocked and width < L.hpBar.size[1] then barWidth, barX = width - chip - gap, (chip + gap) / 2 end
        for _, name in ipairs({"hpBorder", "hpTrack", "hpGhost", "hpFill", "hp"}) do
            local part = box:GetChild(name)
            part:SetAnchoredPosition(barX, y)
            local height = name == "hp" and L.nativeText.lineHeight or bh + (name == "hpBorder" and S.border * 2 or 0)
            part:SetSizeDelta(barWidth + (name == "hpBorder" and S.border * 2 or 0), height)
        end
        tint(box:GetChild("hpBorder"), blocked and C.block or C.line)
        tint(box:GetChild("hpFill"), blocked and C.hpShielded or C.hp)
        box:GetChild("hpFill").fillAmount = math.max(0, math.min(1, actor.hp / actor.maxHp))
        box:GetChild("hpGhost").fillAmount = box:GetChild("hpFill").fillAmount
        box:GetChild("hp").text = number(actor.hp) .. "/" .. number(actor.maxHp)
        for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
            local part = box:GetChild(name)
            part:SetVisible(blocked)
            local side = name == "blockEdge" and chip + S.border * 2 or chip
            part:SetSizeDelta(side, name == "block" and L.nativeText.lineHeight or side)
            part:SetAnchoredPosition(barX - barWidth / 2 - gap - chip / 2, y)
        end
        tint(box:GetChild("blockEdge"), C.panelSunken)
        tint(box:GetChild("blockIcon"), C.block)
        ink(box:GetChild("block"), C.textOnLight)
        box:GetChild("block").text = number(actor.block)
        -- Status chips: rows centred under the bar; the last slot turns into "+N" on overflow.
        local si, entries, row = L.statusIcon, Combat.statusView(actor), box:GetChild("statusRow")
        local pitch = si.size + si.gap
        local perRow = math.max(1, math.min(si.perRow, math.floor((width + si.gap) / pitch)))
        local slots = perRow * si.rows
        local shown = math.min(#entries, slots)
        row:SetAnchoredPosition(0, -portrait / 2 - S.xxl - bh - S.l - (si.rows - 1) * pitch / 2)
        row:GetChild("hit"):SetSizeDelta(width, si.rows * pitch)
        for i = 1, si.perRow * si.rows do
            local icon, count, entry = row:GetChild("icon" .. i), row:GetChild("count" .. i), i <= shown and entries[i]
            local overflow = entry and i == slots and #entries > slots
            icon:SetVisible(entry and not overflow or false)
            count:SetVisible(entry and true or false)
            if entry then
                local k = i - 1
                local line = math.floor(k / perRow)
                local x = (k % perRow - (math.min(perRow, shown - line * perRow) - 1) / 2) * pitch
                local y = (si.rows - 1) * pitch / 2 - line * pitch
                icon:SetAnchoredPosition(x, y)
                picture(icon, Theme.icon.status[entry.id])
                tint(icon, statusKind(entry) == "buff" and C.buff or C.debuff)
                if overflow then
                    count:SetAnchoredPosition(x, y)
                    count.text = "+" .. (#entries - slots + 1)
                    ink(count, C.textDim)
                else
                    count:SetAnchoredPosition(x + si.size / 2, y - si.size / 2 + si.gap)
                    count.text = entry.stack == "none" and "" or number(entry.amount)
                    ink(count, C.text)
                end
            end
        end
    end
    -- Shared detail panel beside its unit; rows list every status with its current effect.
    local function renderInfo(battle)
        local panel, info = child("statusInfo"), self.info
        local actor = info and battle and (info.index == 0 and battle.player or battle.enemies[info.index])
        if not actor or actor.id ~= info.id or actor.hp <= 0 then
            self.info = nil
            panel:SetVisible(false)
            return
        end
        local I, entries = L.statusInfo, Combat.statusView(actor)
        local rows = math.min(#entries, I.rows)
        local extra = #entries == 0 or #entries > I.rows
        local height = I.pad * 2 + I.header + I.summary + rows * I.row + (extra and I.summary or 0)
        local x, portrait
        if info.index == 0 then
            x, portrait = L.player.position[1], L.player.portrait
            x = x + portrait / 2 + S.l + I.width / 2
        else
            local enemyX, _, size = enemySlot(#battle.enemies, info.index, actor)
            x, portrait = enemyX - size / 2 - S.l - I.width / 2, size
        end
        local edge = Theme.canvas.base[1] / 2 - Theme.canvas.safe.x - I.width / 2
        x = math.max(-edge, math.min(edge, x))
        local top = Theme.canvas.base[2] / 2 - L.topBar.height - S.s
        -- Top edge level with the portrait's top, kept under the top bar and above the safe edge.
        local unitY = info.index == 0 and L.player.position[2] or L.enemyRow.y
        local y = math.min(top - height / 2, unitY + portrait / 2 - height / 2)
        y = math.max(-Theme.canvas.base[2] / 2 + Theme.canvas.safe.y + height / 2, y)
        for _, name in ipairs({"border", "plate"}) do
            local delta = name == "border" and S.border * 2 or 0
            panel:GetChild(name):SetAnchoredPosition(x, y)
            panel:GetChild(name):SetSizeDelta(I.width + delta, height + delta)
        end
        local left, cursor = x - I.width / 2 + I.pad, y + height / 2 - I.pad
        local textX = left + I.icon + I.gap + (I.width - I.pad * 2 - I.icon - I.gap) / 2
        panel:GetChild("title"):SetAnchoredPosition(x, cursor - I.header / 2)
        panel:GetChild("title").text = actor.name or "旅行者"
        cursor = cursor - I.header
        panel:GetChild("summary"):SetAnchoredPosition(x, cursor - I.summary / 2)
        panel:GetChild("summary").text = "生命 " .. number(actor.hp) .. "/" .. number(actor.maxHp) .. " · 格挡 " .. number(actor.block)
        cursor = cursor - I.summary
        for i = 1, I.rows do
            local entry = i <= rows and entries[i]
            local icon, name, text = panel:GetChild("icon" .. i), panel:GetChild("name" .. i), panel:GetChild("text" .. i)
            for _, part in ipairs({icon, name, text}) do part:SetVisible(entry and true or false) end
            if entry then
                local colour = statusKind(entry) == "buff" and C.buff or C.debuff
                icon:SetAnchoredPosition(left + I.icon / 2, cursor - I.nameHeight / 2)
                picture(icon, Theme.icon.status[entry.id])
                tint(icon, colour)
                name:SetAnchoredPosition(textX, cursor - I.nameHeight / 2)
                name.text = entry.name .. (entry.stack == "none" and "" or " " .. number(entry.amount)) .. " · " .. kindNames[statusKind(entry)]
                ink(name, colour)
                text:SetAnchoredPosition(textX, cursor - I.nameHeight - S.xs - (I.row - I.nameHeight - S.xs) / 2)
                text.text = statusDetail(entry, battle.rules)
                cursor = cursor - I.row
            end
        end
        local more = panel:GetChild("more")
        more:SetVisible(extra)
        more:SetAnchoredPosition(x, cursor - I.summary / 2)
        more.text = #entries == 0 and "暂无状态" or "另有 " .. (#entries - I.rows) .. " 项状态未列出"
        panel:SetVisible(true)
        panel:SetAsLastSibling()
    end
    closeInfo = function()
        if not self.info then return false end
        self.info = nil
        child("statusInfo"):SetVisible(false)
        return true
    end
    -- index 0 is the hero. Opening the same unit again closes it.
    function self:showStatus(index)
        local run = self.run
        if not self.active or self.busy or self.gesture or not run or run.phase ~= "combat" then return false end
        local actor = index == 0 and run.combat.player or run.combat.enemies[index]
        if not actor or actor.hp <= 0 then return false end
        if self.info and self.info.index == index and self.info.id == actor.id then closeInfo()
        else self.info = {index = index, id = actor.id, battle = run.combat} end
        self:render()
        return true
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
        if self.gesture and not cardReady(self.gesture) then
            self.gesture, self.selected, self.suppressClick = nil, nil, true
        end
        for _, input in ipairs(cardInputs) do
            if input.held and not cardReady(input.held) then input.held = nil end
            if input.released and not cardReady(input.released) then input.released = nil end
        end
        for _, input in ipairs(potionInputs) do
            if input.held and not potionReady(input.held) then input.held = nil end
            if input.released and not potionReady(input.released) then input.released = nil end
        end
        for _, input in ipairs(actionInputs) do
            if input.held and not actionReady(input.held) then input.held = nil end
            if input.released and not actionReady(input.released) then input.released = nil end
        end
        for _, input in ipairs(enemyInputs) do
            if input.held and not enemyReady(input.held) then input.held = nil end
            if input.released and not enemyReady(input.released) then input.released = nil end
        end
        if self.busy and self.feedback and (self.feedbackRun ~= run or self.feedbackBattle ~= (run and run.combat)) then
            self.feedback:cancel() return
        end
        if self.viewRun ~= run then
            self.viewRun, self.target, self.selected = run, 1, nil
            self.potionRun, self.potionBattle, self.potionSlots = nil, nil, nil
        end
        -- A Run survives between encounters, but its combat and enemy indices do not.
        -- Use the committed combat identity, never transient playback frame tables.
        local currentBattle = run and run.combat
        if self.viewBattle ~= currentBattle then
            self.viewBattle, self.target, self.selected = currentBattle, 1, nil
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
        for slot = 1, data.rules.player.potionSlots do
            local item = potions[slot]
            if active and item and item.canUse and item.needTarget then self.potionTargetAvailable = true break end
        end
        show("start", not self.busy and not options.embedded and (not run or run.phase == "defeat"))
        button("start", self.active, true, run and "重新启程" or "启程")
        show("endTurn", fighting)
        show("skip", reward)
        show("continue", not options.embedded and run and run.phase == "map")
        show("result", not fighting) show("resultPlate", not fighting)
        show("hero", fighting)
        local player = battle and battle.player
        label("player", number(player and player.hp or run and run.hp or data.rules.player.maxHp) .. "/" .. number(run and run.maxHp or data.rules.player.maxHp))
        label("piles", number(run and run.gold or 0))
        label("exhaust", battle and tostring(#battle.exhaust) or "0")
        label("energy", number(battle and battle.energy or 0) .. "/" .. number(data.rules.player.energyPerTurn))
        local charged = battle and battle.energy > 0
        tint(child("energyDisc"), charged and C.energy or C.energyEmpty)
        tint(child("energyIcon"), charged and C.geo or C.geoDeep)
        -- Dark digits on amber, light digits once the orb is spent; both stay readable.
        ink(child("energy"), charged and C.textOnLight or C.text)
        label("draw", battle and tostring(#battle.draw) or "0") label("discard", battle and tostring(#battle.discard) or "0")
        -- Turn state shows only while the player cannot act; a live hand already says "your turn".
        label("statuses", fighting and battle.phase ~= "player" and not self.busy and "敌方回合" or "")
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
                local x, width, portrait = enemySlot(count, i, enemy)
                box:SetAnchoredPosition(x, L.enemyRow.y)
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
        local aimUid, aimTarget
        if self.gesture and self.gesture.moving then
            local _, target = dragTarget(self.gesture)
            aimUid, aimTarget = self.gesture.uid, target
        end
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
                if instance then
                    -- The core previews upgrade, growth and every current modifier;
                    -- a card being aimed shows the value for that target.
                    local preview = Combat.cardPreview(battle, instance, instance.uid == aimUid and aimTarget or nil)
                    local combatText = instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
                    if combatText then
                        text = combatText:gsub("{effects%.(%d+)%.value}", function(index)
                            local i = tonumber(index) + 1
                            return preview[i] and amount(preview[i]) or number(definition.effects[i].value)
                        end)
                    end
                    for i = 1, #definition.effects do
                        local entry = preview[i]
                        if entry and entry.op == "damageEqualToBlock" then text = text .. "（当前 " .. amount(entry) .. " 点）" end
                    end
                end
                box:GetChild("label").text = text
                ink(box:GetChild("label"), enabled and C.text or C.textMuted)
                box:GetChild("type").text = typeNames[definition.type] or definition.type
                box:GetChild("cost").text = definition.cost == -2 and ""
                    or definition.costMode == "all_energy" and "X" or tostring(definition.cost)
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
            local valid, target, aiming = dragTarget(g)
            local x, y = dragPose(g)
            local h = L.card.size[2]*D.scale
            -- An aiming card parks under the line so it never hides the enemy row.
            if aiming then x, y = (g.origin or {g.sx})[1], D.lineY-h/2-S.s end
            box:SetAnchoredPosition(x,y)
            box:SetLocalScale(D.scale,D.scale,1)
            box.localRotationZ = 0
            box:GetChild("glow"):SetVisible(valid == true)
            local layer = child("dragLayer")
            tint(layer:GetChild("line"),valid and C.goldBright or C.line)
            local enemy = target and g.battle.enemies[target]
            -- The lit line, card glow and reticle already say "release to play"; no caption over the card.
            layer:GetChild("hint").text = ""
            -- Dotted arc from the card's top edge to the reticle (or the bare pointer).
            local ex, ey, ring = g.x, g.y, D.aimDot[2]*2
            if enemy then
                local tx, _, portrait = enemySlot(#g.battle.enemies,target,enemy)
                ex, ey, ring = tx, L.enemyRow.y, portrait+D.reticlePad
            end
            local reticle = layer:GetChild("reticle")
            reticle:SetVisible(aiming == true)
            reticle:SetAnchoredPosition(ex,ey)
            reticle:SetSizeDelta(ring,ring)
            tint(reticle,enemy and C.goldBright or C.textDim)
            local sx, sy, fy = x, y+h/2, ey-(enemy and ring/2 or 0)
            for i = 1, D.aimDots do
                local dot, t = layer:GetChild("aim" .. i), i/D.aimDots
                dot:SetVisible(aiming == true)
                if aiming then
                    local u, size = 1-t, D.aimDot[1]+(D.aimDot[2]-D.aimDot[1])*t
                    -- Quadratic Bezier with its control point at (start x, end y): rises, then bends over.
                    dot:SetAnchoredPosition(u*u*sx+2*u*t*sx+t*t*ex,u*u*sy+2*u*t*fy+t*t*fy)
                    dot:SetSizeDelta(size,size)
                    tint(dot,enemy and C.goldBright or C.textDim)
                end
            end
            layer:SetAsLastSibling()
        end
        -- Details describe the committed battle only while the player can read them.
        if self.info and (not self.active or self.busy or self.gesture or not fighting
            or self.info.battle ~= run.combat) then self.info = nil end
        renderInfo(battle)
        button("endTurn", active == true, not playable)
        button("skip", self.active and reward == true and not self.busy, false)
        button("continue", self.active and run and run.phase == "map" and not self.busy, true)
        -- Keep physical slots fixed for the encounter: consuming slot one must not
        -- move slot two underneath a queued second click on the same button.
        if fighting and not self.busy then
            self.potionBattle, self.potionRun, self.potionSlots = battle, run, {}
            for slot = 1, data.rules.player.potionSlots do
                local id = run.potions[slot]
                if id then self.potionSlots[slot] = {slot = slot, id = id} end
            end
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
        notice(failure and "演出已恢复，可继续行动。" or "")
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
        notice("") refresh(true)
        print("ABYSS_UI combat_started")
    end
    function self:playSelected(target)
        if not self.active or not self.selected or self.busy or not self.run or self.run.phase ~= "combat" then return end
        local uid, origin = self.selected, self.cardPositions[self.selected]
        local ok, reason = perform(function() return Run.play(self.run, uid, target) end, origin)
        if ok then self.selected = nil end
        notice(ok and "" or reasons[reason] or "当前无法使用这张牌。")
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
            notice(needsTarget(run.combat, instance) and "点选一个敌人" or "再次点击确认出牌")
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
    -- An open detail panel owns the next pointer sequence: its Down closes the panel and
    -- the matching Click is swallowed, so no card, target or button acts underneath it.
    local function down(event)
        pointerObserved = true
        if not self.gesture then self.suppressClick = false end
        self.swallow = nil
        if self.gesture or not closeInfo() then return false end
        self.swallow = {touch = event and event.touchId}
        self:render()
        return true
    end
    local function swallowed(event)
        local swallow = self.swallow
        if swallow and swallow.touch == (event and event.touchId) then self.swallow = nil return true end
        if not closeInfo() then return false end -- click-only hosts dismiss on the click itself
        self:render()
        return true
    end
    local function move(event)
        local g = self.gesture
        if not g or not event or event.touchId ~= g.touch then return end
        local x,y = point(event)
        if not x then return end
        g.x,g.y = x,y
        if (x-g.sx)^2+(y-g.sy)^2 >= L.cardDrag.threshold^2 then g.moving = true end
        if g.moving then
            arm(g)
            local _, target = dragTarget(g)
            if target then g.lock, g.lockIndex = g.battle.enemies[target], target end
            self.suppressClick,self.selected = true,g.uid
            self:render()
        end
    end
    local function release(event, input, ended)
        local g = self.gesture
        local touch = event and event.touchId
        if not g then
            -- Missing/invalid coordinates disable dragging, not ordinary C-mode.
            local held = input and input.held
            if held and held.touch == touch then
                input.held = nil
                input.released = not ended and cardReady(held) and held or nil
            elseif ended and input and input.released and input.released.touch == touch then
                input.released = nil
            end
            return
        end
        if touch ~= g.touch or input and input ~= g.input then return end
        g.input.held = nil
        -- Stationary taps must keep their binding through Up until Click, too.
        if not cardReady(g) then
            g.input.released = nil
            self.gesture, self.selected, self.suppressClick = nil, nil, true
            self:render()
            return
        end
        move(event)
        -- move/render may have cancelled a gesture belonging to an old battle.
        if self.gesture ~= g then return end
        local x,y = point(event)
        local valid,target = false,nil
        if x and g.moving then valid,target = dragTarget(g) end
        self.gesture = nil -- consume before invoking the command or any rendering callback
        if not g.moving then
            g.input.released = not ended and g or nil
            return
        end
        g.input.released = nil
        self.suppressClick,self.selected = true,valid and g.uid or nil
        self:render()
        if valid then self:playSelected(target)
        else notice("") end
    end
    local function listen(control, fn, input)
        control:AddCursorEventListener(clickEvent,function(event)
            if swallowed(event) then return end
            if input and pointerObserved then
                local released = input.released
                -- Never borrow a foreign or missing touch ID, nor fall back to
                -- click-only after this controller has observed pointer input.
                if not released or released.touch ~= (event and event.touchId) then return end
                input.released = nil -- a valid matching click can be consumed only once
                if not cardReady(released) then return end
            end
            if not self.suppressClick and not self.gesture then return fn(event) end
        end)
        if self.dragEnabled and not input then control:AddCursorEventListener(cursor.CursorDown,down) end
    end
    local function bind(name, fn)
        local control, input = child(name), {}
        actionInputs[#actionInputs + 1] = input
        control:AddCursorEventListener(clickEvent, function(event)
            if swallowed(event) then return end
            if actionPointerObserved then
                local released = input.released
                if not released or released.touch ~= (event and event.touchId) then return end
                input.released = nil
                if not actionReady(released) then return end
            end
            if not self.suppressClick and not self.gesture then return fn(event) end
        end)
        if self.dragEnabled then
            control:AddCursorEventListener(cursor.CursorDown, function(event)
                actionPointerObserved = true
                local dismissed = down(event)
                input.held, input.released = nil, nil
                if dismissed then return end
                local run = self.run
                local battle = run and run.combat
                local g = {name = name, run = run, phase = run and run.phase,
                    battle = battle, turn = battle and battle.turn,
                    rewards = run and run.rewards, touch = event and event.touchId}
                if actionReady(g) then input.held = g end
            end)
            local function releaseAction(event, ended)
                local touch, held = event and event.touchId, input.held
                if held and held.touch == touch then
                    input.held = nil
                    input.released = not ended and actionReady(held) and held or nil
                elseif ended and input.released and input.released.touch == touch then
                    input.released = nil
                end
            end
            control:AddCursorEventListener(cursor.CursorUp, releaseAction)
            control:AddCursorEventListener(cursor.CursorEndDrag, function(event) releaseAction(event, true) end)
        end
    end
    bind("start", function() if not self.run or self.run.phase == "defeat" then self:start() end end)
    bind("endTurn", function() self:endTurn() end)
    bind("skip", function() if self.active and self.run and not self.busy and Run.claimCardReward(self.run, 0) then notice("已跳过卡牌奖励。") refresh(true) end end)
    bind("continue", function() if self.active and not options.embedded and not self.busy and self.run and self.run.phase == "map" then assert(Run.startCombat(self.run, "cultist_solo")) refresh(true) end end)
    for i = 1, 3 do
        local slot, control, input = i, child("potion" .. i), {}
        potionInputs[i] = input
        control:AddCursorEventListener(clickEvent, function(event)
            if swallowed(event) then return end
            if potionPointerObserved then
                local released = input.released
                if not released or released.touch ~= (event and event.touchId) then return end
                input.released = nil
                if not potionReady(released) then return end
            end
            if not self.suppressClick and not self.gesture then return self:usePotion(slot) end
        end)
        if self.dragEnabled then
            control:AddCursorEventListener(cursor.CursorDown, function(event)
                potionPointerObserved = true
                local dismissed = down(event)
                input.held, input.released = nil, nil
                if dismissed or self.gesture or not self.run then return end
                local run, binding = self.run, self.potionSlots and self.potionSlots[slot]
                if not binding or self.potionRun ~= run or self.potionBattle ~= run.combat then return end
                local g = {slot = binding.slot, id = binding.id, inventory = run.potions,
                    run = run, battle = run.combat, turn = run.combat and run.combat.turn,
                    touch = event and event.touchId}
                if potionReady(g) then input.held = g end
            end)
            local function releasePotion(event, ended)
                local touch, held = event and event.touchId, input.held
                if held and held.touch == touch then
                    input.held = nil
                    input.released = not ended and potionReady(held) and held or nil
                elseif ended and input.released and input.released.touch == touch then
                    input.released = nil
                end
            end
            control:AddCursorEventListener(cursor.CursorUp, releasePotion)
            control:AddCursorEventListener(cursor.CursorEndDrag, function(event) releasePotion(event, true) end)
        end
    end
    for i = 1, 10 do
        local slot,hit = i,child("card" .. i):GetChild("hit")
        local input = {}
        cardInputs[i] = input
        listen(hit,function() self:playSlot(slot) end,input)
        if self.dragEnabled then
            hit:AddCursorEventListener(cursor.CursorDown,function(event)
                pointerObserved = true
                if self.gesture then return end
                local dismissed = down(event)
                input.held, input.released = nil, nil
                if dismissed or not self.active or self.busy or not self.run then return end
                local run, battle = self.run, self.run.combat
                local instance = run.phase == "combat" and battle.hand[slot]
                local uid = instance and instance.uid or run.phase == "reward" and Run.rewardOptions(run)[slot]
                if not uid then return end
                local g = {uid=uid,slot=slot,run=run,battle=battle,turn=battle and battle.turn,
                    phase=run.phase,rewards=run.rewards,touch=event and event.touchId,input=input}
                input.held = g
                local x,y = point(event)
                if not instance or not x then return end
                local ok,reason = Combat.canPlay(battle,instance.uid,nil)
                if not ok and reason ~= "invalid_target" then return end
                g.sx,g.sy,g.x,g.y,g.origin = x,y,x,y,self.cardPositions[instance.uid]
                self.gesture = g
            end)
            hit:AddCursorEventListener(cursor.CursorDrag,move)
            hit:AddCursorEventListener(cursor.CursorUp,function(event) release(event,input) end)
            hit:AddCursorEventListener(cursor.CursorEndDrag,function(event) release(event,input,true) end)
        end
    end
    if self.dragEnabled then
        local layer = child("dragLayer")
        layer.disableCursorEventPassthrough = true
        local hit = layer:GetChild("hit")
        hit:AddCursorEventListener(cursor.CursorDrag,move)
        hit:AddCursorEventListener(cursor.CursorUp,release)
        hit:AddCursorEventListener(cursor.CursorEndDrag,function(event) release(event,nil,true) end)
    end
    for i = 1, 5 do
        local target, control, input = i, child("enemy" .. i):GetChild("hit"), {}
        enemyInputs[i] = input
        local function chooseEnemy()
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
        end
        control:AddCursorEventListener(clickEvent, function(event)
            if swallowed(event) then
                -- Dismissal consumes this pointer too, but cannot consume a
                -- newer token owned by a different touch on the same actor.
                local touch = event and event.touchId
                if input.held and input.held.touch == touch then input.held = nil end
                if input.released and input.released.touch == touch then input.released = nil end
                return
            end
            if enemyPointerObserved then
                -- Existing enemy hosts may send Down/Click without Up. Both
                -- forms consume the same actor-bound, one-shot ownership.
                local released = input.released or input.held
                if not released or released.touch ~= (event and event.touchId) then return end
                input.held, input.released = nil, nil
                if not enemyReady(released) then return end
            end
            if not self.suppressClick and not self.gesture then return chooseEnemy() end
        end)
        if self.dragEnabled then
            control:AddCursorEventListener(cursor.CursorDown, function(event)
                enemyPointerObserved = true
                local dismissed = down(event)
                input.held, input.released = nil, nil
                if dismissed then return end
                local run, battle = self.run, self.run and self.run.combat
                local actor = battle and battle.enemies[target]
                if not actor then return end
                local g = {slot=target, actor=actor, run=run, battle=battle,
                    turn=battle.turn, touch=event and event.touchId}
                if enemyReady(g) then input.held = g end
            end)
            local function releaseEnemy(event, ended)
                local touch, held = event and event.touchId, input.held
                if held and held.touch == touch then
                    input.held = nil
                    input.released = not ended and enemyReady(held) and held or nil
                elseif ended and input.released and input.released.touch == touch then input.released = nil end
            end
            control:AddCursorEventListener(cursor.CursorUp, releaseEnemy)
            control:AddCursorEventListener(cursor.CursorEndDrag, function(event) releaseEnemy(event, true) end)
        end
    end
    -- Enemy portraits keep targeting; the hero portrait and every status row only open
    -- details, so a status tap never plays a card or moves the potion target.
    listen(child("hero"):GetChild("hit"), function() self:showStatus(0) end)
    for i, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
        local index = i - 1
        listen(child(name):GetChild("statusRow"):GetChild("hit"), function() self:showStatus(index) end)
    end
    local info = child("statusInfo")
    info.disableCursorEventPassthrough = true
    listen(info:GetChild("hit"), function() if closeInfo() then self:render() end end)
    refresh()
    return self
end
return M
