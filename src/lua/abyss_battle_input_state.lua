-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Run = require("abyss_run")
local EnemyView = require('abyss_battle_enemy_view')
local RewardOwner = require("abyss_battle_reward_owner")
local M = {}
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, _dependencies)
    function owner:setData(nextData, nextPresentation)
        assert(not self.busy, "cannot replace card data during feedback")
        assert(type(nextData)=="table" and type(nextPresentation)=="table", "invalid UI card data")
        self.data, self.presentation = nextData, nextPresentation
        self.selected, self.hover, self.help = nil, nil, nil
    end
    local function child(name)
        local nested=name:match('^potion[45]$') or name:match('^potionHelp%d$') or name=='potionReward' or name=='emeraldKeyReward' or name:match('^relicReward%d$')
        local found=(nested and host.stage:GetChild('potionHelp') or host.stage):GetChild(name)
        return assert(found, "missing UI control " .. name)
    end
    local function show(name, value) child(name):SetVisible(value == true) end
    local function label(name, value) child(name).text = value end
    local function colour(value) return host.platform.color(value.r, value.g, value.b, value.a) end
    local function tint(control, value) control.imageColor = colour(value) end
    local function ink(control, value) control.fontColor = colour(value) end
    local function picture(control, id) control:SetImage(host.platform.imageSource, id) end
    local function notice(value)
        label("notice", value)
        owner.rewardNotice = value
    end
    local function rewardScreen(screen)
        if owner.rewardScreen ~= screen then
            owner.rewardScreen, owner.rewardEpoch = screen, (owner.rewardEpoch or 0) + 1
            owner.hover = nil
        end
    end
    local function dragReady(g)
        return owner.active and not owner.busy and owner.run == g.run and owner.run.phase == "combat"
            and owner.run.combat == g.battle and g.battle.phase == "player" and g.battle.turn == g.turn
    end
    local function rewardReady(g)
        return RewardOwner.ready(owner, g)
    end
    local function cardReady(g)
        if not owner.active or owner.busy or owner.run ~= g.run or owner.run.phase ~= g.phase then return false end
        if g.phase == "combat" then
            local instance = g.battle.hand[g.slot]
            return dragReady(g) and instance ~= nil and instance.uid == g.uid
        end
        if g.phase ~= "reward" or owner.rewardScreen ~= "cards" or not rewardReady(g) then return false end
        return Run.rewardOptions(owner.run)[g.slot] == g.uid
    end
    local function cancelCardInputs()
        for _, input in ipairs(ownership.cardInputs) do input.held, input.released = nil, nil end
    end
    local function potionReady(g)
        return dragReady(g) and owner.run.potions == g.inventory
            and owner.run.potions[g.slot] == g.id
    end
    local function cancelPotionInputs()
        for _, input in ipairs(ownership.potionInputs) do input.held, input.released = nil, nil end
    end
    local function cancelPotionAim(message)
        if not owner.potionAim then return false end
        local aim=owner.potionAim
        if aim.moving and aim.input then
            aim.input.held,aim.input.released=nil,nil
            aim.input.consumed={touch=aim.touch}
            -- Explicit command wrappers may clear suppression before rejecting
            -- this invalidated aim. Retain that release's finite origin, while
            -- true stale/resize cancellation barriers remain deliberately true.
            if owner.suppressClick==false then
                ownership.releasedDragTouch,owner.suppressClick=aim.touch,aim
            end
        end
        owner.potionAim = nil
        if message then notice(message) end
        return true
    end
    local function aimReady(aim)
        if not potionReady(aim) then return false end
        if aim.moving and (not aim.input or not aim.input.held or aim.input.held.aim~=aim) then return false end
        local enemies = aim.battle.enemies
        if #enemies ~= #aim.actors then return false end
        for i, actor in ipairs(aim.actors) do
            if enemies[i] ~= actor or Actors.isActive(actor) ~= aim.living[i] then return false end
        end
        return true
    end
    local function actionContextReady(g)
        local run = owner.run
        if not owner.active or owner.busy or owner.gesture or run ~= g.run then return false end
        if run and (run.phase ~= g.phase or run.combat ~= g.battle
            or g.battle and g.battle.turn ~= g.turn) then return false end
        return true
    end
    local function playAreaReady(g)
        if g.aim then return owner.potionAim == g.aim and aimReady(g.aim) end
        local instance = g.battle and g.battle.hand[g.slot or 0]
        return dragReady(g) and instance and instance.uid == g.uid and owner.selected == g.uid
            and owner.selectionEpoch == g.selectionEpoch and not needsTarget(g.battle, instance)
    end
    local function rewardListActionReady(g, rewards)
        local relicIndex=g.name:match('^relicReward(%d)$')
        if relicIndex then
            local item=rewards.relics and rewards.relics[tonumber(relicIndex)]
            return item and not item.claimed and not item.unavailable
        end
        if g.name == "cardReward" then return not rewards.cardResolved end
        if g.name == "goldReward" then return rewards.goldClaimed == false end
        if g.name == 'emeraldKeyReward' then return Run.canClaimEmeraldKey(owner.run) end
        if g.name == "claimPotion" then return rewards.potion and not rewards.potion.resolved end
        if rewards.manualContinue then
            if g.name == "stolenGold" then return rewards.stolenGold and not rewards.stolenGold.claimed end
            if g.name == "continue" then return true end
        end
        return false
    end
    local function rewardActionReady(g, run)
        if not rewardReady(g) then return false end
        if owner.rewardScreen == "cards" then return g.name == "skip" and not run.rewards.cardResolved end
        if owner.rewardScreen ~= "list" then return false end
        return rewardListActionReady(g, run.rewards)
    end
    local function actionReady(g)
        if not actionContextReady(g) then return false end
        local run = owner.run
        if g.name == "start" then return not host.options.embedded and (not run or run.phase == "defeat") end
        if not run then return false end
        if g.name == "playArea" then return playAreaReady(g) end
        if g.name == "endTurn" then return dragReady(g) end
        if run.phase == "reward" then return rewardActionReady(g, run) end
        return g.name == "continue" and not host.options.embedded and run.phase == "map"
    end
    local function cancelActionInputs()
        for _, input in ipairs(ownership.actionInputs) do input.held, input.released = nil, nil end
    end
    local function enemyAt(slot,battle)
        battle=battle or owner.run and owner.run.combat
        return battle and EnemyView.slots(battle)[slot]
    end
    local function sameEnemySlot(slot,actor,battle)
        local entry=enemyAt(slot,battle)
        return entry and entry.actor==actor and entry.id==actor.id
    end
    local function enemyReady(g)
        return not owner.info and dragReady(g) and Actors.isActive(g.actor) and g.battle.enemies[g.slot] == g.actor
            and sameEnemySlot(g.screenSlot,g.actor,g.battle)
            and owner.selected == g.uid and owner.selectionEpoch == g.selectionEpoch
            and owner.potionAim == g.aim and (not g.aim or aimReady(g.aim))
    end
    local function discardEnemyPointer(input,event)
        local touch = event and event.touchId
        if input.held and input.held.touch == touch then input.held = nil end
        if input.released and input.released.touch == touch then input.released = nil end
    end
    -- Click-only controls must not inherit the latest completed drag's named
    -- touch, even after an independent action. A fresh Down retires that origin.
    -- Anonymous origins consume one ambiguous Click without a permanent lock.
    local function consumeReleasedDragClick(event)
        if not owner.active or owner.busy or owner.gesture then return false end
        local touch = event and event.touchId
        if touch ~= nil and touch == ownership.releasedDragTouch then return true end
        local g = owner.suppressClick
        if type(g) ~= 'table' then return false end
        owner.suppressClick = nil
        return g.touch == touch
    end
    return {
        child=child, show=show, label=label, colour=colour, tint=tint,
        ink=ink, picture=picture, notice=notice, rewardScreen=rewardScreen, dragReady=dragReady,
        rewardReady=rewardReady, cardReady=cardReady, cancelCardInputs=cancelCardInputs, potionReady=potionReady, cancelPotionInputs=cancelPotionInputs,
        cancelPotionAim=cancelPotionAim, aimReady=aimReady, actionContextReady=actionContextReady, playAreaReady=playAreaReady, rewardListActionReady=rewardListActionReady,
        rewardActionReady=rewardActionReady, actionReady=actionReady, cancelActionInputs=cancelActionInputs, enemyAt=enemyAt, sameEnemySlot=sameEnemySlot,
        enemyReady=enemyReady, discardEnemyPointer=discardEnemyPointer, consumeReleasedDragClick=consumeReleasedDragClick
    }
end
return M
