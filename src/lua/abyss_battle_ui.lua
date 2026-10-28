-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local RewardLayout=require('abyss_battle_reward_layout')
local Actors = require("abyss_actor")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local Events = require("abyss_events")
local Feedback = require("abyss_feedback")
local CardView = require("abyss_battle_card_view")
local CardInput = require("abyss_card_input")
local EnemyView = require('abyss_battle_enemy_view')
local DamageView = require('abyss_battle_damage_view')
local StatusView = require("abyss_battle_status_view")
local PotionView = require("abyss_battle_potion_view")
local IntentView = require("abyss_battle_intent_view")
local UnitView = require("abyss_battle_unit_view")
local InfoContent = require("abyss_battle_info_content")
local InfoView = require("abyss_battle_info_view")
local RewardOwner = require("abyss_battle_reward_owner")
local Controller = require("abyss_controller")
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space
local reasons = { insufficient_energy = "能量不足", invalid_target = "请选择存活的敌人", card_content_unavailable = "此卡牌尚未实装，可选择其他卡牌或跳过。",
    card_not_in_hand = "这张牌已离开手牌", not_player_turn = "敌方行动中",
    normality_limit = "平庸：本回合已打出三张牌",
    advanced_card_not_enabled = "此牌效果尚未接入", not_in_combat = "战斗已经结束",
    empty_potion_slot = "此药水已使用", invalid_potion_slot = "请选择有效药水",
    smoke_not_allowed = '此战斗不能使用烟雾弹',
    effect_overflow = "当前状态已达上限", potion_slots_full = "药水槽已满，请先丢弃旧药水。",
    potion_content_unavailable = "该稀有度药水尚未实装。", potion_blocked_by_sozu = "遗物阻止获得药水。" }
local temporaryOps = {gainTemporaryStrength=true, gainTemporaryDexterity=true}
local stanceNames={Neutral="无姿态",Calm="平静",Wrath="愤怒",Divinity="神格"}
local orbNames={lightning="闪电",frost="冰霜",dark="黑暗",plasma="等离子"}
local intentColors = { attack = C.danger, defend = C.block, buff = C.buff, debuff = C.debuff }
local number = require("abyss_numbers").integer
local kindNames = { buff = "增益", debuff = "减益" }
local statusKind = StatusView.statusKind
local statusDetail = StatusView.statusDetail
local potionText = PotionView.potionText
local intentView = IntentView.intentView
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end

