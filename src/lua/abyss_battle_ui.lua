-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
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
local number = require("abyss_numbers").integer
-- A displayed damage variable is exact, never a cross-target range.
local function amount(preview)
    assert(preview.low == preview.high, "card damage display must be exact")
    return number(preview.low)
end
-- Negative Strength/Dexterity are debuffs, as the core's Artifact gate treats them.
local function statusKind(entry) return entry.amount < 0 and "debuff" or entry.kind end
local kindNames = { buff = "增益", debuff = "减益" }
local function signed(value) return (value < 0 and "-" or "+") .. number(math.abs(value)) end
-- Text only: amounts come from statusView, percentages from the shared rules.
-- Every sentence names the real number so players never decode "所示/等量/层数".
-- "你" is always the player; the owner is whoever's panel is open.
local function statusDetail(entry, rules, actor)
    local n, c = number(entry.amount), rules.combat
    if entry.id == "strength" then
        return "攻击每段伤害 " .. signed(entry.amount) .. "。" .. (entry.temporary ~= 0
            and "其中 " .. number(entry.temporary) .. " 层在回合结束时移除。" or "")
    elseif entry.id == "dexterity" then return "获得的格挡 " .. signed(entry.amount) .. "。"
    elseif entry.id == "vulnerable" then return "受到的攻击伤害 +" .. number(c.vulnerablePercent - 100) .. "%，持续 " .. n .. " 回合。"
    elseif entry.id == "weak" then return "造成的攻击伤害 -" .. number(100 - c.weakPercent) .. "%，持续 " .. n .. " 回合。"
    elseif entry.id == "frail" then return "获得的格挡 -" .. number(100 - c.frailPercent) .. "%，持续 " .. n .. " 回合。"
    elseif entry.id == "poison" then return "回合开始时失去 " .. n .. " 点生命，之后每回合少 1 点。"
    elseif entry.id == "regen" then return "回合结束时回复 " .. n .. " 点生命，之后每回合少 1 点。"
    elseif entry.id == "thorns" then return "受到攻击时，对攻击者造成 " .. n .. " 点伤害。"
    elseif entry.id == "artifact" then return "抵挡接下来 " .. n .. " 次减益效果。"
    elseif entry.id == "entangled" then return "本回合不能打出攻击牌。"
    elseif entry.id == "barricade" then return "回合开始时格挡不会清空。"
    elseif entry.id == "ritual" then return "每个敌方回合结束时，获得 " .. n .. " 层力量。"
    elseif entry.id == "enrage" then return "你每打出一张技能牌，它获得 " .. n .. " 层力量。"
    elseif entry.id == "angry" then return "每次被攻击并损失生命，获得 " .. n .. " 层力量。"
    elseif entry.id == "curl_up" then return "第一次被攻击并损失生命后，获得 " .. n .. " 点格挡。"
    elseif entry.id == "spore_cloud" then return "它倒下时，你获得 " .. n .. " 层易伤。"
    elseif entry.id == "sharp_hide" then return "你每打出一张攻击牌，受到 " .. n .. " 点伤害（可被格挡）。"
    elseif entry.id == "mode_shift" then
        local block = actor and actor.ai and actor.ai.shiftBlock
        return "再损失 " .. n .. " 点生命，就转入防守形态" .. (block and "并获得 " .. number(block) .. " 点格挡" or "") .. "。"
    end
    return entry.description .. (entry.stack == "none" and "" or "（" .. n .. "）")
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
-- STS shows mixed moves as one compound intent (ATTACK_DEBUFF, ATTACK_DEFEND,
-- DEFEND_BUFF...). Data keeps a single kind, so the second icon comes from the
-- effects themselves: the first effect class that differs from the kind.
local effectKinds = { damage = "attack", block = "defend", gainStatus = "buff",
    applyStatus = "debuff", makeTempCardInDiscard = "debuff" }
local function intentBadge(intent)
    for _, kind in ipairs({ "debuff", "defend", "buff", "attack" }) do
        if kind ~= intent.kind then
            for _, effect in ipairs(intent.effects or {}) do
                if effectKinds[effect.op] == kind then return kind end
            end
        end
    end
