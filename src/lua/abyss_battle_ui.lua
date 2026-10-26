-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local Events = require("abyss_events")
local Feedback = require("abyss_feedback")
local CardView = require("abyss_battle_card_view")
local M = {}
local C, L, S = Theme.color, Theme.layout, Theme.space
local reasons = { insufficient_energy = "能量不足", invalid_target = "请选择存活的敌人",
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
-- Negative Strength/Dexterity are debuffs, as the core's Artifact gate treats them.
local function statusKind(entry) return entry.amount < 0 and "debuff" or entry.kind end
local kindNames = { buff = "增益", debuff = "减益" }
local function signed(value) return (value < 0 and "-" or "+") .. number(math.abs(value)) end
-- Text only: amounts come from statusView, percentages from the shared rules.
-- Every line names the real number so players never decode "所示/等量/层数".
-- "你" is always the player; the owner is whoever's panel is open.
-- Returns the effect, how long it lasts (right of the name) and an optional condition.
local function statusDetail(entry, rules, actor)
    if entry.originalV4 then return entry.description,entry.duration,'当前资源与剩余次数，按实际结算更新。'end
    local n, c, id, always = number(entry.amount), rules.combat, entry.id, "本场战斗"
    if id == "strength" then
        local t = entry.temporary or 0
        return "普通攻击每段伤害 " .. signed(entry.amount), t ~= 0 and (t == entry.amount or entry.amount == 0) and "本回合" or always,
            t ~= 0 and "回合结束时失去 " .. number(t) .. " 层力量" or "不影响火焰药水的固定伤害"
    elseif id == "dexterity" then
        local t = entry.temporary or 0
        return "卡牌获得的格挡 " .. signed(entry.amount), t ~= 0 and (t == entry.amount or entry.amount == 0) and "本回合" or always,
            t ~= 0 and "回合结束时失去 " .. number(t) .. " 层敏捷" or "不影响固定格挡药水"
    elseif id == "vulnerable" then return "受到的普通攻击伤害 +" .. number(c.vulnerablePercent - 100) .. "%", "剩余 " .. n .. " 回合", "数字表示持续回合；不放大中毒，轮末递减"
    elseif id == "weak" then return "造成的普通攻击伤害 -" .. number(100 - c.weakPercent) .. "%", "剩余 " .. n .. " 回合", "数字表示持续回合；不减少中毒，轮末递减"
    elseif id == "frail" then return "卡牌获得的格挡 -" .. number(100 - c.frailPercent) .. "%", "剩余 " .. n .. " 回合", "只影响卡牌格挡；不影响固定格挡药水，轮末递减"
    elseif id == "poison" then return "自己的回合开始时失去 " .. n .. " 点生命", "每回合 -1", "无视格挡；随后剩 " .. number(math.max(0, entry.amount - 1)) .. " 层，减到 0 消失"
    elseif id == "regen" then return "回合结束时回复 " .. n .. " 点生命", "每回合 -1", "随后层数减 1，减到 0 消失"
    elseif id == "thievery" then return "每次攻击先窃取最多 " .. n .. " 金币", always, "完全格挡仍会失金；击败它可在战后取回，逃跑则不返还"
    elseif id == "thorns" then return "受到攻击时，对攻击者造成 " .. n .. " 点伤害", always
    elseif id == "artifact" then return "抵挡接下来 " .. n .. " 次减益效果", "剩余 " .. n .. " 次", "每抵挡一次减 1；不抵挡塞入的状态牌"
    elseif id == "entangled" then return "本回合不能打出攻击牌", "本回合", "你的回合结束时移除"
    elseif id == "barricade" then return "回合开始时格挡不会清空", always
    elseif id == "ritual" then
        if actor.id == 'player' then return "每个自己的回合结束时，获得 " .. n .. " 层力量", always, "获得它的当回合即可触发" end
        return "每个敌方回合结束时，获得 " .. n .. " 层力量", always, "获得它的那一轮不触发"
    elseif id == 'duplication' then return '接下来的 '..n..' 张牌额外使用一次',always,'每次消耗1层；轮末另减少1层；复制不会再次触发复制'
    elseif id == 'plated_armor' then return "回合结束时获得 " .. n .. " 点固定格挡", always, "受到有来源的普通攻击生命伤害时失去1层"
    elseif id == 'metallicize' then return "回合结束时获得 " .. n .. " 点固定格挡", always
    elseif id == "enrage" then return "你每打出一张技能牌，它获得 " .. n .. " 层力量", always
    elseif id == "angry" then return "每次被攻击并损失生命，获得 " .. n .. " 层力量", always, "药水、中毒和荆棘的伤害不触发"
    elseif id == "curl_up" then return "首次被攻击并损失生命后，获得 " .. n .. " 点格挡", "仅一次", "在那次攻击结束时生效"
    elseif id == "spore_cloud" then return "它倒下时，你获得 " .. n .. " 层易伤", "倒下时"
    elseif id == "sharp_hide" then return "你每打出一张攻击牌，受到 " .. n .. " 点伤害", always, "可被格挡；多段攻击也只触发一次"
    elseif id == "mode_shift" then
        local block = actor and actor.ai and actor.ai.shiftBlock
        return "再损失 " .. n .. " 点生命，就转入防守形态", "形态转换", block and "转换时获得 " .. number(block) .. " 点格挡" or nil
    elseif id=='flame_barrier' then return '受到普通攻击时，对攻击者造成 '..n..' 点反伤','下回合开始','直到你的下回合开始移除；零伤害或完全格挡的攻击也触发'
    elseif id=='evolve' then return '每次抽到状态牌，额外抽 '..n..' 张牌',always,'额外抽牌在当前动作之后结算；禁抽仍生效'
    elseif id=='fire_breathing' then return '每次抽到状态牌或诅咒，对所有敌人造成 '..n..' 点固定伤害',always,'不受力量、虚弱和姿态影响'
    elseif id=='blur' then return '接下来 '..n..' 次回合开始保留剩余格挡','剩余 '..n..' 轮','每轮结束减少一层'
    elseif id=='choked' then return '每当你打出一张牌，此敌人失去 '..n..' 点生命','到它下次回合开始','无视格挡；施加勒颈的当张牌不触发新层数'
    elseif id=='shackled' then return '回合结束时恢复 '..n..' 层力量','此次回合结束','恢复后移除'
    elseif id=='draw_next_turn' or id=='draw_card_next_turn' then return '下回合正常抽牌后，再抽 '..n..' 张牌','下次回合','即使禁抽也会到期移除'
    elseif id=='lock_on' then return '此目标受到的充能球伤害提高50%','剩余 '..n..' 轮','不提高冰霜格挡或等离子能量'
    elseif id=='battle_hymn' then return '每回合抽牌前，生成 '..n..' 张惩罚',always,'加入手牌，满手时进入弃牌堆'
    elseif id=='collect' then return '接下来 '..n..' 回合恢复能量时，获得一张奇迹＋','剩余 '..n..' 次','奇迹＋提供2能量；生成不会直接增加能量'
    elseif id=='energy_down' then return '每回合开始失去 '..n..' 点能量',always,'在本回合基础能量恢复之后扣除'
    elseif id=='like_water' then return '回合结束时若处于平静，获得 '..n..' 点固定格挡',always,'在保留、虚无和弃牌处理之前结算'
    elseif id=='study' then return '每回合结束时，随机插入 '..n..' 张洞见到抽牌堆',always,'不等同于抽到这张牌'
    elseif id=='block_return' then return '此敌人每受到一次普通攻击，你获得 '..n..' 点固定格挡',always,'零伤害或完全格挡也触发；不响应固定伤害'
    elseif id=='wrath_next_turn' then return '下回合抽牌前进入愤怒','下次回合开始','随后移除'
    elseif id=='vigor' then return '下一张攻击的每段普通伤害增加 '..n,always,'当前攻击的所有命中都受益，之后移除'
    elseif id=='mark' then return '点穴触发时失去 '..n..' 点生命',always,'每次点穴会触发所有敌人已有的印记，无视格挡'
    elseif id=='rupture' then return '每次因自己作为来源的效果失去生命，获得 '..n..' 层力量',always,'每次触发加一次，不按失去的生命量倍增'
    elseif id=='combust' then return '回合结束时，对所有敌人造成 '..n..' 点固定伤害',always,
        '先失去 '..number(actor and actor.combustHpLoss or 1)..' 点生命；失去生命致死时不再造成伤害'
    elseif id=='brutality' then return '每个你的回合正常抽牌后，额外抽 '..n..' 张牌',always,'随后失去 '..n..' 点生命'
    elseif id=='berserk' then return '每个你的回合开始，额外获得 '..n..' 点能量',always,'从下回合开始生效'
    elseif id=='energized' or id=='energized_blue' then return '下回合能量恢复时，额外获得 '..n..' 点能量','下次回合开始','获得能量后移除'
    elseif id=='next_turn_block' then return '下回合开始时，获得 '..n..' 点固定格挡','下次回合开始','已包含出牌时的敏捷和脆弱，不再重复计算'
    elseif id=='after_image' then return '每打出一张牌，获得 '..n..' 点固定格挡',always,'在尖刺外皮的出牌反伤前获得格挡'
    elseif id=='thousand_cuts' then return '每打出一张牌，对所有敌人造成 '..n..' 点固定伤害',always,'在该牌完成清理后结算'
    elseif id=='envenom' then return '每次普通攻击造成未被格挡的伤害，施加 '..n..' 层中毒',always,'每段独立触发；完全格挡时不触发'
    elseif id=='rage' then return '每打出一张攻击牌，获得 '..n..' 点固定格挡','本回合','回合结束时移除；多段攻击只触发一次'
    elseif id=='heat_sinks' then return '每打出一张能力牌，抽 '..n..' 张牌',always,'抽牌先于当前能力牌的原生效果'
    elseif id=='storm' then return '每打出一张能力牌，生成 '..n..' 个闪电球',always,'打出第一张雷暴时不触发自身'
    elseif id=="accuracy" then return "飞刃的基础伤害增加 "..n,always
    elseif id=="infinite_blades" then return "每个你的回合抽牌前，获得 "..n.." 张飞刃",always,"打出能力的当回合不立即生成"
    elseif id=="noxious_fumes" then return "每个你的回合抽牌后，给予所有敌人 "..n.." 层中毒",always,"从下回合开始触发"
    elseif id=="focus" then return "闪电伤害、冰霜格挡与黑暗储伤增长 "..signed(entry.amount),always,"不影响等离子能量或黑暗已有储伤"
    elseif id=="bias" then return "每个你的回合开始，失去 "..n.." 点集中",always,"一层人工制品可抵挡一次完整的失去集中"
    elseif id=="rushdown" then return "进入愤怒时，抽 "..n.." 张牌",always
    elseif id=="mental_fortress" then return "改变姿态时，获得 "..n.." 点固定格挡",always
    elseif id=="nirvana" then return "每次占卜，获得 "..n.." 点固定格挡",always,"没有可查看的牌时也会触发"
    elseif id=="mantra" then return "叠加到10层时，消耗10层并进入神格",always,"当前 "..n.." 层"
    elseif id=="devotion" then return "每个你的回合抽牌后，获得 "..n.." 层真言",always,"没有真言且供奉至少10层时，改为直接进入神格"
    elseif id=="metallicize" then return "每回合结束时，获得 "..n.." 点固定格挡",always
    elseif id=="demon_form" then return "每个你的回合抽牌后，获得 "..n.." 层力量",always,"从下回合开始触发"
    elseif id=="corruption" then return "使用技能不扣能量，并消耗该技能",always,"已降低的战斗费用不会因移除此能力而恢复"
    elseif id=="feel_no_pain" then return "每消耗一张牌，获得 "..n.." 点固定格挡",always
    elseif id=="dark_embrace" then return "每消耗一张牌，抽 "..n.." 张牌",always
    elseif id=="loop" then return "每回合开始，最先唤起的球额外触发 "..n.." 次被动",always
    elseif id=="electrodynamics" then return "闪电球的被动与唤起对所有存活敌人生效",always
    end
    return entry.description, entry.stack == "none" and "" or n
end
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
local function potionText(item, battle, expanded)
    local effects = {}
    for _, effect in ipairs(item.effects) do
        local value = number(effect.value or 0)
        if effect.op == "damage" then effects[#effects + 1] = expanded and "对选中敌人造成 " .. value .. " 点固定伤害，先抵消格挡；不受力量、虚弱或易伤修正" or "单敌·固定" .. value
        elseif effect.op == 'damageAll' then effects[#effects+1] = expanded and '对所有敌人造成 '..value..' 点伤害；不受力量、虚弱或易伤影响' or '全敌·伤害'..value
        elseif effect.op == "block" then effects[#effects + 1] = expanded and "立即使自己获得 " .. value .. " 点固定格挡；不受敏捷或脆弱修正" or "自用·格挡" .. value
        elseif effect.op == "energy" then effects[#effects + 1] = expanded and "立即获得 " .. value .. " 点能量，仅本回合可用" or "自用·能量" .. value
        elseif effect.op == "draw" then effects[#effects + 1] = "抽牌 " .. value
        elseif effect.op == 'upgradeHand' then effects[#effects+1]='升级全部可升级手牌（仅本场战斗）'
        elseif effect.op == 'healPercent' then effects[#effects+1]='回复最大生命'..value..'%的生命'
        elseif effect.op == 'increaseMaxHp' then effects[#effects+1]='最大生命+'..value..'，并回复'..value..'生命'
        elseif effect.op == 'exhaustMany' then effects[#effects+1]='选择任意张手牌消耗（可不选）'
        elseif effect.op == 'discardRedraw' then effects[#effects+1]='选择任意张手牌丢弃，再抽等量牌'
        elseif effect.op == 'discardToHand' then effects[#effects+1]='选择'..value..'张弃牌回手，本回合费用为0'
        elseif effect.op == 'randomizeHandCost' then effects[#effects+1]='手牌战斗费用随机改为0至3（不改变X费和不可打出牌）'
        elseif effect.op == 'escape' then effects[#effects+1]='逃离战斗，不获得奖励（Boss或背袭敌人房间不可用）'
        elseif effect.op == 'playTopCards' then effects[#effects+1]='免费打出抽牌堆顶'..value..'张牌，目标随机（不额外消耗）'
        elseif temporaryOps[effect.op] then
            local status = assert(battle.catalog.statuses[effect.status])
            effects[#effects+1] = expanded and "先获得 " .. value .. " 层" .. status.name
                .. "，再施加回合结束时失去 " .. value .. " 层的减益；人工制品可抵挡减益"
                or status.name .. "+" .. value .. "·回合末-" .. value
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            local status = assert(battle.catalog.statuses[effect.status])
            effects[#effects + 1] = (effect.op == "applyStatus" and (expanded and "对选中敌人施加 " or "单敌·") or (expanded and "使自己获得 " or "自用·"))
                .. (expanded and value .. (status.stack == "duration" and " 回合" or " 层") .. status.name or status.name .. value)
                .. (expanded and effect.status == "poison" and "；使用时不立即扣血" or "")
        end
    end
    return item.name .. "\n" .. table.concat(effects, "，")
end
-- STS shows mixed moves as one compound intent (ATTACK_DEBUFF, ATTACK_DEFEND,
-- DEFEND_BUFF...). Data keeps a single kind, so the second icon comes from the
-- effects themselves: the first effect class that differs from the kind.
local effectKinds = { damage = "attack", block = "defend", gainStatus = "buff",
    applyStatus = "debuff", makeTempCardInDiscard = "debuff" }
local function intentBadge(intent)
    for _, kind in ipairs({ "debuff", "defend", "buff", "attack" }) do
        if kind ~= intent.kind then
            for _, effect in ipairs(intent.effects or {}) do
                if effectKinds[effect.op] == kind then return kind end
            end
        end
    end
end
-- Short names written beside a non-attack intent icon; attacks show their damage instead.
local intentLabels = { defend = "防御", buff = "强化", debuff = "削弱", charge = "蓄能", sleep = "沉睡",
    stunned = "苏醒", split = "分裂", escape = "逃跑" }
-- One read of the next move: the compact face (value, icon kind, badge, label),
-- the joined sentence, and one row per effect for the detail card.
local function intentView(state, index)
    local intent = Combat.intent(state, index)
    if not intent then
        local gone = state.enemies[index] and state.enemies[index].escaped and "已逃跑" or "已击败"
        return { value = "", kind = "unknown", label = gone, text = gone, rows = {} }
    end
    local enemy = state.enemies[index]
    local function special(kind, icon, text, note)
        return { value = "", kind = icon, label = intentLabels[kind], text = text,
            rows = {{ icon = icon, colour = C.textDim, name = intentLabels[kind], text = text, note = note }} }
    end
    if intent.kind == "escape" then return special("escape", "unknown", "逃离战场，不返还已窃取的金币。") end
    if intent.kind == "charge" then return special("charge", "unknown", "本回合不攻击，正在蓄能。", "蓄满后发动攻击") end
    if intent.kind == "sleep" then return special("sleep", "sleep", "沉睡中，本回合不行动。", "损失生命就会惊醒") end
    if intent.kind == "stunned" then return special("stunned", "unknown", "刚被惊醒，本回合不行动。") end
    if intent.kind == "split" then
        local child = state.catalog.enemies[enemy.ai.splitEnemy]
        return special("split", "unknown", "分裂为两只" .. child.name .. "，各自生命等于分裂时的当前生命。")
    end
    local result, rows, attack = {}, {}, nil
    -- ApplyPower must gate each copied status before stacking it: Artifact can
    -- block an otherwise overflowing addition and is spent in effect order.
    local preview = Events.frame(state)
    preview.events = {}
    local copy, player = preview.enemies[index], preview.player
    if enemy.ai and enemy.ai.kind == "looter" and (intent.id == enemy.ai.mugIntent or intent.id == enemy.ai.lungeIntent) then
        local gold = number(enemy.ai.stealAmount)
        result[#result + 1] = "先窃取最多 " .. gold .. " 金币（完全格挡仍会失金）"
        rows[#rows + 1] = { icon = Theme.icon.gold.id, colour = C.debuff, name = "窃金 " .. gold,
            text = "先窃取你最多 " .. gold .. " 金币", note = "完全格挡仍会失金" }
    end
    local soften=state.originalV4 and require('abyss_original_v4').intentReduction(state,index) or 0
    for _, effect in ipairs(intent.effects) do
        if effect.op == "damage" or effect.op=='damageAll' then
            -- The number already includes Strength, Weak and Vulnerable on both sides.
            local amount = Combat.attackAmount(state, copy, player, effect.value)
            local times = effect.times or 1
            local hits,total,unequal={},0,false
            for hit=1,times do local cut=math.min(amount,soften);soften=soften-cut;hits[hit]=amount-cut;total=total+hits[hit]
                if hit>1 and hits[hit]~=hits[1]then unequal=true end
            end
            amount=hits[1];local each=number(amount)
            local face = each .. (times > 1 and "×" .. times or "")
            if unequal then local values={};for _,hit in ipairs(hits)do values[#values+1]=number(hit)end;face=table.concat(values,'+')end
            attack = attack or face
            result[#result + 1] = unequal and ("依次攻击 "..face.." 点伤害") or times > 1 and "攻击 " .. times .. " 次，每次 " .. each .. " 点伤害"
                or "攻击造成 " .. each .. " 点伤害"
            rows[#rows + 1] = { icon = "attack", colour = C.danger, name = "攻击 " .. face,
                tag = times > 1 and "共 " .. number(total) or nil,
                text = unequal and ("依次攻击 "..face.." 点伤害") or times > 1 and "攻击 " .. times .. " 次，每次 " .. each .. " 点伤害" or "造成 " .. each .. " 点伤害",
                note = amount ~= effect.value and "基础 " .. number(effect.value) .. "，已计入双方力量、虚弱与易伤" or nil }
        elseif effect.op == "block" then
            local amount = number(Combat.blockAmount(state, copy, effect.value, effect.target == "random_ally"))
            local ally = effect.target == "random_ally"
            result[#result + 1] = ally and "让一名随机队友获得 " .. amount .. " 点格挡（没有队友时给自己）" or "获得 " .. amount .. " 点格挡"
            rows[#rows + 1] = { icon = "defend", colour = C.block, name = "格挡 " .. amount,
                text = ally and "让一名随机队友获得 " .. amount .. " 点格挡" or "自身获得 " .. amount .. " 点格挡",
                note = ally and "没有队友时给自己" or nil }
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            local gain = effect.op == "gainStatus"
            Actors.applyPower(preview, gain and copy or player, effect.status, effect.value, copy)
            local status = assert(state.catalog.statuses[effect.status])
            local size = number(math.abs(effect.value))
            local sentence = (gain and "自身" or "使你") .. (effect.value < 0 and "失去 " or "获得 ") .. size .. (status.stack == "duration" and " 回合" or " 层") .. status.name
            result[#result + 1] = sentence
            local entry = { id = effect.status, amount = effect.value, temporary = 0, kind = status.kind,
                description = status.description, stack = status.stack }
            local kind = gain and statusKind(entry) == "buff" and "buff" or "debuff"
            rows[#rows + 1] = { icon = kind, colour = intentColors[kind],
                name = status.name .. " " .. (effect.value < 0 and signed(effect.value) or size),
                tag = status.stack == "duration" and "持续 " .. size .. " 回合" or nil,
                text = sentence, note = (statusDetail(entry, state.rules, enemy)) }
        elseif effect.op == "makeTempCardInDiscard" then
            local value = number(effect.value)
            local name = assert(state.catalog.cards[effect.card]).name
            result[#result + 1] = "将 " .. value .. " 张「" .. name .. "」放入你的弃牌堆"
            rows[#rows + 1] = { icon = "debuff", colour = C.debuff, name = "塞入「" .. name .. "」×" .. value,
                text = "将 " .. value .. " 张「" .. name .. "」放入你的弃牌堆" }
        else
            result[#result + 1] = "未知"
            rows[#rows + 1] = { icon = "unknown", colour = C.textDim, name = "未知", text = "下一步行动未知" }
        end
    end
    return { value = intent.kind == "attack" and (attack or "?") or "", kind = intent.kind, badge = intentBadge(intent),
        label = intent.kind ~= "attack" and intentLabels[intent.kind] or nil,
        text = #result > 0 and table.concat(result, "；") or "下一步行动未知。", rows = rows }
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
        local nested=name:match('^potion[45]$') or name:match('^potionHelp%d$') or name=='potionReward'
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
        local run=self.run
        if not run or run.phase~='reward' or run.rewards~=g.rewards or run.combat~=g.battle then return false end
        if g.rewardScreen ~= self.rewardScreen or g.rewardEpoch ~= self.rewardEpoch then return false end
        local rewards,potion=run.rewards,run.rewards.potion
        local item=rewards.stolenGold
        if g.manualContinue~=rewards.manualContinue or g.cards~=rewards.cards
            or #g.cardChoices~=#rewards.cards or g.item~=item
            or g.goldAmount~=(item and item.amount) or g.goldType~=(item and item.type)
            or g.normalGold ~= rewards.gold or g.goldClaimed ~= rewards.goldClaimed then return false end
        for i,id in ipairs(rewards.cards) do if g.cardChoices[i]~=id then return false end end
        if g.potion~=potion or g.potionResolved~=(potion and potion.resolved)
            or g.potionResult~=(potion and potion.result) or g.potionId~=(potion and potion.id)
            or g.potionUnavailable~=(potion and potion.unavailable) then return false end
        if rewards.manualContinue then
            -- Keep the no-loss reward owner's gesture through a pure redraw.
            -- Stolen-gold pages retain their existing explicit-redraw boundary;
            -- potion/card identity and resolution changes invalidate either page.
            if (item and g.render~=self.rewardRender) or g.item~=item or g.claimed~=(item and item.claimed)
                or g.cardResolved~=rewards.cardResolved then return false end
        end
        return true
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
    local function actionReady(g)
        local run = self.run
        if not self.active or self.busy or self.gesture or run ~= g.run then return false end
        if run and (run.phase ~= g.phase or run.combat ~= g.battle
            or g.battle and g.battle.turn ~= g.turn) then return false end
        if g.name == "start" then return not options.embedded and (not run or run.phase == "defeat") end
        if not run then return false end
        if g.name == "playArea" then
            if g.aim then return self.potionAim == g.aim and aimReady(g.aim) end
            local instance = g.battle and g.battle.hand[g.slot or 0]
            return dragReady(g) and instance and instance.uid == g.uid and self.selected == g.uid
                and self.selectionEpoch == g.selectionEpoch and not needsTarget(g.battle, instance)
        end
        if g.name == "endTurn" then return dragReady(g) end
        if run.phase == "reward" then
            if not rewardReady(g) then return false end
            if self.rewardScreen == "cards" then return g.name == "skip" and not run.rewards.cardResolved end
            if self.rewardScreen ~= "list" then return false end
            if g.name == "cardReward" then return not run.rewards.cardResolved end
            if g.name == "goldReward" then return run.rewards.goldClaimed == false end
            if g.name == "claimPotion" then
                return run.rewards.potion and not run.rewards.potion.resolved
            end
            if run.rewards.manualContinue then
                if g.name == "stolenGold" then return run.rewards.stolenGold and not run.rewards.stolenGold.claimed end
                if g.name == "continue" then return true end
            end
        end
        return g.name == "continue" and not options.embedded and run.phase == "map"
    end
    local function cancelActionInputs()
        for _, input in ipairs(actionInputs) do input.held, input.released = nil, nil end
    end
    -- Dynamic spawns can occupy an old enemy slot. Pointer ownership follows
    -- the actor object, battle and turn, never a reusable numeric slot alone.
    local enemyInputs, enemyPointerObserved = {}, false
    local function enemyReady(g)
        return not self.info and dragReady(g) and Actors.isActive(g.actor) and g.battle.enemies[g.slot] == g.actor
            and self.selected == g.uid and self.selectionEpoch == g.selectionEpoch
            and self.potionAim == g.aim and (not g.aim or aimReady(g.aim))
    end
    local D = L.cardDrag
    local function enemySlot(count, i, enemy)
        local step = count > 1 and (L.enemyRow.xTo-L.enemyRow.xFrom)/(count-1) or 0
        local badge = math.max(L.blockBadge.size, 3 * Theme.font.body + L.blockBadge.padding * 2)
        local full = L.hpBar.size[1] + badge + L.blockBadge.gap
        local x = count == 1 and (L.enemyRow.xFrom+L.enemyRow.xTo)/2 or L.enemyRow.xFrom+(i-1)*step
        local right = Theme.canvas.base[1] / 2 - Theme.canvas.safe.x
        local playerRight = L.player.position[1] + L.hpBar.size[1] / 2
        local width = math.min(full, count > 1 and step-S.s or full,
            2 * (right - x) - S.s, 2 * (x - playerRight - S.s) - S.s)
        local portrait = enemy.tier == "boss" and L.enemyRow.bossPortrait or math.min(L.enemyRow.portrait,width)
        return x, width, portrait, step
    end
    -- Targeted cards enter the docked aiming pose after crossing the line.
    -- No-target commits use the release point inside the explicit field below.
    local function dragPose(g)
        local origin, h = g.origin or {g.sx,g.sy}, L.card.size[2]*D.scale
        local x, y = origin[1]+g.x-g.sx, origin[2]+g.y-g.sy
        return x, y, y+h/2-D.commitOverlap*h >= D.lineY or g.y >= D.lineY, y < D.cancelY
    end
    -- Once armed, only pulling the card clearly back into the hand disarms it, so a
    -- wobble or release jitter near the line never turns an intended play into a cancel.
    local function arm(g)
        local _, _, crossed, back = dragPose(g)
        if crossed then g.armed = true elseif back then g.armed = false end
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
        if ok then return inPlayArea(g.x,g.y), nil end
        if reason ~= "invalid_target" then return false end
        if not g.armed then return false end
        local count = #battle.enemies
        for i, enemy in ipairs(battle.enemies) do
            local x, _, portrait, step = enemySlot(count,i,enemy)
            local reach = math.min(D.targetColumn,count > 1 and step or D.targetColumn)/2
            if math.abs(g.x-x) <= math.min(reach,portrait/2+D.reticlePad)
                and math.abs(g.y-L.enemyRow.y) <= portrait/2+D.reticlePad
                and Combat.canPlay(battle,g.uid,i) then
                return true, i, true
            end
        end
        return false, nil, true
    end
    local function button(name, enabled, primary, caption)
        local box = child(name)
        box.interactable = enabled == true
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
        local cancelled = cancelPotionAim("已取消药水瞄准。") or self.gesture ~= nil
        cancelCardInputs()
        cancelPotionInputs()
        cancelActionInputs()
        for _, input in ipairs(enemyInputs) do input.held, input.released = nil, nil end
        if cancelled then self.gesture, self.selected, self.suppressClick = nil, nil, true end
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
    local function unit(box, actor, portrait, icon, width, selected)
        local bh = L.hpBar.size[2]
        for _, name in ipairs({"plate", "border", "portrait"}) do
            local delta = name == "border" and S.border * 2 or name == "portrait" and -S.l or 0
            box:GetChild(name):SetSizeDelta(portrait + delta, portrait + delta)
        end
        box:GetChild("hit"):SetSizeDelta(portrait, portrait)
        box:GetChild("impact"):SetSizeDelta(portrait, portrait)
        box:GetChild("shield"):SetSizeDelta(portrait, portrait)
        box:GetChild("floating"):SetSizeDelta(width + S.xl, L.nativeText.lineHeight * 2)
        picture(box:GetChild("portrait"), icon)
        tint(box:GetChild("portrait"), box.name == "hero" and C.geo or C.text)
        tint(box:GetChild("border"), selected and C.goldBright or C.line)
        box:GetChild("name").text = actor.name or "旅行者"
        box:GetChild("name"):SetAnchoredPosition(0, -portrait / 2 - S.m)
        box:GetChild("name"):SetSizeDelta(width, L.nativeText.lineHeight)
        -- Block always sits beside the health bar's left end; enemy columns
        -- reserve space for both rather than relocating guard onto the portrait.
        -- Native digits can occupy a full glyph: the fixed 28px chip cut
        -- Block 10 down to "1". Widen the chip, never shrink away its digits.
        local blocked, gap = actor.block > 0, L.blockBadge.gap
        local chip = math.max(L.blockBadge.size, #number(actor.block) * Theme.font.body + L.blockBadge.padding * 2)
        local hpText = number(actor.hp) .. "/" .. number(actor.maxHp)
        local barWidth, barX, y = width, 0, -portrait / 2 - S.xxl - bh / 2
        if box.name ~= "hero" then
            -- Reserve the same three-digit guard lane even with zero Block:
            -- gaining/losing Block must never move or resize the health bar.
            local reserve = math.max(L.blockBadge.size, 3 * Theme.font.body + L.blockBadge.padding * 2) + gap
            barWidth, barX = math.min(L.hpBar.size[1], width - reserve), reserve / 2
        end
        for _, name in ipairs({"hpBorder", "hpTrack", "hpGhost", "hpFill", "hp"}) do
            local part = box:GetChild(name)
            part:SetAnchoredPosition(barX, y)
            local height = name == "hp" and L.nativeText.lineHeight or bh + (name == "hpBorder" and S.border * 2 or 0)
            part:SetSizeDelta(barWidth + (name == "hpBorder" and S.border * 2 or 0), height)
        end
        tint(box:GetChild("hpBorder"), blocked and C.block or C.line)
        tint(box:GetChild("hpFill"), blocked and C.hpShielded or C.hp)
        box:GetChild("hpFill").fillAmount = math.max(0, math.min(1, actor.hp / actor.maxHp))
        box:GetChild("hpGhost").fillAmount = box:GetChild("hpFill").fillAmount
        box:GetChild("hp").text = hpText
        for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
            local part = box:GetChild(name)
            part:SetVisible(blocked)
            local side = name == "blockEdge" and chip + S.border * 2 or chip
            local height = L.blockBadge.size + (name == "blockEdge" and S.border * 2 or 0)
            part:SetSizeDelta(side, name == "block" and L.nativeText.lineHeight or height)
            part:SetAnchoredPosition(barX - barWidth / 2 - gap - chip / 2, y)
        end
        tint(box:GetChild("blockEdge"), C.panelSunken)
        tint(box:GetChild("blockIcon"), C.block)
        ink(box:GetChild("block"), C.textOnLight)
        box:GetChild("block").text = number(actor.block)
        -- Status chips: rows centred under the bar; the last slot turns into "+N" on overflow.
        local si, entries, row = L.statusIcon, Combat.statusView(actor), box:GetChild("statusRow")
        local pitch = si.size + si.gap
        local perRow = math.max(1, math.min(si.perRow, math.floor((width + si.gap) / pitch)))
        local slots = perRow * si.rows
        local shown = math.min(#entries, slots)
        row:SetAnchoredPosition(0, -portrait / 2 - S.xxl - bh - S.l - (si.rows - 1) * pitch / 2)
        row:GetChild("hit"):SetSizeDelta(width, si.rows * pitch)
        for i = 1, si.perRow * si.rows do
            local statusImage, count, entry = row:GetChild("icon" .. i), row:GetChild("count" .. i), i <= shown and entries[i]
            local target = row:GetChild("hit" .. i)
            target:SetVisible(entry and true or false)
            local overflow = entry and i == slots and #entries > slots
            statusImage:SetVisible(entry and not overflow or false)
            count:SetVisible(entry and true or false)
            if entry then
                local k = i - 1
                local line = math.floor(k / perRow)
                local x = (k % perRow - (math.min(perRow, shown - line * perRow) - 1) / 2) * pitch
                local statusY = (si.rows - 1) * pitch / 2 - line * pitch
                statusImage:SetAnchoredPosition(x, statusY)
                target:SetAnchoredPosition(x, statusY)
                picture(statusImage, Theme.icon.status[entry.icon or entry.id])
                tint(statusImage, statusKind(entry) == "buff" and C.buff or C.debuff)
                if overflow then
                    count:SetAnchoredPosition(x, statusY)
                    count.text = "+" .. (#entries - slots + 1)
                    ink(count, C.textDim)
                else
                    count:SetAnchoredPosition(x + si.size / 2, statusY - si.size / 2 + si.gap)
                    count.text = entry.stack == "none" and "" or number(entry.amount)
                    ink(count, C.text)
                end
            end
        end
    end
    -- Lines a left-aligned small-font sentence takes in the card's text column.
    -- CJK glyphs are one font size wide, digits and Latin about half.
    local function lines(text)
        if not text or text == "" then return 0 end
        local I, width = L.statusInfo, 0
        -- Bytes, not the utf8 library: ASCII ~half a glyph, each multi-byte lead one glyph.
        for i = 1, #text do
            local b = text:byte(i)
            width = width + (b < 128 and 0.55 or b >= 192 and 1 or 0)
        end
        local per = math.floor((I.width - I.pad * 2 - I.icon - I.gap) / Theme.font.small)
        return math.max(1, math.ceil(width / per))
    end
    -- The detail card for one unit, intent or card: a header, then sections of rows.
    -- Statuses group buffs before debuffs; every row is name + duration, effect, condition.
    local function describeInfo(battle, info, actor)
        local entries = Combat.statusView(actor)
        local card = { title = actor.name or "旅行者", tag = "当前状态", accent = C.gold,
            hp = actor.hp, maxHp = actor.maxHp, block = actor.block, sections = {} }
        local function statusRow(entry)
            local text, tag, note = statusDetail(entry, battle.rules, actor)
            local kind = statusKind(entry)
            return { status = entry.id, icon = Theme.icon.status[entry.icon or entry.id], colour = kind == "buff" and C.buff or C.debuff, tag = tag, text = text, note = note,
                name = entry.name .. (entry.stack == "none" and "" or " " .. number(entry.amount)) }
        end
        if info.kind == "intent" then
            local view = intentView(battle, info.index)
            card.tag, card.accent, card.hp = "下一步行动", intentColors[view.kind] or C.textDim, nil
            card.subtitle = "尚未执行 · 敌方回合时发生"
            card.sections[1] = { rows = view.rows }
            return card
        elseif info.kind == "card" or info.kind == "potion" then
            local instance
            for _, held in ipairs(battle.hand) do if held.uid == info.uid then instance = held break end end
            local definition, rows
            if info.kind == "potion" then
                if self.run.potions ~= info.inventory or self.run.potions[info.slot] ~= info.potionId then return end
                for _, item in ipairs(data.potions.potions) do if item.id == info.potionId then definition = item break end end
                if not definition then return end
                rows = {{name = definition.name, text = potionText(definition, battle, true):match("\n(.*)"),
                    note = definition.targetPolicy == "enemy_one" and "对选中的一名敌人；先选药水，再点击敌人" or "对自己使用；短按药水生效", colour = C.goldBright}}
            else
                if not instance then return end
                definition, rows = Combat.cardDefinition(battle, instance), {}
            end
            local function keywords(effects)
                for _, effect in ipairs(effects) do
                    local id = effect.status or effect.op == "gainTemporaryStrength" and "strength"
                    local status = id and battle.catalog.statuses[id]
                    if status then
                        local row = statusRow({id = id, name = status.name, amount = effect.value, temporary = temporaryOps[effect.op] and effect.value or 0,
                            kind = status.kind, description = status.description, stack = status.stack})
                        -- A keyword is not on anyone yet: say how long it would last, not what remains.
                        if status.stack == "duration" then row.tag = "持续 " .. number(effect.value) .. " 回合" end
                        rows[#rows + 1] = row
                    end
                    if effect["then"] then keywords(effect["then"]) end
                end
            end
            if definition.originalV4 then
                local full=require('abyss_original_v4_display').describe(definition,instance.upgraded)
                local preview=Combat.cardPreview(battle,instance,self.target)
                if preview.text and preview.text~=''then full=full..'\n'..preview.text end
                local chunk,index='',0
                local function flush()
                    if chunk~=''then index=index+1;rows[#rows+1]={name='完整效果 '..index,text=chunk,colour=C.goldBright,icon=Theme.icon.cardArt[definition.type]};chunk=''end
                end
                for glyph in full:gmatch('[%z\1-\127\194-\244][\128-\191]*')do
                    if lines(chunk..glyph)>2 then flush()end
                    chunk=chunk..glyph
                end
                flush()
            end
            keywords(definition.effects)
            if definition.exhaust then rows[#rows + 1] = {icon = Theme.icon.exhaust, colour = C.goldBright, name = "消耗",
                text = "打出后移出本场战斗", note = "不进入弃牌堆"} end
            if definition.ethereal then rows[#rows + 1] = {intent = "unknown", colour = C.goldBright, name = "虚无",
                text = "回合结束时若仍在手中，将被消耗"} end
            if #rows == 0 then return end
            card.title, card.tag, card.hp = info.kind == "potion" and definition.name or presentation[instance.cardId].name, "关键词", nil
            card.subtitle = info.kind == "potion" and "药水说明，尚未使用 · 查看不消耗" or "卡牌效果说明，尚未生效"
            card.sections[1] = { rows = rows }
            return card
        elseif info.statusId then
            local selected
            for _, entry in ipairs(entries) do if entry.id == info.statusId then selected = entry break end end
            if not selected then return end
            entries = {selected}
        elseif info.offset then
            local remaining = {}
            for i = info.offset, #entries do remaining[#remaining + 1] = entries[i] end
            entries = remaining
        end
        if actor==battle.player and not info.statusId and not info.offset then
            if battle.originalV4 then
                local rows={}
                for line in require('abyss_original_v4_display').summary(battle):gmatch('[^\n]+')do
                    rows[#rows+1]={name='当前资源',text=line,colour=C.gold,icon=Theme.icon.cardArt.skill}
                end
                card.title=battle.originalV4Rules and battle.originalV4Rules.roles[battle.originalV4.role].name or '角色资源'
                card.sections[#card.sections+1]={label='角色资源与剩余次数',colour=C.gold,rows=rows}
            end
            if self.run and self.run.characterProfile and self.run.characterProfile.id=="silent" then
                card.sections[#card.sections+1]={label="弃牌",colour=C.gold,rows={
                    {name="本回合弃牌 "..number(battle.discardedThisTurn or 0),text="弃牌可触发退费，或降低部分牌本回合的费用。",
                        colour=C.gold,icon=Theme.icon.cardArt.skill}}}
            end
            if actor.stance and (self.run and self.run.character=='watcher' or actor.stanceKnown or actor.stance~='Neutral') then
                local stance=actor.stance
                local text=stance=="Wrath" and "普通攻击造成与受到的伤害均翻倍。"
                    or stance=="Calm" and "离开平静时获得2点能量。"
                    or stance=="Divinity" and "普通攻击伤害为3倍；下个你的回合开始退出。"
                    or "当前没有姿态的伤害修正。"
                card.sections[#card.sections+1]={label="姿态",colour=C.gold,rows={
                    {name=stanceNames[stance],text=text,colour=C.gold,icon=Theme.icon.cardArt.power}}}
            end
            if battle.orbs and (self.run and self.run.character=='defect' or battle.orbs.slots>0 or #battle.orbs.balls>0) then
                local view=require("abyss_orbs").view(battle)
                local rows={{name="球位 "..#view.balls.." / "..view.slots,text="左侧序号最先被唤起；集中 "..number(view.focus).."。",
                    colour=C.gold,icon=Theme.icon.cardArt.power}}
                for i,ball in ipairs(view.balls) do
                    local passive=ball.kind=="dark" and "储伤增长 " or ball.kind=="frost" and "格挡 " or ball.kind=="plasma" and "能量 " or "伤害 "
                    rows[#rows+1]={name=i.." · "..orbNames[ball.kind],text="被动："..passive..number(ball.passive).."；唤起："..number(ball.evoke),
                        colour=C.gold,icon=Theme.icon.cardArt.power}
                end
                card.sections[#card.sections+1]={label="充能球（按唤起顺序）",colour=C.gold,rows=rows}
            end
        end
        for _, kind in ipairs({"buff", "debuff"}) do
            local rows = {}
            for _, entry in ipairs(entries) do if statusKind(entry) == kind then rows[#rows + 1] = statusRow(entry) end end
            if #rows > 0 then card.sections[#card.sections + 1] = { label = kindNames[kind], colour = kind == "buff" and C.buff or C.debuff, rows = rows } end
        end
        if #card.sections == 0 then card.empty = "暂无状态" end
        return card
    end
    -- Split sections into pages that fit under the top bar; a section continuing
    -- onto the next page repeats its label so every row keeps its group.
    local function paginate(card)
        local I = L.statusInfo
        local room = Theme.canvas.base[2] - L.topBar.height - S.s - Theme.canvas.safe.y
        local budget = room - I.pad * 2 - I.header - I.summary - I.divider - I.footer
        local pages, page, used = {}, nil, 0
        local function open() page = {items = {}, rows = 0, sections = 0}; pages[#pages + 1] = page; used = 0 end
        open()
        for _, section in ipairs(card.sections) do
            local labelled, continued = false, false
            for _, row in ipairs(section.rows) do
                row.textLines, row.noteLines = lines(row.text), lines(row.note)
                local height = I.name + (row.textLines + row.noteLines) * I.line + I.entryGap
                local head = section.label and not labelled and I.section or 0
                if page.rows > 0 and (page.rows >= I.rows or used + head + height > budget
                    or head > 0 and page.sections >= I.sections) then
                    open(); continued, labelled = labelled, false
                end
                if section.label and not labelled then
                    page.items[#page.items + 1] = {label = section.label .. (continued and "（续）" or ""), colour = section.colour}
                    page.sections, used, labelled = page.sections + 1, used + I.section, true
                end
                page.items[#page.items + 1] = {row = row}
                page.rows, used = page.rows + 1, used + height
            end
        end
        return pages
    end
    -- Shared detail card beside its unit. Rows show every status with its current effect;
    -- more than a page turns with a tap on the card, a tap elsewhere closes it.
    local function renderInfo(battle)
        local panel, info = child("statusInfo"), self.info
        local actor = info and battle and (info.index == 0 and battle.player or battle.enemies[info.index])
        local card = actor and actor.id == info.id and Actors.isActive(actor) and describeInfo(battle, info, actor)
        if not card then
            self.info = nil
            panel:SetVisible(false)
            return
        end
        local I = L.statusInfo
        local pages = paginate(card)
        info.page = math.max(1, math.min(info.page or 1, #pages))
        info.pages = #pages
        local page = pages[info.page]
        local footer = not info.transient and (#pages > 1 and "第 " .. info.page .. "/" .. #pages .. " 页 · 点按卡片翻页"
            or "点按任意处关闭") or #pages > 1 and "共 " .. #pages .. " 页 · 点击查看全部" or nil
        local body = card.empty and I.section or 0
        for _, item in ipairs(page.items) do
            body = body + (item.label and I.section or I.name + (item.row.textLines + item.row.noteLines) * I.line + I.entryGap)
        end
        local height = I.pad * 2 + I.header + I.summary + I.divider + body + (footer and I.footer or 0)
        local x, portrait
        if info.index == 0 then
            x, portrait = L.player.position[1], L.player.portrait
            x = x + portrait / 2 + S.l + I.width / 2
        else
            local enemyX, _, size = enemySlot(#battle.enemies, info.index, actor)
            x, portrait = enemyX - size / 2 - S.l - I.width / 2, size
        end
        local edge = Theme.canvas.base[1] / 2 - Theme.canvas.safe.x - I.width / 2
        x = math.max(-edge, math.min(edge, x))
        local top = Theme.canvas.base[2] / 2 - L.topBar.height - S.s
        -- Top edge level with the portrait's top, kept under the top bar and above the safe edge.
        local unitY = info.index == 0 and L.player.position[2] or L.enemyRow.y
        local y = math.min(top - height / 2, unitY + portrait / 2 - height / 2)
        y = math.max(-Theme.canvas.base[2] / 2 + Theme.canvas.safe.y + height / 2, y)
        local function place(name, px, py, w, h)
            local part = panel:GetChild(name)
            part:SetAnchoredPosition(px, py)
            if w then part:SetSizeDelta(w, h) end
            return part
        end
        place("shadow", x + S.s, y - S.s, I.width + S.border * 2, height + S.border * 2)
        place("border", x, y, I.width + S.border * 2, height + S.border * 2)
        place("plate", x, y, I.width, height)
        place("page", x, y, I.width, height)
        tint(place("accent", x, y + height / 2 - I.accent / 2, I.width, I.accent), card.accent)
        local line, inner = L.nativeText.lineHeight, I.width - I.pad * 2
        local left, right, cursor = x - I.width / 2 + I.pad, x + I.width / 2 - I.pad, y + height / 2 - I.pad
        local title = place("title", left + (inner - I.tagWidth) / 2, cursor - I.header / 2)
        title.text = card.title
        local tag = place("tag", right - I.tagWidth / 2, cursor - I.header / 2)
        tag.text = card.tag
        ink(tag, card.accent)
        cursor = cursor - I.header
        -- Vitals first for units; intent and keyword cards say they have not happened yet.
        local mid, glyph = cursor - I.summary / 2, Theme.font.label
        local summary = panel:GetChild("summary")
        for _, name in ipairs({"hpIcon", "blockIcon", "guard"}) do panel:GetChild(name):SetVisible(card.hp ~= nil) end
        if card.hp then
            place("hpIcon", left + glyph / 2, mid)
            place("summary", left + glyph + S.xs + (inner / 2 - glyph - S.xs) / 2, mid, inner / 2 - glyph - S.xs, line)
            summary.text = "生命 " .. number(card.hp) .. "/" .. number(card.maxHp)
            ink(summary, C.text)
            place("blockIcon", left + inner / 2 + glyph / 2, mid)
            local guard = place("guard", left + inner / 2 + glyph + S.xs + (inner / 2 - glyph - S.xs) / 2, mid, inner / 2 - glyph - S.xs, line)
            guard.text = "格挡 " .. number(card.block)
            ink(guard, card.block > 0 and C.block or C.textMuted)
            tint(panel:GetChild("blockIcon"), card.block > 0 and C.block or C.textMuted)
        else
            place("summary", x, mid, inner, line)
            summary.text = card.subtitle
            ink(summary, C.textDim)
        end
        cursor = cursor - I.summary
        place("rule", x, cursor - I.divider / 2)
        cursor = cursor - I.divider
        local sectionCount, rowCount = 0, 0
        if card.empty then
            sectionCount = 1
            local label = place("section1", x + S.xs + S.s, cursor - I.section / 2)
            label.text = card.empty
            ink(label, C.textMuted)
            panel:GetChild("sectionMark1"):SetVisible(false)
            panel:GetChild("section1"):SetVisible(true)
            cursor = cursor - I.section
        end
        local textX = left + I.icon + I.gap + (inner - I.icon - I.gap) / 2
        for _, item in ipairs(page.items) do
            if item.label then
                sectionCount = sectionCount + 1
                local mark = place("sectionMark" .. sectionCount, left + S.xs / 2, cursor - I.section / 2)
                local label = place("section" .. sectionCount, x + S.xs + S.s, cursor - I.section / 2)
                tint(mark, item.colour)
                label.text = item.label
                ink(label, item.colour)
                mark:SetVisible(true) label:SetVisible(true)
                cursor = cursor - I.section
            else
                rowCount = rowCount + 1
                local row, i = item.row, rowCount
                local icon = place("icon" .. i, left + I.icon / 2, cursor - I.name / 2)
                picture(icon, row.icon and type(row.icon) == "number" and row.icon
                    or row.status and Theme.icon.status[row.status]
                    or Theme.icon.intent[row.icon or row.intent] or Theme.icon.intent.unknown)
                tint(icon, row.colour)
                local name = place("name" .. i, textX, cursor - I.name / 2)
                name.text = row.name
                ink(name, row.colour)
                local rowTag = place("tag" .. i, right - I.tagWidth / 2, cursor - I.name / 2)
                rowTag.text = row.tag or ""
                cursor = cursor - I.name
                local text = place("text" .. i, textX, cursor - row.textLines * I.line / 2,
                    inner - I.icon - I.gap, math.max(line, row.textLines * I.line + I.line))
                text.text = row.text
                cursor = cursor - row.textLines * I.line
                local note = place("note" .. i, textX, cursor - row.noteLines * I.line / 2,
                    inner - I.icon - I.gap, math.max(line, row.noteLines * I.line + I.line))
                note.text = row.note or ""
                cursor = cursor - row.noteLines * I.line - I.entryGap
                for _, part in ipairs({icon, name, rowTag, text, note}) do part:SetVisible(true) end
                note:SetVisible(row.note ~= nil)
            end
        end
        for i = sectionCount + 1, I.sections do
            panel:GetChild("sectionMark" .. i):SetVisible(false)
            panel:GetChild("section" .. i):SetVisible(false)
        end
        for i = rowCount + 1, I.rows do
            for _, name in ipairs({"icon", "name", "tag", "text", "note"}) do panel:GetChild(name .. i):SetVisible(false) end
        end
        local more = panel:GetChild("more")
        more:SetVisible(footer ~= nil)
        more:SetAnchoredPosition(x, y - height / 2 + I.pad + I.footer / 2)
        more.text = footer or ""
        panel:SetVisible(true)
        panel:GetChild("hit"):SetVisible(not info.transient)
        panel:GetChild("page"):SetVisible(not info.transient)
        panel.disableCursorEventPassthrough = not info.transient
        panel:SetAsLastSibling()
    end
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
        if not Actors.isActive(actor) then return false end
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
        if not actor or actor.hp<=0 then return false end
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
        if not actor or actor.hp<=0 then return end
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
    local function placeCard(box, count, index, selected)
        local w, h = L.card.size[1], L.card.size[2]
        local spacing = count <= 1 and 0 or math.max(L.hand.spacingMin, math.min(L.hand.spacingMax, (L.hand.maxWidth - w) / (count - 1)))
        local distance = index - (count - 1) / 2
        local angle = -distance * L.hand.arcDegrees
        local radians = math.abs(angle) * math.pi / 180
        local halfHeight = (h * math.cos(radians) + w * math.sin(radians)) / 2
        local floor = -Theme.canvas.base[2] / 2 + Theme.canvas.safe.y + halfHeight
        local x, y = distance * spacing, math.max(floor, L.hand.y - math.abs(distance) * L.hand.arcDrop) + (selected and Theme.motion.hoverLift or 0)
        box:SetAnchoredPosition(x, y)
        local scale = selected and Theme.motion.hoverScale or 1
        box:SetLocalScale(scale, scale, 1)
        box.localRotationZ = selected and 0 or angle
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
        child = child, show = show, ink = ink, tint = tint, picture = picture,
        placeCard = placeCard, placeReward = placeReward,
        dragTarget = dragTarget, dragPose = dragPose, enemySlot = enemySlot,
    })
    function self:setHover(slot)
        local run = self.run
        if slot and not (self.active and not self.busy and run and run.phase == "reward"
            and self.rewardScreen == "cards" and Run.rewardOptions(run)[slot]) then slot = nil end
        if self.hover == slot then return end
        self.hover = slot
        self:render(true)
    end
    function self:render(presentationOnly)
        -- Reward entrance/hover animation cannot revoke a finger's live Down.
        -- Explicit redraws do; authoritative run/reward/item checks always apply.
        if not presentationOnly then self.rewardRender = (self.rewardRender or 0) + 1 end
        local run = self.run
        if self.potionAim and not aimReady(self.potionAim) then cancelPotionAim("药水瞄准已失效，已取消；请重新选择药水。") end
        if self.gesture and not cardReady(self.gesture) then
            self.gesture, self.selected, self.suppressClick = nil, nil, true
        end
        for _, input in ipairs(cardInputs) do
            if input.held and not cardReady(input.held) then input.held = nil end
            if input.released and not cardReady(input.released) then input.released = nil end
        end
        for _, input in ipairs(potionInputs) do
            if input.held and not potionReady(input.held) then input.held = nil end
            if input.released and not potionReady(input.released) then input.released = nil end
        end
        for _, input in ipairs(actionInputs) do
            if input.held and not actionReady(input.held) then input.held = nil end
            if input.released and not actionReady(input.released) then input.released = nil end
        end
        for _, input in ipairs(enemyInputs) do
            if input.held and not enemyReady(input.held) then input.held = nil end
            if input.released and not enemyReady(input.released) then input.released = nil end
        end
        if self.busy and self.feedback and (self.feedbackRun ~= run or self.feedbackBattle ~= (run and run.combat)) then
            self.feedback:cancel() return
        end
        if self.viewRun ~= run then
            self.viewRun, self.target, self.selected = run, 1, nil
            self.potionRun, self.potionBattle, self.potionSlots = nil, nil, nil
            playbackIntents = nil
        end
        -- A Run survives between encounters, but its combat and enemy indices do not.
        -- Use the committed combat identity, never transient playback frame tables.
        local currentBattle = run and run.combat
        if self.viewBattle ~= currentBattle then
            self.viewBattle, self.target, self.selected = currentBattle, 1, nil
            playbackIntents = nil
        end
        local fighting = self.displayBattle ~= nil or run and run.phase == "combat"
        local battle = self.displayBattle or fighting and run.combat
        if self.displayBattle and battle.originalV4 then
            -- Playback owns detached mutable frames. Borrow only immutable rules
            -- for card targets/costs; a presentation frame is not a playable state.
            battle.originalV4Rules=self.feedbackBattle.originalV4Rules
        end
        local enemyPlayback = self.busy and self.displayBattle and battle.phase == "enemy"
        if not enemyPlayback then playbackIntents = nil end
        local reward = not self.busy and run and run.phase == "reward"
        if reward and (self.rewardOwner ~= run.rewards or self.rewardRun ~= run) then
            self.rewardOwner, self.rewardRun, self.rewardNotice = run.rewards, run, ""
            rewardScreen("list")
        elseif not reward then
            if self.rewardScreen then label("notice", "") end
            self.rewardOwner, self.rewardRun, self.rewardNotice = nil, nil, nil
            rewardScreen(nil)
        end
        local picking = reward and self.rewardScreen == "cards"
        local listing = reward and self.rewardScreen == "list"
        if not reward then self.hover = nil end
        -- A new reward object restarts the entrance so cards rise into place.
        if picking and (not self.rewardView or self.rewardView.rewards ~= run.rewards) then
            self.rewardView = {rewards = run.rewards, cards = {}}
            for i = 1, 10 do self.rewardView.cards[i] = {scale = R.scale * R.enterScale, lift = 0, rise = -R.enterRise} end
        elseif not picking then self.rewardView = nil end
        local active = self.active and fighting and battle.phase == "player" and not self.busy
        -- Validation stages potion transactions; do it once while input is available,
        -- never copy the event journal once per animation step.
        local potions = self.busy and self.potionViewCache or fighting and Run.potionView(run) or {}
        if not self.busy then self.potionViewCache = potions end
        local potionCapacity=run and Run.potionCapacity(run) or 0
        self.potionTargetAvailable = false
        for slot = 1, potionCapacity do
            local item = potions[slot]
            if active and item and item.canUse and item.needTarget then self.potionTargetAvailable = true break end
        end
        show("start", not self.busy and not options.embedded and (not run or run.phase == "defeat"))
        button("start", self.active, true, run and "重新启程" or "启程")
        show("endTurn", fighting)
        local manual = listing and run.rewards.manualContinue
        local stolen = manual and run.rewards.stolenGold
        local potionReward=listing and run.rewards.potion
        local pendingPotion=potionReward and not potionReward.resolved
        show("skip", picking and not run.rewards.cardResolved)
        show("continue", manual or not options.embedded and run and run.phase == "map")
        child("skip"):SetAnchoredPosition(R.skip[1], R.skip[2])
        child("continue"):SetAnchoredPosition(manual and L.battleRewards.continue[1] or 0,
            manual and L.battleRewards.continue[2] or -S.xxl * 3)
        local row = 0
        local function rewardRow(name, visible)
            show(name, visible == true)
            if visible then
                child(name):SetAnchoredPosition(L.battleRewards.rowOrigin[1], L.battleRewards.rowOrigin[2] - row * L.battleRewards.rowStep)
                row = row + 1
            end
        end
        rewardRow("goldReward", listing and not run.rewards.goldClaimed)
        rewardRow("stolenGold", stolen and not stolen.claimed)
        rewardRow("claimPotion", pendingPotion)
        rewardRow("cardReward", listing and not run.rewards.cardResolved)
        show("potionReward", pendingPotion == true)
        button("goldReward", self.active and listing and run.rewards.goldClaimed == false, false,
            listing and number(run.rewards.gold) .. " 金币" or "金币")
        button("cardReward", self.active and listing and not run.rewards.cardResolved, false, "选择一张卡牌加入牌组")
        -- A full belt keeps the row clickable: its rejection explains how to free a slot.
        button("claimPotion", self.active and pendingPotion == true and not potionReward.unavailable, false)
        if potionReward then
            local definition
            for _,item in ipairs(data.potions.potions) do if item.id==potionReward.id then definition=item;break end end
            local detail=potionReward.unavailable and (potionReward.rarity.." 药水尚未实装")
                or (definition and potionText(definition,run.combat):gsub("\n", " · ") .. " · ×1" or "药水 ×1")
            button("claimPotion", self.active and pendingPotion == true and not potionReward.unavailable, false, detail)
            label("potionReward", potionReward.unavailable and "该稀有度药水尚未实装；可继续前往地图。"
                or Run.potionCount(run)>=Run.potionCapacity(run)
                    and "药水槽已满；点顶部药水入口丢弃旧药水后，再点击奖励领取。" or "")
        end
        show("rewardStage", picking)
        show("rewardList", listing)
        show("notice", not reward)
        if listing then
            child("rewardList"):GetChild("subtitle").text = self.rewardNotice ~= "" and self.rewardNotice
                or (row == 0 and "奖励已领取" or "点击条目领取奖励")
        end
        local fieldSelected = false
        if active and not self.gesture then
            for _,instance in ipairs(battle.hand) do
                if instance.uid == self.selected and not needsTarget(battle,instance) then fieldSelected = true break end
            end
        end
        show("playArea", fieldSelected or active and self.potionAim ~= nil)
        child("playArea"):GetChild("label").text = self.potionAim and "点击空白处取消药水瞄准" or "出牌区域 · 点击出牌"
        -- The battle HUD (energy, piles) belongs to playing cards; clear it while choosing a reward.
        for _, name in ipairs({"energyRing", "energyDisc", "energyIcon", "energy", "drawIcon", "drawBadgeRing", "drawBadge",
            "draw", "drawLabel", "discardIcon", "discardBadgeRing", "discardBadge", "discard", "discardLabel"}) do
            show(name, not reward)
        end
        show("result", not fighting and not reward) show("resultPlate", not fighting and not reward)
        show("hero", fighting)
        local player = battle and battle.player
        label("player", number(player and player.hp or run and run.hp or data.rules.player.maxHp) .. "/" .. number(run and run.maxHp or data.rules.player.maxHp))
        label("piles", number(player and player.gold or run and run.gold or 0))
        -- The top bar names the scene, never the game: floor and fight kind.
        local flow = run and run.nodeFlow
        local fightKind = flow and ({ elite = "精英战斗", boss = "首领战斗" })[flow.type] or "战斗"
        local heading=flow and flow.floor and ("第 " .. flow.floor .. " 层 · " .. fightKind) or fightKind
        if player and player.stance and (run and run.character=='watcher' or player.stanceKnown or player.stance~='Neutral') then
            heading=heading.." · "..stanceNames[player.stance]
        end
        if battle and battle.orbs and (run and run.character=='defect' or battle.orbs.slots>0 or #battle.orbs.balls>0) then
            heading=heading.." · 球 "..#battle.orbs.balls.."/"..battle.orbs.slots
        end
        if battle and run and run.characterProfile and run.characterProfile.id=="silent" then
            heading=heading.." · 弃 "..number(battle.discardedThisTurn or 0)
        end
        if battle and battle.originalV4 then heading=heading..' · '..require('abyss_original_v4_data').rules.roles[battle.originalV4.role].name end
        label("title",heading)
        label("exhaust", battle and tostring(#battle.exhaust) or "0")
        label("energy", number(battle and battle.energy or 0) .. "/" .. number(data.rules.player.energyPerTurn))
        local charged = battle and battle.energy > 0
        tint(child("energyDisc"), charged and C.energy or C.energyEmpty)
        tint(child("energyIcon"), charged and C.geo or C.geoDeep)
        -- Dark digits on amber, light digits once the orb is spent; both stay readable.
        ink(child("energy"), charged and C.textOnLight or C.text)
        label("draw", battle and tostring(#battle.draw) or "0") label("discard", battle and tostring(#battle.discard) or "0")
        -- Turn state shows only while the player cannot act; a live hand already says "your turn".
        label("statuses", fighting and battle.phase ~= "player" and not self.busy and "敌方回合" or "")
        if fighting then unit(child("hero"), player, L.player.portrait, Theme.icon.player, L.hpBar.size[1], false) end
        if not run then label("result", "战斗演练\n点击启程，试用旅行者的初始牌组")
        elseif reward then
            child("rewardStage"):GetChild("title").text = "选择一张卡牌"
            child("rewardStage"):GetChild("subtitle").text = "点击卡牌加入牌组，或跳过返回奖励列表"
        elseif run.phase == "defeat" then label("result", "旅途暂歇\n重新启程，重建牌组")
        elseif run.phase == "map" then label("result", "奖励已处理 · 牌组 " .. #run.deck .. " 张\n可再次挑战，检查新增卡牌") end
        ink(child("result"), run and run.phase == "defeat" and C.danger or C.goldBright)
        local count = fighting and #battle.enemies or 0
        local pendingTarget = false
        if fighting and self.selected then
            for _, instance in ipairs(battle.hand) do
                if instance.uid == self.selected then pendingTarget = needsTarget(battle, instance) break end
            end
        end
        for i = 1, 5 do
            local box = child("enemy" .. i)
            local enemy = fighting and battle.enemies[i]
            box:SetVisible(enemy ~= nil and enemy ~= false and (Actors.isActive(enemy) or self.busy and (self.feedback.escaping[enemy.id]
                or not enemy.escaped and not self.feedback.deaths[enemy.id])))
            if enemy then
                local x, width, portrait = enemySlot(count, i, enemy)
                box:SetAnchoredPosition(x, L.enemyRow.y)
                local targetable = active and pendingTarget and Combat.canPlay(battle, self.selected, i)
                if self.gesture and self.gesture.moving then
                    local valid, hovered = dragTarget(self.gesture)
                    targetable = valid and hovered == i
                end
                local potionTarget = self.potionAim ~= nil and not pendingTarget and Actors.isActive(enemy)
                unit(box, enemy, portrait, Theme.icon.enemy[enemy.definitionId], width, targetable == true or potionTarget or self.acting == enemy.id)
                -- An intent event is the historical action's starting face.
                -- Later frames already include its effects: do not apply them
                -- again. Unacted enemies still preview the current state.
                local shown = playbackIntents and playbackIntents[enemy.id]
                local face = shown and Actors.isActive(enemy) and shown or intentView(battle, i)
                local event = enemyPlayback and self.feedback.current
                if event and event.kind == "intent" and event.detail.enemy == enemy.id then
                    playbackIntents = playbackIntents or {}
                    playbackIntents[enemy.id] = face
                elseif not Actors.isActive(enemy) and playbackIntents then playbackIntents[enemy.id] = nil end
                local kind, badge = face.kind, face.badge
                -- Icon, then the damage or a two-character kind name in the icon's colour.
                local iconY = math.max(L.intent.offsetY, portrait / 2 + S.xxl)
                local valueX = -S.xl + L.intent.size / 2 + S.xs + L.intent.valueWidth / 2
                box:GetChild("intent").text = face.value
                box:GetChild("intent"):SetAnchoredPosition(valueX, iconY)
                local label = box:GetChild("intentLabel")
                label.text = face.label or ""
                label:SetAnchoredPosition(valueX, iconY)
                ink(label, intentColors[kind] or C.textDim)
                box:GetChild("intentIcon"):SetAnchoredPosition(-S.xl, iconY)
                box:GetChild("intentHit"):SetAnchoredPosition(0, iconY)
                picture(box:GetChild("intentIcon"), Theme.icon.intent[kind] or Theme.icon.intent.unknown)
                tint(box:GetChild("intentIcon"), intentColors[kind] or C.textDim)
                local badgeIcon = box:GetChild("intentBadge")
                local inset = (L.intent.size - L.intent.badge) / 2
                badgeIcon:SetAnchoredPosition(-S.xl + inset, iconY - inset)
                badgeIcon:SetVisible(badge ~= nil)
                if badge then
                    picture(badgeIcon, Theme.icon.intent[badge])
                    tint(badgeIcon, intentColors[badge])
                end
            end
        end
        local playable = cardView.renderCards(data, presentation, battle, fighting, active, reward, picking)
        cardView.renderDrag()
        -- Details describe the committed battle only while the player can read them.
        if self.info and (not self.active or self.busy or self.gesture or not fighting
            or self.info.battle ~= run.combat) then self.info = nil end
        renderInfo(battle)
        button("endTurn", active == true, not playable)
        button("skip", self.active and picking == true and not run.rewards.cardResolved and not self.busy, false, "跳过")
        button("stolenGold", self.active and stolen and not stolen.claimed and not self.busy, false,
            stolen and (stolen.claimed and "已取回失金 " or "取回失金 ") .. number(stolen.amount) or "取回失金")
        button("continue", self.active and run and (manual or run.phase == "map") and not self.busy, true,
            manual and "前往地图" or "再战一场")
        -- Keep physical slots fixed for the encounter: consuming slot one must not
        -- move slot two underneath a queued second click on the same button.
        if fighting and not self.busy then
            self.potionBattle, self.potionRun, self.potionSlots = battle, run, {}
            for slot = 1, potionCapacity do
                local id = run.potions[slot]
                if id then self.potionSlots[slot] = {slot = slot, id = id} end
            end
        end
        for i = 1, L.battlePotions.count do
            local visible=fighting and i<=potionCapacity
            show("potion" .. i, visible)
            local binding = self.potionSlots and self.potionSlots[i]
            local item = binding and potions[binding.slot]
            if item and item.id ~= binding.id then item = nil end
            button("potion" .. i, visible and active and item and item.canUse, false, item and potionText(item, battle) or "空药水槽")
            show("potionHelp" .. i, visible)
            button("potionHelp" .. i, visible and active and item ~= nil, false, "说明")
        end
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
        self.feedback:begin(before, battle, first, presentation, origin)
        return ok, reason
    end
    function self:chooseCards(kind, uids, token, generation)
        if self.busy or not self.run or self.run.phase~="combat" then return false, "not_in_combat" end
        local command = kind=="discard" and Run.chooseDiscard or kind=="scry" and Run.chooseScry
            or kind=="hand" and Run.chooseHand or kind=='pile' and Run.choosePile
        if not command then return false, "invalid_choice_kind" end
        return perform(function() return command(self.run,uids,token,generation) end)
    end
    function self:update(dt)
        if self.potionAim and not aimReady(self.potionAim) then self:render() end
        local help=self.help
        if help then
            local current=self.run and self.run.combat
            local actor=current and (help.spec.index==0 and current.player or current.enemies[help.spec.index])
            if not self.active or self.busy or self.run~=help.run or current~=help.battle
                or current.turn~=help.turn or actor~=help.actor or actor.hp<=0 or self.gesture and self.gesture.moving
                or help.card and (help.card.input.held~=help.card or not cardReady(help.card)) then
                self.help=nil
            elseif help.spec.kind=="potion" and (self.run.potions~=help.spec.inventory or self.run.potions[help.spec.slot]~=help.spec.potionId) then
                self.help=nil
            elseif not help.fired then
                help.t=help.t+dt
                if help.t+0.000001>=L.statusInfo.delay then
                    help.fired=true
                    if help.held and help.spec.kind=="card" then
                        self.gesture=nil;cancelCardInputs();self.suppressClick=true
                    end
                    self:openHelp(help.spec,help.source,true)
                end
            end
        end
        if self.feedbackRun and (self.feedbackRun ~= self.run or self.feedbackBattle ~= (self.run and self.run.combat)) then
            self.feedback:cancel()
            self.feedbackRun, self.feedbackBattle = nil, nil
            self:render() return
        end
        self.feedback:update(dt)
        local view = self.rewardView
        if view and self.active and not self.busy and self.run and self.run.phase == "reward" and view.rewards == self.run.rewards then
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
            if moving then self:render(true) end
        end
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
    function self:playSlot(index)
        local run = self.run
        if not self.active or not run or self.busy or self.gesture or self.suppressClick then return end
        if run.phase == "reward" then
            if self.rewardScreen ~= "cards" then return end
            local ok,reason = Run.claimCardReward(run, index)
            if ok then
                -- Claiming commits a new rewards object for the same encounter.
                -- Adopt this known result before rendering its local feedback;
                -- unrelated replacement rewards still reset the page normally.
                self.rewardOwner, self.rewardRun = run.rewards, run
                rewardScreen("list")
            end
            notice(ok and "卡牌已加入牌组。" or reasons[reason] or "当前无法领取奖励。")
            refresh(ok) return
        elseif run.phase == "combat" then
            cancelPotionAim("已取消药水瞄准。")
            local instance = run.combat.hand[index]
            if not instance then return end
            self.selectionEpoch = (self.selectionEpoch or 0) + 1
            if self.selected == instance.uid then self.selected = nil notice("") refresh() return end
            local ok, reason = Combat.canPlay(run.combat, instance.uid, self.target)
            if not ok then notice(reasons[reason] or "当前无法使用这张牌。") refresh() return end
            self.selected = instance.uid
            notice(needsTarget(run.combat, instance) and "点选一个敌人；再点原牌取消" or "点击战场出牌区域；再点原牌取消")
        end
        refresh()
    end
    function self:endTurn()
        if not self.active or not self.run or self.busy or self.gesture or self.suppressClick or self.run.phase ~= "combat" or self.run.combat.phase ~= "player" then return end
        self.selected = nil
        perform(function() return Run.endTurn(self.run) end)
    end
    function self:usePotion(index)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        local binding = self.potionSlots and self.potionSlots[index]
        if not binding or self.potionRun ~= self.run or self.potionBattle ~= self.run.combat
            or self.run.potions[binding.slot] ~= binding.id then return false end
        local item = Run.potionView(self.run)[binding.slot]
        if not item or not item.canUse then notice(reasons[item and item.reason] or "当前无法使用此药水。") return false end
        local previous = self.potionAim
        cancelPotionAim()
        if previous and previous.slot == binding.slot then notice("已取消药水瞄准。") refresh() return true end
        if item.targetPolicy == "enemy_one" then
            self.selected = nil
            self.selectionEpoch = (self.selectionEpoch or 0) + 1
            cancelCardInputs()
            cancelActionInputs()
            local battle = self.run.combat
            local aim = {run=self.run,battle=battle,turn=battle.turn,inventory=self.run.potions,
                slot=binding.slot,id=binding.id,actors={},living={}}
            for i, actor in ipairs(battle.enemies) do aim.actors[i],aim.living[i]=actor,Actors.isActive(actor) end
            self.potionAim = aim
            notice(item.name .. " · 对一名敌人：点击敌人使用；再点药水或空白取消；点说明查看效果。")
            refresh()
            return true
        end
        return self:commitPotion(binding.slot, nil)
    end
    function self:commitPotion(slot, target)
        if not self.active or self.busy or self.gesture or self.suppressClick or not self.run or self.run.phase ~= "combat" then return false end
        local aim = self.potionAim
        if target and (not aim or aim.slot ~= slot or not aimReady(aim)) then
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
    local function processPotionReward(claim)
        if not self.active or not self.run or self.busy or self.gesture or self.suppressClick then return false end
        if self.rewardScreen ~= "list" then return false end
        local ok,reason=(claim and Run.claimPotionReward or Run.skipPotionReward)(self.run)
        notice(ok and (reason == 'potion_blocked_by_sozu' and "遗物阻止获得药水。"
            or claim and "药水已放入背包。" or "已放弃药水。") or reasons[reason] or "当前无法处理药水。")
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
    local function down(event)
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
            arm(g)
            self.suppressClick,self.selected = true,g.uid
            self:render()
        end
    end
    local function release(event, input, ended)
        local g = self.gesture
        local touch = event and event.touchId
        if not g then
            -- Missing/invalid coordinates disable dragging, not ordinary C-mode.
            local held = input and input.held
            if held and held.touch == touch then
                if self.help and self.help.card == held then self.help = nil end
                input.held = nil
                input.released = not ended and cardReady(held) and held or nil
            elseif ended and input and input.released and input.released.touch == touch then
                input.released = nil
            end
            return
        end
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
        local x = point(event)
        local valid,target = false,nil
        if x and g.moving then valid,target = dragTarget(g) end
        self.gesture = nil -- consume before invoking the command or any rendering callback
        if not g.moving then
            g.input.released = not ended and g or nil
            return
        end
        g.input.released = nil
        self.suppressClick,self.selected = true,valid and g.uid or nil
        self:render()
        if valid then self:playSelected(target)
        else notice("") end
    end
    local function listen(control, fn, input)
        control:AddCursorEventListener(clickEvent,function(event)
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
    local function bind(name, fn)
        local control, input = child(name), {}
        if name == "playArea" then control = control:GetChild("hit") end
        actionInputs[#actionInputs + 1] = input
        control:AddCursorEventListener(clickEvent, function(event)
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
                local run = self.run
                local battle = run and run.combat
                local g = {name = name, run = run, phase = run and run.phase,
                    uid = self.selected, selectionEpoch = self.selectionEpoch,
                    battle = battle, turn = battle and battle.turn,
                    rewards = run and run.rewards, touch = event and event.touchId,
                    rewardScreen = self.rewardScreen, rewardEpoch = self.rewardEpoch,
                    normalGold = run and run.rewards and run.rewards.gold,
                    goldClaimed = run and run.rewards and run.rewards.goldClaimed,
                    render = self.rewardRender, cardResolved = run and run.rewards and run.rewards.cardResolved,
                    item = run and run.rewards and run.rewards.stolenGold,
                    goldAmount = run and run.rewards and run.rewards.stolenGold and run.rewards.stolenGold.amount,
                    goldType = run and run.rewards and run.rewards.stolenGold and run.rewards.stolenGold.type,
                    manualContinue = run and run.rewards and run.rewards.manualContinue,
                    cards = run and run.rewards and run.rewards.cards,
                    cardChoices = run and run.rewards and Combat.copy(run.rewards.cards),
                    potion = run and run.rewards and run.rewards.potion,
                    potionResolved = run and run.rewards and run.rewards.potion and run.rewards.potion.resolved,
                    potionResult = run and run.rewards and run.rewards.potion and run.rewards.potion.result,
                    potionId = run and run.rewards and run.rewards.potion and run.rewards.potion.id,
                    potionUnavailable = run and run.rewards and run.rewards.potion and run.rewards.potion.unavailable,
                    claimed = run and run.rewards and run.rewards.stolenGold and run.rewards.stolenGold.claimed}
                if name == "playArea" and battle then
                    g.aim = self.potionAim
                    g.x,g.y,g.invalidPoint = point(event)
                    for i,instance in ipairs(battle.hand) do if instance.uid == self.selected then g.slot = i break end end
                end
                if not g.invalidPoint and actionReady(g) then input.held = g end
            end)
            local function releaseAction(event, ended)
                local touch, held = event and event.touchId, input.held
                if held and held.touch == touch then
                    input.held = nil
                    local x,y,invalidPoint = point(event)
                    local fieldValid = name ~= "playArea" or not invalidPoint and (not x or inPlayArea(x,y)
                        and (not held.x or (x-held.x)^2+(y-held.y)^2 < D.threshold^2))
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
    for i = 1, L.battlePotions.count do
        local slot, control, input = i, child("potion" .. i), {}
        potionInputs[i] = input
        control:AddCursorEventListener(clickEvent, function(event)
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
    for i = 1, 10 do
        local slot,hit = i,child("card" .. i):GetChild("hit")
        local input = {}
        cardInputs[i] = input
        listen(hit,function() self:playSlot(slot) end,input)
        if self.dragEnabled then
            hit:AddCursorEventListener(cursor.CursorDown,function(event)
                pointerObserved = true
                if self.gesture then return end
                local dismissed = down(event)
                input.held, input.released = nil, nil
                if dismissed or not self.active or self.busy or not self.run then return end
                local run, battle = self.run, self.run.combat
                local instance = run.phase == "combat" and battle.hand[slot]
                local uid = instance and instance.uid or run.phase == "reward" and Run.rewardOptions(run)[slot]
                if not uid then return end
                local g = {uid=uid,slot=slot,run=run,battle=battle,turn=battle and battle.turn,
                    phase=run.phase,rewards=run.rewards,touch=event and event.touchId,input=input,
                    rewardScreen=self.rewardScreen,rewardEpoch=self.rewardEpoch,
                    normalGold=run.rewards and run.rewards.gold,
                    goldClaimed=run.rewards and run.rewards.goldClaimed,
                    render=self.rewardRender, cardResolved=run.rewards and run.rewards.cardResolved,
                    item=run.rewards and run.rewards.stolenGold,
                    goldAmount=run.rewards and run.rewards.stolenGold and run.rewards.stolenGold.amount,
                    goldType=run.rewards and run.rewards.stolenGold and run.rewards.stolenGold.type,
                    manualContinue=run.rewards and run.rewards.manualContinue,
                    cards=run.rewards and run.rewards.cards,
                    cardChoices=run.rewards and Combat.copy(run.rewards.cards),
                    potion=run.rewards and run.rewards.potion,
                    potionResolved=run.rewards and run.rewards.potion and run.rewards.potion.resolved,
                    potionResult=run.rewards and run.rewards.potion and run.rewards.potion.result,
                    potionId=run.rewards and run.rewards.potion and run.rewards.potion.id,
                    potionUnavailable=run.rewards and run.rewards.potion and run.rewards.potion.unavailable,
                    claimed=run.rewards and run.rewards.stolenGold and run.rewards.stolenGold.claimed}
                input.held = g
                cancelPotionAim("已取消药水瞄准。")
                self:queueHelp(self:cardHelpSpec(slot),hit,true,event and event.touchId,g)
                local x,y = point(event)
                if not instance or not x then return end
                local ok,reason = Combat.canPlay(battle,instance.uid,nil)
                if not ok and reason ~= "invalid_target" then return end
                g.sx,g.sy,g.x,g.y,g.origin = x,y,x,y,self.cardPositions[instance.uid]
                self.gesture = g
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
        hit:AddCursorEventListener(cursor.CursorDrag,move)
        hit:AddCursorEventListener(cursor.CursorUp,release)
        hit:AddCursorEventListener(cursor.CursorEndDrag,function(event) release(event,nil,true) end)
    end
    for i = 1, 5 do
        local target, control, input = i, child("enemy" .. i):GetChild("hit"), {}
        enemyInputs[i] = input
        local function chooseEnemy()
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
        control:AddCursorEventListener(clickEvent, function(event)
            if swallowed(event) then
                -- Dismissal consumes this pointer too, but cannot consume a
                -- newer token owned by a different touch on the same actor.
                local touch = event and event.touchId
                if input.held and input.held.touch == touch then input.held = nil end
                if input.released and input.released.touch == touch then input.released = nil end
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
                local actor = battle and battle.enemies[target]
                if not actor then return end
                local g = {slot=target, actor=actor, run=run, battle=battle,
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
    -- Enemy portraits keep targeting; the hero portrait and every status row only open
    -- details, so a status tap never plays a card or moves the potion target.
    listen(child("hero"):GetChild("hit"), function() self:showStatus(0) end)
    for i, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
        local index = i - 1
        listen(child(name):GetChild("statusRow"):GetChild("hit"), function() self:showStatus(index) end)
    end
    local info = child("statusInfo")
    info.disableCursorEventPassthrough = true
    listen(info:GetChild("hit"), function() if closeInfo() then self:render() end end)
    -- A tap on the card itself turns to the next page; a single page closes like any tap.
    -- Not routed through listen(): that dismisses the open card before any handler runs.
    info:GetChild("page"):AddCursorEventListener(clickEvent, function()
        local open = self.info
        if not open then return end
        self.swallow = nil
        if (open.pages or 1) > 1 then open.page = open.page % open.pages + 1 self:render()
        elseif closeInfo() then self:render() end
    end)
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
        local function ready(token)
            local run=self.run
            return token and self.active and not self.busy and not self.gesture and run==token.run
                and run.phase=="combat" and run.combat==token.battle and run.combat.turn==token.turn
                and (token.spec.index==0 and run.combat.player or run.combat.enemies[token.spec.index])==token.actor
                and token.actor.hp>0
                and (token.spec.kind~="potion" or run.potions==token.spec.inventory and run.potions[token.spec.slot]==token.spec.potionId)
        end
        control:AddCursorEventListener(clickEvent,function(event)
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
        local index=i-1
        if index>0 then bindHelp(child(name):GetChild("intentHit"),function() return {kind="intent",index=index} end,true) end
        for slot=1,L.statusIcon.perRow*L.statusIcon.rows do
            local position=slot
            bindHelp(child(name):GetChild("statusRow"):GetChild("hit"..slot),function()
                local battle=self.run and self.run.combat
                local actor=battle and (index==0 and battle.player or battle.enemies[index])
                if not actor or actor.hp<=0 then return end
                local entries=Combat.statusView(actor)
                local count=#battle.enemies
                local width=index==0 and L.hpBar.size[1] or select(2,enemySlot(count,index,actor))
                local perRow=math.max(1,math.min(L.statusIcon.perRow,math.floor((width+L.statusIcon.gap)/(L.statusIcon.size+L.statusIcon.gap))))
                local slots=perRow*L.statusIcon.rows
                if not entries[position] then return end
                return {index=index,statusId=not(position==slots and #entries>slots) and entries[position].id or nil,
                    offset=position==slots and #entries>slots and position or nil}
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
    refresh()
    return self
end
return M
