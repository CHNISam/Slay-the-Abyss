-- Unit presentation only; status entries and all combat values come from the core.
local Combat = require("abyss_combat")
local Theme = require("abyss_theme")
local number = require("abyss_numbers").integer
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space

local function healthGeometry(box, portrait, width)
    local barWidth, barX = width, 0
    if box.name ~= "hero" then
        -- Keep the three-digit guard lane even at zero Block so health never shifts.
        local reserve = math.max(L.blockBadge.size, 3 * Theme.font.body + L.blockBadge.padding * 2) + L.blockBadge.gap
        barWidth, barX = math.min(L.hpBar.size[1], width - reserve), reserve / 2
    end
    return barWidth, barX, -portrait / 2 - S.xxl - L.hpBar.size[2] / 2
end

function M.new(picture, tint, ink, statusKind)
    local function portraitParts(box, actor, portrait, icon, width, selected)
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
    end

    local function healthParts(box, actor, barWidth, barX, y, blocked)
        local bh = L.hpBar.size[2]
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
    end

    local function blockParts(box, actor, barWidth, barX, y, blocked, chip)
        for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
            local part = box:GetChild(name)
            part:SetVisible(blocked)
            local side = name == "blockEdge" and chip + S.border * 2 or chip
            local height = L.blockBadge.size + (name == "blockEdge" and S.border * 2 or 0)
            part:SetSizeDelta(side, name == "block" and L.nativeText.lineHeight or height)
            part:SetAnchoredPosition(barX - barWidth / 2 - L.blockBadge.gap - chip / 2, y)
        end
        tint(box:GetChild("blockEdge"), C.panelSunken)
        tint(box:GetChild("blockIcon"), C.block)
        ink(box:GetChild("block"), C.textOnLight)
        box:GetChild("block").text = number(actor.block)
    end

    local function statusCount(count, entry, x, y, overflow, layout)
        if overflow then
            count:SetAnchoredPosition(x, y)
            count.text = "+" .. (#layout.entries - layout.slots + 1)
            ink(count, C.textDim)
        else
            count:SetAnchoredPosition(x + L.statusIcon.size / 2, y - L.statusIcon.size / 2 + L.statusIcon.gap)
            count.text = entry.stack == "none" and "" or number(entry.amount)
            ink(count, C.text)
        end
    end

    local function statusSlot(row, i, entry, layout)
        local statusImage, count = row:GetChild("icon" .. i), row:GetChild("count" .. i)
        local target = row:GetChild("hit" .. i)
        target:SetVisible(entry and true or false)
        local overflow = entry and i == layout.slots and #layout.entries > layout.slots
        statusImage:SetVisible(entry and not overflow or false)
        count:SetVisible(entry and true or false)
        if entry then
            local k = i - 1
            local line = math.floor(k / layout.perRow)
            local x = (k % layout.perRow - (math.min(layout.perRow, layout.shown - line * layout.perRow) - 1) / 2) * layout.pitch
            local y = (L.statusIcon.rows - 1) * layout.pitch / 2 - line * layout.pitch
            statusImage:SetAnchoredPosition(x, y)
            target:SetAnchoredPosition(x, y)
            picture(statusImage, Theme.icon.status[entry.icon or entry.id])
            tint(statusImage, statusKind(entry) == "buff" and C.buff or C.debuff)
            statusCount(count, entry, x, y, overflow, layout)
        end
    end

    local function statuses(box, actor, portrait, width)
        local si, entries, row = L.statusIcon, Combat.statusView(actor), box:GetChild("statusRow")
        local pitch = si.size + si.gap
        local perRow = math.max(1, math.min(si.perRow, math.floor((width + si.gap) / pitch)))
        local slots = perRow * si.rows
        local layout = {entries = entries, pitch = pitch, perRow = perRow, slots = slots, shown = math.min(#entries, slots)}
        row:SetAnchoredPosition(0, -portrait / 2 - S.xxl - L.hpBar.size[2] - S.l - (si.rows - 1) * pitch / 2)
        row:GetChild("hit"):SetSizeDelta(width, si.rows * pitch)
        for i = 1, si.perRow * si.rows do
            statusSlot(row, i, i <= layout.shown and entries[i], layout)
        end
    end

    return function(box, actor, portrait, icon, width, selected)
        portraitParts(box, actor, portrait, icon, width, selected)
        -- Widen the Block chip for native digits rather than shrinking its text.
        local blocked = actor.block > 0
        local chip = math.max(L.blockBadge.size, #number(actor.block) * Theme.font.body + L.blockBadge.padding * 2)
        local barWidth, barX, y = healthGeometry(box, portrait, width)
        healthParts(box, actor, barWidth, barX, y, blocked)
        blockParts(box, actor, barWidth, barX, y, blocked, chip)
        statuses(box, actor, portrait, width)
    end
end

return M