end
local function intentText(state, index, detailed)
    local intent = Combat.intent(state, index)
    if not intent then return "已击败", "unknown" end
    if intent.kind == "charge" then return "蓄能", "unknown" end
    if intent.kind == "sleep" then return "沉睡", "sleep" end
    if intent.kind == "stunned" then return "苏醒中", "unknown" end
    if intent.kind == "split" then
        local child = state.catalog.enemies[state.enemies[index].ai.splitEnemy]
        return detailed and "分裂为两只" .. child.name .. "，各自生命等于分裂时的当前生命。" or "分裂", "unknown"
    end
    local result, compact = {}, {}
    -- ApplyPower must gate each copied status before stacking it: Artifact can
    -- block an otherwise overflowing addition and is spent in effect order.
    local preview = Events.frame(state)
    preview.events = {}
    local enemy, player = preview.enemies[index], preview.player
    for _, effect in ipairs(intent.effects) do
        if effect.op == "damage" then
            local each = number(Combat.attackAmount(state, enemy, player, effect.value))
            local times = effect.times or 1
            compact.attack = compact.attack or each .. (times > 1 and "×" .. times or "")
            -- The number already includes Strength, Weak and Vulnerable on both sides.
            result[#result + 1] = times > 1 and "攻击 " .. times .. " 次，每次 " .. each .. " 点伤害"
                or "攻击造成 " .. each .. " 点伤害"
        elseif effect.op == "block" then
            local amount = number(Combat.blockAmount(state, enemy, effect.value, effect.target == "random_ally"))
            compact.defend = compact.defend or amount
            result[#result + 1] = effect.target == "random_ally"
                and "让一名随机队友获得 " .. amount .. " 点格挡（没有队友时给自己）" or "获得 " .. amount .. " 点格挡"
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            Actors.applyPower(preview, effect.op == "gainStatus" and enemy or player, effect.status, effect.value, enemy)
            local name, size = assert(state.catalog.statuses[effect.status]).name, number(math.abs(effect.value))
            local who = effect.op == "gainStatus" and "自身" or "使你"
            result[#result + 1] = who .. (effect.value < 0 and "失去 " or "获得 ") .. size .. " 层" .. name
        elseif effect.op == "makeTempCardInDiscard" then
            local value = number(effect.value)
            local name = assert(state.catalog.cards[effect.card]).name
            result[#result + 1] = "将 " .. value .. " 张「" .. name .. "」放入你的弃牌堆"
        else result[#result + 1] = "未知" end
    end
    local badge = intentBadge(intent)
    if not detailed then return intent.kind == "attack" and (compact.attack or "?") or "", intent.kind, badge end
    return #result > 0 and table.concat(result, "；") or "下一步行动未知。", intent.kind, badge
end

function M.new(root, data, presentation, clickEvent, platform, options)
    options = options or {}
    local self = { root = root, data = data, presentation = presentation, target = 1, seed = 1, busy = false, active = true }
    local playbackIntents
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
            local target = row:GetChild("hit" .. i)
            target:SetVisible(entry and true or false)
            local overflow = entry and i == slots and #entries > slots
            icon:SetVisible(entry and not overflow or false)
            count:SetVisible(entry and true or false)
            if entry then
                local k = i - 1
                local line = math.floor(k / perRow)
                local x = (k % perRow - (math.min(perRow, shown - line * perRow) - 1) / 2) * pitch
                local y = (si.rows - 1) * pitch / 2 - line * pitch
                icon:SetAnchoredPosition(x, y)
                target:SetAnchoredPosition(x, y)
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
        local title, summary = actor.name or "旅行者", "生命 " .. number(actor.hp) .. "/" .. number(actor.maxHp) .. " · 格挡 " .. number(actor.block)
        if info.kind == "intent" then
            local description, kind = intentText(battle, info.index, true)
            local names = {attack="攻击",defend="防御",buff="强化",debuff="削弱",charge="蓄能",sleep="沉睡",stunned="苏醒中",split="分裂"}
            entries = {{heading=names[kind] or "未知",text=description,intent=kind}}
            title, summary = title .. " · 行动意图", "下一次行动，尚未执行"
        elseif info.kind == "card" then
            local instance
            for _, card in ipairs(battle.hand) do if card.uid == info.uid then instance=card break end end
            if not instance then self.info=nil;panel:SetVisible(false);return end
            local definition = Combat.cardDefinition(battle,instance)
            entries={}
            local function keywords(effects)
                for _, effect in ipairs(effects) do
                    local id=effect.status or effect.op=="gainTemporaryStrength" and "strength"
                    local status=id and battle.catalog.statuses[id]
                    if status then
                        local entry={id=id,name=status.name,amount=effect.value,temporary=0,kind=status.kind,
                            description=status.description,stack=status.stack}
                        entry.heading,entry.text=status.name .. " · 关键词",statusDetail(entry,battle.rules)
                        entries[#entries+1]=entry
                    end
                    if effect["then"] then keywords(effect["then"]) end
                end
            end
            keywords(definition.effects)
            if definition.exhaust then entries[#entries+1]={heading="消耗",text="打出后移出本场战斗，不进入弃牌堆。",intent="unknown"} end
            if definition.ethereal then entries[#entries+1]={heading="虚无",text="回合结束时若仍在手中，将被消耗。",intent="unknown"} end
            title,summary=(presentation[instance.cardId].name) .. " · 关键词","卡牌效果说明，不代表已施加状态"
            if #entries==0 then self.info=nil;panel:SetVisible(false);return end
        elseif info.statusId then
            local selected={}
            for _, entry in ipairs(entries) do if entry.id==info.statusId then selected[1]=entry break end end
            entries=selected
            if #entries==0 then self.info=nil;panel:SetVisible(false);return end
        elseif info.offset then
            local remaining={}
            for i=info.offset,#entries do remaining[#remaining+1]=entries[i] end
            entries=remaining
        end
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
        panel:GetChild("title").text = title
        cursor = cursor - I.header
        panel:GetChild("summary"):SetAnchoredPosition(x, cursor - I.summary / 2)
        panel:GetChild("summary").text = summary
        cursor = cursor - I.summary
        for i = 1, I.rows do
            local entry = i <= rows and entries[i]
            local icon, name, text = panel:GetChild("icon" .. i), panel:GetChild("name" .. i), panel:GetChild("text" .. i)
            for _, part in ipairs({icon, name, text}) do part:SetVisible(entry and true or false) end
            if entry then
                local colour = entry.heading and C.goldBright or statusKind(entry) == "buff" and C.buff or C.debuff
                icon:SetAnchoredPosition(left + I.icon / 2, cursor - I.nameHeight / 2)
                picture(icon, entry.intent and (Theme.icon.intent[entry.intent] or Theme.icon.intent.unknown) or Theme.icon.status[entry.id])
                tint(icon, colour)
                name:SetAnchoredPosition(textX, cursor - I.nameHeight / 2)
                name.text = entry.heading or entry.name .. (entry.stack == "none" and "" or " " .. number(entry.amount)) .. " · " .. kindNames[statusKind(entry)]
                ink(name, colour)
                text:SetAnchoredPosition(textX, cursor - I.nameHeight - S.xs - (I.row - I.nameHeight - S.xs) / 2)
                text.text = entry.text or statusDetail(entry, battle.rules, actor)
                cursor = cursor - I.row
            end
        end
        local more = panel:GetChild("more")
        more:SetVisible(extra)
        more:SetAnchoredPosition(x, cursor - I.summary / 2)
        more.text = #entries == 0 and "暂无状态" or "另有 " .. (#entries - I.rows) .. " 项状态未列出"
        panel:SetVisible(true)
        panel:GetChild("hit"):SetVisible(not info.transient)
        panel.disableCursorEventPassthrough = not info.transient
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
    function self:openHelp(spec, source, transient)
        local run=self.run
        if not self.active or self.busy or not run or run.phase~="combat" then return false end
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        if not actor or actor.hp<=0 then return false end
        self.info={index=spec.index,id=actor.id,battle=run.combat,kind=spec.kind,statusId=spec.statusId,
            offset=spec.offset,uid=spec.uid,source=source,transient=transient==true}
        self:render()
        return self.info~=nil
    end
    function self:queueHelp(spec,source,held,touch)
        local run=self.run
        if not spec or not self.active or self.busy or not run or run.phase~="combat" then return end
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        if not actor or actor.hp<=0 then return end
        self.help={spec=spec,source=source,held=held,touch=touch,t=0,run=run,battle=run.combat,
            turn=run.combat.turn,actor=actor}
    end
    function self:cardHelpSpec(slot)
        local battle=self.run and self.run.phase=="combat" and self.run.combat
        local instance=battle and battle.hand[slot]
        if not instance then return end
        local card=Combat.cardDefinition(battle,instance)
        local function hasKeyword(effects)
            for _,effect in ipairs(effects) do
                if effect.status or effect.op=="gainTemporaryStrength" or effect["then"] and hasKeyword(effect["then"]) then return true end
            end
        end
        if card.exhaust or card.ethereal or hasKeyword(card.effects) then return {kind="card",index=0,uid=instance.uid} end
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
    -- Post-battle pick: centred cards on their own stage, never the hand arc.
    -- Hover/press only changes scale and a small lift, so a card's edge stays
    -- under the pointer and neighbours never overlap (step > hover width).
    local R = L.rewardPick
    local function rewardTarget(slot)
        local hot = self.hover == slot
        return hot and R.hoverScale or R.scale, hot and R.hoverLift or 0
    end
    local function placeReward(box, count, index, anim, hot)
        local x = (index - 1 - (count - 1) / 2) * R.step
        box:SetAnchoredPosition(x, R.y + anim.lift + anim.rise)
        box:SetLocalScale(anim.scale, anim.scale, 1)
        box.localRotationZ = 0
        box:GetChild("glow"):SetVisible(hot)
        -- Later siblings draw on top: neighbours first, the hovered card last.
        if not hot then box:SetAsLastSibling() end
        return {x, R.y}
    end
    function self:setHover(slot)
        local run = self.run
        if slot and not (self.active and not self.busy and run and run.phase == "reward" and Run.rewardOptions(run)[slot]) then slot = nil end
        if self.hover == slot then return end
        self.hover = slot
        self:render()
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
            playbackIntents = nil
        end
        -- A Run survives between encounters, but its combat and enemy indices do not.
        -- Use the committed combat identity, never transient playback frame tables.
        local currentBattle = run and run.combat
        if self.viewBattle ~= currentBattle then
            self.viewBattle, self.target, self.selected = currentBattle, 1, nil
            playbackIntents = nil
        end
        local fighting = self.displayBattle ~= nil or run and run.phase == "combat"
        local battle = self.displayBattle or fighting and run.combat
        local enemyPlayback = self.busy and self.displayBattle and battle.phase == "enemy"
        if not enemyPlayback then playbackIntents = nil end
        local reward = not self.busy and run and run.phase == "reward"
        if not reward then self.hover = nil end
        -- A new reward object restarts the entrance so cards rise into place.
        if reward and (not self.rewardView or self.rewardView.rewards ~= run.rewards) then
            self.rewardView = {rewards = run.rewards, cards = {}}
            for i = 1, 10 do self.rewardView.cards[i] = {scale = R.scale * R.enterScale, lift = 0, rise = -R.enterRise} end
        elseif not reward then self.rewardView = nil end
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
        show("rewardStage", reward)
        -- The battle HUD (energy, piles) belongs to playing cards; clear it while choosing a reward.
        for _, name in ipairs({"energyRing", "energyDisc", "energyIcon", "energy", "drawIcon", "drawBadgeRing", "drawBadge",
            "draw", "drawLabel", "discardIcon", "discardBadgeRing", "discardBadge", "discard", "discardLabel"}) do
            show(name, not reward)
        end
        show("continue", not options.embedded and run and run.phase == "map")
        show("result", not fighting and not reward) show("resultPlate", not fighting and not reward)
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
        elseif reward then
            child("rewardStage"):GetChild("subtitle").text = "战斗胜利 · 金币 ＋" .. number(run.rewards.gold) .. " · 点击卡牌加入牌组，或跳过"
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
                -- An intent event is the historical action's starting face.
                -- Later frames already include its effects: do not apply them
                -- again. Unacted enemies still preview the current state.
                local shown = playbackIntents and playbackIntents[enemy.id]
                local value, kind, badge
                if shown and enemy.hp > 0 then value, kind, badge = shown[1], shown[2], shown[3]
                else value, kind, badge = intentText(battle, i) end
                local event = enemyPlayback and self.feedback.current
                if event and event.kind == "intent" and event.detail.enemy == enemy.id then
                    playbackIntents = playbackIntents or {}
                    playbackIntents[enemy.id] = {value, kind, badge}
                elseif enemy.hp <= 0 and playbackIntents then playbackIntents[enemy.id] = nil end
                box:GetChild("intent").text = value
                box:GetChild("intent"):SetAnchoredPosition(S.l, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                box:GetChild("intentIcon"):SetAnchoredPosition(-S.xl, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                box:GetChild("intentHit"):SetAnchoredPosition(0, math.max(L.intent.offsetY, portrait / 2 + S.xxl))
                picture(box:GetChild("intentIcon"), Theme.icon.intent[kind] or Theme.icon.intent.unknown)
                tint(box:GetChild("intentIcon"), intentColors[kind] or C.textDim)
                local badgeIcon = box:GetChild("intentBadge")
                local iconY = math.max(L.intent.offsetY, portrait / 2 + S.xxl)
                local inset = (L.intent.size - L.intent.badge) / 2
                badgeIcon:SetAnchoredPosition(-S.xl + inset, iconY - inset)
                badgeIcon:SetVisible(badge ~= nil)
                if badge then
                    picture(badgeIcon, Theme.icon.intent[badge])
                    tint(badgeIcon, intentColors[badge])
                end
            end
        end
        local rewards = reward and Run.rewardOptions(run) or {}
        local aimUid, aimTarget
        if self.gesture and self.gesture.moving then
            local valid, target = dragTarget(self.gesture)
            if valid and not target then
                local only, alive = nil, 0
                for i, enemy in ipairs(battle.enemies) do
                    if enemy.hp > 0 then only, alive = i, alive + 1 end
                end
                if alive == 1 then target = only end
            end
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
                    or definition.costMode == "all_energy" and "X" or number(definition.cost)
                ink(box:GetChild("cost"), enabled and C.textOnLight or C.danger)
                tint(box:GetChild("costDisc"), enabled and C.energy or C.energyEmpty)
                local hovered = reward and not fighting and self.hover == i
                tint(box:GetChild("border"), (selected or hovered) and C.goldBright or enabled and (C.rarity[definition.rarity] or C.line) or C.line)
                tint(box:GetChild("artPlate"), enabled and (C.cardType[definition.type] or C.panelRaised) or C.panelSunken)
                picture(box:GetChild("art"), Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
                local pose
                if reward and not fighting then
                    local hot = self.hover == i
                    pose = placeReward(box, #rewards, i, self.rewardView.cards[i], hot)
                    if hot then selectedBox = box end
                else pose = placeCard(box, fighting and #battle.hand or #rewards, i - 1, selected == true) end
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
        playbackIntents = nil
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
        local help=self.help
        if help then
            local current=self.run and self.run.combat
            local actor=current and (help.spec.index==0 and current.player or current.enemies[help.spec.index])
            if not self.active or self.busy or self.run~=help.run or current~=help.battle
                or current.turn~=help.turn or actor~=help.actor or actor.hp<=0 or self.gesture and self.gesture.moving then
                self.help=nil
            elseif not help.fired then
                help.t=help.t+dt
                if help.t+0.000001>=L.statusInfo.delay then
                    help.fired=true
                    if help.held and help.spec.kind=="card" then
                        self.gesture=nil;cancelCardInputs();self.suppressClick=true
                    end
                    self:openHelp(help.spec,help.source,true)
                end
            end
        end
        if self.feedbackRun and (self.feedbackRun ~= self.run or self.feedbackBattle ~= (self.run and self.run.combat)) then
            self.feedback:cancel()
            self.feedbackRun, self.feedbackBattle = nil, nil
            self:render() return
        end
        self.feedback:update(dt)
        local view = self.rewardView
        if view and self.active and not self.busy and self.run and self.run.phase == "reward" and view.rewards == self.run.rewards then
            local k, moving = 1 - math.exp(-R.ease * dt), false
            for i, anim in ipairs(view.cards) do
                local scale, lift = rewardTarget(i)
                for key, goal in pairs({scale = scale, lift = lift, rise = 0}) do
                    local gap = goal - anim[key]
                    if math.abs(gap) > 0.002 then
                        anim[key] = math.abs(gap) < 0.05 and goal or anim[key] + gap * k
                        moving = true
                    end
                end
            end
            if moving then self:render() end
        end
    end
    function self:setActive(active)
        assert(type(active) == "boolean", "active must be boolean")
        self.active = active
        if not active then self.help=nil end
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
        self.help=nil
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
                self:queueHelp(self:cardHelpSpec(slot),hit,true,event and event.touchId)
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
    -- hoverSlot: a reward card also reports pointer enter/exit for its hover pose (one listener per event).
    local function bindHelp(control,describe,clickable,hoverSlot)
        local input={}
        local function cancel()
            input.held,input.released=nil,nil
            if hoverSlot and self.hover==hoverSlot then self:setHover(nil) end
            if self.help and self.help.source==control then self.help=nil end
            if self.info and self.info.source==control and self.info.transient then closeInfo();self:render() end
        end
        if cursor and cursor.CursorEnter and cursor.CursorExit then
            control:AddCursorEventListener(cursor.CursorEnter,function()
                if hoverSlot then self:setHover(hoverSlot) end
                self:queueHelp(describe(),control,false)
            end)
            control:AddCursorEventListener(cursor.CursorExit,cancel)
        end
        if not clickable then return end
        local function ready(token)
            local run=self.run
            return token and self.active and not self.busy and not self.gesture and run==token.run
                and run.phase=="combat" and run.combat==token.battle and run.combat.turn==token.turn
                and (token.spec.index==0 and run.combat.player or run.combat.enemies[token.spec.index])==token.actor
                and token.actor.hp>0
        end
        control:AddCursorEventListener(clickEvent,function(event)
            local touch=event and event.touchId
            if input.consumed and input.consumed.touch==touch then input.consumed=nil;return end
            if input.pointerObserved then
                local token=input.released;input.released=nil
                if not ready(token) or token.touch~=touch then return end
            end
            if swallowed(event) then return end
            local spec=describe()
            if spec then self:openHelp(spec,control,false) end
        end)
        if cursor and cursor.CursorDown and cursor.CursorUp then
            control:AddCursorEventListener(cursor.CursorDown,function(event)
                input.pointerObserved=true;input.held,input.released,input.consumed=nil,nil,nil
                if down(event) then return end
                local run=self.run
                if not run or run.phase~="combat" then return end
                local spec=describe()
                if not spec then return end
                local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
                local token={run=run,battle=run.combat,turn=run.combat.turn,touch=event and event.touchId,spec=spec,actor=actor}
                if ready(token) then input.held=token;self:queueHelp(describe(),control,true,token.touch) end
            end)
            control:AddCursorEventListener(cursor.CursorUp,function(event)
                local token=input.held;input.held=nil
                if not ready(token) or token.touch~=(event and event.touchId) then return end
                local help=self.help
                if help and help.source==control and help.fired then
                    input.consumed={touch=token.touch}
                    if self.info and self.info.source==control then self.info.transient=false;self:render() end
                else input.released=token end
                if help and help.source==control then self.help=nil end
            end)
            if cursor.CursorEndDrag then control:AddCursorEventListener(cursor.CursorEndDrag,cancel) end
        end
    end
    for i,name in ipairs({"hero","enemy1","enemy2","enemy3","enemy4","enemy5"}) do
        local index=i-1
        if index>0 then bindHelp(child(name):GetChild("intentHit"),function() return {kind="intent",index=index} end,true) end
        for slot=1,L.statusIcon.perRow*L.statusIcon.rows do
            local position=slot
            bindHelp(child(name):GetChild("statusRow"):GetChild("hit"..slot),function()
                local battle=self.run and self.run.combat
                local actor=battle and (index==0 and battle.player or battle.enemies[index])
                if not actor or actor.hp<=0 then return end
                local entries=Combat.statusView(actor)
                local count=#battle.enemies
                local width=index==0 and L.hpBar.size[1] or select(4,enemySlot(count,index,actor))
                -- enemySlot's fourth result is column spacing; use the same width clamp as unit().
                if index>0 then width=math.min(L.hpBar.size[1],count>1 and width-S.s or L.hpBar.size[1]) end
                local perRow=math.max(1,math.min(L.statusIcon.perRow,math.floor((width+L.statusIcon.gap)/(L.statusIcon.size+L.statusIcon.gap))))
                local slots=perRow*L.statusIcon.rows
                if not entries[position] then return end
                return {index=index,statusId=not(position==slots and #entries>slots) and entries[position].id or nil,
                    offset=position==slots and #entries>slots and position or nil}
            end,true)
        end
    end
    for slot=1,10 do
        local index=slot
        bindHelp(child("card"..slot):GetChild("hit"),function() return self:cardHelpSpec(index) end,false,slot)
    end
    refresh()
    return self
end
return M
