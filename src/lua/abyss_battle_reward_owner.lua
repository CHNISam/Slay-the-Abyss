-- Pointer reward ownership follows content and resolution, not just a page slot.
local Combat = require("abyss_combat")
local M = {}

local function captureGold(token, rewards)
    local item = rewards and rewards.stolenGold
    token.normalGold = rewards and rewards.gold
    token.goldClaimed = rewards and rewards.goldClaimed
    token.item = item
    token.goldAmount = item and item.amount
    token.goldType = item and item.type
    token.claimed = item and item.claimed
end

local function capturePotion(token, rewards)
    local potion = rewards and rewards.potion
    token.potion = potion
    token.potionResolved = potion and potion.resolved
    token.potionResult = potion and potion.result
    token.potionId = potion and potion.id
    token.potionUnavailable = potion and potion.unavailable
end

function M.capture(token, view, run)
    local rewards = run and run.rewards
    token.rewards = rewards
    token.rewardScreen, token.rewardEpoch = view.rewardScreen, view.rewardEpoch
    token.render = view.rewardRender
    token.cardResolved = rewards and rewards.cardResolved
    token.manualContinue = rewards and rewards.manualContinue
    token.cards = rewards and rewards.cards
    token.cardChoices = rewards and Combat.copy(rewards.cards)
    token.upgrades = rewards and rewards.cardUpgrades
    token.cardUpgrades = rewards and Combat.copy(rewards.cardUpgrades or {})
    token.relics=rewards and rewards.relics
    token.relicState=rewards and Combat.copy(rewards.relics or {})
    captureGold(token, rewards)
    capturePotion(token, rewards)
    return token
end

local function sameCardOffers(token,rewards)
    if token.cards~=rewards.cards or token.upgrades~=rewards.cardUpgrades or #token.cardChoices~=#rewards.cards then return false end
    for i, id in ipairs(rewards.cards) do
        if token.cardChoices[i] ~= id or token.cardUpgrades[i] ~= (rewards.cardUpgrades and rewards.cardUpgrades[i]) then return false end
    end
    return true
end

local function sameGoldAndCards(token, rewards)
    local item = rewards.stolenGold
    return token.manualContinue == rewards.manualContinue and sameCardOffers(token,rewards)
        and token.item == item and token.goldAmount == (item and item.amount) and token.goldType == (item and item.type)
        and token.normalGold == rewards.gold and token.goldClaimed == rewards.goldClaimed
end

local function samePotion(token, potion)
    return token.potion == potion and token.potionResolved == (potion and potion.resolved)
        and token.potionResult == (potion and potion.result) and token.potionId == (potion and potion.id)
        and token.potionUnavailable == (potion and potion.unavailable)
end

local function sameManualPage(token, view, rewards)
    local item = rewards.stolenGold
    -- A no-loss reward keeps its gesture through a pure redraw. Stolen-gold
    -- pages retain their explicit-redraw boundary and their claimed identity.
    return not ((item and token.render ~= view.rewardRender) or token.item ~= item
        or token.claimed ~= (item and item.claimed) or token.cardResolved ~= rewards.cardResolved)
end

local function sameRelics(token,rewards)
    if token.relics~=rewards.relics then return false end
    if #token.relicState~=#(rewards.relics or {})then return false end
    for i,item in ipairs(rewards.relics or {})do
        local old=token.relicState[i]
        if not old or old.id~=item.id or old.sourceId~=item.sourceId or old.claimed~=item.claimed or old.unavailable~=item.unavailable then return false end
    end
    return true
end

function M.ready(view, token)
    local run = view.run
    if not run or run.phase ~= "reward" or run.rewards ~= token.rewards or run.combat ~= token.battle then return false end
    if token.rewardScreen ~= view.rewardScreen or token.rewardEpoch ~= view.rewardEpoch then return false end
    local rewards = run.rewards
    if not sameRelics(token,rewards)then return false end
    if not sameGoldAndCards(token, rewards) then return false end
    if not samePotion(token, rewards.potion) then return false end
    if rewards.manualContinue and not sameManualPage(token, view, rewards) then return false end
    return true
end

return M
