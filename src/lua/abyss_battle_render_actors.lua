-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Theme = require("abyss_theme")
local EnemyView = require('abyss_battle_enemy_view')
local DamageView = require('abyss_battle_damage_view')
local PotionView = require("abyss_battle_potion_view")
local IntentView = require("abyss_battle_intent_view")
local RewardOwner = require("abyss_battle_reward_owner")
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
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, dependencies)
    local function pendingCardTarget(frame)
        if not frame.fighting or not owner.selected then return false end
        for _, instance in ipairs(frame.battle.hand) do
            if instance.uid == owner.selected then return needsTarget(frame.battle, instance) end
        end
        return false
    end
    local function potionHighlighted(enemy, index, pendingTarget)
        local aim = owner.potionAim
        if not aim or pendingTarget or not Actors.isActive(enemy) then return false end
        if aim.moving then
            local valid, hovered = dependencies.potionDragTarget(aim)
            return valid and hovered == index
        end
        -- Point selection advertises every legal enemy; a moving bottle locks
        -- only the hovered target through potionDragTarget above.
        return true
    end
    local function enemyHighlighted(frame, enemy, index, pendingTarget)
        local targetable = frame.active and pendingTarget and Combat.canPlay(frame.battle, owner.selected, index)
        if owner.gesture and owner.gesture.moving then
            local valid, hovered = dependencies.dragTarget(owner.gesture)
            targetable = valid and hovered == index
        end
        return targetable == true or potionHighlighted(enemy,index,pendingTarget) or owner.acting == enemy.id
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
    local function renderEnemyIntent(box, face, portrait)
        local icons = IntentView.icons(face)
        local size = L.intent.size
        local iconY = portrait / 2 + L.intent.portraitGap + size / 2
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
        local attack=icons[1]=='attack' and attackLabel.text~=''
        attackLabel:SetVisible(attack)
        local glyphWidth=utf8.len(attackLabel.text)*L.intent.numberSize
        local textWidth=math.max(L.intent.valueWidth,glyphWidth)
        local left=(1-(#icons+1)/2)*pitch-size/2-S.xs
        local valueY=iconY-size/2+L.intent.numberSize/2-L.statusIcon.gap
        attackLabel:SetAnchoredPosition(left+textWidth/2,valueY)
        attackLabel:SetSizeDelta(textWidth,L.nativeText.lineHeight)
        dependencies.ink(attackLabel, C.text)
        box:GetChild('intentLabel'):SetVisible(false)
        local span=#icons*pitch-size/2
        local x0,x1=-span/2,span/2
        local y0,y1=iconY-size/2,iconY+size/2
        if attack then
            x0,x1=math.min(x0,left),math.max(x1,left+glyphWidth)
            y0=math.min(y0,valueY-L.intent.numberSize/2)
        end
        local width,height=math.max(L.statusIcon.minimumTouch,x1-x0),math.max(L.statusIcon.minimumTouch,y1-y0)
        box:GetChild('intentHit'):SetAnchoredPosition((x0+x1)/2,(y0+y1)/2)
        box:GetChild('intentHit'):SetSizeDelta(width,height)
    end
    local function enemyAimProjection(frame)
        local aimed = owner.gesture or owner.carry
        local projection = { pendingTarget = pendingCardTarget(frame) }
        if aimed and aimed.moving then projection.valid, projection.target = dependencies.dragTarget(aimed) end
        if projection.valid then projection.losses = DamageView.preview(frame.battle, aimed.uid, projection.target) end
        local potion=owner.potionAim
        if potion and potion.moving then
            projection.valid,projection.target=dependencies.potionDragTarget(potion)
            if projection.valid then projection.losses=DamageView.potionPreview(owner.run,potion.slot,projection.target) end
        end
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
        local x, width, portrait, step, y = dependencies.enemySlot(count, slot, enemy)
        box:SetAnchoredPosition(x, y)
        local selected = enemyHighlighted(frame, enemy, entry.index, aim.pendingTarget)
        local loss = aim.losses and aim.losses[entry.index]
        if aim.valid and not aim.target and loss and loss.loss > 0 then selected = true end
        host.unit(box, enemy, portrait, enemyPortraitIcon(enemy), width, selected,step)
        local dim = (aim.pendingTarget or owner.potionAim ~= nil) and not selected
        local portraitTone = C.text
        dependencies.tint(box:GetChild('portrait'), { r = portraitTone.r, g = portraitTone.g, b = portraitTone.b, a = dim and 102 or 255 })
        renderDamagePreview(box, enemy, portrait, width, loss)
        renderEnemyIntent(box, enemyIntentFace(frame, enemy, entry.index), portrait)
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
        local reward=owner.info and owner.info.reward and RewardOwner.ready(owner,owner.info.reward)
        if owner.info and (not owner.active or owner.busy or owner.gesture or not frame.fighting and not reward
            or owner.info.battle ~= frame.run.combat) then owner.info = nil end
        host.renderInfo(frame.battle or reward and frame.run.combat)
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
    local function potionSelected(slot)
        return owner.potionMenu and owner.potionMenu.slot==slot
            or owner.potionAim and owner.potionAim.slot==slot
    end
    local function paintPotionShell(slot,item)
        local selected=item~=nil and potionSelected(slot)==true
        local tones=C.potionShell
        for _,state in ipairs({'normal','hover','pressed','disabled'})do
            local face=dependencies.child('potion'..slot):GetChild(state)
            face:GetChild('emptyShell'):SetVisible(item==nil)
            face:GetChild('filledShell'):SetVisible(item~=nil and item.id~='fire_potion')
            face:GetChild('fireShell'):SetVisible(item~=nil and item.id=='fire_potion')
            face:GetChild('selectedShell'):SetVisible(selected)
            dependencies.tint(face:GetChild('filledShell'):GetChild('rim'),selected and tones.selected.border or tones.normal.border)
            dependencies.tint(face:GetChild('fireShell'):GetChild('rim'),selected and tones.selected.border or tones.fire.border)
            local bottle=face:GetChild('bottle');bottle:SetVisible(item~=nil)
            if item then
                dependencies.picture(bottle,Theme.icon.potion[item.id] or Theme.icon.intent.unknown)
                dependencies.tint(bottle,item.id=='fire_potion' and tones.fire.ink or tones.normal.ink)
            end
        end
    end
    local function renderPotions(frame)
        -- Fixed physical slots prevent a queued second click moving to another item.
        bindPotionSlots(frame)
        for i = 1, L.battlePotions.count do
            local visible = frame.fighting and i <= frame.potionCapacity
            dependencies.show("potion" .. i, visible)
            local item = boundPotion(frame, i)
            dependencies.button("potion" .. i, visible and frame.active and item ~= nil, false,
                item and potionText(item, frame.battle) or "空药水槽")
            dependencies.show("potionHelp" .. i, false)
            dependencies.button("potionHelp" .. i, visible and frame.active and item ~= nil, false, "")
            paintPotionShell(i,item)
        end
    end

    return {
        pendingCardTarget=pendingCardTarget, enemyHighlighted=enemyHighlighted, enemyIntentFace=enemyIntentFace, renderEnemyIntent=renderEnemyIntent, enemyAimProjection=enemyAimProjection,
        renderDamagePreview=renderDamagePreview, enemyPortraitIcon=enemyPortraitIcon, renderEnemySlot=renderEnemySlot, renderEnemies=renderEnemies, renderDetails=renderDetails,
        renderRewardActions=renderRewardActions, renderContinue=renderContinue, bindPotionSlots=bindPotionSlots, boundPotion=boundPotion, renderPotions=renderPotions,
        potionSelected=potionSelected, paintPotionShell=paintPotionShell
    }
end
return M
