-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local Events = require("abyss_events")
local Controller = require("abyss_controller")
local RewardOwner = require("abyss_battle_reward_owner")
local M = {}
local L = Theme.layout
local reasons = { insufficient_energy = "能量不足", invalid_target = "请选择存活的敌人", card_content_unavailable = "此卡牌尚未实装，可选择其他卡牌或跳过。",
    card_not_in_hand = "这张牌已离开手牌", not_player_turn = "敌方行动中",
    normality_limit = "平庸：本回合已打出三张牌",
    advanced_card_not_enabled = "此牌效果尚未接入", not_in_combat = "战斗已经结束",
    empty_potion_slot = "此药水已使用", invalid_potion_slot = "请选择有效药水",
    smoke_not_allowed = '此战斗不能使用烟雾弹',
    effect_overflow = "当前状态已达上限", potion_slots_full = "药水槽已满，请先丢弃旧药水。",
    potion_content_unavailable = "该稀有度药水尚未实装。", potion_blocked_by_sozu = "遗物阻止获得药水。" }
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, _ownership, host, dependencies)
    local R = L.rewardPick
    local function refresh(changed)
        if owner.run and owner.run.phase == "combat" then
            local battle, found = owner.run.combat, false
            if not battle.enemies[owner.target] or not Actors.isActive(battle.enemies[owner.target]) then
                for i, enemy in ipairs(battle.enemies) do if Actors.isActive(enemy) then owner.target = i break end end
            end
            for _, card in ipairs(battle.hand) do if card.uid == owner.selected then found = true break end end
            if not found then owner.selected = nil end
        else owner.selected = nil end
        owner:render()
        if changed and host.options.onChange then host.options.onChange(owner) end
    end
    local function perform(command, origin)
        local battle = owner.run.combat
        local before, first = Events.frame(battle), #battle.events + 1
        owner.busy, owner.feedbackRun, owner.feedbackBattle = true, owner.run, battle
        owner.displayBattle = {catalog = battle.catalog, rules = battle.rules}
        for k, v in pairs(before) do owner.displayBattle[k] = v end
        local shown, failure = pcall(owner.render, owner)
        if not shown then
            owner.busy, owner.displayBattle = false, nil
            print("ABYSS_FEEDBACK prepare_failed " .. tostring(failure))
            pcall(refresh)
            return false, "presentation_unavailable"
        end
        local called, ok, reason = pcall(command)
        if not called or not ok then
            owner.busy, owner.displayBattle = false, nil
            if not called then print("ABYSS_FEEDBACK command_failed " .. tostring(ok)) end
            refresh()
            return false, called and reason or "command_failed"
        end
        -- No core callback is retained by playback. The committed result is immutable to it.
        owner.feedbackLast = #battle.events
        owner.feedback:setFastMode(owner.fastMode==true)
        owner.feedback:begin(before, battle, first, owner.presentation, origin)
        return ok, reason
    end
    function owner:chooseCards(kind, uids, token, generation,battle)
        if self.busy or not self.run or self.run.phase~="combat" then return false, "not_in_combat" end
        local command = kind=="discard" and Run.chooseDiscard or kind=="scry" and Run.chooseScry
            or kind=="hand" and Run.chooseHand or kind=='pile' and Run.choosePile or kind=='potion'and Run.choosePotionStance
        if not command then return false, "invalid_choice_kind" end
        return perform(function() return command(self.run,uids,token,generation,battle) end)
    end
    local function helpContextChanged(help)
        local current = owner.run and owner.run.combat
        local actor = current and (help.spec.index == 0 and current.player or current.enemies[help.spec.index])
        return not owner.active or owner.busy or owner.run ~= help.run or current ~= help.battle
            or current.turn ~= help.turn or actor ~= help.actor or not Actors.isPresent(actor)
            or help.spec.screenSlot and not dependencies.sameEnemySlot(help.spec.screenSlot,actor,current)
            or help.spec.kind=='rewardCard' and not RewardOwner.ready(owner,help.spec)
    end
    local function helpPointerChanged(help)
        return owner.gesture and owner.gesture.moving
            or help.card and (help.card.input.held ~= help.card or not dependencies.cardReady(help.card))
    end
    local function fireHelp(help, dt)
        help.t = help.t + dt
        if help.t + 0.000001 >= L.statusInfo.delay then
            help.fired = true
            if help.held and (help.spec.kind == "card" or help.spec.kind=='rewardCard') then
                owner.gesture = nil
                dependencies.cancelCardInputs()
                owner.suppressClick = true
            end
            -- A deliberate card hold opens a pageable reader; hover stays transient.
            local heldCard=help.held and (help.spec.kind=='card' or help.spec.kind=='rewardCard')
            if heldCard then owner.swallow={touch=help.touch}end
            owner:openHelp(help.spec, help.source, not heldCard)
        end
    end
    local function updateHelp(dt)
        local help = owner.help
        if not help then return end
        if helpContextChanged(help) or helpPointerChanged(help) then owner.help = nil
        elseif help.spec.kind == "potion" and (owner.run.potions ~= help.spec.inventory
            or owner.run.potions[help.spec.slot] ~= help.spec.potionId) then owner.help = nil
        elseif not help.fired then fireHelp(help, dt) end
    end
    local function animateRewardCards(view, dt)
        local k, moving = 1 - math.exp(-R.ease * dt), false
        for i, anim in ipairs(view.cards) do
            local scale, lift = dependencies.rewardTarget(i)
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
        local view = owner.rewardView
        if view and owner.active and not owner.busy and owner.run and owner.run.phase == "reward" and view.rewards == owner.run.rewards then
            if animateRewardCards(view, dt) then owner:render(true) end
        end
    end
    function owner:update(dt)
        if self.gesture then self.gesture.elapsed = (self.gesture.elapsed or 0) + dt end
        if dependencies.updateCarry then dependencies.updateCarry() end
        if self.potionAim and not dependencies.aimReady(self.potionAim) then self:render() end
        updateHelp(dt)
        if self.feedbackRun and (self.feedbackRun ~= self.run or self.feedbackBattle ~= (self.run and self.run.combat)) then
            self.feedback:cancel()
            self.feedbackRun, self.feedbackBattle = nil, nil
            self:render() return
        end
        dependencies.updateEnemyIntents(dt)
        self.feedback:update(dt)
        dependencies.updateEnemyNames(dt)
        updateRewardCards(dt)
        host.cardView.update(dt)
    end
    function owner:setActive(active)
        assert(type(active) == "boolean", "active must be boolean")
        self.active = active
        if not active then self.help=nil;dependencies.cancelPotionAim("已取消药水瞄准。") end
        host.root:SetVisible(active)
        self:render()
    end
    function owner:start()
        if not self.active or host.options.embedded or self.busy then return false end
        self.feedback:cancel()
        self.run = Run.new(self.data, self.seed)
        self.seed = (self.seed + 1) % 65536
        assert(Run.startCombat(self.run, "cultist_solo"))
        self.target, self.selected = 1, nil
        dependencies.notice("") refresh(true)
        print("ABYSS_UI combat_started")
    end
    function owner:playSelected(target)
        if not self.active or not self.selected or self.busy or self.gesture or not self.run or self.run.phase ~= "combat" then return end
        local uid, origin = self.selected, self.cardPositions[self.selected]
        local ok, reason = perform(function() return Run.play(self.run, uid, target) end, origin)
        if ok then self.selected = nil end
        dependencies.notice(ok and "" or reasons[reason] or "当前无法使用这张牌。")
        if reason ~= "presentation_unavailable" then refresh() end
    end
    function owner:chooseCard(token,uid)
        if self.busy or not self.run or self.run.phase~="combat" then return false end
        local ok,reason=perform(function() return Run.chooseCard(self.run,token,uid) end)
        dependencies.notice(ok and "" or reasons[reason] or "这次选牌已失效。")
        refresh()
        return ok,reason
    end
    local function claimCard(index, run)
        if owner.rewardScreen ~= "cards" then return end
        local ok, reason = Run.claimCardReward(run, index)
        if ok then
            -- Adopt the committed rewards object before local feedback; an
            -- unrelated replacement still resets the page on the next render.
            owner.rewardOwner, owner.rewardRun = run.rewards, run
            dependencies.rewardScreen("list")
        end
        dependencies.notice(ok and "卡牌已加入牌组。" or reasons[reason] or "当前无法领取奖励。")
        refresh(ok)
    end
    local function selectCombatCard(index, run)
        dependencies.cancelPotionAim("已取消药水瞄准。")
        local instance = run.combat.hand[index]
        if not instance then return end
        owner.selectionEpoch = (owner.selectionEpoch or 0) + 1
        if owner.selected == instance.uid then owner.selected = nil dependencies.notice("") refresh() return end
        local ok, reason = Combat.canPlay(run.combat, instance.uid, owner.target)
        if not ok then dependencies.notice(reasons[reason] or "当前无法使用这张牌。") refresh() return end
        owner.selected = instance.uid
        dependencies.notice("")  -- STS 式：选牌只靠抬起/发光反馈，不显示任何教学字幕
        refresh()
    end
    function owner:playSlot(index)
        local run = self.run
        if not self.active or not run or self.busy or self.gesture or self.suppressClick then return end
        if run.phase == "reward" then return claimCard(index, run)
        elseif run.phase == "combat" then return selectCombatCard(index, run) end
        refresh()
    end
    function owner:endTurn()
        if not self.active or not self.run or self.busy or self.gesture or self.suppressClick or self.run.phase ~= "combat" or self.run.combat.phase ~= "player" then return end
        self.selected = nil
        perform(function() return Run.endTurn(self.run) end)
    end
    local function potionBinding(index)
        local binding = owner.potionSlots and owner.potionSlots[index]
        if not binding or owner.potionRun ~= owner.run or owner.potionBattle ~= owner.run.combat
            or owner.run.potions[binding.slot] ~= binding.id then return end
        return binding
    end
    local function beginPotionAim(binding, item)
        owner.selected = nil
        owner.selectionEpoch = (owner.selectionEpoch or 0) + 1
        dependencies.cancelCardInputs()
        dependencies.cancelActionInputs()
        local battle = owner.run.combat
        local aim = {run=owner.run,battle=battle,turn=battle.turn,inventory=owner.run.potions,
            slot=binding.slot,id=binding.id,actors={},living={}}
        for i, actor in ipairs(battle.enemies) do aim.actors[i],aim.living[i]=actor,Actors.isActive(actor) end
        owner.potionAim = aim
        dependencies.notice(item.name .. (Controller.isController(host.platform.controller)
            and " · 摇杆选择敌人 · 确认使用 · 返回取消"
            or " · 对一名敌人：点击敌人使用；再点药水或空白取消；点说明查看效果。"))
        refresh()
        return true
    end
    function owner:usePotion(index)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        local binding = potionBinding(index)
        if not binding then return false end
        local item = Run.potionView(self.run)[binding.slot]
        if not item or not item.canUse then dependencies.notice(reasons[item and item.reason] or "当前无法使用此药水。") return false end
        local previous = self.potionAim
        dependencies.cancelPotionAim()
        if previous and previous.slot == binding.slot then dependencies.notice("已取消药水瞄准。") refresh() return true end
        if item.targetPolicy == "enemy_one" then return beginPotionAim(binding, item) end
        return self:commitPotion(binding.slot, nil)
    end
    local function potionTargetReady(slot, target)
        local aim = owner.potionAim
        return not target or aim and aim.slot == slot and dependencies.aimReady(aim)
    end
    function owner:commitPotion(slot, target)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        if not potionTargetReady(slot, target) then
            dependencies.cancelPotionAim("药水瞄准已失效，已取消。") refresh() return false
        end
        dependencies.cancelPotionAim()
        local ok, reason = perform(function() return Run.usePotion(self.run, slot, target) end)
        if ok then
            self.potionSlots[slot] = nil
        end
        dependencies.notice(ok and "药水已生效。" or reasons[reason] or "当前无法使用此药水。")
        if reason ~= "presentation_unavailable" then refresh() end
        return ok, reason
    end
    local function potionRewardNotice(ok, reason, claim)
        if not ok then return reasons[reason] or "当前无法处理药水。" end
        if reason == "potion_blocked_by_sozu" then return "遗物阻止获得药水。" end
        return claim and "药水已放入背包。" or "已放弃药水。"
    end
    local function processPotionReward(claim)
        if not owner.active or not owner.run or owner.busy or owner.gesture or owner.suppressClick then return false end
        if owner.rewardScreen ~= "list" then return false end
        local ok,reason=(claim and Run.claimPotionReward or Run.skipPotionReward)(owner.run)
        dependencies.notice(potionRewardNotice(ok, reason, claim))
        refresh(ok)
        return ok,reason
    end
    function owner.claimPotionReward(_) return processPotionReward(true) end
    function owner.skipPotionReward(_) return processPotionReward(false) end
    return {
        refresh=refresh, perform=perform, helpContextChanged=helpContextChanged, helpPointerChanged=helpPointerChanged, fireHelp=fireHelp,
        updateHelp=updateHelp, animateRewardCards=animateRewardCards, updateRewardCards=updateRewardCards, claimCard=claimCard, selectCombatCard=selectCombatCard,
        potionBinding=potionBinding, beginPotionAim=beginPotionAim, potionTargetReady=potionTargetReady, potionRewardNotice=potionRewardNotice, processPotionReward=processPotionReward
    }
end
return M
