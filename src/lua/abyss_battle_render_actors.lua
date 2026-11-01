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
    -- A new view binding starts fresh; weak native keys cannot retain retired actors.
    local intentImages=setmetatable({},{__mode='k'})
    local intentTexts=setmetatable({},{__mode='k'})
    local potionCaptions=setmetatable({},{__mode='k'})
    local function intentPicture(control,id)
        local image=type(id)=='table' and id.id or id
        local source=host.platform.imageSource
        local painted=intentImages[control]
        if painted and painted.image==image and painted.source==source and control.alive~=false then return end
        intentImages[control]=nil
        if dependencies.picture(control,id)~=false then intentImages[control]={image=image,source=source} end
    end
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
    local function enemyIntentFace(frame,enemy,index)
        local face
        if IntentView.hasSourceIntent(enemy)then
            local view=host.monsterIntentParticles
            local selected=view:needsSelected(enemy.id) and IntentView.selectedDescriptor(frame.battle,index) or nil
            face=view:face(enemy.id,selected,function(base)
                return Combat.intentAttackAmount(frame.battle,enemy,frame.battle.player,base)
            end)
        else face=intentView(frame.battle,index)end
        -- Dome changes visibility, never the source selected/displayed state.
        if require('abyss_boss_relics').hidesIntents(owner.run)then face.hidden=true;face.value=''end
        return face
    end
    local function intentGeometry(portrait,geometry)
        if geometry then return geometry.intentX,geometry.intentY,geometry.intentWidth end
        return 0,portrait/2,128*Theme.canvas.base[1]/1920
    end
    local function intentTone(alpha,kind)
        -- STS intent atlases are colour-coded (attack red, defend blue, buff gold,
        -- debuff violet); white-tinted silhouettes read as one undifferentiated blob.
        local ink=({attack=C.danger,defend=C.block,buff=C.buff,debuff=C.debuff,strong_debuff=C.debuff})[kind] or C.text
        return {r=ink.r,g=ink.g,b=ink.b,a=255*(alpha or 1)}
    end
    local function renderIntentIcon(box,face,x,y,size,allowed,alpha)
        local kind=face.worldKind or face.kind
        local visible=allowed~=false and (face.sourceEnum and face.worldVisible or not face.sourceEnum)
        local icon=box:GetChild('intentIcon');icon:SetVisible(visible==true)
        -- STS 128px intent frames are mostly transparent padding; the official glyphs here
        -- are full-bleed, so draw them at the glyph size and float them clear of the head.
        local glyph=math.min(size,L.intent.size)
        icon:SetSizeDelta(glyph,glyph);icon:SetAnchoredPosition(x,y)
        if visible then
            intentPicture(icon,Theme.icon.intent[kind] or Theme.icon.intent.unknown)
            dependencies.tint(icon,intentTone(alpha,kind))
        end
    end
    local function renderIntentValue(box,face,x,y,allowed,alpha)
        local kind=face.worldKind or face.kind
        local value=box:GetChild('intent')
        local attack=face.sourceEnum and face.sourceEnum:sub(1,6)=='ATTACK' or not face.sourceEnum and kind=='attack'
        value:SetVisible(allowed~=false and attack and face.value~='')
        local text=face.value and face.value:gsub('×','x') or ''
        if intentTexts[value]~=text or value.alive==false then
            intentTexts[value]=nil
            value.text=text
            intentTexts[value]=text
        end
        local width=math.max(L.intent.valueWidth,utf8.len(text)*L.intent.numberSize)
        value:SetSizeDelta(width,L.nativeText.lineHeight)
        value:SetAnchoredPosition(x+L.intent.size/2+S.xs+width/2,y)
        dependencies.ink(value,intentTone(alpha))
    end
    local function renderEnemyIntent(box,face,portrait,geometry,allowed,alpha)
        local x,y,size=intentGeometry(portrait,geometry)
        renderIntentIcon(box,face,x,y,size,allowed,alpha)
        for _,name in ipairs({'intentBadge','intentExtra','intentLabel'})do box:GetChild(name):SetVisible(false)end
        renderIntentValue(box,face,x,y,allowed,alpha)
        local sx,sy=Theme.canvas.base[1]/1920,Theme.canvas.base[2]/1080
        local hit=box:GetChild('intentHit');hit:SetVisible(allowed~=false)
        hit:SetAnchoredPosition(x,y);hit:SetSizeDelta(64*sx,64*sy)
    end
    local function enemyIntentAllowed(actor,battle)
        return not require('abyss_boss_relics').hidesIntents(owner.run) and Actors.isPresent(actor) and not owner.feedback.dying[actor.id]
            and not owner.feedback.escaping[actor.id] and battle.player.hp>0
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
        local geometry=EnemyView.geometry(enemy)
        host.unit(box, enemy, portrait, enemyPortraitIcon(enemy), width, selected,step,geometry)
        host.monsterPowers:render(box,entry.controlSlot,enemy,geometry)
        box:GetChild('hit'):SetSizeDelta(geometry.hitWidth,geometry.hitHeight)
        box:GetChild('hit'):SetAnchoredPosition(geometry.hitX-x,geometry.hitY-y)
        local dim = (aim.pendingTarget or owner.potionAim ~= nil) and not selected
        local portraitTone = C.text
        local tone={r=portraitTone.r,g=portraitTone.g,b=portraitTone.b,a=dim and 102 or 255}
        dependencies.tint(box:GetChild('portrait'),tone)
        host.monsterArt:write(box,x,y,portrait,tone)
        renderDamagePreview(box, enemy, portrait, width, loss)
        renderEnemyIntent(box, enemyIntentFace(frame, enemy, entry.index), portrait,geometry,
            enemyIntentAllowed(enemy,frame.battle),host.monsterIntentParticles:alpha(enemy.id))
        host.monsterIntentParticles:paint(box,enemy.id,geometry,enemyIntentAllowed(enemy,frame.battle))
    end
    local function updateEnemyIntents(dt)
        local battle=owner.displayBattle or owner.run and owner.run.combat
        if not battle or not owner.active then return end
        -- The surface manager owns live handles. Feedback rows may still include
        -- a death whose independently clocked surface has already retired.
        for _,entry in ipairs(owner.feedback.enemyRows or {})do
            local actor=entry.actor
            local box=host.monsterSurfaces:find(entry.id)
            if box then
            local face=enemyIntentFace({battle=battle,enemyPlayback=owner.feedback.busy},actor,entry.index)
            local g=EnemyView.geometry(actor)
            local dying,escaping=owner.feedback.dying[entry.id],owner.feedback.escaping[entry.id]
            host.monsterIntentParticles:update(entry.id,dt,face,g,dying,escaping)
            renderEnemyIntent(box,face,g.portrait,g,enemyIntentAllowed(actor,battle),
                host.monsterIntentParticles:alpha(entry.id))
            host.monsterIntentParticles:paint(box,entry.id,g,enemyIntentAllowed(actor,battle) and face.sourceEnum~='NONE')
            else
                assert(not Actors.isPresent(actor),'active monster intent surface missing: '..entry.id)
            end
        end
    end
    local function nameBlocked(actor)
        if owner.feedback.dying[actor.id] or owner.feedback.escaping[actor.id] then return true end
        if not owner.gesture then return false end
        local battle=owner.run and owner.run.combat
        for _,card in ipairs(battle and battle.hand or {})do
            if card.uid==owner.selected then return not needsTarget(battle,card)end
        end
        return false
    end
    local function updateEnemyNames(dt)
        local battle=owner.run and owner.run.combat
        if ownership.nameBattle~=battle or not ownership.nameStates then ownership.nameBattle=battle;ownership.nameStates={}end
        local x,y
        if host.platform.cursorPosition then x,y=dependencies.point({GetUIPos=host.platform.cursorPosition})end
        local wanted={}
        host.monsterSurfaces:each(function(box,_,entry)
            local id,actor=entry.id,entry.actor;wanted[id]=true
            local state=ownership.nameStates[id] or {timer=0,alpha=0}
            ownership.nameStates[id]=state
            local g=EnemyView.geometry(actor)
            local hovered=x and y and math.abs(x-g.hitX)<g.hitWidth/2 and math.abs(y-g.hitY)<g.hitHeight/2
            local offset
            state.timer,state.alpha,offset=EnemyView.nameStep(state.timer,state.alpha,dt,hovered,nameBlocked(actor),1)
            local name=box:GetChild('name');name:SetVisible(owner.active and offset~=nil and state.alpha>0)
            if offset then
                name:SetAnchoredPosition(g.nameX-(box:GetChild('portrait').x or 0),g.nameY+offset*g.sourceScale)
                dependencies.ink(name,{r=C.gold.r,g=C.gold.g,b=C.gold.b,a=math.floor(255*state.alpha)})
            end
        end)
        for id in pairs(ownership.nameStates)do if not wanted[id]then ownership.nameStates[id]=nil end end
    end
    local function hideEscapingHud(box,id)
        if not owner.feedback.escaping[id] then return end
        for _,name in ipairs({'hpBorder','hpTrack','hpGhost','hpFill','hp','blockEdge','blockIcon','block','name','statusRow','intentIcon','intentBadge','intentExtra','intent','intentHit'})do
            box:GetChild(name):SetVisible(false)
        end
    end
    local function renderEnemies(frame)
        local rows = frame.fighting and EnemyView.slots(frame.battle, owner.feedback) or {}
        if not owner.active then rows={}end
        host.monsterIntentParticles:sync(rows,owner.run and owner.run.combat,owner.feedback.current,owner.active and frame.fighting)
        host.monsterSurfaces:select(rows,owner.run and owner.run.combat)
        owner.feedback.enemyRows = rows
        local aim = enemyAimProjection(frame)
        for _,entry in ipairs(rows)do owner.feedback.bindEnemySlot(entry.controlSlot,entry.id)end
        host.monsterArt:select(rows)
        for index,entry in ipairs(rows)do
            local box=assert(host.monsterSurfaces:find(entry.id))
            renderEnemySlot(frame,box,entry,index,#rows,aim)
            hideEscapingHud(box,entry.id)
            box:SetVisible(true)
        end
        updateEnemyNames(0)
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
    local function paintPotionContents(face,item,tones)
        local bottle=face:GetChild('bottle');bottle:SetVisible(item~=nil)
        face:GetChild('label'):SetVisible(false)
        if item then
            dependencies.picture(bottle,Theme.icon.potion[item.id] or Theme.icon.intent.unknown)
            dependencies.tint(bottle,(Theme.icon.potionTint or {})[item.id]
                or (item.id=='fire_potion' and tones.fire.ink or tones.normal.ink))
        end
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
            paintPotionContents(face,item,tones)
        end
    end
    local function paintPotionCaption(slot,item,visible)
        local caption=dependencies.child('potionCaption'..slot)
        local shown=visible==true and item~=nil
        local text=item and PotionView.slotLabel(item)or ''
        local prior=potionCaptions[caption]
        if not prior or prior.shown~=shown or prior.text~=text then
            potionCaptions[caption]=nil
            local accepted=true
            if not prior or prior.shown~=shown then accepted=caption:SetVisible(shown)~=false end
            if not prior or prior.text~=text then caption.text=text end
            if accepted then potionCaptions[caption]={shown=shown,text=text} end
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
            paintPotionCaption(i,item,visible)
            paintPotionShell(i,item)
        end
    end

    return {
        updateEnemyNames=updateEnemyNames, updateEnemyIntents=updateEnemyIntents, pendingCardTarget=pendingCardTarget, enemyHighlighted=enemyHighlighted, enemyIntentFace=enemyIntentFace, renderEnemyIntent=renderEnemyIntent, enemyAimProjection=enemyAimProjection,
        renderDamagePreview=renderDamagePreview, enemyPortraitIcon=enemyPortraitIcon, renderEnemySlot=renderEnemySlot, renderEnemies=renderEnemies, renderDetails=renderDetails,
        renderRewardActions=renderRewardActions, renderContinue=renderContinue, bindPotionSlots=bindPotionSlots, boundPotion=boundPotion, renderPotions=renderPotions,
        potionSelected=potionSelected, paintPotionShell=paintPotionShell
    }
end
return M
