-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Theme = require("abyss_theme")
local EnemyView = require('abyss_battle_enemy_view')
local DamageView = require('abyss_battle_damage_view')
local PotionView = require("abyss_battle_potion_view")
local IntentView = require("abyss_battle_intent_view")
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space
local intentColors = { attack = C.danger, defend = C.block, buff = C.buff, debuff = C.debuff }
local number = require("abyss_numbers").integer
local potionText = PotionView.potionText
local intentView = IntentView.intentView
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
-- Only this responsibility owns these closures; cross-responsibility calls are explicit ports.
function M.install(owner, ownership, host, dependencies)
    local function pendingCardTarget(frame)
        if not frame.fighting or not owner.selected then return false end
        for _, instance in ipairs(frame.battle.hand) do
            if instance.uid == owner.selected then return needsTarget(frame.battle, instance) end
        end
        return false
    end
    local function enemyHighlighted(frame, enemy, index, pendingTarget)
        local targetable = frame.active and pendingTarget and Combat.canPlay(frame.battle, owner.selected, index)
        if owner.gesture and owner.gesture.moving then
            local valid, hovered = dependencies.dragTarget(owner.gesture)
            targetable = valid and hovered == index
        end
        local potionTarget = owner.potionAim ~= nil and not pendingTarget and Actors.isActive(enemy)
        return targetable == true or potionTarget or owner.acting == enemy.id
    end
    local function enemyIntentFace(frame, enemy, index)
        local shown = ownership.playbackIntents and ownership.playbackIntents[enemy.id]
        local face = shown and Actors.isActive(enemy) and shown or intentView(frame.battle, index)
        local event = frame.enemyPlayback and owner.feedback.current
        -- Cache the historical starting face, not an already-applied later frame.
        if event and event.kind == "intent" and event.detail.enemy == enemy.id then
            ownership.playbackIntents = ownership.playbackIntents or {}
            ownership.playbackIntents[enemy.id] = face
        elseif not Actors.isActive(enemy) and ownership.playbackIntents then
            ownership.playbackIntents[enemy.id] = nil
        end
        return face
    end
    local function renderEnemyIntent(box, face, portrait, enemyY)
        local icons = IntentView.icons(face)
        local size, line, ceiling = L.intent.size, L.nativeText.lineHeight, L.battleNotice.position[2] - L.battleNotice.size[2] / 2
        local iconY = math.min(ceiling - enemyY - size / 2, math.max(L.intent.offsetY, portrait / 2 + S.xs + line / 2 + size / 2))
        local pitch = size * 1.5
        for i, name in ipairs({'intentIcon','intentBadge','intentExtra'}) do
            local control, kind = box:GetChild(name), icons[i]
            control:SetVisible(kind ~= nil)
            control:SetSizeDelta(size, size)
            control:SetAnchoredPosition((i - (#icons + 1) / 2) * pitch, iconY)
            if kind then
                dependencies.picture(control, Theme.icon.intent[kind] or Theme.icon.intent.unknown)
                dependencies.tint(control, intentColors[kind] or C.goldDim)
            end
        end
        local attackLabel = box:GetChild('intent')
        attackLabel.text = face.value or ''
        attackLabel:SetVisible(icons[1] == 'attack' and attackLabel.text ~= '')
        attackLabel:SetAnchoredPosition((1 - (#icons + 1) / 2) * pitch + (L.intent.valueWidth - size) / 2,
            iconY - size / 2)
        dependencies.ink(attackLabel, C.text)
        box:GetChild('intentLabel'):SetVisible(false)
        local hitSpan = #icons * pitch - size / 2
        local hitWidth = math.max(hitSpan, L.intent.valueWidth)
        box:GetChild('intentHit'):SetAnchoredPosition((hitWidth - hitSpan) / 2, iconY - line / 4)
        box:GetChild('intentHit'):SetSizeDelta(hitWidth, size + line / 2)
    end
    local function enemyAimProjection(frame)
        local aimed = owner.gesture or owner.carry
        local projection = { pendingTarget = pendingCardTarget(frame) }
        if aimed and aimed.moving then projection.valid, projection.target = dependencies.dragTarget(aimed) end
        if projection.valid then projection.losses = DamageView.preview(frame.battle, aimed.uid, projection.target) end
        return projection
    end
    local function renderDamagePreview(box, enemy, portrait, width, loss)
        local preview = box:GetChild('damagePreview')
        preview:SetVisible(loss ~= nil and loss.loss > 0)
        preview:SetAnchoredPosition(0, -portrait / 2 - S.xxl + L.nativeText.lineHeight)
        preview:SetSizeDelta(width, L.nativeText.lineHeight)
        preview.text = loss and loss.loss > 0 and (loss.hp <= 0 and '击杀' or '−' .. number(loss.loss)) or ''
        if loss and loss.loss > 0 then box:GetChild('hpFill').fillAmount = math.max(0, loss.hp / enemy.maxHp) end
    end
    local function enemyPortraitIcon(enemy)
        return Theme.icon.enemy[enemy.definitionId] or Theme.icon.node[enemy.tier == 'normal' and 'combat' or enemy.tier]
    end
    local function renderEnemySlot(frame, box, entry, slot, count, aim)
        local enemy = entry.actor
        local x, width, portrait = dependencies.enemySlot(count, slot, enemy)
        box:SetAnchoredPosition(x, EnemyView.rowY(count, slot))
        local selected = enemyHighlighted(frame, enemy, entry.index, aim.pendingTarget)
        local loss = aim.losses and aim.losses[entry.index]
        if aim.valid and not aim.target and loss and loss.loss > 0 then selected = true end
        host.unit(box, enemy, portrait, enemyPortraitIcon(enemy), width, selected)
        local dim = (aim.pendingTarget or owner.potionAim ~= nil) and not selected
        local portraitTone = C.text
        dependencies.tint(box:GetChild('portrait'), { r = portraitTone.r, g = portraitTone.g, b = portraitTone.b, a = dim and 102 or 255 })
        renderDamagePreview(box, enemy, portrait, width, loss)
        renderEnemyIntent(box, enemyIntentFace(frame, enemy, entry.index), portrait, EnemyView.rowY(count, slot))
    end
    local function renderEnemies(frame)
        local rows = frame.fighting and EnemyView.slots(frame.battle, owner.busy and owner.feedback or nil) or {}
        owner.feedback.enemyRows = rows
        local aim = enemyAimProjection(frame)
        for i = 1, 5 do
            local box, entry = dependencies.child('enemy' .. i), rows[i]
            owner.feedback.bindEnemySlot(i, entry and entry.id)
            box:SetVisible(entry ~= nil)
            if entry then renderEnemySlot(frame, box, entry, i, #rows, aim) end
        end
    end
    local function renderDetails(frame)
        if owner.info and (not owner.active or owner.busy or owner.gesture or not frame.fighting
            or owner.info.battle ~= frame.run.combat) then owner.info = nil end
        host.renderInfo(frame.battle)
    end
    local function renderRewardActions(frame)
        local run, stolen = frame.run, frame.stolen
        dependencies.button("skip", owner.active and frame.picking == true and not run.rewards.cardResolved and not owner.busy, false, "跳过")
        dependencies.button("stolenGold", owner.active and stolen and not stolen.claimed and not owner.busy, false,
            stolen and (stolen.claimed and "已取回失金 " or "取回失金 ") .. number(stolen.amount) or "取回失金")
    end
    local function renderContinue(frame)
        local run = frame.run
        dependencies.button("continue", owner.active and run and (frame.manual or run.phase == "map") and not owner.busy, true,
            frame.manual and "前往地图" or "再战一场")
    end
    local function bindPotionSlots(frame)
        if frame.fighting and not owner.busy then
            owner.potionBattle, owner.potionRun, owner.potionSlots = frame.battle, frame.run, {}
            for slot = 1, frame.potionCapacity do
                local id = frame.run.potions[slot]
                if id then owner.potionSlots[slot] = {slot = slot, id = id} end
            end
        end
    end
    local function boundPotion(frame, index)
        local binding = owner.potionSlots and owner.potionSlots[index]
        local item = binding and frame.potions[binding.slot]
        if item and item.id ~= binding.id then return nil end
        return item
    end
    local function renderPotions(frame)
        -- Fixed physical slots prevent a queued second click moving to another item.
        bindPotionSlots(frame)
        for i = 1, L.battlePotions.count do
            local visible = frame.fighting and i <= frame.potionCapacity
            dependencies.show("potion" .. i, visible)
            local item = boundPotion(frame, i)
            dependencies.button("potion" .. i, visible and frame.active and item and item.canUse, false,
                item and potionText(item, frame.battle) or "空药水槽")
            dependencies.show("potionHelp" .. i, visible)
            dependencies.button("potionHelp" .. i, visible and frame.active and item ~= nil, false, "")
            for _,state in ipairs({'normal','hover','pressed','disabled'}) do
                local bottle=dependencies.child('potionHelp'..i):GetChild(state):GetChild('bottle')
                bottle:SetVisible(item~=nil)
                if item then dependencies.picture(bottle,Theme.icon.potion[item.id] or Theme.icon.intent.unknown) end
            end
        end
    end
    return {
        pendingCardTarget=pendingCardTarget, enemyHighlighted=enemyHighlighted, enemyIntentFace=enemyIntentFace, renderEnemyIntent=renderEnemyIntent, enemyAimProjection=enemyAimProjection,
        renderDamagePreview=renderDamagePreview, enemyPortraitIcon=enemyPortraitIcon, renderEnemySlot=renderEnemySlot, renderEnemies=renderEnemies, renderDetails=renderDetails,
        renderRewardActions=renderRewardActions, renderContinue=renderContinue, bindPotionSlots=bindPotionSlots, boundPotion=boundPotion, renderPotions=renderPotions
    }
end
return M
