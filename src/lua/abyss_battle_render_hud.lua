-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local RewardLayout=require('abyss_battle_reward_layout')
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local PotionView = require("abyss_battle_potion_view")
local UnitView = require("abyss_battle_unit_view")
local RelicNames = require("abyss_relic_names")
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space
local stanceNames={Neutral="无姿态",Calm="平静",Wrath="愤怒",Divinity="神格"}
local number = require("abyss_numbers").integer
local potionText = PotionView.potionText
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
local function cardRewardCaption(frame)
    if not frame.listing then return '选择一张卡牌加入牌组'end
    local run,remaining=frame.run,0
    for _,group in ipairs(run.rewards.cardRewardGroups or {})do if not group.resolved then remaining=remaining+1 end end
    local label=remaining>1 and ('查看'..remaining..'组卡牌奖励')or '选择一张卡牌加入牌组'
    if require('abyss_relic_hooks').owns(run,'singing_bowl')then label=label..' / 生命上限+2'end
    return label
end
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, _ownership, host, dependencies)
    local R = L.rewardPick
    local rewardSizeOwner = {}
    local function renderStartControls(frame)
        local run = frame.run
        dependencies.show("start", not owner.busy and not host.options.embedded and (not run or run.phase == "defeat"))
        dependencies.button("start", owner.active, true, run and "重新启程" or "启程")
        dependencies.show("endTurn", frame.fighting)
    end
    local function rewardNavigation(frame)
        local run = frame.run
        frame.manual = frame.listing and run.rewards.manualContinue
        frame.stolen = frame.manual and run.rewards.stolenGold
        frame.potionReward = frame.listing and run.rewards.potion
        frame.pendingPotion = frame.potionReward and not frame.potionReward.resolved
        dependencies.show("skip", frame.picking and not run.rewards.cardResolved)
        dependencies.show("continue", frame.manual or not host.options.embedded and run and run.phase == "map")
        dependencies.child("skip"):SetAnchoredPosition(R.skip[1], R.skip[2])
        dependencies.child("continue"):SetAnchoredPosition(
            frame.manual and L.battleRewards.continue[1] or 0,
            frame.manual and L.battleRewards.continue[2] or -S.xxl * 3)
    end
    local function renderRewardRows(frame)
        RewardLayout.render(frame,dependencies.child,rewardSizeOwner)
    end
    local function renderRelicRewards(frame)
        local run=frame.run
        for i=1,2 do
            local item=frame.listing and run.rewards.relics and run.rewards.relics[i]
            local caption=item and (RelicNames.get(run.data,item.sourceId)..(item.unavailable and ' · 尚不可领取' or ''))or '遗物'
            dependencies.button('relicReward'..i,owner.active and item and not item.claimed and not item.unavailable or false,false,caption)
        end
    end
    local function renderRewardButtons(frame)
        local run = frame.run
        renderRelicRewards(frame)
        dependencies.button('emeraldKeyReward',owner.active and frame.listing and Run.canClaimEmeraldKey(run) and not owner.busy or false,false,'领取绿钥匙')
        dependencies.button("goldReward", owner.active and frame.listing and run.rewards.goldClaimed == false, false,
            frame.listing and number(run.rewards.gold) .. " 金币" or "金币")
        dependencies.button("cardReward", owner.active and frame.listing and not run.rewards.cardResolved, false,cardRewardCaption(frame))
        -- Full belts stay clickable so rejection can explain how to free a slot.
        dependencies.button("claimPotion", owner.active and frame.pendingPotion == true and not frame.potionReward.unavailable, false)
    end
    local function rewardPotionDefinition(frame)
        for _, item in ipairs(owner.data.potions.potions) do
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
        dependencies.button("claimPotion", owner.active and frame.pendingPotion == true and not reward.unavailable, false,
            rewardPotionCaption(frame))
        dependencies.label("potionReward", reward.unavailable and "该稀有度药水尚未实装；可继续前往地图。"
            or Run.potionCount(run) >= Run.potionCapacity(run)
                and "药水槽已满；点顶部药水入口丢弃旧药水后，再点击奖励领取。" or "")
    end
    local function renderRewardStage(frame)
        dependencies.show("rewardStage", frame.picking)
        dependencies.show("rewardList", frame.listing)
        dependencies.show("notice", not frame.reward)
        if frame.listing then
            dependencies.child("rewardList"):GetChild("subtitle").text = owner.rewardNotice ~= "" and owner.rewardNotice
                or (frame.rewardRows == 0 and "奖励已领取" or "点击条目领取奖励")
        end
    end
    local function fieldCardSelected(frame)
        if not frame.active or owner.gesture then return false end
        for _, instance in ipairs(frame.battle.hand) do
            if instance.uid == owner.selected and not needsTarget(frame.battle, instance) then return true end
        end
        return false
    end
    local function renderPlayArea(frame)
        dependencies.show("playArea", fieldCardSelected(frame) or frame.active and owner.potionAim ~= nil)
        dependencies.child("playArea"):GetChild("label").text = owner.potionAim and "点击空白处取消药水瞄准" or ""
    end
    local function renderHudVisibility(frame)
        for _, name in ipairs({"energyRing", "energyDisc", "energyIcon", "energy", "drawIcon", "drawBadgeRing", "drawBadge",
            "draw", "drawLabel", "discardIcon", "discardBadgeRing", "discardBadge", "discard", "discardLabel"}) do
            dependencies.show(name, not frame.reward)
        end
        dependencies.show("result", not frame.fighting and not frame.reward)
        dependencies.show("resultPlate", not frame.fighting and not frame.reward)
        dependencies.show("hero", frame.fighting and not owner.feedback.deaths.player)
    end
    local function playerHealthText(frame)
        local player, run = frame.player, frame.run
        return number(player and player.hp or run and run.hp or owner.data.rules.player.maxHp)
            .. "/" .. number(run and run.maxHp or owner.data.rules.player.maxHp)
    end
    local function renderPlayerTotals(frame)
        frame.player = frame.battle and frame.battle.player
        dependencies.label("player", playerHealthText(frame))
        local player, run = frame.player, frame.run
        -- Render the current rule owner directly: a render-only counter cannot
        -- finish during idle frames and must not leak a balance across runs.
        local gold = player and player.gold or run and run.gold or 0
        dependencies.label("piles", number(gold))
        dependencies.ink(dependencies.child("piles"), C.topPanelGold)
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
        -- Keep the floor identifiable without a naked number over the first potion slot.
        dependencies.label("floor", "")
        local floor=flow and flow.floor and " · 第"..tostring(flow.floor).."层" or ""
        dependencies.label("title", kind .. floor .. stanceHeading(frame) .. orbHeading(frame) .. discardHeading(frame) .. originalHeading(frame))
    end
    local function renderEnergy(frame)
        local battle = frame.battle
        local exhausted = battle and #battle.exhaust or 0
        dependencies.label("exhaust", tostring(exhausted))
        -- STS ExhaustPanel only shows once the exhaust pile is non-empty; an empty "0"
        -- beside the shared deck button read as a second draw pile.
        dependencies.show("exhaustIcon", frame.fighting == true and exhausted > 0)
        dependencies.show("exhaust", frame.fighting == true and exhausted > 0)
        local value = number(battle and battle.energy or 0) .. "/" .. number(owner.data.rules.player.energyPerTurn)
        dependencies.label("energy", value)
        local charged = battle and battle.energy > 0
        local icon = dependencies.child("energyIcon")
        icon:GetChild("valueShadow").text = value
        dependencies.tint(icon:GetChild("face"), charged and L.energy.faceColour or C.energyEmpty)
        icon:GetChild("light"):SetVisible(charged == true)
        dependencies.tint(icon:GetChild("core"), charged and L.energy.elementColour or C.energyEmpty)
        dependencies.ink(dependencies.child("energy"), L.energy.numberColour)
    end
    local function renderPilesAndTurn(frame)
        local battle = frame.battle
        dependencies.label("draw", battle and tostring(#battle.draw) or "0")
        dependencies.label("discard", battle and tostring(#battle.discard) or "0")
        for _,kind in ipairs({'draw','discard','exhaust'})do
            local hit=dependencies.child(kind..'Icon'):GetChild('hit')
            hit:SetVisible(frame.fighting==true)
            hit.raycastTarget=host.options.onPile~=nil and frame.active==true
        end
        dependencies.label("statuses", frame.fighting and battle.phase ~= "player" and not owner.busy and "敌方回合" or "")
        if frame.fighting then
            local hero=dependencies.child("hero")
            local lift=UnitView.noticeLift(frame.player,L.player.portrait,L.player.position[2],true)
            hero:SetAnchoredPosition(L.player.position[1],L.player.position[2]+lift)
            host.unit(hero,frame.player,L.player.portrait,Theme.icon.player,L.battleUnit.nameWidth,false)
        end
    end
    local function renderResult(frame)
        local run = frame.run
        if not run then dependencies.label("result", "战斗演练\n点击启程，试用旅行者的初始牌组")
        elseif frame.reward then
            dependencies.child("rewardStage"):GetChild("title").text = "选择一张卡牌"
            dependencies.child("rewardStage"):GetChild("subtitle").text = "点击卡牌加入牌组，或跳过返回奖励列表"
        elseif run.phase == "defeat" then dependencies.label("result", "旅途暂歇\n重新启程，重建牌组")
        elseif run.phase == "map" then dependencies.label("result", "奖励已处理 · 牌组 " .. #run.deck .. " 张\n可再次挑战，检查新增卡牌") end
        dependencies.ink(dependencies.child("result"), run and run.phase == "defeat" and C.danger or C.goldBright)
    end
    return {
        renderStartControls=renderStartControls, rewardNavigation=rewardNavigation, renderRewardRows=renderRewardRows, renderRelicRewards=renderRelicRewards, renderRewardButtons=renderRewardButtons,
        rewardPotionDefinition=rewardPotionDefinition, rewardPotionCaption=rewardPotionCaption, renderPotionReward=renderPotionReward, renderRewardStage=renderRewardStage, fieldCardSelected=fieldCardSelected,
        renderPlayArea=renderPlayArea, renderHudVisibility=renderHudVisibility, playerHealthText=playerHealthText, renderPlayerTotals=renderPlayerTotals, stanceHeading=stanceHeading,
        orbHeading=orbHeading, discardHeading=discardHeading, originalHeading=originalHeading, renderSceneHeading=renderSceneHeading, renderEnergy=renderEnergy,
        renderPilesAndTurn=renderPilesAndTurn, renderResult=renderResult
    }
end
return M
