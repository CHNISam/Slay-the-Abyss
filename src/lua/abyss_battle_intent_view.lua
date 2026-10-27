-- Read-only intent projection. Core preview APIs retain all combat arithmetic.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local Theme = require("abyss_theme")
local StatusView = require("abyss_battle_status_view")
local number = require("abyss_numbers").integer
local M = {}
local C = Theme.color
local intentColors = { attack = C.danger, defend = C.block, buff = C.buff, debuff = C.debuff }
local intentLabels = { defend = "防御", buff = "强化", debuff = "削弱", charge = "蓄能", sleep = "沉睡",
    unknown = "未知", stunned = "苏醒", split = "分裂", escape = "逃跑" }
local effectKinds = { damage = "attack", block = "defend", gainStatus = "buff",
    applyStatus = "debuff", makeTempCardInDiscard = "debuff", enemyVampireDamage = "attack",
    enemyHealAll = "buff", enemyStrengthAll = "buff", enemyCleanse = "buff",
    enemyRally = 'buff', enemyEncourage = 'buff', enemyTorchSpawn = 'buff', enemyTorchRevive = 'buff',
    enemyBronzeSpawn = 'buff', enemyStasis = 'debuff', writhingParasite='debuff', enemyBurnBoth='debuff', enemyDazedDraw='debuff',awakenedVoid='debuff' }

-- Mixed moves show the first other effect kind in the original icon priority.
function M.intentBadge(intent)
    for _, kind in ipairs({ "debuff", "defend", "buff", "attack" }) do
        if kind ~= intent.kind then
            for _, effect in ipairs(intent.effects or {}) do
                if effectKinds[effect.op] == kind then return kind end
            end
        end
    end
end

local function special(kind, icon, text, note)
    return { value = "", kind = icon, label = intentLabels[kind], text = text,
        rows = {{ icon = icon, colour = C.textDim, name = intentLabels[kind], text = text, note = note }} }
end

local specialIntents = {
    unknown = function(_,enemy)
        if enemy.ai and enemy.ai.kind=='darkling'then
            local view=special('unknown','unknown','再生：本次行动不攻击，随后准备复生；全部共生暗影同时休眠才会被击败。')
            view.label,view.rows[1].name='再生','再生';return view
        end
        if enemy.ai and enemy.ai.kind=='awakened_one'then
            return special('unknown','unknown','重生：本次行动恢复至300点生命，随后进入第二形态。')
        end
        return special('unknown','unknown','下一步行动未知。')
    end,
    escape = function()
        return special("escape", "unknown", "逃离战场，不返还已窃取的金币。")
    end,
    charge = function()
        return special("charge", "unknown", "本回合不攻击，正在蓄能。", "蓄满后发动攻击")
    end,
    sleep = function()
        return special("sleep", "sleep", "沉睡中，本回合不行动。", "损失生命就会惊醒")
    end,
    stunned = function(_, enemy)
        if enemy.definitionId ~= 'lagavulin' then
            return {value='',kind='unknown',label='昏眩',text='陷入昏眩，本回合不行动。',
                rows={{icon='unknown',colour=C.textDim,name='昏眩',text='陷入昏眩，本回合不行动。'}}}
        end
        return special("stunned", "unknown", "刚被惊醒，本回合不行动。")
    end,
    split = function(state, enemy)
        local children=enemy.ai.splitEnemies
        local child = state.catalog.enemies[children and children[1] or enemy.ai.splitEnemy]
        local names=children and (child.name .. '和' .. state.catalog.enemies[children[2]].name) or ('两只' .. child.name)
        return special("split", "unknown", "分裂为" .. names .. "，各自生命等于分裂时的当前生命。")
    end,
}

local function goneView(state, index)
    local gone = state.enemies[index] and state.enemies[index].escaped and "已逃跑" or "已击败"
    return { value = "", kind = "unknown", label = gone, text = gone, rows = {} }
end

local function newPreview(state, index, intent)
    local preview = Events.frame(state)
    preview.events = {}
    local soften = state.originalV4 and require("abyss_original_v4").intentReduction(state, index) or 0
    return { state = state, enemy = state.enemies[index], intent = intent, preview = preview,
        copy = preview.enemies[index], player = preview.player, soften = soften, result = {}, rows = {} }
