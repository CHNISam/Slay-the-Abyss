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

function M.new(view, controls)
    local child, show = controls.child, controls.show
    local ink, tint, picture = controls.ink, controls.tint, controls.picture
    local placeCard, placeReward = controls.placeCard, controls.placeReward
    local dragTarget, dragPose, enemySlot = controls.dragTarget, controls.dragPose, controls.enemySlot
    local function renderCards(data, presentation, battle, fighting, active, reward, picking)
        local run = view.run
        local rewards = picking and Run.rewardOptions(run) or {}
        local aimUid, aimTarget
        if view.gesture and view.gesture.moving then
            local _, target = dragTarget(view.gesture)
            aimUid, aimTarget = view.gesture.uid, target
        end
        view.cardPositions = {}
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
                local enabled = reward or active and Combat.canPlay(battle, instance.uid, view.target)
                playable = playable or enabled
                local selected = instance and instance.uid == view.selected
                CardDisplay.writeTitle(box:GetChild("name"),display.name,instance and instance.upgraded,
                    instance and definition.repeatable and (instance.upgrades or 1) or nil)
                ink(box:GetChild("name"), instance and instance.upgraded and C.positive or enabled and C.text or C.textMuted)
                local text = instance and instance.upgraded and display.upgradeText or display.text
                if instance and definition.originalV4 and view.busy then
                    text='效果结算中'
                elseif instance then
                    -- The core previews upgrade, growth and every current modifier;
                    -- a card being aimed shows the value for that target.
                    local preview = Combat.cardPreview(battle, instance, instance.uid == aimUid and aimTarget or nil)
                    text=CardDisplay.combatText(display,definition,instance,preview)
                end
                CardDisplay.writeBody(box:GetChild("label"),text)
                ink(box:GetChild("label"), enabled and C.text or C.textMuted)
                box:GetChild("type").text = typeNames[definition.type] or definition.type
                box:GetChild("cost").text = definition.cost == -2 and ""
                    or definition.costMode == "all_energy" and "X" or number(definition.cost)
                ink(box:GetChild("cost"), enabled and C.textOnLight or C.danger)
                tint(box:GetChild("costDisc"), enabled and C.energy or C.energyEmpty)
                local hovered = reward and not fighting and view.hover == i
                tint(box:GetChild("border"), (selected or hovered) and C.goldBright or enabled and (C.rarity[definition.rarity] or C.line) or C.line)
                tint(box:GetChild("artPlate"), enabled and (C.cardType[definition.type] or C.panelRaised) or C.panelSunken)
                picture(box:GetChild("art"), CardDisplay.art(definition))
                local pose
                if reward and not fighting then
                    local hot = view.hover == i
                    pose = placeReward(box, #rewards, i, view.rewardView.cards[i], hot)
                    if hot then selectedBox = box end
                else pose = placeCard(box, fighting and #battle.hand or #rewards, i - 1, selected == true) end
                if instance then view.cardPositions[instance.uid] = pose end
                if selected then selectedBox = box end
            end
        end
        if selectedBox then selectedBox:SetAsLastSibling() end
        return playable
    end
    local function renderDrag(valid, target, aiming, resolved)
        local g = view.gesture
        show("dragLayer", g ~= nil and g.moving == true)
        if g and g.moving then
            local box = child("card" .. g.slot)
            if not resolved then valid, target, aiming = dragTarget(g) end
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
            g.drawn, g.drawnValid, g.drawnTarget, g.drawnAiming = true, valid, target, aiming
        end
    end
    return { renderCards = renderCards, renderDrag = renderDrag }
end
return M
