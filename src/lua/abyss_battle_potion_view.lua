-- Read-only compact and expanded potion wording; effects stay in the core.
local number = require("abyss_numbers").integer
local M = {}

local function temporaryStatus(v)
    local status = assert(v.battle.catalog.statuses[v.effect.status])
    return v.expanded and "先获得 " .. v.value .. " 层" .. status.name
        .. "，再施加回合结束时失去 " .. v.value .. " 层的减益；人工制品可抵挡减益"
        or status.name .. "+" .. v.value .. "·回合末-" .. v.value
end

local function statusEffect(v)
    local status = assert(v.battle.catalog.statuses[v.effect.status])
    local prefix = v.effect.op == "applyStatus" and (v.expanded and "对选中敌人施加 " or "单敌·")
        or (v.expanded and "使自己获得 " or "自用·")
    return prefix
        .. (v.expanded and v.value .. (status.stack == "duration" and " 回合" or " 层") .. status.name or status.name .. v.value)
        .. (v.expanded and v.effect.status == "poison" and "；使用时不立即扣血" or "")
end

local effects = {
    damage = function(v)
        return v.expanded and "对选中敌人造成 " .. v.value .. " 点固定伤害，先抵消格挡；不受力量、虚弱或易伤修正" or "单敌·固定" .. v.value
    end,
    damageAll = function(v)
        return v.expanded and "对所有敌人造成 " .. v.value .. " 点伤害；不受力量、虚弱或易伤影响" or "全敌·伤害" .. v.value
    end,
    block = function(v)
        return v.expanded and "立即使自己获得 " .. v.value .. " 点固定格挡；不受敏捷或脆弱修正" or "自用·格挡" .. v.value
    end,
    energy = function(v)
        return v.expanded and "立即获得 " .. v.value .. " 点能量，仅本回合可用" or "自用·能量" .. v.value
    end,
    draw = function(v)
        return "抽牌 " .. v.value
    end,
    upgradeHand = function()
        return "升级全部可升级手牌（仅本场战斗）"
    end,
    healPercent = function(v)
        return "回复最大生命" .. v.value .. "%的生命"
    end,
    increaseMaxHp = function(v)
        return "最大生命+" .. v.value .. "，并回复" .. v.value .. "生命"
    end,
    exhaustMany = function()
        return "选择任意张手牌消耗（可不选）"
    end,
    discardRedraw = function()
        return "选择任意张手牌丢弃，再抽等量牌"
    end,
    discardToHand = function(v)
        return "选择" .. v.value .. "张弃牌回手，本回合费用为0"
    end,
    randomizeHandCost = function()
        return "手牌战斗费用随机改为0至3（不改变X费和不可打出牌）"
    end,
    escape = function()
        return "逃离战斗，不获得奖励（Boss或背袭敌人房间不可用）"
    end,
    playTopCards = function(v)
        return "免费打出抽牌堆顶" .. v.value .. "张牌，目标随机（不额外消耗）"
    end,
    gainTemporaryStrength = temporaryStatus,
    gainTemporaryDexterity = temporaryStatus,
    gainStatus = statusEffect,
    applyStatus = statusEffect,
}

function M.potionText(item, battle, expanded)
    local special=require('abyss_potion_text').special(item,battle,expanded)
    if special then return item.name..'\n'..special end
    local descriptions = {}
    for _, effect in ipairs(item.effects) do
        local value = number(require('abyss_inventory').potionValue(battle,effect)or 0)
        local describe = effects[effect.op]
        if describe then
            descriptions[#descriptions + 1] = describe({ effect = effect, battle = battle, expanded = expanded, value = value })
        end
    end
    return item.name .. "\n" .. table.concat(descriptions, "，")
end

return M