function M.new(root, data, presentation, clickEvent, platform, options)
    options = options or {}
    local self = { root = root, data = data, presentation = presentation, target = 1, seed = 1, busy = false, active = true }
    function self:setData(nextData, nextPresentation)
        assert(not self.busy, "cannot replace card data during feedback")
        assert(type(nextData)=="table" and type(nextPresentation)=="table", "invalid UI card data")
        data, presentation = nextData, nextPresentation
        self.data, self.presentation = data, presentation
        self.selected, self.hover, self.help = nil, nil, nil
    end
    local playbackIntents
    local stage = options.embedded and root or assert(root:GetChild("stage"), "missing stage")
    local function child(name)
        local nested=name:match('^potion[45]$') or name:match('^potionHelp%d$') or name=='potionReward' or name=='emeraldKeyReward' or name:match('^relicReward%d$')
        local found=(nested and stage:GetChild('potionHelp') or stage):GetChild(name)
        return assert(found, "missing UI control " .. name)
    end
    local function show(name, value) child(name):SetVisible(value == true) end
    local function label(name, value) child(name).text = value end
    local function colour(value) return platform.color(value.r, value.g, value.b, value.a) end
    local function tint(control, value) control.imageColor = colour(value) end
    local function ink(control, value) control.fontColor = colour(value) end
    local function picture(control, id) control:SetImage(platform.imageSource, id) end
    local function notice(value)
        label("notice", value)
        self.rewardNotice = value
    end
    local function rewardScreen(screen)
        if self.rewardScreen ~= screen then
            self.rewardScreen, self.rewardEpoch = screen, (self.rewardEpoch or 0) + 1
            self.hover = nil
        end
    end
    local cursor = platform.cursorEvents
    self.dragEnabled = cursor and cursor.CursorDown and cursor.CursorDrag and cursor.CursorUp and cursor.CursorEndDrag
    self.instructions = self.dragEnabled and "拖到战场出牌区域松手，目标牌拖向敌人；再点原牌取消。"
        or "点选卡牌，再点敌人或战场出牌区域；再点原牌取消。"
    local function dragReady(g)
        return self.active and not self.busy and self.run == g.run and self.run.phase == "combat"
            and self.run.combat == g.battle and g.battle.phase == "player" and g.battle.turn == g.turn
    end
    -- A card click is the final event of one physical pointer sequence. Retain
    -- its original rule identity, not a global permission another Down can reset.
    local cardInputs, pointerObserved = {}, false
    local function rewardReady(g)
        return RewardOwner.ready(self, g)
    end
    local function cardReady(g)
        if not self.active or self.busy or self.run ~= g.run or self.run.phase ~= g.phase then return false end
        if g.phase == "combat" then
            local instance = g.battle.hand[g.slot]
            return dragReady(g) and instance ~= nil and instance.uid == g.uid
        end
        if g.phase ~= "reward" or self.rewardScreen ~= "cards" or not rewardReady(g) then return false end
        return Run.rewardOptions(self.run)[g.slot] == g.uid
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
    local function cancelPotionAim(message)
        if not self.potionAim then return false end
        self.potionAim = nil
        if message then notice(message) end
        return true
    end
    local function aimReady(aim)
        if not potionReady(aim) then return false end
        local enemies = aim.battle.enemies
        if #enemies ~= #aim.actors then return false end
        for i, actor in ipairs(aim.actors) do
            if enemies[i] ~= actor or Actors.isActive(actor) ~= aim.living[i] then return false end
        end
        return true
    end
    -- Action buttons have their own pointer capability: some hosts deliver
    -- card/potion pointers but only Click for these preset buttons.
    local actionInputs, actionPointerObserved, fieldPointerObserved = {}, false, false
    local function actionContextReady(g)
        local run = self.run
        if not self.active or self.busy or self.gesture or run ~= g.run then return false end
        if run and (run.phase ~= g.phase or run.combat ~= g.battle
            or g.battle and g.battle.turn ~= g.turn) then return false end
        return true
    end
    local function playAreaReady(g)
        if g.aim then return self.potionAim == g.aim and aimReady(g.aim) end
        local instance = g.battle and g.battle.hand[g.slot or 0]
        return dragReady(g) and instance and instance.uid == g.uid and self.selected == g.uid
            and self.selectionEpoch == g.selectionEpoch and not needsTarget(g.battle, instance)
    end
    local function rewardListActionReady(g, rewards)
        local relicIndex=g.name:match('^relicReward(%d)$')
        if relicIndex then
            local item=rewards.relics and rewards.relics[tonumber(relicIndex)]
            return item and not item.claimed and not item.unavailable
        end
        if g.name == "cardReward" then return not rewards.cardResolved end
        if g.name == "goldReward" then return rewards.goldClaimed == false end
        if g.name == 'emeraldKeyReward' then return Run.canClaimEmeraldKey(self.run) end
        if g.name == "claimPotion" then return rewards.potion and not rewards.potion.resolved end
        if rewards.manualContinue then
            if g.name == "stolenGold" then return rewards.stolenGold and not rewards.stolenGold.claimed end
            if g.name == "continue" then return true end
        end
        return false
    end
    local function rewardActionReady(g, run)
        if not rewardReady(g) then return false end
        if self.rewardScreen == "cards" then return g.name == "skip" and not run.rewards.cardResolved end
        if self.rewardScreen ~= "list" then return false end
        return rewardListActionReady(g, run.rewards)
    end
    local function actionReady(g)
        if not actionContextReady(g) then return false end
        local run = self.run
        if g.name == "start" then return not options.embedded and (not run or run.phase == "defeat") end
        if not run then return false end
        if g.name == "playArea" then return playAreaReady(g) end
        if g.name == "endTurn" then return dragReady(g) end
        if run.phase == "reward" then return rewardActionReady(g, run) end
        return g.name == "continue" and not options.embedded and run.phase == "map"
    end
    local function cancelActionInputs()
        for _, input in ipairs(actionInputs) do input.held, input.released = nil, nil end
    end
    -- Dynamic spawns can occupy an old enemy slot. Pointer ownership follows
    -- the actor object, battle and turn, never a reusable numeric slot alone.
    local enemyInputs, enemyPointerObserved = {}, false
    local function enemyAt(slot,battle)
        battle=battle or self.run and self.run.combat
        return battle and EnemyView.slots(battle)[slot]
    end
    local function sameEnemySlot(slot,actor,battle)
        local entry=enemyAt(slot,battle)
        return entry and entry.actor==actor and entry.id==actor.id
    end
    local function enemyReady(g)
        return not self.info and dragReady(g) and Actors.isActive(g.actor) and g.battle.enemies[g.slot] == g.actor
            and sameEnemySlot(g.screenSlot,g.actor,g.battle)
            and self.selected == g.uid and self.selectionEpoch == g.selectionEpoch
            and self.potionAim == g.aim and (not g.aim or aimReady(g.aim))
    end
    local function discardEnemyPointer(input,event)
        local touch = event and event.touchId
        if input.held and input.held.touch == touch then input.held = nil end
        if input.released and input.released.touch == touch then input.released = nil end
    end
    local D = L.cardDrag
    local function enemySlot(count, i, enemy)
        return EnemyView.position(count, i, enemy)
    end
    local function enemyPosition(battle,index)
        local entry,slot,count=EnemyView.find(battle,index,self.busy and battle==self.displayBattle and self.feedback or nil)
        assert(entry,'enemy has no visible presentation slot')
        return enemySlot(count,slot,entry.actor)
    end
    -- Source PC behavior: the card center follows the pointer, not the grab offset.
    local function dragPose(g)
        return g.x, g.y + (g.touchScreen and 270*g.sourceScale or 0)
    end
    local function inPlayArea(x,y)
        local area = D.playArea
        return math.abs(x-area[1]) <= area[3]/2 and math.abs(y-area[2]) <= area[4]/2
    end
    -- Target cards require an explicit enemy hit, including a little touch padding.
    -- Open ground never substitutes the nearest enemy, even when only one remains.
    local function dragTarget(g)
        if not dragReady(g) then return false end
        local battle = g.battle
        local ok, reason = Combat.canPlay(battle,g.uid,nil)
        if not ok and reason ~= "invalid_target" then return false end
        local hovered
        local rows = EnemyView.slots(battle)
        local count = #rows
        for i, entry in ipairs(rows) do
            local enemy = entry.actor
            local x, _, portrait, step = enemySlot(count,i,enemy)
            local reach = math.min(D.targetColumn,count > 1 and step or D.targetColumn)/2
            if math.abs(g.x-x) <= math.min(reach,portrait/2+D.reticlePad)
                and math.abs(g.y-EnemyView.rowY(count,i)) <= portrait/2+D.reticlePad
                and Actors.isActive(enemy) then
                hovered = entry.index; break
            end
        end
        CardInput.sample(g, g.x, g.y, hovered, not ok)
        if g.cancelled then return false, nil, g.aiming end
        if ok then return g.dropZone, nil end
        return g.aiming and hovered ~= nil and Combat.canPlay(battle,g.uid,hovered) or false, hovered, g.aiming
    end
    local function button(name, enabled, primary, caption)
        local box = child(name)
        box.interactable,box.raycastTarget = enabled == true,enabled == true
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
        local cancelled = cancelPotionAim("已取消药水瞄准。") or self.gesture ~= nil or self.carry ~= nil
        cancelCardInputs()
        cancelPotionInputs()
        cancelActionInputs()
        for _, input in ipairs(enemyInputs) do input.held, input.released = nil, nil end
        if cancelled then self.gesture, self.carry, self.selected, self.suppressClick = nil, nil, nil, true end
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
    local unit = UnitView.new(picture, tint, ink, statusKind)
    local lines = InfoContent.lines
    local infoContent = InfoContent.new(self, {
        statusDetail = statusDetail, statusKind = statusKind, intentView = intentView, potionText = potionText,
        temporaryOps = temporaryOps, stanceNames = stanceNames, orbNames = orbNames,
        kindNames = kindNames, intentColors = intentColors,
    }, lines)
    local function describeInfo(battle, info, actor)
        return infoContent(data, presentation, battle, info, actor)
    end
    local paginate = InfoView.paginator(lines)
    local renderInfo = InfoView.new(self, child, enemyPosition, describeInfo, paginate, tint, ink, picture)
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
        if not Actors.isPresent(actor) then return false end
        cancelPotionAim("已取消药水瞄准。")
        if self.info and self.info.index == index and self.info.id == actor.id then closeInfo()
        else self.info = {index = index, id = actor.id, battle = run.combat} end
        self:render()
        return true
    end
    function self:openHelp(spec, source, transient)
        local run=self.run
        if not self.active or self.busy or not run or run.phase~="combat" then return false end
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        if not Actors.isPresent(actor)then return false end
        cancelPotionAim("已取消药水瞄准。")
        self.info={index=spec.index,id=actor.id,battle=run.combat,kind=spec.kind,statusId=spec.statusId,
            offset=spec.offset,uid=spec.uid,source=source,transient=transient==true,
            slot=spec.slot,potionId=spec.potionId,inventory=spec.inventory}
        self:render()
        return self.info~=nil
    end
    function self:queueHelp(spec,source,held,touch,card)
        local run=self.run
        if not spec or not self.active or self.busy or not run or run.phase~="combat" then return end
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        if not Actors.isPresent(actor)then return end
        self.help={spec=spec,source=source,held=held,touch=touch,t=0,run=run,battle=run.combat,
            turn=run.combat.turn,actor=actor,card=card}
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
    function self:potionHelpSpec(slot)
        local run = self.run
        if not run or run.phase ~= "combat" or not run.potions[slot] or slot>Run.potionCapacity(run) then return end
        return {kind="potion",index=0,slot=slot,potionId=run.potions[slot],inventory=run.potions}
    end
    local function placeHandHit(box, w, h, restAngle, baseY, y, scale)
        local r = restAngle * math.pi / 180
        local c,s = math.abs(math.cos(r)),math.abs(math.sin(r))
        local restH,restW = (h*c+w*s)/2,(w*c+h*s)/2
        local hotH = h*Theme.motion.hoverScale/2
        local low = math.min(baseY-restH,baseY+Theme.motion.hoverLift-hotH)
        local high = math.max(baseY+restH,baseY+Theme.motion.hoverLift+hotH)
        local dy,a = (low+high)/2-y,box.localRotationZ*math.pi/180
        local hit = box:GetChild('hit')
        -- Inverse the card transform: one world-space hit rectangle covers both poses.
        hit:SetAnchoredPosition(math.sin(a)*dy/scale,math.cos(a)*dy/scale)
        hit:SetSizeDelta(math.max(restW*2,w*Theme.motion.hoverScale)/scale,(high-low)/scale)
        hit:SetLocalScale(1,1,1)
        hit.localRotationZ = -box.localRotationZ
    end
    local function placeCard(box, count, index, selected)
        local w, h = L.card.size[1], L.card.size[2]
        local spacing = count <= 1 and 0 or math.max(L.hand.spacingMin, math.min(L.hand.spacingMax, (L.hand.maxWidth - w) / (count - 1)))
        local distance = index - (count - 1) / 2
        local angle = -distance * L.hand.arcDegrees
        local radians = math.abs(angle) * math.pi / 180
        local halfHeight = (h * math.cos(radians) + w * math.sin(radians)) / 2
        local floor = -Theme.canvas.base[2] / 2 + Theme.canvas.safe.y + halfHeight
        local baseY = math.max(floor,L.hand.y-math.abs(distance)*L.hand.arcDrop)
        local x, y = distance * spacing, baseY + (selected and Theme.motion.hoverLift or 0)
        box:SetAnchoredPosition(x, y)
        local scale = selected and Theme.motion.hoverScale or 1
        box:SetLocalScale(scale, scale, 1)
        box.localRotationZ = selected and 0 or angle
        placeHandHit(box,w,h,angle,baseY,y,scale)
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
        local hit = box:GetChild('hit')
        hit:SetAnchoredPosition(0,0)
        hit:SetSizeDelta(L.card.size[1],L.card.size[2])
        hit:SetLocalScale(1,1,1)
        hit.localRotationZ = 0
        local x = (index - 1 - (count - 1) / 2) * R.step
        box:SetAnchoredPosition(x, R.y + anim.lift + anim.rise)
        box:SetLocalScale(anim.scale, anim.scale, 1)
        box.localRotationZ = 0
        box:GetChild("glow"):SetVisible(hot)
        -- Later siblings draw on top: neighbours first, the hovered card last.
        if not hot then box:SetAsLastSibling() end
        return {x, R.y}
    end
    local cardView = CardView.new(self, {
        child = child, show = show, ink = ink, tint = tint, picture = picture, platform = platform,
        placeCard = placeCard, placeReward = placeReward,
        dragTarget = dragTarget, dragPose = dragPose, enemyPosition = enemyPosition,
    })
    local function canHover()
        return self.active and not self.busy and not self.gesture and not self.carry
    end
    function self:setHover(slot)
        local run = self.run
        local reward = run and run.phase == 'reward' and self.rewardScreen == 'cards' and Run.rewardOptions(run)[slot]
        local hand = run and run.phase == 'combat' and run.combat.phase == 'player' and run.combat.hand[slot]
        if slot and not (canHover() and (reward or hand)) then slot,hand = nil,nil end
        if self.hover == slot then return end
        self.hover = slot
        self.handHover = hand and {run=run,battle=run.combat,turn=run.combat.turn,slot=slot,uid=hand.uid}
        self:render(true)
    end
    local function pruneInputs(inputs, ready)
        for _, input in ipairs(inputs) do
            if input.held and not ready(input.held) then input.held = nil end
            if input.released and not ready(input.released) then input.released = nil end
        end
    end
    local function prepareRenderInputs(view, presentationOnly)
        -- Animation redraws preserve a live Down; explicit redraws invalidate it.
        if not presentationOnly then view.rewardRender = (view.rewardRender or 0) + 1 end
        local run = view.run
        if view.potionAim and not aimReady(view.potionAim) then
            cancelPotionAim("药水瞄准已失效，已取消；请重新选择药水。")
        end
        if view.gesture and not cardReady(view.gesture) then
            view.gesture, view.selected, view.suppressClick = nil, nil, true
        end
        if view.carry and (view.selected ~= view.carry.uid or not cardReady(view.carry)) then
            if view.selected == view.carry.uid then view.selected = nil end
            view.carry = nil
        end
        pruneInputs(cardInputs, cardReady)
        pruneInputs(potionInputs, potionReady)
        pruneInputs(actionInputs, actionReady)
        pruneInputs(enemyInputs, enemyReady)
        return run
    end
    local function renderFeedbackReady(run)
        if self.busy and self.feedback and
            (self.feedbackRun ~= run or self.feedbackBattle ~= (run and run.combat)) then
            self.feedback:cancel()
            return false
        end
        return true
    end
    local function syncRenderIdentity(run)
        if self.viewRun ~= run then
            self.viewRun, self.target, self.selected = run, 1, nil
            self.potionRun, self.potionBattle, self.potionSlots = nil, nil, nil
            playbackIntents = nil
        end
        -- Encounters change committed identity even while their Run survives.
        local battle = run and run.combat
        if self.viewBattle ~= battle then
            self.viewBattle, self.target, self.selected = battle, 1, nil
            playbackIntents = nil
        end
    end
    local function renderFrame(run)
        local fighting = self.displayBattle ~= nil or run and run.phase == "combat"
        local battle = self.displayBattle or fighting and run.combat
        if self.displayBattle and battle.originalV4 then
            -- Only immutable target/cost rules are borrowed by playback frames.
            battle.originalV4Rules = self.feedbackBattle.originalV4Rules
        end
        local enemyPlayback = self.busy and self.displayBattle and battle.phase == "enemy"
        if not enemyPlayback then playbackIntents = nil end
        return {run = run, battle = battle, fighting = fighting, enemyPlayback = enemyPlayback}
    end
    local function handHoverReady()
        local token,run = self.handHover,self.run
        if not token then return false end
        local instance = token.battle.hand[token.slot]
        return canHover() and run == token.run and run.phase == 'combat' and run.combat == token.battle
            and token.battle.turn == token.turn and token.battle.phase == 'player'
            and instance and instance.uid == token.uid
    end
    local function syncRewardOwner(frame)
        local run = frame.run
        local reward = not self.busy and run and run.phase == "reward"
        frame.reward = reward
        if reward and (self.rewardOwner ~= run.rewards or self.rewardRun ~= run) then
            self.rewardOwner, self.rewardRun, self.rewardNotice = run.rewards, run, ""
            rewardScreen("list")
        elseif not reward then
            if self.rewardScreen then label("notice", "") end
            self.rewardOwner, self.rewardRun, self.rewardNotice = nil, nil, nil
            rewardScreen(nil)
        end
        frame.picking = reward and self.rewardScreen == "cards"
        frame.listing = reward and self.rewardScreen == "list"
        if reward then self.handHover = nil
        elseif not handHoverReady() then self.hover,self.handHover = nil,nil end
    end
    local function syncRewardEntrance(frame)
        if frame.picking and (not self.rewardView or self.rewardView.rewards ~= frame.run.rewards) then
            self.rewardView = {rewards = frame.run.rewards, cards = {}}
            for i = 1, 10 do
                self.rewardView.cards[i] = {scale = R.scale * R.enterScale, lift = 0, rise = -R.enterRise}
            end
        elseif not frame.picking then
            self.rewardView = nil
        end
    end
    local function targetPotionAvailable(frame)
        for slot = 1, frame.potionCapacity do
            local item = frame.potions[slot]
            if frame.active and item and item.canUse and item.needTarget then return true end
        end
        return false
    end
    local function prepareRenderPotions(frame)
        local run, battle = frame.run, frame.battle
        frame.active = self.active and frame.fighting and battle.phase == "player" and not self.busy
        -- Stage transactions once while input is available, never per animation step.
        frame.potions = self.busy and self.potionViewCache or frame.fighting and Run.potionView(run) or {}
        if not self.busy then self.potionViewCache = frame.potions end
        frame.potionCapacity = run and Run.potionCapacity(run) or 0
        self.potionTargetAvailable = targetPotionAvailable(frame)
    end
    local function renderStartControls(frame)
        local run = frame.run
        show("start", not self.busy and not options.embedded and (not run or run.phase == "defeat"))
        button("start", self.active, true, run and "重新启程" or "启程")
        show("endTurn", frame.fighting)
    end
    local function rewardNavigation(frame)
        local run = frame.run
        frame.manual = frame.listing and run.rewards.manualContinue
        frame.stolen = frame.manual and run.rewards.stolenGold
        frame.potionReward = frame.listing and run.rewards.potion
        frame.pendingPotion = frame.potionReward and not frame.potionReward.resolved
        show("skip", frame.picking and not run.rewards.cardResolved)
        show("continue", frame.manual or not options.embedded and run and run.phase == "map")
        child("skip"):SetAnchoredPosition(R.skip[1], R.skip[2])
        child("continue"):SetAnchoredPosition(
            frame.manual and L.battleRewards.continue[1] or 0,
            frame.manual and L.battleRewards.continue[2] or -S.xxl * 3)
    end
    local function renderRewardRows(frame)
        RewardLayout.render(frame,child)
    end
    local function renderRelicRewards(frame)
        local run=frame.run
        for i=1,2 do
            local item=frame.listing and run.rewards.relics and run.rewards.relics[i]
            local definition=item and require('abyss_relic_rewards').definition(run,item.sourceId)
            local caption=item and ((definition and definition.name or item.sourceId)..(item.unavailable and ' · 尚不可领取' or ''))or '遗物'
            button('relicReward'..i,self.active and item and not item.claimed and not item.unavailable or false,false,caption)
        end
    end
    local function renderRewardButtons(frame)
        local run = frame.run
        renderRelicRewards(frame)
        button('emeraldKeyReward',self.active and frame.listing and Run.canClaimEmeraldKey(run) and not self.busy or false,false,'领取绿钥匙')
        button("goldReward", self.active and frame.listing and run.rewards.goldClaimed == false, false,
            frame.listing and number(run.rewards.gold) .. " 金币" or "金币")
        button("cardReward", self.active and frame.listing and not run.rewards.cardResolved, false, "选择一张卡牌加入牌组")
        -- Full belts stay clickable so rejection can explain how to free a slot.
        button("claimPotion", self.active and frame.pendingPotion == true and not frame.potionReward.unavailable, false)
    end
    local function rewardPotionDefinition(frame)
        for _, item in ipairs(data.potions.potions) do
            if item.id == frame.potionReward.id then return item end
        end
    end
    local function rewardPotionCaption(frame)
        local reward, definition = frame.potionReward, rewardPotionDefinition(frame)
        return reward.unavailable and (reward.rarity .. " 药水尚未实装")
            or (definition and potionText(definition, frame.run.combat):gsub("\n", " · ") .. " · ×1" or "药水 ×1")
    end
    local function renderPotionReward(frame)
        local reward, run = frame.potionReward, frame.run
        if not reward then return end
        button("claimPotion", self.active and frame.pendingPotion == true and not reward.unavailable, false,
            rewardPotionCaption(frame))
        label("potionReward", reward.unavailable and "该稀有度药水尚未实装；可继续前往地图。"
            or Run.potionCount(run) >= Run.potionCapacity(run)
                and "药水槽已满；点顶部药水入口丢弃旧药水后，再点击奖励领取。" or "")
    end
    local function renderRewardStage(frame)
        show("rewardStage", frame.picking)
        show("rewardList", frame.listing)
        show("notice", not frame.reward)
        if frame.listing then
            child("rewardList"):GetChild("subtitle").text = self.rewardNotice ~= "" and self.rewardNotice
                or (frame.rewardRows == 0 and "奖励已领取" or "点击条目领取奖励")
        end
    end
    local function fieldCardSelected(frame)
        if not frame.active or self.gesture then return false end
        for _, instance in ipairs(frame.battle.hand) do
            if instance.uid == self.selected and not needsTarget(frame.battle, instance) then return true end
        end
        return false
    end
    local function renderPlayArea(frame)
        show("playArea", fieldCardSelected(frame) or frame.active and self.potionAim ~= nil)
        child("playArea"):GetChild("label").text = self.potionAim and "点击空白处取消药水瞄准" or "出牌区域 · 点击出牌"
    end
    local function renderHudVisibility(frame)
        for _, name in ipairs({"energyRing", "energyDisc", "energyIcon", "energy", "drawIcon", "drawBadgeRing", "drawBadge",
            "draw", "drawLabel", "discardIcon", "discardBadgeRing", "discardBadge", "discard", "discardLabel"}) do
            show(name, not frame.reward)
        end
        show("result", not frame.fighting and not frame.reward)
        show("resultPlate", not frame.fighting and not frame.reward)
        show("hero", frame.fighting)
    end
    local function playerHealthText(frame)
        local player, run = frame.player, frame.run
        return number(player and player.hp or run and run.hp or data.rules.player.maxHp)
            .. "/" .. number(run and run.maxHp or data.rules.player.maxHp)
    end
    local function renderPlayerTotals(frame)
        frame.player = frame.battle and frame.battle.player
        label("player", playerHealthText(frame))
        local player, run = frame.player, frame.run
        label("piles", number(player and player.gold or run and run.gold or 0))
    end
    local function stanceHeading(frame)
        local player, run = frame.player, frame.run
        if player and player.stance and
            (run and run.character == "watcher" or player.stanceKnown or player.stance ~= "Neutral") then
            return " · " .. stanceNames[player.stance]
        end
        return ""
    end
    local function orbHeading(frame)
        local battle, run = frame.battle, frame.run
        if battle and battle.orbs and
            (run and run.character == "defect" or battle.orbs.slots > 0 or #battle.orbs.balls > 0) then
            return " · 球 " .. #battle.orbs.balls .. "/" .. battle.orbs.slots
        end
        return ""
    end
    local function discardHeading(frame)
        local battle, run = frame.battle, frame.run
        if battle and run and run.characterProfile and run.characterProfile.id == "silent" then
            return " · 弃 " .. number(battle.discardedThisTurn or 0)
        end
        return ""
    end
    local function originalHeading(frame)
        if frame.battle and frame.battle.originalV4 then
            return " · " .. require("abyss_original_v4_data").rules.roles[frame.battle.originalV4.role].name
        end
        return ""
    end
    local function renderSceneHeading(frame)
        local flow = frame.run and frame.run.nodeFlow
        local kind = flow and ({elite = "精英战斗", boss = "首领战斗"})[flow.type] or "战斗"
        local heading = flow and flow.floor and ("第 " .. flow.floor .. " 层 · " .. kind) or kind
        label("title", heading .. stanceHeading(frame) .. orbHeading(frame) .. discardHeading(frame) .. originalHeading(frame))
    end
    local function renderEnergy(frame)
        local battle = frame.battle
        label("exhaust", battle and tostring(#battle.exhaust) or "0")
        label("energy", number(battle and battle.energy or 0) .. "/" .. number(data.rules.player.energyPerTurn))
        local charged = battle and battle.energy > 0
        tint(child("energyDisc"), charged and C.energy or C.energyEmpty)
        tint(child("energyIcon"):GetChild('core'), charged and C.geoDeep or C.energyEmpty)
        ink(child("energy"), charged and C.textOnLight or C.text)
    end
    local function renderPilesAndTurn(frame)
        local battle = frame.battle
        label("draw", battle and tostring(#battle.draw) or "0")
        label("discard", battle and tostring(#battle.discard) or "0")
        for _,kind in ipairs({'draw','discard','exhaust'})do
            local hit=child(kind..'Icon'):GetChild('hit')
            hit:SetVisible(frame.fighting==true)
            hit.raycastTarget=options.onPile~=nil and frame.active==true
        end
        label("statuses", frame.fighting and battle.phase ~= "player" and not self.busy and "敌方回合" or "")
        if frame.fighting then unit(child("hero"), frame.player, L.player.portrait, Theme.icon.player, L.hpBar.size[1], false) end
    end
    local function renderResult(frame)
        local run = frame.run
        if not run then label("result", "战斗演练\n点击启程，试用旅行者的初始牌组")
        elseif frame.reward then
            child("rewardStage"):GetChild("title").text = "选择一张卡牌"
            child("rewardStage"):GetChild("subtitle").text = "点击卡牌加入牌组，或跳过返回奖励列表"
        elseif run.phase == "defeat" then label("result", "旅途暂歇\n重新启程，重建牌组")
        elseif run.phase == "map" then label("result", "奖励已处理 · 牌组 " .. #run.deck .. " 张\n可再次挑战，检查新增卡牌") end
        ink(child("result"), run and run.phase == "defeat" and C.danger or C.goldBright)
    end
    local function pendingCardTarget(frame)
        if not frame.fighting or not self.selected then return false end
        for _, instance in ipairs(frame.battle.hand) do
            if instance.uid == self.selected then return needsTarget(frame.battle, instance) end
        end
        return false
    end
    local function enemyHighlighted(frame, enemy, index, pendingTarget)
        local targetable = frame.active and pendingTarget and Combat.canPlay(frame.battle, self.selected, index)
        if self.gesture and self.gesture.moving then
            local valid, hovered = dragTarget(self.gesture)
            targetable = valid and hovered == index
        end
        local potionTarget = self.potionAim ~= nil and not pendingTarget and Actors.isActive(enemy)
        return targetable == true or potionTarget or self.acting == enemy.id
    end
    local function enemyIntentFace(frame, enemy, index)
        local shown = playbackIntents and playbackIntents[enemy.id]
        local face = shown and Actors.isActive(enemy) and shown or intentView(frame.battle, index)
        local event = frame.enemyPlayback and self.feedback.current
        -- Cache the historical starting face, not an already-applied later frame.
        if event and event.kind == "intent" and event.detail.enemy == enemy.id then
            playbackIntents = playbackIntents or {}
            playbackIntents[enemy.id] = face
        elseif not Actors.isActive(enemy) and playbackIntents then
            playbackIntents[enemy.id] = nil
        end
        return face
    end
    local function renderEnemyIntent(box, face, portrait)
        local icons = IntentView.icons(face)
        local size, line = L.intent.size, L.nativeText.lineHeight
        local iconY = math.max(L.intent.offsetY, portrait / 2 + S.xs + line + size / 2)
        local pitch = size * 1.5
        for i, name in ipairs({'intentIcon','intentBadge','intentExtra'}) do
            local control, kind = box:GetChild(name), icons[i]
            control:SetVisible(kind ~= nil)
            control:SetSizeDelta(size, size)
            control:SetAnchoredPosition((i - (#icons + 1) / 2) * pitch, iconY)
            if kind then
                picture(control, Theme.icon.intent[kind] or Theme.icon.intent.unknown)
                tint(control, intentColors[kind] or C.goldDim)
            end
        end
        local attackLabel = box:GetChild('intent')
        attackLabel.text = face.value or ''
        attackLabel:SetVisible(icons[1] == 'attack' and attackLabel.text ~= '')
        attackLabel:SetAnchoredPosition((1 - (#icons + 1) / 2) * pitch + (L.intent.valueWidth - size) / 2,
            iconY - size / 2 - line / 2)
        ink(attackLabel, C.text)
        box:GetChild('intentLabel'):SetVisible(false)
        box:GetChild('intentHit'):SetAnchoredPosition(0, iconY - line / 2)
        box:GetChild('intentHit'):SetSizeDelta(#icons * pitch - size / 2, size + line)
    end
    local function enemyAimProjection(frame)
        local aimed = self.gesture or self.carry
        local projection = { pendingTarget = pendingCardTarget(frame) }
        if aimed and aimed.moving then projection.valid, projection.target = dragTarget(aimed) end
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
        local x, width, portrait = enemySlot(count, slot, enemy)
        box:SetAnchoredPosition(x, EnemyView.rowY(count, slot))
        local selected = enemyHighlighted(frame, enemy, entry.index, aim.pendingTarget)
        local loss = aim.losses and aim.losses[entry.index]
        if aim.valid and not aim.target and loss and loss.loss > 0 then selected = true end
        unit(box, enemy, portrait, enemyPortraitIcon(enemy), width, selected)
        local dim = (aim.pendingTarget or self.potionAim ~= nil) and not selected
        local portraitTone = C.text
        tint(box:GetChild('portrait'), { r = portraitTone.r, g = portraitTone.g, b = portraitTone.b, a = dim and 102 or 255 })
        renderDamagePreview(box, enemy, portrait, width, loss)
        renderEnemyIntent(box, enemyIntentFace(frame, enemy, entry.index), portrait)
    end
    local function renderEnemies(frame)
        local rows = frame.fighting and EnemyView.slots(frame.battle, self.busy and self.feedback or nil) or {}
        self.feedback.enemyRows = rows
        local aim = enemyAimProjection(frame)
        for i = 1, 5 do
            local box, entry = child('enemy' .. i), rows[i]
            self.feedback.bindEnemySlot(i, entry and entry.id)
            box:SetVisible(entry ~= nil)
            if entry then renderEnemySlot(frame, box, entry, i, #rows, aim) end
        end
    end
    local function renderDetails(frame)
        if self.info and (not self.active or self.busy or self.gesture or not frame.fighting
            or self.info.battle ~= frame.run.combat) then self.info = nil end
        renderInfo(frame.battle)
    end
    local function renderRewardActions(frame)
        local run, stolen = frame.run, frame.stolen
        button("skip", self.active and frame.picking == true and not run.rewards.cardResolved and not self.busy, false, "跳过")
        button("stolenGold", self.active and stolen and not stolen.claimed and not self.busy, false,
            stolen and (stolen.claimed and "已取回失金 " or "取回失金 ") .. number(stolen.amount) or "取回失金")
    end
    local function renderContinue(frame)
        local run = frame.run
        button("continue", self.active and run and (frame.manual or run.phase == "map") and not self.busy, true,
            frame.manual and "前往地图" or "再战一场")
    end
    local function bindPotionSlots(frame)
        if frame.fighting and not self.busy then
            self.potionBattle, self.potionRun, self.potionSlots = frame.battle, frame.run, {}
            for slot = 1, frame.potionCapacity do
                local id = frame.run.potions[slot]
                if id then self.potionSlots[slot] = {slot = slot, id = id} end
            end
        end
    end
    local function boundPotion(frame, index)
        local binding = self.potionSlots and self.potionSlots[index]
        local item = binding and frame.potions[binding.slot]
        if item and item.id ~= binding.id then return nil end
        return item
    end
    local function renderPotions(frame)
        -- Fixed physical slots prevent a queued second click moving to another item.
        bindPotionSlots(frame)
        for i = 1, L.battlePotions.count do
            local visible = frame.fighting and i <= frame.potionCapacity
            show("potion" .. i, visible)
            local item = boundPotion(frame, i)
            button("potion" .. i, visible and frame.active and item and item.canUse, false,
                item and potionText(item, frame.battle) or "空药水槽")
            show("potionHelp" .. i, visible)
            button("potionHelp" .. i, visible and frame.active and item ~= nil, false, "")
            for _,state in ipairs({'normal','hover','pressed','disabled'}) do
                local bottle=child('potionHelp'..i):GetChild(state):GetChild('bottle')
                bottle:SetVisible(item~=nil)
                if item then picture(bottle,Theme.icon.potion[item.id] or Theme.icon.intent.unknown) end
            end
        end
    end
    function self:render(presentationOnly)
        local run = prepareRenderInputs(self, presentationOnly)
        if not renderFeedbackReady(run) then return end
        syncRenderIdentity(run)
        local frame = renderFrame(run)
        syncRewardOwner(frame)
        syncRewardEntrance(frame)
        prepareRenderPotions(frame)
        renderStartControls(frame)
        rewardNavigation(frame)
        renderRewardRows(frame)
        renderRewardButtons(frame)
        renderPotionReward(frame)
        renderRewardStage(frame)
        renderPlayArea(frame)
        renderHudVisibility(frame)
        renderPlayerTotals(frame)
        renderSceneHeading(frame)
        renderEnergy(frame)
        renderPilesAndTurn(frame)
        renderResult(frame)
        renderEnemies(frame)
        local playable = cardView.renderCards(data, presentation, frame.battle, frame.fighting, frame.active, frame.reward, frame.picking)
        cardView.renderDrag()
        renderDetails(frame)
        button("endTurn", frame.active == true, not playable)
        renderRewardActions(frame)
        renderContinue(frame)
        renderPotions(frame)
    end
    local function refresh(changed)
        if self.run and self.run.phase == "combat" then
            local battle, found = self.run.combat, false
            if not battle.enemies[self.target] or not Actors.isActive(battle.enemies[self.target]) then
                for i, enemy in ipairs(battle.enemies) do if Actors.isActive(enemy) then self.target = i break end end
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
        self.feedback:setFastMode(self.fastMode==true)
        self.feedback:begin(before, battle, first, presentation, origin)
        return ok, reason
    end
    function self:chooseCards(kind, uids, token, generation,battle)
        if self.busy or not self.run or self.run.phase~="combat" then return false, "not_in_combat" end
        local command = kind=="discard" and Run.chooseDiscard or kind=="scry" and Run.chooseScry
            or kind=="hand" and Run.chooseHand or kind=='pile' and Run.choosePile or kind=='potion'and Run.choosePotionStance
        if not command then return false, "invalid_choice_kind" end
        return perform(function() return command(self.run,uids,token,generation,battle) end)
    end
    local updateCarry
    local function helpContextChanged(help)
        local current = self.run and self.run.combat
        local actor = current and (help.spec.index == 0 and current.player or current.enemies[help.spec.index])
        return not self.active or self.busy or self.run ~= help.run or current ~= help.battle
            or current.turn ~= help.turn or actor ~= help.actor or not Actors.isPresent(actor)
            or help.spec.screenSlot and not sameEnemySlot(help.spec.screenSlot,actor,current)
    end
    local function helpPointerChanged(help)
        return self.gesture and self.gesture.moving
            or help.card and (help.card.input.held ~= help.card or not cardReady(help.card))
    end
    local function fireHelp(help, dt)
        help.t = help.t + dt
        if help.t + 0.000001 >= L.statusInfo.delay then
            help.fired = true
            if help.held and help.spec.kind == "card" then
                self.gesture = nil
                cancelCardInputs()
                self.suppressClick = true
            end
            self:openHelp(help.spec, help.source, true)
        end
    end
    local function updateHelp(dt)
        local help = self.help
        if not help then return end
        if helpContextChanged(help) or helpPointerChanged(help) then self.help = nil
        elseif help.spec.kind == "potion" and (self.run.potions ~= help.spec.inventory
            or self.run.potions[help.spec.slot] ~= help.spec.potionId) then self.help = nil
        elseif not help.fired then fireHelp(help, dt) end
    end
    local function animateRewardCards(view, dt)
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
        return moving
    end
    local function updateRewardCards(dt)
        local view = self.rewardView
        if view and self.active and not self.busy and self.run and self.run.phase == "reward" and view.rewards == self.run.rewards then
            if animateRewardCards(view, dt) then self:render(true) end
        end
    end
    function self:update(dt)
        if self.gesture then self.gesture.elapsed = (self.gesture.elapsed or 0) + dt end
        if updateCarry then updateCarry() end
        if self.potionAim and not aimReady(self.potionAim) then self:render() end
        updateHelp(dt)
        if self.feedbackRun and (self.feedbackRun ~= self.run or self.feedbackBattle ~= (self.run and self.run.combat)) then
            self.feedback:cancel()
            self.feedbackRun, self.feedbackBattle = nil, nil
            self:render() return
        end
        self.feedback:update(dt)
        updateRewardCards(dt)
        cardView.update(dt)
    end
    function self:setActive(active)
        assert(type(active) == "boolean", "active must be boolean")
        self.active = active
        if not active then self.help=nil;cancelPotionAim("已取消药水瞄准。") end
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
        if not self.active or not self.selected or self.busy or self.gesture or not self.run or self.run.phase ~= "combat" then return end
        local uid, origin = self.selected, self.cardPositions[self.selected]
        local ok, reason = perform(function() return Run.play(self.run, uid, target) end, origin)
        if ok then self.selected = nil end
        notice(ok and "" or reasons[reason] or "当前无法使用这张牌。")
        if reason ~= "presentation_unavailable" then refresh() end
    end
    function self:chooseCard(token,uid)
        if self.busy or not self.run or self.run.phase~="combat" then return false end
        local ok,reason=perform(function() return Run.chooseCard(self.run,token,uid) end)
        notice(ok and "" or reasons[reason] or "这次选牌已失效。")
        refresh()
        return ok,reason
    end
    local function claimCard(index, run)
        if self.rewardScreen ~= "cards" then return end
        local ok, reason = Run.claimCardReward(run, index)
        if ok then
            -- Adopt the committed rewards object before local feedback; an
            -- unrelated replacement still resets the page on the next render.
            self.rewardOwner, self.rewardRun = run.rewards, run
            rewardScreen("list")
        end
        notice(ok and "卡牌已加入牌组。" or reasons[reason] or "当前无法领取奖励。")
        refresh(ok)
    end
    local function selectCombatCard(index, run)
        cancelPotionAim("已取消药水瞄准。")
        local instance = run.combat.hand[index]
        if not instance then return end
        self.selectionEpoch = (self.selectionEpoch or 0) + 1
        if self.selected == instance.uid then self.selected = nil notice("") refresh() return end
        local ok, reason = Combat.canPlay(run.combat, instance.uid, self.target)
        if not ok then notice(reasons[reason] or "当前无法使用这张牌。") refresh() return end
        self.selected = instance.uid
        notice(Controller.isController(platform.controller)
            and (needsTarget(run.combat,instance) and "摇杆选择敌人 · 确认出牌 · 返回取消" or "确认出牌 · 返回取消")
            or (needsTarget(run.combat,instance) and "点选一个敌人；再点原牌取消" or "点击战场出牌区域；再点原牌取消"))
        refresh()
    end
    function self:playSlot(index)
        local run = self.run
        if not self.active or not run or self.busy or self.gesture or self.suppressClick then return end
        if run.phase == "reward" then return claimCard(index, run)
        elseif run.phase == "combat" then return selectCombatCard(index, run) end
        refresh()
    end
    function self:endTurn()
        if not self.active or not self.run or self.busy or self.gesture or self.suppressClick or self.run.phase ~= "combat" or self.run.combat.phase ~= "player" then return end
        self.selected = nil
        perform(function() return Run.endTurn(self.run) end)
    end
    local function potionBinding(index)
        local binding = self.potionSlots and self.potionSlots[index]
        if not binding or self.potionRun ~= self.run or self.potionBattle ~= self.run.combat
            or self.run.potions[binding.slot] ~= binding.id then return end
        return binding
    end
    local function beginPotionAim(binding, item)
        self.selected = nil
        self.selectionEpoch = (self.selectionEpoch or 0) + 1
        cancelCardInputs()
        cancelActionInputs()
        local battle = self.run.combat
        local aim = {run=self.run,battle=battle,turn=battle.turn,inventory=self.run.potions,
            slot=binding.slot,id=binding.id,actors={},living={}}
        for i, actor in ipairs(battle.enemies) do aim.actors[i],aim.living[i]=actor,Actors.isActive(actor) end
        self.potionAim = aim
        notice(item.name .. (Controller.isController(platform.controller)
            and " · 摇杆选择敌人 · 确认使用 · 返回取消"
            or " · 对一名敌人：点击敌人使用；再点药水或空白取消；点说明查看效果。"))
        refresh()
        return true
    end
    function self:usePotion(index)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        local binding = potionBinding(index)
        if not binding then return false end
        local item = Run.potionView(self.run)[binding.slot]
        if not item or not item.canUse then notice(reasons[item and item.reason] or "当前无法使用此药水。") return false end
        local previous = self.potionAim
        cancelPotionAim()
        if previous and previous.slot == binding.slot then notice("已取消药水瞄准。") refresh() return true end
        if item.targetPolicy == "enemy_one" then return beginPotionAim(binding, item) end
        return self:commitPotion(binding.slot, nil)
    end
    local function potionTargetReady(slot, target)
        local aim = self.potionAim
        return not target or aim and aim.slot == slot and aimReady(aim)
    end
    function self:commitPotion(slot, target)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        if not potionTargetReady(slot, target) then
            cancelPotionAim("药水瞄准已失效，已取消。") refresh() return false
        end
        cancelPotionAim()
        local ok, reason = perform(function() return Run.usePotion(self.run, slot, target) end)
        if ok then
            self.potionSlots[slot] = nil
        end
        notice(ok and "药水已生效。" or reasons[reason] or "当前无法使用此药水。")
        if reason ~= "presentation_unavailable" then refresh() end
        return ok, reason
    end
    local function potionRewardNotice(ok, reason, claim)
        if not ok then return reasons[reason] or "当前无法处理药水。" end
        if reason == "potion_blocked_by_sozu" then return "遗物阻止获得药水。" end
        return claim and "药水已放入背包。" or "已放弃药水。"
    end
    local function processPotionReward(claim)
        if not self.active or not self.run or self.busy or self.gesture or self.suppressClick then return false end
        if self.rewardScreen ~= "list" then return false end
        local ok,reason=(claim and Run.claimPotionReward or Run.skipPotionReward)(self.run)
        notice(potionRewardNotice(ok, reason, claim))
        refresh(ok)
        return ok,reason
    end
    function self:claimPotionReward() return processPotionReward(true) end
    function self:skipPotionReward() return processPotionReward(false) end
    local function point(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local x,y = event:GetUIPos()
        -- Keep unavailable coordinates compatible, but let field taps reject explicit bad numbers.
        if type(x) == "number" and (x ~= x or math.abs(x) == math.huge)
            or type(y) == "number" and (y ~= y or math.abs(y) == math.huge) then return nil,nil,true end
        if type(x) ~= "number" or type(y) ~= "number" then return end
        local width,height = self.canvasWidth or Theme.canvas.base[1],self.canvasHeight or Theme.canvas.base[2]
        local k = math.min(width/Theme.canvas.base[1],height/Theme.canvas.base[2])
        return (x-width/2)/k,(y-height/2)/k
    end
    -- An open detail panel owns the next pointer sequence: its Down closes the panel and
    -- the matching Click is swallowed, so no card, target or button acts underneath it.
    local function retireInterruptedPress(event)
        local g = self.gesture
        if not g or g.touch ~= (event and event.touchId) then return false end
        -- Another Down from the same pointer starts a new physical sequence.
        -- Its previous Up may have been lost outside the native hit surface.
        -- A different touch must never steal a live drag.
        g.input.held, g.input.released = nil, nil
        self.gesture, self.carry, self.selected = nil, nil, nil
        self.hover, self.handHover, self.help = nil, nil, nil
        self.suppressClick = true
        if g.moving then cardView.renderDrag() end
        return true
    end
    local function down(event)
        retireInterruptedPress(event)
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
    local function move(event, input)
        local g = self.gesture
        if not g or not event or event.touchId ~= g.touch then return end
        -- A reused touch ID does not transfer ownership between card controls.
        -- The overlay may continue only the current held gesture and card UID.
        if input and input ~= g.input or g.input.held ~= g or not cardReady(g) then return end
        local x,y = point(event)
        if not x then return end
        g.x,g.y = x,y
        if (x-g.sx)^2+(y-g.sy)^2 >= L.cardDrag.threshold^2 then g.moving = true end
        if g.moving then
            self.suppressClick,self.selected = true,g.uid
            local valid, target, aiming = dragTarget(g)
            if g.cancelled then
                g.input.held, g.input.released = nil, nil
                self.gesture, self.selected, self.hover, self.handHover = nil, nil, nil, nil
                self:render(); return
            end
            if g.drawnValid ~= valid or g.drawnTarget ~= target or g.drawnAiming ~= aiming then
                self:render()
            else
                cardView.renderDrag(valid, target, aiming, true)
            end
        end
    end
    updateCarry = function()
        local g = self.carry
        if not g then return end
        if not cardReady(g) or self.selected ~= g.uid then self:render(); return end
        if not platform.cursorPosition or g.touchScreen then return end
        local x,y = point({GetUIPos=platform.cursorPosition})
        if not x or x == g.x and y == g.y then return end
        g.x,g.y = x,y
        local valid,target,aiming = dragTarget(g)
        if g.cancelled then
            self.carry,self.selected,self.hover,self.handHover = nil,nil,nil,nil
            self:render()
        elseif g.drawnValid ~= valid or g.drawnTarget ~= target or g.drawnAiming ~= aiming then
            self:render()
        else cardView.renderDrag(valid,target,aiming,true) end
    end
    local function releaseCardTap(event, input, ended)
        local touch = event and event.touchId
        -- Missing/invalid coordinates disable dragging, not ordinary C-mode.
        local held = input and input.held
        if held and held.touch == touch then
            if self.help and self.help.card == held then self.help = nil end
            input.held = nil
            input.released = not ended and cardReady(held) and held or nil
        elseif ended and input and input.released and input.released.touch == touch then
            input.released = nil
        end
    end
    local function finishCardRelease(g, event, ended)
        local x = point(event)
        local valid,target = false,nil
        if x and g.moving then valid,target = dragTarget(g) end
        self.gesture = nil -- consume before invoking the command or any rendering callback
        if not g.moving then
            g.input.released = not ended and g or nil
            return
        end
        g.input.released = nil
        local action = x and CardInput.release(g, valid) or 'cancel'
        self.carry = (action == 'target' or action == 'carry') and g or nil
        self.suppressClick,self.selected = true,action ~= 'cancel' and g.uid or nil
        self:render()
        if action == 'play' then self:playSelected(target)
        else notice("") end
    end
    local function release(event, input, ended)
        local g = self.gesture
        local touch = event and event.touchId
        if not g then releaseCardTap(event, input, ended) return end
        if touch ~= g.touch or input and input ~= g.input then return end
        if self.help and self.help.card == g then self.help = nil end
        -- Stationary taps must keep their binding through Up until Click, too.
        if not cardReady(g) then
            g.input.held = nil
            g.input.released = nil
            self.gesture, self.selected, self.suppressClick = nil, nil, true
            self:render()
            return
        end
        move(event, input)
        g.input.held = nil
        -- move/render may have cancelled a gesture belonging to an old battle.
        if self.gesture ~= g then return end
        finishCardRelease(g, event, ended)
    end
    local controller=platform.controller
    function self.cancelControllerPointers(_)
        cancelCardInputs();cancelActionInputs();cancelPotionInputs()
        for _,input in ipairs(enemyInputs)do input.held,input.released=nil,nil end
    end
    local function controllerReady()
        return self.active and not self.busy and not self.gesture and self.run
            and (self.run.phase=="reward" or self.run.phase=="combat" and self.run.combat.phase=="player")
    end
    function self.controllerBack(_)
        if closeInfo() then self:render();return true end
        if self.selected or self.potionAim then
            cancelPotionAim();self.selected,self.carry,self.hover=nil,nil,nil;self.suppressClick=false
            self.selectionEpoch=(self.selectionEpoch or 0)+1
            cancelCardInputs();cancelActionInputs();refresh()
            return true
        end
        if self.run and self.run.phase=="reward" and self.rewardScreen=="cards" then
            rewardScreen("list");refresh();return true
        end
        return false
    end
    local function listen(control, fn, input)
        if controller and not input then
            Controller.bind(controller,control,control.parent.name=="statusInfo" and "battleInfo" or "battle",fn,
                function()return self.active and not self.busy end)
        end
        control:AddCursorEventListener(clickEvent,function(event)
            if Controller.pointerBlocked(controller)then return false end
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
    local function actionToken(name, event)
        local run = self.run
        local battle = run and run.combat
        local g = {name = name, run = run, phase = run and run.phase,
            uid = self.selected, selectionEpoch = self.selectionEpoch,
            battle = battle, turn = battle and battle.turn, touch = event and event.touchId}
        RewardOwner.capture(g, self, run)
        if name == "playArea" and battle then
            g.aim = self.potionAim
            g.x, g.y, g.invalidPoint = point(event)
            for i, instance in ipairs(battle.hand) do if instance.uid == self.selected then g.slot = i break end end
        end
        return g
    end
    local function fieldReleaseValid(name, held, event)
        local x, y, invalidPoint = point(event)
        return name ~= "playArea" or not invalidPoint and (not x or inPlayArea(x, y)
            and (not held.x or (x-held.x)^2+(y-held.y)^2 < D.threshold^2))
    end
    local function bind(name, fn)
        local control, input = child(name), {}
        if name == "playArea" then control = control:GetChild("hit") end
        actionInputs[#actionInputs + 1] = input
        Controller.bind(controller,control,name=="playArea" and "aim" or "battle",function()
            self.suppressClick=false;return fn()
        end,function()
            if not controllerReady()then return false end
            if name~="playArea"then return true end
            if self.potionAim or not self.selected or self.run.phase~="combat"then return false end
            for _,card in ipairs(self.run.combat.hand)do
                if card.uid==self.selected then return not needsTarget(self.run.combat,card)end
            end
            return false
        end,name=="endTurn" and 90 or 50)
        control:AddCursorEventListener(clickEvent, function(event)
            if Controller.pointerBlocked(controller)then return false end
            if swallowed(event) then return end
            if name == "playArea" and fieldPointerObserved or name ~= "playArea" and actionPointerObserved then
                local released = input.released
                if not released or released.touch ~= (event and event.touchId) then return end
                input.released = nil
                if not actionReady(released) then return end
            end
            if not self.suppressClick and not self.gesture then return fn(event) end
        end)
        if self.dragEnabled then
            control:AddCursorEventListener(cursor.CursorDown, function(event)
                if name == "playArea" then fieldPointerObserved = true else actionPointerObserved = true end
                local dismissed = down(event)
                input.held, input.released = nil, nil
                if dismissed then return end
                local g = actionToken(name, event)
                if not g.invalidPoint and actionReady(g) then input.held = g end
            end)
            local function releaseAction(event, ended)
                local touch, held = event and event.touchId, input.held
                if held and held.touch == touch then
                    input.held = nil
                    local fieldValid = fieldReleaseValid(name, held, event)
                    input.released = not ended and fieldValid and actionReady(held) and held or nil
                elseif ended and input.released and input.released.touch == touch then
                    input.released = nil
                end
            end
            control:AddCursorEventListener(cursor.CursorUp, releaseAction)
            control:AddCursorEventListener(cursor.CursorEndDrag, function(event) releaseAction(event, true) end)
            if name == "playArea" then
                control:AddCursorEventListener(cursor.CursorDrag, function(event)
                    local held = input.held
                    if not held or held.touch ~= (event and event.touchId) then return end
                    local x,y = point(event)
                    if not x or not held.x or (x-held.x)^2+(y-held.y)^2 >= D.threshold^2 then
                        input.held, input.released = nil, nil
                    end
                end)
            end
        end
    end
    bind("start", function() if not self.run or self.run.phase == "defeat" then self:start() end end)
    bind("endTurn", function() self:endTurn() end)
    bind("playArea", function()
        if cancelPotionAim("已取消药水瞄准。") then refresh() return end
        local battle = self.run and self.run.phase == "combat" and self.run.combat
        if not battle then return end
        for _,instance in ipairs(battle.hand) do
            if instance.uid == self.selected and not needsTarget(battle,instance) then self:playSelected(nil) return end
        end
    end)
    bind("skip", function()
        if not self.active or not self.run or self.busy or self.run.phase ~= "reward" or self.rewardScreen ~= "cards" then return end
        -- PC SkipCardButton closes the picker; the unclaimed CARD row remains.
        rewardScreen("list")
        notice("")
        refresh()
    end)
    bind("cardReward", function()
        if not self.active or self.busy or not self.run or self.run.phase ~= "reward"
            or self.rewardScreen ~= "list" or self.run.rewards.cardResolved then return end
        rewardScreen("cards")
        notice("")
        refresh()
    end)
    bind("goldReward", function()
        if not self.active or self.busy or self.rewardScreen ~= "list" or not self.run then return end
        local ok = Run.claimGoldReward(self.run)
        if ok then notice("金币已领取。") refresh(true) end
    end)
    bind('emeraldKeyReward',function()
        if not self.active or self.busy or self.rewardScreen~='list' or not self.run then return false end
        local ok,why=Run.claimEmeraldKey(self.run)
        if ok then notice('已获得绿钥匙。');refresh(true)end
        return ok,why
    end)
    for i=1,2 do
        local slot=i
        bind('relicReward'..slot,function()
            if not self.active or self.busy or self.rewardScreen~='list' or not self.run then return false end
            local ok,why=Run.claimRelicReward(self.run,slot)
            if ok then notice('已获得遗物。');refresh(true)end
            return ok,why
        end)
    end
    bind("claimPotion", function() return self:claimPotionReward() end)
    bind("stolenGold", function()
        if self.active and self.run and not self.busy and self.rewardScreen == "list"
            and Run.claimStolenGoldReward(self.run) then notice("已取回失金。") refresh(true) end
    end)
    bind("continue", function()
        if not self.active or self.busy or not self.run then return end
        if self.run.phase == "reward" then
            if self.rewardScreen ~= "list" then return end
            local ok,reason=Run.leaveCombatRewards(self.run)
            if not ok then notice(reasons[reason] or "当前无法离开奖励。") end
            refresh(ok)
        elseif not options.embedded and self.run.phase == "map" then assert(Run.startCombat(self.run, "cultist_solo")) refresh(true) end
    end)
    local function bindPotionControls()
        for i = 1, L.battlePotions.count do
            local slot, control, input = i, child("potion" .. i), {}
            potionInputs[i] = input
            Controller.bind(controller,control,"battle",function()
                self.suppressClick=false;return self:usePotion(slot)
            end,controllerReady,30+slot,"potions")
            control:AddCursorEventListener(clickEvent, function(event)
                if Controller.pointerBlocked(controller)then return false end
                if input.consumed and input.consumed.touch == (event and event.touchId) then input.consumed=nil return end
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
                    input.held, input.released, input.consumed = nil, nil, nil
                    if dismissed or self.gesture or not self.run then return end
                    local run, binding = self.run, self.potionSlots and self.potionSlots[slot]
                    if not binding or self.potionRun ~= run or self.potionBattle ~= run.combat then return end
                    local g = {slot = binding.slot, id = binding.id, inventory = run.potions,
                        run = run, battle = run.combat, turn = run.combat and run.combat.turn,
                        touch = event and event.touchId}
                    if potionReady(g) then input.held = g; self:queueHelp(self:potionHelpSpec(slot),control,true,g.touch) end
                end)
                local function releasePotion(event, ended)
                    local touch, held = event and event.touchId, input.held
                    if held and held.touch == touch then
                        input.held = nil
                        input.released = not ended and potionReady(held) and held or nil
                        if self.help and self.help.source == control then
                            if self.help.fired then
                                input.released = nil
                                input.consumed = {touch=touch}
                                if self.info then self.info.transient=false; self:render() end
                            end
                            self.help = nil
                        end
                    elseif ended and input.released and input.released.touch == touch then
                        input.released = nil
                    end
                end
                control:AddCursorEventListener(cursor.CursorUp, releasePotion)
                control:AddCursorEventListener(cursor.CursorEndDrag, function(event) releasePotion(event, true) end)
            end
        end
    end
    bindPotionControls()
    local function cardToken(slot, input, event)
        local run, battle = self.run, self.run.combat
        local instance = run.phase == "combat" and battle.hand[slot]
        local uid = instance and instance.uid or run.phase == "reward" and Run.rewardOptions(run)[slot]
        if not uid then return end
        local g = {uid=uid,slot=slot,run=run,battle=battle,turn=battle and battle.turn,
            phase=run.phase,touch=event and event.touchId,input=input}
        RewardOwner.capture(g, self, run)
        return g, instance, battle
    end
    local function beginCardDrag(g, instance, battle, event)
        local x, y = point(event)
        if not instance or not x then return end
        local ok, reason = Combat.canPlay(battle, instance.uid, nil)
        if not ok and reason ~= "invalid_target" then return end
        g.sx, g.sy, g.x, g.y, g.origin = x, y, x, y, self.cardPositions[instance.uid]
        CardInput.begin(g, Theme.canvas.base[2], platform.touchScreen and platform.touchScreen(), Theme.canvas.base[1])
        g.handCancelY = L.hand.y + Theme.motion.hoverLift
        self.hover, self.handHover = nil, nil
        self.carry = nil
        self.gesture = g
    end
    local function bindCardControls()
        for i = 1, 10 do
            local slot,hit = i,child("card" .. i):GetChild("hit")
            local input = {}
            cardInputs[i] = input
            Controller.bind(controller,hit,"battle",function()
                self.suppressClick=false;self:playSlot(slot);return true
            end,controllerReady,slot,"hand",function()self:setHover(slot)end)
            if controller and controller.api.events.LostFocus then
                hit:AddNavigationEventListener(controller.api.events.LostFocus,function()
                    if self.hover==slot then self:setHover(nil)end
                end)
            end
            listen(hit,function() self:playSlot(slot) end,input)
            if self.dragEnabled then
                hit:AddCursorEventListener(cursor.CursorDown,function(event)
                    pointerObserved = true
                    retireInterruptedPress(event)
                    if self.gesture then return end
                    local dismissed = down(event)
                    input.held, input.released = nil, nil
                    if dismissed or not self.active or self.busy or not self.run then return end
                    local g, instance, battle = cardToken(slot, input, event)
                    if not g then return end
                    input.held = g
                    cancelPotionAim("已取消药水瞄准。")
                    self:queueHelp(self:cardHelpSpec(slot),hit,true,event and event.touchId,g)
                    beginCardDrag(g, instance, battle, event)
                end)
                hit:AddCursorEventListener(cursor.CursorDrag,function(event) move(event,input) end)
                hit:AddCursorEventListener(cursor.CursorUp,function(event) release(event,input) end)
                hit:AddCursorEventListener(cursor.CursorEndDrag,function(event) release(event,input,true) end)
            end
        end
        if self.dragEnabled then
            local layer = child("dragLayer")
            layer.disableCursorEventPassthrough = true
            local hit = layer:GetChild("hit")
            -- Do not replay this press onto whatever was under the old drag.
            -- Retire its capture only; a subsequent deliberate click owns input.
            hit:AddCursorEventListener(cursor.CursorDown,retireInterruptedPress)
            hit:AddCursorEventListener(cursor.CursorDrag,move)
            hit:AddCursorEventListener(cursor.CursorUp,release)
            hit:AddCursorEventListener(cursor.CursorEndDrag,function(event) release(event,nil,true) end)
        end
    end
    bindCardControls()
    local function bindEnemyControls()
        for i = 1, 5 do
            local screenSlot, control, input = i, child("enemy" .. i):GetChild("hit"), {}
            enemyInputs[i] = input
            local function chooseEnemy()
            local entry=enemyAt(screenSlot)
            if not entry then return false end
            local target=entry.index
            if self.potionAim then
                local slot = self.potionAim.slot
                self.target = target
                return self:commitPotion(slot, target)
            end
            if self.active and self.run and not self.busy and self.run.phase == "combat" and self.run.combat.enemies[target] and Actors.isActive(self.run.combat.enemies[target]) then
                self.target = target
                local selected
                for _, instance in ipairs(self.run.combat.hand) do
                    if instance.uid == self.selected then selected = instance break end
                end
                if selected and needsTarget(self.run.combat, selected) then self:playSelected(target)
                else
                    local prefix = self.potionTargetAvailable and "药水目标：" .. self.run.combat.enemies[target].name .. "；" or ""
                    notice(prefix .. "意图：" .. intentView(self.run.combat, target).text) refresh()
                end
            end
            end
            Controller.bind(controller,control,function()
                local selected
                if self.run and self.run.combat then
                    for _,card in ipairs(self.run.combat.hand)do if card.uid==self.selected then selected=card end end
                end
                return (self.potionAim or selected and needsTarget(self.run.combat,selected)) and "aim" or "battle"
            end,function()self.suppressClick=false;return chooseEnemy()end,function()
                local entry=enemyAt(screenSlot)
                return controllerReady() and self.run.phase=="combat" and entry and Actors.isActive(entry.actor)
            end,screenSlot,"enemies",function()
                local entry=enemyAt(screenSlot)
                if entry then self.target=entry.index;self:render()end
            end)
            control:AddCursorEventListener(clickEvent, function(event)
                if Controller.pointerBlocked(controller)then return false end
                if swallowed(event) then
                    -- Dismissal consumes this pointer too, but cannot consume a
                    -- newer token owned by a different touch on the same actor.
                    discardEnemyPointer(input,event)
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
                    local entry=enemyAt(screenSlot,battle)
                    local actor=entry and entry.actor
                    if not actor then return end
                    local g = {slot=entry.index,screenSlot=screenSlot, actor=actor, run=run, battle=battle,
                        uid=self.selected, selectionEpoch=self.selectionEpoch,aim=self.potionAim,
                        turn=battle.turn, touch=event and event.touchId}
                    if enemyReady(g) then input.held = g end
                end)
                local function releaseEnemy(event, ended)
                    enemyPointerObserved = true
                    local touch, held = event and event.touchId, input.held
                    if held and held.touch == touch then
                        input.held = nil
                        input.released = not ended and enemyReady(held) and held or nil
                        if ended and cancelPotionAim("已取消药水瞄准。") then self:render() end
                    elseif ended and input.released and input.released.touch == touch then
                        input.released = nil
                        if cancelPotionAim("已取消药水瞄准。") then self:render() end
                    end
                end
                control:AddCursorEventListener(cursor.CursorUp, releaseEnemy)
                control:AddCursorEventListener(cursor.CursorEndDrag, function(event) releaseEnemy(event, true) end)
            end
        end
    end
    bindEnemyControls()
    local function helpActorReady(token,run)
        local spec=token.spec
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        return actor==token.actor and Actors.isPresent(token.actor)
            and (not spec.screenSlot or sameEnemySlot(spec.screenSlot,token.actor,run.combat))
    end
    local function statusActorAt(slot)
        local battle=self.run and self.run.combat
        if not battle then return end
        if slot==0 then return battle,0,battle.player end
        local entry=enemyAt(slot,battle)
        if entry then return battle,entry.index,entry.actor end
    end
    local function bindDetailControls()
        -- Enemy portraits keep targeting; the hero portrait and every status row only open
        -- details, so a status tap never plays a card or moves the potion target.
        listen(child("hero"):GetChild("hit"), function() self:showStatus(0) end)
        for i, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
            local screenSlot = i - 1
            listen(child(name):GetChild("statusRow"):GetChild("hit"), function()
                local entry=screenSlot>0 and enemyAt(screenSlot)
                if screenSlot==0 or entry then self:showStatus(entry and entry.index or 0) end
            end)
        end
        local info = child("statusInfo")
        info.disableCursorEventPassthrough = true
        listen(info:GetChild("hit"), function() if closeInfo() then self:render() end end)
        -- A tap on the card itself turns to the next page; a single page closes like any tap.
        -- Not routed through listen(): that dismisses the open card before any handler runs.
        local function infoPage()
            local open = self.info
            if not open then return end
            self.swallow = nil
            if (open.pages or 1) > 1 then open.page = open.page % open.pages + 1 self:render()
            elseif closeInfo() then self:render() end
        end
        info:GetChild("page"):AddCursorEventListener(clickEvent,function()
            if Controller.pointerBlocked(controller)then return false end
            return infoPage()
        end)
        Controller.bind(controller,info:GetChild("page"),"battleInfo",infoPage,nil,1)
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
            Controller.bind(controller,control,function()return self.potionAim and "aim" or "battle"end,function()
                local spec=describe()
                if spec then return self:openHelp(spec,control,false)end
            end,controllerReady,80)
            local function ready(token)
                local run=self.run
                return token and self.active and not self.busy and not self.gesture and run==token.run
                    and run.phase=="combat" and run.combat==token.battle and run.combat.turn==token.turn
                    and helpActorReady(token,run)
                    and (token.spec.kind~="potion" or run.potions==token.spec.inventory and run.potions[token.spec.slot]==token.spec.potionId)
            end
            control:AddCursorEventListener(clickEvent,function(event)
                if Controller.pointerBlocked(controller)then return false end
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
            local screenSlot=i-1
            if screenSlot>0 then bindHelp(child(name):GetChild("intentHit"),function()
                local entry=enemyAt(screenSlot)
                return entry and {kind="intent",index=entry.index,screenSlot=screenSlot}
            end,true) end
            for slot=1,L.statusIcon.perRow*L.statusIcon.rows do
                local position=slot
                bindHelp(child(name):GetChild("statusRow"):GetChild("hit"..slot),function()
                    local battle,index,actor=statusActorAt(screenSlot)
                    if not Actors.isPresent(actor)then return end
                    local entries=Combat.statusView(actor)
                    local width=index==0 and L.hpBar.size[1] or select(2,enemyPosition(battle,index))
                    local perRow=math.max(1,math.min(L.statusIcon.perRow,math.floor((width+L.statusIcon.gap)/(L.statusIcon.size+L.statusIcon.gap))))
                    local slots=perRow*L.statusIcon.rows
                    if not entries[position] then return end
                    local overflow=position==slots and #entries>slots
                    return {index=index,screenSlot=screenSlot>0 and screenSlot or nil,statusId=not overflow and entries[position].id or nil,
                        offset=overflow and position or nil}
                end,true)
            end
        end
        for slot=1,10 do
            local index=slot
            bindHelp(child("card"..slot):GetChild("hit"),function() return self:cardHelpSpec(index) end,false,slot)
        end
        for slot=1,L.battlePotions.count do
            local index=slot
            bindHelp(child("potionHelp"..slot),function() return self:potionHelpSpec(index) end,true)
            bindHelp(child("potion"..slot),function() return self:potionHelpSpec(index) end,false)
        end
    end
    bindDetailControls()
    for _,kind in ipairs({'draw','discard','exhaust'})do
        local hit=child(kind..'Icon'):GetChild('hit')
        local function available()
            return options.onPile~=nil and self.active and not self.busy and not self.gesture and not self.carry
                and self.run and self.run.phase=='combat' and self.run.combat.phase=='player'
        end
        local function openPile()
            if available()then return options.onPile(kind)end
            return false
        end
        hit:AddCursorEventListener(clickEvent,function()
            if Controller.pointerBlocked(controller)then return false end
            return openPile()
        end)
        Controller.bind(controller,hit,'battle',openPile,available,80)
    end
    local keys = platform.keyEvents
    if keys and keys.KeyboardSprintKeyDown and root.AddKeyEventListener then
        -- The official UI maps SprintKey to the user's right-mouse binding.
        root:AddKeyEventListener(keys.KeyboardSprintKeyDown, function()
            if not self.active or not (self.gesture or self.carry or self.selected) then return false end
            cancelCardInputs()
            self.gesture,self.carry,self.selected,self.hover = nil,nil,nil,nil
            self.suppressClick = true
            self:render()
            return true
        end)
    end
    refresh()
    return self
end
return M
