-- Unit presentation only; status entries and all combat values come from the core.
local Combat = require("abyss_combat")
local Theme = require("abyss_theme")
local number = require("abyss_numbers").integer
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space

function M.geometry(portrait,player)
    local g=L.battleUnit
    local foot=portrait/2+(player and g.heroFoot or 0)
    local gap=player and g.heroNameGap or g.nameGap
    local line=player and g.heroNameLine or g.nameLine
    local healthGap=player and g.heroHealthGap or g.healthGap
    local healthRow=player and L.hpBar.size[2] or g.healthRow
    local healthY=-foot-gap-line-healthGap-healthRow/2
    return {nameY=-foot-gap-line/2,healthY=healthY,
        healthWidth=player and g.heroHealthWidth or L.hpBar.size[1],
        firstStatusY=healthY-healthRow/2-g.statusGap-L.statusIcon.size/2}
end

-- Native text rectangles must stay 40 high but are transparent. Only visible
-- glyph height and the actual status touch surfaces contribute to clearance.
function M.noticeLift(actor,portrait,baseY,player)
    local entries,si=Combat.statusView(actor),L.statusIcon
    local g=M.geometry(portrait,player)
    local lower=math.min(-portrait/2,g.nameY-Theme.font.label/2,g.healthY-Theme.font.small/2)
    if actor.block>0 then lower=math.min(lower,g.healthY-math.max(L.blockBadge.size,Theme.font.body)/2) end
    if #entries>0 then
        local lines=math.ceil(math.min(#entries,si.perRow*si.rows)/si.perRow)
        local finalY=g.firstStatusY-(lines-1)*(si.size+si.gap)
        lower=math.min(lower,finalY-si.minimumTouch/2,finalY+L.battleUnit.badgeOffset[2]-Theme.font.small/2)
    end
    local top=L.battleNotice.bandTop
    return math.max(0,top-baseY-lower),lower,top
end

function M.new(picture, tint, ink, statusKind)
    local function portraitParts(box, actor, portrait, icon, width, selected, targetWidth)
        for _, name in ipairs({"plate", "border", "portrait"}) do
            local delta = name == "border" and S.border * 2 or 0
            box:GetChild(name):SetSizeDelta(portrait + delta, portrait + delta)
        end
        box:GetChild("plate"):SetVisible(false)
        box:GetChild("border"):SetVisible(false)
        box:GetChild("hit"):SetSizeDelta(math.min(portrait,targetWidth or portrait),portrait)
        box:GetChild("impact"):SetSizeDelta(portrait, portrait)
        box:GetChild("shield"):SetSizeDelta(portrait, portrait)
        box:GetChild("floating"):SetSizeDelta(width + S.xl, L.nativeText.lineHeight * 2)
        picture(box:GetChild("portrait"), icon)
        tint(box:GetChild("portrait"), box.name == "hero" and C.geo or C.text)
        tint(box:GetChild("border"), selected and C.goldBright or C.line)
        for _, x in ipairs({-1,1}) do for _, y in ipairs({-1,1}) do
            for _, axis in ipairs({'H','V'}) do
                local corner=box:GetChild('target'..axis..x..'_'..y)
                corner:SetVisible(selected == true)
                corner:SetAnchoredPosition(x*portrait/2,y*portrait/2)
            end
        end end
        box:GetChild("name").text = actor.name or "旅行者"
        box:GetChild("name"):SetAnchoredPosition(0,M.geometry(portrait,box.name=='hero').nameY)
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
            return x, y
        else
            count:SetAnchoredPosition(x + L.battleUnit.badgeOffset[1], y + L.battleUnit.badgeOffset[2])
            count.text = entry.stack == "none" and "" or entry.amount > 99 and "99+" or number(entry.amount):gsub("^-","−")
            ink(count, C.text)
            return x + L.battleUnit.badgeOffset[1], y + L.battleUnit.badgeOffset[2]
        end
    end

    local function statusPlates(row, i, entry, overflow, x, y, countX, countY)
        local frames = row:GetChild('backplates')
        local edge, body = frames:GetChild('edge' .. i), frames:GetChild('body' .. i)
        local badge = row:GetChild('countBackplates'):GetChild('badge' .. i)
        edge:SetVisible(entry and not overflow or false)
        body:SetVisible(entry and not overflow or false)
        badge:SetVisible(entry and (overflow or entry.stack ~= 'none') or false)
        if not entry then return end
        edge:SetAnchoredPosition(x, y)
        body:SetAnchoredPosition(x, y)
        badge:SetAnchoredPosition(countX, countY)
        tint(edge, statusKind(entry) == 'buff' and C.gold or C.debuff)
    end

    local function statusSlot(row, i, entry, layout)
        local statusImage, count = row:GetChild("icon" .. i), row:GetChild("count" .. i)
        local target = row:GetChild("hit" .. i)
        target:SetVisible(entry and true or false)
        local overflow = entry and i == layout.slots and #layout.entries >= layout.slots
        statusImage:SetVisible(entry and not overflow or false)
        count:SetVisible(entry and true or false)
        if entry then
            local k = i - 1
            local line = math.floor(k / layout.perRow)
            local x = (k % layout.perRow - (math.min(layout.perRow, layout.shown - line * layout.perRow) - 1) / 2) * layout.pitch
            local y = (L.statusIcon.rows - 1) * layout.pitch / 2 - line * layout.pitch
            statusImage:SetAnchoredPosition(x, y)
            target:SetAnchoredPosition(x, y)
            picture(statusImage, Theme.icon.status[entry.icon or entry.id] or Theme.icon.intent[entry.kind] or Theme.icon.intent.unknown)
            tint(statusImage, C.text)
            local countX, countY = statusCount(count, entry, x, y, overflow, layout)
            local digits=math.max(L.statusIcon.size,utf8.len(count.text)*Theme.font.small+S.hairline*2)
            count:SetSizeDelta(digits,L.nativeText.lineHeight)
            row:GetChild("countBackplates"):GetChild("badge"..i):SetSizeDelta(digits,L.statusIcon.size)
            statusPlates(row, i, entry, overflow, x, y, countX, countY)
        else
            statusPlates(row, i)
        end
    end

    local function statuses(box, actor, portrait, width)
        local si, entries, row = L.statusIcon, Combat.statusView(actor), box:GetChild("statusRow")
        local pitch = si.size + si.gap
        local perRow = si.perRow
        local slots = perRow * si.rows
        local layout = {entries = entries, pitch = pitch, perRow = perRow, slots = slots, shown = math.min(#entries, slots)}
        local firstY=M.geometry(portrait,box.name=='hero').firstStatusY
        row:SetAnchoredPosition(0,firstY-(si.rows-1)*pitch/2)
        local lines=math.ceil(layout.shown/perRow)
        local target=row:GetChild("hit")
        target:SetVisible(lines>0)
        target:SetAnchoredPosition(0,(si.rows-lines)*pitch/2)
        target:SetSizeDelta(width,math.max(si.minimumTouch,lines*pitch))
        for i = 1, si.perRow * si.rows do
            statusSlot(row, i, i <= layout.shown and entries[i], layout)
        end
    end

    return function(box, actor, portrait, icon, width, selected, targetWidth)
        portraitParts(box, actor, portrait, icon, width, selected, targetWidth)
        -- Widen the Block chip for native digits rather than shrinking its text.
        local blocked = actor.block > 0
        local chip = math.max(L.blockBadge.size, #number(actor.block) * Theme.font.body + L.blockBadge.padding * 2)
        local geometry=M.geometry(portrait,box.name=='hero')
        local barWidth,barX,y=geometry.healthWidth,0,geometry.healthY
        healthParts(box, actor, barWidth, barX, y, blocked)
        blockParts(box, actor, barWidth, barX, y, blocked, chip)
        statuses(box, actor, portrait, width)
    end
end

return M