end

local function theft(v)
    local ai = v.enemy.ai
    if not ai or ai.kind ~= "looter" or (v.intent.id ~= ai.mugIntent and v.intent.id ~= ai.lungeIntent) then return end
    local gold = number(ai.stealAmount)
    v.result[#v.result + 1] = "先窃取最多 " .. gold .. " 金币（完全格挡仍会失金）"
    v.rows[#v.rows + 1] = { icon = Theme.icon.gold.id, colour = C.debuff, name = "窃金 " .. gold,
        text = "先窃取你最多 " .. gold .. " 金币", note = "完全格挡仍会失金" }
end

local function attackHits(v, effect)
    local amount = Combat.intentAttackAmount(v.state, v.copy, v.player, effect.value)
    local times = effect.times or 1
    local hits, total, unequal = {}, 0, false
    for hit = 1, times do
        local cut = math.min(amount, v.soften)
        v.soften = v.soften - cut
        hits[hit] = amount - cut
        total = total + hits[hit]
        if hit > 1 and hits[hit] ~= hits[1] then unequal = true end
    end
    return hits, total, unequal, times
end

local function attackFace(hits, times, unequal)
    if unequal then
        local values = {}
        for _, hit in ipairs(hits) do values[#values + 1] = number(hit) end
        return table.concat(values, "+")
    end
    return number(hits[1]) .. (times > 1 and "×" .. times or "")
end

local function attackSentence(face, times, each, unequal, singlePrefix)
    if unequal then return "依次攻击 " .. face .. " 点伤害" end
    if times > 1 then return "攻击 " .. times .. " 次，每次 " .. each .. " 点伤害" end
    return singlePrefix .. each .. " 点伤害"
end

local function attackEffect(v, effect)
    local hits, total, unequal, times = attackHits(v, effect)
    local amount, each = hits[1], number(hits[1])
    local face = attackFace(hits, times, unequal)
    v.attack = v.attack or face
    v.result[#v.result + 1] = attackSentence(face, times, each, unequal, "攻击造成 ")
    v.rows[#v.rows + 1] = { icon = "attack", colour = C.danger, name = "攻击 " .. face,
        tag = times > 1 and "共 " .. number(total) or nil,
        text = attackSentence(face, times, each, unequal, "造成 "),
        note = amount ~= effect.value and "基础 " .. number(effect.value) .. "，已计入双方力量、虚弱与易伤" or nil }
end

local function blockEffect(v, effect)
    local master = effect.target == 'automaton'
    local amount = number(Combat.blockAmount(v.state, v.copy, effect.value, effect.fixed or master or effect.target == "random_ally"))
    local ally = effect.target == "random_ally"
    local text = effect.target=='all_allies' and '敌方全体存活单位各获得 '..amount..' 点格挡'
        or master and '使青铜机枢获得 '..amount..' 点格挡'
        or ally and "让一名随机队友获得 " .. amount .. " 点格挡（没有队友时给自己）" or "获得 " .. amount .. " 点格挡"
    v.result[#v.result + 1] = text
    v.rows[#v.rows + 1] = { icon = "defend", colour = C.block, name = "格挡 " .. amount,
        text = text,
        note = ally and "没有队友时给自己" or nil }
end

local function statusSentence(gain, effect, status, size)
    return (gain and "自身" or "使你") .. (effect.value < 0 and "失去 " or "获得 ")
        .. size .. (status.stack == "duration" and " 回合" or " 层") .. status.name
end

local function statusRow(v, effect, gain, status, size, sentence)
    local entry = { id = effect.status, amount = effect.value, temporary = 0, kind = status.kind,
        description = status.description, stack = status.stack }
    local kind = gain and StatusView.statusKind(entry) == "buff" and "buff" or "debuff"
    return { icon = kind, colour = intentColors[kind],
        name = status.name .. " " .. (effect.value < 0 and StatusView.signed(effect.value) or size),
        tag = status.stack == "duration" and "持续 " .. size .. " 回合" or nil,
        text = sentence, note = (StatusView.statusDetail(entry, v.state.rules, v.enemy)) }
end

local function statusEffect(v, effect)
    local gain = effect.op == "gainStatus"
    -- Each copied status passes ApplyPower before later effects read it. Artifact
    -- is spent in order and can reject a status before its addition overflows.
    Actors.applyPower(v.preview, gain and v.copy or v.player, effect.status, effect.value, v.copy)
    local status = assert(v.state.catalog.statuses[effect.status])
    local size = number(math.abs(effect.value))
    local sentence = statusSentence(gain, effect, status, size)
    v.result[#v.result + 1] = sentence
    v.rows[#v.rows + 1] = statusRow(v, effect, gain, status, size, sentence)
end

local function discardEffect(v, effect)
    local value = number(effect.value)
    local name = assert(v.state.catalog.cards[effect.card]).name
    if effect.upgraded or effect.card=='burn' and v.enemy.hexBurnUpgraded then name=name..'+'end
    local text = "将 " .. value .. " 张「" .. name .. "」放入你的弃牌堆"
    v.result[#v.result + 1] = text
    v.rows[#v.rows + 1] = { icon = "debuff", colour = C.debuff, name = "塞入「" .. name .. "」×" .. value, text = text }
end

local function unknownEffect(v)
    v.result[#v.result + 1] = "未知"
    v.rows[#v.rows + 1] = { icon = "unknown", colour = C.textDim, name = "未知", text = "下一步行动未知" }
end

local function burnBothEffect(v)
    local name=assert(v.state.catalog.cards.burn).name
    local text='将 1 张「'..name..'」放入你的抽牌堆，另 1 张放入弃牌堆'
    v.result[#v.result+1]=text
    v.rows[#v.rows+1]={icon='debuff',colour=C.debuff,name='塞入「'..name..'」×2',text=text}
end

local function dazedDrawEffect(v)
    local name=assert(v.state.catalog.cards.dazed).name
    local text='将 2 张「'..name..'」随机放入你的抽牌堆'
    v.result[#v.result+1]=text
    v.rows[#v.rows+1]={icon='debuff',colour=C.debuff,name='塞入「'..name..'」×2',text=text}
end

local function act2Row(v, name, text, kind, note)
    v.result[#v.result+1]=text
    v.rows[#v.rows+1]={icon=kind,colour=intentColors[kind],name=name,text=text,note=note}
end
local function vampireEffect(v,effect)
    attackEffect(v,effect)
    act2Row(v,'吸血','按你实际损失的生命回复自身生命','buff','格挡部分不产生治疗')
end
local function stasisEffect(v)
    act2Row(v,'扣押卡牌','扣押抽牌堆中的一张牌；抽牌堆为空时从弃牌堆选择。击败此浮核后归还，满手时放入弃牌堆',
        'debuff','优先稀有，其次罕见、普通；同稀有度随机选择')
end
local function summonEffect(v,effect)
    local name,text
    if effect.op=='enemyEncourage' then
        name,text='鼓舞','敌方全体存活单位各获得 '..number(effect.value)..' 层力量，其他队友各获得 6 点格挡'
    elseif effect.op=='reptomancerSummon'then name,text='召唤','召唤 1 把浮游蛇刃，补充空位（最多 4 把）'
    elseif effect.op=='enemyRally' then name,text='召唤','召唤最多 2 名随从，补充空位'
    elseif effect.op=='enemyTorchSpawn' then name,text='召唤','召唤 2 名燃炬随从'
    elseif effect.op=='enemyBronzeSpawn' then name,text='召唤','召唤 2 名青铜浮核'
    else name,text='复活','复活已倒下的燃炬随从，存活随从保持原状态' end
    act2Row(v,name,text,'buff')
end
local function groupEffect(v,effect)
    local name,text
    if effect.op=='enemyHealAll' then
        name,text='群体治疗 '..number(effect.value),'敌方全体存活单位各回复最多 '..number(effect.value)..' 点生命'
    elseif effect.op=='enemyStrengthAll' then
        name,text='群体力量 '..number(effect.value),'敌方全体存活单位各获得 '..number(effect.value)..' 层力量'
    else name,text='净化','移除自身全部负面状态及暂时失去力量的状态' end
    act2Row(v,name,text,'buff')
end
local function parasiteEffect(v)
    act2Row(v,'寄生','永久获得一张寄生诅咒；本场战斗的牌堆不加入此牌','debuff','整场战斗只施放一次；御守可阻止获得')
end
local function awakenedVoidEffect(v)
    act2Row(v,'虚空','将1张虚空放入抽牌堆的随机位置','debuff','抽到时失去1点能量；虚无')
end
local function timeEaterEffect(v,effect)
    local name,text
    if effect.kind=='cleanse'then name,text='净化','移除自身所有减益（保留正力量）'
    elseif effect.kind=='removeShackled'then name,text='解除力量恢复','移除暂时失去力量的恢复状态'
    else name,text='加速治疗','回复至 '..number(math.floor(v.enemy.maxHp/2))..' 点生命（行动时确定治疗量）'end
    act2Row(v,name,text,'buff')
end
local function daggerSacrificeEffect(v)
    act2Row(v,'自毁','自毁：攻击后失去等于行动开始时生命的生命值（无视格挡）','debuff')
end
local effects = { daggerSacrifice=daggerSacrificeEffect,reptomancerSummon=summonEffect,timeEater=timeEaterEffect, writhingParasite=parasiteEffect,awakenedVoid=awakenedVoidEffect,damage = attackEffect, damageAll = attackEffect, block = blockEffect,
    enemyBurnBoth=burnBothEffect,enemyDazedDraw=dazedDrawEffect,
    enemyVampireDamage=vampireEffect,enemyStasis=stasisEffect,
    enemyRally=summonEffect,enemyTorchSpawn=summonEffect,enemyTorchRevive=summonEffect,
    enemyEncourage=summonEffect,enemyBronzeSpawn=summonEffect,
    enemyHealAll=groupEffect,enemyStrengthAll=groupEffect,enemyCleanse=groupEffect,
    gainStatus = statusEffect, applyStatus = statusEffect, makeTempCardInDiscard = discardEffect }

local function joinedView(v)
    local intent = v.intent
    return { value = intent.kind == "attack" and (v.attack or "?") or "", kind = intent.kind, badge = M.intentBadge(intent),
        label = intent.kind ~= "attack" and intentLabels[intent.kind] or nil,
        text = #v.result > 0 and table.concat(v.result, "；") or "下一步行动未知。", rows = v.rows }
end

-- One ordered preview supplies the compact face, joined text and detail rows.
function M.intentView(state, index)
    local intent = Combat.intent(state, index)
    if not intent then return goneView(state, index) end
    if state.enemies[index].ai and state.enemies[index].ai.kind=='darkling'and intent.id=='reincarnate'then
        local hp=number(math.floor(state.enemies[index].maxHp/2))
        return {value='',kind='buff',label='复生',text='本次行动回复 '..hp..' 点生命，恢复共生，随后重新选招。',
            rows={{icon='buff',colour=C.buff,name='复生',text='回复 '..hp..' 点生命并恢复共生。'}}}
    end
    local describeSpecial = specialIntents[intent.kind]
    -- Summon retains the source unknown face, but its bounded definition has
    -- a useful Chinese detail row. Do not suppress Awakened/Darkling unknowns.
    if state.enemies[index].ai and state.enemies[index].ai.kind=='reptomancer'and intent.id=='summon'then
        describeSpecial=nil
    end
    if describeSpecial then return describeSpecial(state, state.enemies[index]) end
    local view = newPreview(state, index, intent)
    theft(view)
    for _, effect in ipairs(intent.effects) do
        local describe = effects[effect.op] or unknownEffect
        describe(view, effect)
    end
    if view.enemy.ai and view.enemy.ai.kind=='act1_boss' and intent.id=='inferno'then
        act2Row(view,'灼伤强化','升级抽牌堆和弃牌堆中的灼伤，并向弃牌堆加入3张灼伤+','debuff')
    end
    return joinedView(view)
end

return M
