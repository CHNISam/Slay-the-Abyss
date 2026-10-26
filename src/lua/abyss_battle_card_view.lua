-- Card faces, placement and drag trajectory only. The host owns input validity
-- and commands; the core supplies costs, previews and playability.
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local CardDisplay = require("abyss_card_display")
local number = require("abyss_numbers").integer
local C, L, S = Theme.color, Theme.layout, Theme.space
local D = L.cardDrag
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }
local M = {}

local function cardDefinition(data, battle, instance, id)
    local definition = instance and Combat.cardDefinition(battle, instance)
    if definition then return definition end
    for _, card in ipairs(data.cards.cards) do
        if card.id == id then return card end
    end
end

local function repeatCount(definition, instance)
    return instance and definition.repeatable and (instance.upgrades or 1) or nil
end

local function costText(definition)
    if definition.cost == -2 then return "" end
    if definition.costMode == "all_energy" then return "X" end
    return number(definition.cost)
end

function M.new(view, controls)
    local child, show = controls.child, controls.show
    local ink, tint, picture = controls.ink, controls.tint, controls.picture
    local placeCard, placeReward = controls.placeCard, controls.placeReward
    local dragTarget, dragPose, enemySlot = controls.dragTarget, controls.dragPose, controls.enemySlot
    local function currentAim()
        if view.gesture and view.gesture.moving then
            local _, target = dragTarget(view.gesture)
            return view.gesture.uid, target
        end
    end

    local function bodyText(card, battle, aimUid, aimTarget)
        local instance, definition, display = card.instance, card.definition, card.display
        if instance and definition.originalV4 and view.busy then return "效果结算中" end
        if not instance then return display.text end
        -- The core previews upgrade, growth and every current modifier;
        -- a card being aimed shows the value for that target.
        local target = instance.uid == aimUid and aimTarget or nil
        local preview = Combat.cardPreview(battle, instance, target)
        return CardDisplay.combatText(display, definition, instance, preview)
    end

    local function writeName(box, card)
        local instance, enabled = card.instance, card.enabled
        CardDisplay.writeTitle(box:GetChild("name"), card.display.name, instance and instance.upgraded,
            repeatCount(card.definition, instance))
        ink(box:GetChild("name"), instance and instance.upgraded and C.positive or enabled and C.text or C.textMuted)
    end

    local function writeDetails(box, card, battle, aimUid, aimTarget)
        local definition, enabled = card.definition, card.enabled
        local text = bodyText(card, battle, aimUid, aimTarget)
        CardDisplay.writeBody(box:GetChild("label"), text)
        ink(box:GetChild("label"), enabled and C.text or C.textMuted)
        box:GetChild("type").text = typeNames[definition.type] or definition.type
        box:GetChild("cost").text = costText(definition)
        ink(box:GetChild("cost"), enabled and C.textOnLight or C.danger)
        tint(box:GetChild("costDisc"), enabled and C.energy or C.energyEmpty)
    end

    local function writeFrame(box, card, hovered)
        local definition, enabled = card.definition, card.enabled
        tint(box:GetChild("border"), (card.selected or hovered) and C.goldBright
            or enabled and (C.rarity[definition.rarity] or C.line) or C.line)
        tint(box:GetChild("artPlate"), enabled and (C.cardType[definition.type] or C.panelRaised) or C.panelSunken)
        picture(box:GetChild("art"), Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
    end

    local function place(box, card, context, i)
        local pose
        if context.reward and not context.fighting then
            pose = placeReward(box, #context.rewards, i, view.rewardView.cards[i], view.hover == i)
        else
            local count = context.fighting and #context.battle.hand or #context.rewards
            pose = placeCard(box, count, i - 1, card.selected == true)
        end
        if card.instance then view.cardPositions[card.instance.uid] = pose end
    end

    local function slotCard(context, instance, id)
        return {
            instance = instance,
            definition = cardDefinition(context.data, context.battle, instance, id),
            display = assert(context.presentation[id], "missing card presentation " .. id),
            enabled = context.reward or context.active and Combat.canPlay(context.battle, instance.uid, view.target),
            selected = instance and instance.uid == view.selected,
        }
    end

    local function renderSlot(context, i, aimUid, aimTarget)
        local box = child("card" .. i)
        local instance = context.fighting and context.battle.hand[i]
        local id = instance and instance.cardId or context.rewards[i]
        box:SetVisible(id ~= nil and id ~= false)
        if not id then return end
        local card = slotCard(context, instance, id)
        writeName(box, card)
        writeDetails(box, card, context.battle, aimUid, aimTarget)
        local hovered = context.reward and not context.fighting and view.hover == i
        writeFrame(box, card, hovered)
        place(box, card, context, i)
        return card, (card.selected or hovered) and box or nil
    end

    local function renderCards(data, presentation, battle, fighting, active, reward, picking)
        local context = { data = data, presentation = presentation, battle = battle, fighting = fighting,
            active = active, reward = reward, rewards = picking and Run.rewardOptions(view.run) or {} }
        local aimUid, aimTarget = currentAim()
        view.cardPositions = {}
        local playable, selectedBox = false, nil
        for i = 1, 10 do
            local card, hotBox = renderSlot(context, i, aimUid, aimTarget)
            if card then playable = playable or card.enabled end
            selectedBox = hotBox or selectedBox
        end
        if selectedBox then selectedBox:SetAsLastSibling() end
        return playable
    end

    local function placeDraggedCard(box, g, aiming)
        local x, y = dragPose(g)
        local h = L.card.size[2] * D.scale
        -- An aiming card parks under the line so it never hides the enemy row.
        if aiming then x, y = (g.origin or {g.sx})[1], D.lineY - h/2 - S.s end
        box:SetAnchoredPosition(x, y)
        box:SetLocalScale(D.scale, D.scale, 1)
        box.localRotationZ = 0
        return x, y, h
    end

    local function aimEndpoint(g, target, enemy)
        if enemy then
            local tx, _, portrait = enemySlot(#g.battle.enemies, target, enemy)
            return tx, L.enemyRow.y, portrait + D.reticlePad
        end
        return g.x, g.y, D.aimDot[2] * 2
    end

    local function renderReticle(layer, aiming, ex, ey, ring, enemy)
        local reticle = layer:GetChild("reticle")
        reticle:SetVisible(aiming == true)
        reticle:SetAnchoredPosition(ex, ey)
        reticle:SetSizeDelta(ring, ring)
        tint(reticle, enemy and C.goldBright or C.textDim)
    end

    local function renderArc(layer, aiming, sx, sy, ex, fy, enemy)
        for i = 1, D.aimDots do
            local dot, t = layer:GetChild("aim" .. i), i/D.aimDots
            dot:SetVisible(aiming == true)
            if aiming then
                local u, size = 1-t, D.aimDot[1] + (D.aimDot[2] - D.aimDot[1])*t
                -- Quadratic Bezier with its control point at (start x, end y): rises, then bends over.
                dot:SetAnchoredPosition(u*u*sx + 2*u*t*sx + t*t*ex, u*u*sy + 2*u*t*fy + t*t*fy)
                dot:SetSizeDelta(size, size)
                tint(dot, enemy and C.goldBright or C.textDim)
            end
        end
    end

    local function renderDrag()
        local g = view.gesture
        show("dragLayer", g ~= nil and g.moving == true)
        if g and g.moving then
            local box = child("card" .. g.slot)
            local valid, target, aiming = dragTarget(g)
            local x, y, h = placeDraggedCard(box, g, aiming)
            box:GetChild("glow"):SetVisible(valid == true)
            local layer = child("dragLayer")
            tint(layer:GetChild("line"),valid and C.goldBright or C.line)
            local enemy = target and g.battle.enemies[target]
            -- The lit line, card glow and reticle already say "release to play"; no caption over the card.
            layer:GetChild("hint").text = ""
            -- Dotted arc from the card's top edge to the reticle (or the bare pointer).
            local ex, ey, ring = aimEndpoint(g, target, enemy)
            renderReticle(layer, aiming, ex, ey, ring, enemy)
            local sx, sy, fy = x, y+h/2, ey-(enemy and ring/2 or 0)
            renderArc(layer, aiming, sx, sy, ex, fy, enemy)
            layer:SetAsLastSibling()
        end
    end
    return { renderCards = renderCards, renderDrag = renderDrag }
end
return M
