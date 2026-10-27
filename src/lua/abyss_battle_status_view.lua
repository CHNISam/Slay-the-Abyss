-- Read-only status descriptions. Rule values and status amounts stay in the core.
local number = require("abyss_numbers").integer
local M = {}
local always = "本场战斗"

function M.statusKind(entry)
    if entry.id=='regrow'then return entry.kind end -- -1 is a no-number BUFF sentinel.
    -- Negative Strength/Dexterity follow the core's Artifact debuff gate.
    return entry.amount < 0 and "debuff" or entry.kind
end

function M.signed(value)
    return (value < 0 and "-" or "+") .. number(math.abs(value))
end

local function temporaryDuration(entry)
    local temporary = entry.temporary or 0
    if temporary ~= 0 and (temporary == entry.amount or entry.amount == 0) then return "本回合" end
    return always
end

local function temporaryNote(entry, name, fallback)
    local temporary = entry.temporary or 0
    return temporary ~= 0 and "回合结束时失去 " .. number(temporary) .. " 层" .. name or fallback
end

-- Each status owns its explanation. The handler receives already formatted
-- amounts, plus the original entry/rules/owner for the few conditional details.
local descriptions = {
    time_warp = function(v)
        return '累计使用 '..v.n..'/12 张牌；满12张后结束回合，全体敌人获得2点力量', always, '复制和自动使用的牌也计数；跨回合保留。'
    end,
    draw_reduction = function(v)
        return '回合开始时少抽1张牌', v.n..' 回合', '叠加延长持续时间，不额外减少抽牌数。'
    end,
    strength = function(v)
        return "普通攻击每段伤害 " .. M.signed(v.entry.amount), temporaryDuration(v.entry),
            temporaryNote(v.entry, "力量", "不影响火焰药水的固定伤害")
    end,
    dexterity = function(v)
        return "卡牌获得的格挡 " .. M.signed(v.entry.amount), temporaryDuration(v.entry),
            temporaryNote(v.entry, "敏捷", "不影响固定格挡药水")
    end,
    vulnerable = function(v)
        return "受到的普通攻击伤害 +" .. number(v.combat.vulnerablePercent - 100) .. "%", "剩余 " .. v.n .. " 回合",
            "数字表示持续回合；不放大中毒，轮末递减"
    end,
    weak = function(v)
        return "造成的普通攻击伤害 -" .. number(100 - v.combat.weakPercent) .. "%", "剩余 " .. v.n .. " 回合",
            "数字表示持续回合；不减少中毒，轮末递减"
    end,
    frail = function(v)
        return "卡牌获得的格挡 -" .. number(100 - v.combat.frailPercent) .. "%", "剩余 " .. v.n .. " 回合",
            "只影响卡牌格挡；不影响固定格挡药水，轮末递减"
    end,
    poison = function(v)
        return "自己的回合开始时失去 " .. v.n .. " 点生命", "每回合 -1",
            "无视格挡；随后剩 " .. number(math.max(0, v.entry.amount - 1)) .. " 层，减到 0 消失"
    end,
    regen = function(v)
        return "回合结束时回复 " .. v.n .. " 点生命", "每回合 -1", "随后层数减 1，减到 0 消失"
    end,
    thievery = function(v)
        return "每次攻击先窃取最多 " .. v.n .. " 金币", always, "完全格挡仍会失金；击败它可在战后取回，逃跑则不返还"
    end,
    thorns = function(v)
        return "受到攻击时，对攻击者造成 " .. v.n .. " 点伤害", always
    end,
    artifact = function(v)
        return "抵挡接下来 " .. v.n .. " 次减益效果", "剩余 " .. v.n .. " 次", "每抵挡一次减 1；不抵挡塞入的状态牌"
    end,
    entangled = function()
        return "本回合不能打出攻击牌", "本回合", "你的回合结束时移除"
    end,
    barricade = function()
        return "回合开始时格挡不会清空", always
    end,
    ritual = function(v)
        if v.actor.id == "player" then
            return "每个自己的回合结束时，获得 " .. v.n .. " 层力量", always, "获得它的当回合即可触发"
        end
        return "每个敌方回合结束时，获得 " .. v.n .. " 层力量", always, "获得它的那一轮不触发"
    end,
    duplication = function(v)
        return "接下来的 " .. v.n .. " 张牌额外使用一次", always, "每次消耗1层；轮末另减少1层；复制不会再次触发复制"
    end,
    plated_armor = function(v)
        return "回合结束时获得 " .. v.n .. " 点固定格挡", always, "受到有来源的普通攻击生命伤害时失去1层"
    end,
    metallicize = function(v)
        return "回合结束时获得 " .. v.n .. " 点固定格挡", always
    end,
    enrage = function(v)
        return "你每打出一张技能牌，它获得 " .. v.n .. " 层力量", always
    end,
    angry = function(v)
        return "每次被攻击并损失生命，获得 " .. v.n .. " 层力量", always, "药水、中毒和荆棘的伤害不触发"
    end,
    curl_up = function(v)
        return "首次被攻击并损失生命后，获得 " .. v.n .. " 点格挡", "仅一次", "在那次攻击结束时生效"
    end,
    spore_cloud = function(v)
        return "它倒下时，你获得 " .. v.n .. " 层易伤", "倒下时"
    end,
    sharp_hide = function(v)
        return "你每打出一张攻击牌，受到 " .. v.n .. " 点伤害", always, "可被格挡；多段攻击也只触发一次"
    end,
    mode_shift = function(v)
        local block = v.actor and v.actor.ai and v.actor.ai.shiftBlock
        return "再损失 " .. v.n .. " 点生命，就转入防守形态", "形态转换",
            block and "转换时获得 " .. number(block) .. " 点格挡" or nil
    end,
    flame_barrier = function(v)
        return "受到普通攻击时，对攻击者造成 " .. v.n .. " 点反伤", "下回合开始", "直到你的下回合开始移除；零伤害或完全格挡的攻击也触发"
    end,
    evolve = function(v)
        return "每次抽到状态牌，额外抽 " .. v.n .. " 张牌", always, "额外抽牌在当前动作之后结算；禁抽仍生效"
    end,
    fire_breathing = function(v)
        return "每次抽到状态牌或诅咒，对所有敌人造成 " .. v.n .. " 点固定伤害", always, "不受力量、虚弱和姿态影响"
    end,
    blur = function(v)
        return "接下来 " .. v.n .. " 次回合开始保留剩余格挡", "剩余 " .. v.n .. " 轮", "每轮结束减少一层"
    end,
    choked = function(v)
        return "每当你打出一张牌，此敌人失去 " .. v.n .. " 点生命", "到它下次回合开始", "无视格挡；施加勒颈的当张牌不触发新层数"
    end,
    shackled = function(v)
        return "回合结束时恢复 " .. v.n .. " 层力量", "此次回合结束", "恢复后移除"
    end,
    draw_next_turn = function(v)
        return "下回合正常抽牌后，再抽 " .. v.n .. " 张牌", "下次回合", "即使禁抽也会到期移除"
    end,
    lock_on = function(v)
        return "此目标受到的充能球伤害提高50%", "剩余 " .. v.n .. " 轮", "不提高冰霜格挡或等离子能量"
    end,
    battle_hymn = function(v)
        return "每回合抽牌前，生成 " .. v.n .. " 张惩罚", always, "加入手牌，满手时进入弃牌堆"
    end,
    collect = function(v)
        return "接下来 " .. v.n .. " 回合恢复能量时，获得一张奇迹＋", "剩余 " .. v.n .. " 次", "奇迹＋提供2能量；生成不会直接增加能量"
    end,
    energy_down = function(v)
        return "每回合开始失去 " .. v.n .. " 点能量", always, "在本回合基础能量恢复之后扣除"
    end,
    like_water = function(v)
        return "回合结束时若处于平静，获得 " .. v.n .. " 点固定格挡", always, "在保留、虚无和弃牌处理之前结算"
    end,
    study = function(v)
        return "每回合结束时，随机插入 " .. v.n .. " 张洞见到抽牌堆", always, "不等同于抽到这张牌"
    end,
    block_return = function(v)
        return "此敌人每受到一次普通攻击，你获得 " .. v.n .. " 点固定格挡", always, "零伤害或完全格挡也触发；不响应固定伤害"
    end,
    wrath_next_turn = function()
        return "下回合抽牌前进入愤怒", "下次回合开始", "随后移除"
    end,
    vigor = function(v)
        return "下一张攻击的每段普通伤害增加 " .. v.n, always, "当前攻击的所有命中都受益，之后移除"
    end,
    mark = function(v)
        return "点穴触发时失去 " .. v.n .. " 点生命", always, "每次点穴会触发所有敌人已有的印记，无视格挡"
    end,
    rupture = function(v)
        return "每次因自己作为来源的效果失去生命，获得 " .. v.n .. " 层力量", always, "每次触发加一次，不按失去的生命量倍增"
    end,
    combust = function(v)
        return "回合结束时，对所有敌人造成 " .. v.n .. " 点固定伤害", always,
            "先失去 " .. number(v.actor and v.actor.combustHpLoss or 1) .. " 点生命；失去生命致死时不再造成伤害"
    end,
    brutality = function(v)
        return "每个你的回合正常抽牌后，额外抽 " .. v.n .. " 张牌", always, "随后失去 " .. v.n .. " 点生命"
    end,
    berserk = function(v)
        return "每个你的回合开始，额外获得 " .. v.n .. " 点能量", always, "从下回合开始生效"
    end,
    energized = function(v)
        return "下回合能量恢复时，额外获得 " .. v.n .. " 点能量", "下次回合开始", "获得能量后移除"
    end,
    next_turn_block = function(v)
        return "下回合开始时，获得 " .. v.n .. " 点固定格挡", "下次回合开始", "已包含出牌时的敏捷和脆弱，不再重复计算"
    end,
    after_image = function(v)
        return "每打出一张牌，获得 " .. v.n .. " 点固定格挡", always, "在尖刺外皮的出牌反伤前获得格挡"
    end,
    thousand_cuts = function(v)
        return "每打出一张牌，对所有敌人造成 " .. v.n .. " 点固定伤害", always, "在该牌完成清理后结算"
    end,
    envenom = function(v)
        return "每次普通攻击造成未被格挡的伤害，施加 " .. v.n .. " 层中毒", always, "每段独立触发；完全格挡时不触发"
    end,
    rage = function(v)
        return "每打出一张攻击牌，获得 " .. v.n .. " 点固定格挡", "本回合", "回合结束时移除；多段攻击只触发一次"
    end,
    heat_sinks = function(v)
        return "每打出一张能力牌，抽 " .. v.n .. " 张牌", always, "抽牌先于当前能力牌的原生效果"
    end,
    storm = function(v)
        return "每打出一张能力牌，生成 " .. v.n .. " 个闪电球", always, "打出第一张雷暴时不触发自身"
    end,
    accuracy = function(v)
        return "飞刃的基础伤害增加 " .. v.n, always
    end,
    infinite_blades = function(v)
        return "每个你的回合抽牌前，获得 " .. v.n .. " 张飞刃", always, "打出能力的当回合不立即生成"
    end,
    noxious_fumes = function(v)
        return "每个你的回合抽牌后，给予所有敌人 " .. v.n .. " 层中毒", always, "从下回合开始触发"
    end,
    focus = function(v)
        return "闪电伤害、冰霜格挡与黑暗储伤增长 " .. M.signed(v.entry.amount), always, "不影响等离子能量或黑暗已有储伤"
    end,
    bias = function(v)
        return "每个你的回合开始，失去 " .. v.n .. " 点集中", always, "一层人工制品可抵挡一次完整的失去集中"
    end,
    rushdown = function(v)
        return "进入愤怒时，抽 " .. v.n .. " 张牌", always
    end,
    mental_fortress = function(v)
        return "改变姿态时，获得 " .. v.n .. " 点固定格挡", always
    end,
    nirvana = function(v)
        return "每次占卜，获得 " .. v.n .. " 点固定格挡", always, "没有可查看的牌时也会触发"
    end,
    mantra = function(v)
        return "叠加到10层时，消耗10层并进入神格", always, "当前 " .. v.n .. " 层"
    end,
    devotion = function(v)
        return "每个你的回合抽牌后，获得 " .. v.n .. " 层真言", always, "没有真言且供奉至少10层时，改为直接进入神格"
    end,
    demon_form = function(v)
        return "每个你的回合抽牌后，获得 " .. v.n .. " 层力量", always, "从下回合开始触发"
    end,
    corruption = function()
        return "使用技能不扣能量，并消耗该技能", always, "已降低的战斗费用不会因移除此能力而恢复"
    end,
    feel_no_pain = function(v)
        return "每消耗一张牌，获得 " .. v.n .. " 点固定格挡", always
    end,
    dark_embrace = function(v)
        return "每消耗一张牌，抽 " .. v.n .. " 张牌", always
    end,
    loop = function(v)
        return "每回合开始，最先唤起的球额外触发 " .. v.n .. " 次被动", always
    end,
    electrodynamics = function()
        return "闪电球的被动与唤起对所有存活敌人生效", always
    end,
}
descriptions.draw_card_next_turn = descriptions.draw_next_turn
descriptions.energized_blue = descriptions.energized

-- Returns the effect, duration tag and optional condition, naming real values.
function M.statusDetail(entry, rules, actor)
    if entry.originalV4 then return entry.description, entry.duration, "当前资源与剩余次数，按实际结算更新。" end
    local n = number(entry.amount)
    local describe = descriptions[entry.id]
    if describe then return describe({ entry = entry, combat = rules.combat, actor = actor, n = n }) end
    return entry.description, entry.stack == "none" and "" or n
end

return M
