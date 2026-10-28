-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local M = {}
local L = Theme.layout
-- Only this responsibility owns these closures; cross-responsibility calls are explicit ports.
function M.install(owner, ownership, _host, dependencies)
    local R = L.rewardPick
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
        if view.potionAim and not dependencies.aimReady(view.potionAim) then
            dependencies.cancelPotionAim("药水瞄准已失效，已取消；请重新选择药水。")
        end
        if view.gesture and not dependencies.cardReady(view.gesture) then
            view.gesture, view.selected, view.suppressClick = nil, nil, true
        end
        if view.carry and (view.selected ~= view.carry.uid or not dependencies.cardReady(view.carry)) then
            if view.selected == view.carry.uid then view.selected = nil end
            view.carry = nil
        end
        pruneInputs(ownership.cardInputs, dependencies.cardReady)
        pruneInputs(ownership.potionInputs, dependencies.potionReady)
        pruneInputs(ownership.actionInputs, dependencies.actionReady)
        pruneInputs(ownership.enemyInputs, dependencies.enemyReady)
        return run
    end
    local function renderFeedbackReady(run)
        if owner.busy and owner.feedback and
            (owner.feedbackRun ~= run or owner.feedbackBattle ~= (run and run.combat)) then
            owner.feedback:cancel()
            return false
        end
        return true
    end
    local function syncRenderIdentity(run)
        if owner.viewRun ~= run then
            owner.viewRun, owner.target, owner.selected = run, 1, nil
            owner.potionRun, owner.potionBattle, owner.potionSlots = nil, nil, nil
            ownership.playbackIntents = nil
        end
        -- Encounters change committed identity even while their Run survives.
        local battle = run and run.combat
        if owner.viewBattle ~= battle then
            owner.viewBattle, owner.target, owner.selected = battle, 1, nil
            ownership.playbackIntents = nil
        end
    end
    local function renderFrame(run)
        local fighting = owner.displayBattle ~= nil or run and run.phase == "combat"
        local battle = owner.displayBattle or fighting and run.combat
        if owner.displayBattle and battle.originalV4 then
            -- Only immutable target/cost rules are borrowed by playback frames.
            battle.originalV4Rules = owner.feedbackBattle.originalV4Rules
        end
        local enemyPlayback = owner.busy and owner.displayBattle and battle.phase == "enemy"
        if not enemyPlayback then ownership.playbackIntents = nil end
        return {run = run, battle = battle, fighting = fighting, enemyPlayback = enemyPlayback}
    end
    local function handHoverReady()
        local token,run = owner.handHover,owner.run
        if not token then return false end
        local instance = token.battle.hand[token.slot]
        return dependencies.canHover() and run == token.run and run.phase == 'combat' and run.combat == token.battle
            and token.battle.turn == token.turn and token.battle.phase == 'player'
            and instance and instance.uid == token.uid
    end
    local function syncRewardOwner(frame)
        local run = frame.run
        local reward = not owner.busy and run and run.phase == "reward"
        frame.reward = reward
        if reward and (owner.rewardOwner ~= run.rewards or owner.rewardRun ~= run) then
            owner.rewardOwner, owner.rewardRun, owner.rewardNotice = run.rewards, run, ""
            dependencies.rewardScreen("list")
        elseif not reward then
            if owner.rewardScreen then dependencies.label("notice", "") end
            owner.rewardOwner, owner.rewardRun, owner.rewardNotice = nil, nil, nil
            dependencies.rewardScreen(nil)
        end
        frame.picking = reward and owner.rewardScreen == "cards"
        frame.listing = reward and owner.rewardScreen == "list"
        if reward then owner.handHover = nil
        elseif not handHoverReady() then owner.hover,owner.handHover = nil,nil end
    end
    local function syncRewardEntrance(frame)
        if frame.picking and (not owner.rewardView or owner.rewardView.rewards ~= frame.run.rewards) then
            owner.rewardView = {rewards = frame.run.rewards, cards = {}}
            for i = 1, 10 do
                owner.rewardView.cards[i] = {scale = R.scale * R.enterScale, lift = 0, rise = -R.enterRise}
            end
        elseif not frame.picking then
            owner.rewardView = nil
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
        frame.active = owner.active and frame.fighting and battle.phase == "player" and not owner.busy
        -- Stage transactions once while input is available, never per animation step.
        frame.potions = owner.busy and owner.potionViewCache or frame.fighting and Run.potionView(run) or {}
        if not owner.busy then owner.potionViewCache = frame.potions end
        frame.potionCapacity = run and Run.potionCapacity(run) or 0
        owner.potionTargetAvailable = targetPotionAvailable(frame)
    end
    return {
        pruneInputs=pruneInputs, prepareRenderInputs=prepareRenderInputs, renderFeedbackReady=renderFeedbackReady, syncRenderIdentity=syncRenderIdentity, renderFrame=renderFrame,
        handHoverReady=handHoverReady, syncRewardOwner=syncRewardOwner, syncRewardEntrance=syncRewardEntrance, targetPotionAvailable=targetPotionAvailable, prepareRenderPotions=prepareRenderPotions
    }
end
return M
