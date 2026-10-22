-- Event-driven view/controller; gameplay state belongs to Run and Combat.
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local M = {}

local reasons = { insufficient_energy = "能量不足", invalid_target = "请选择存活的敌人",
    card_not_in_hand = "这张牌已离开手牌", not_player_turn = "当前无法出牌",
    advanced_card_not_enabled = "此牌效果尚未接入", not_in_combat = "战斗已经结束" }

local function number(value) return string.format("%.0f", value) end
local function statuses(actor)
    local result = {}
    for _, entry in ipairs(Combat.statusView(actor)) do
        result[#result + 1] = entry.name .. " " .. number(entry.amount)
    end
    return #result > 0 and table.concat(result, " · ") or "无状态"
end

local function intentText(state, index)
    local intent = Combat.intent(state, index)
    if not intent then return "已击败" end
    local result = {}
    for _, effect in ipairs(intent.effects) do
        local value = effect.value and number(effect.value) or ""
        if effect.op == "damage" then result[#result + 1] = "攻击 " .. value .. ((effect.times or 1) > 1 and "×" .. effect.times or "") .. "（基础）"
        elseif effect.op == "block" then result[#result + 1] = "格挡 " .. value
        elseif effect.op == "gainStatus" or effect.op == "applyStatus" then
            local status = assert(state.catalog.statuses[effect.status], "missing intent status")
            result[#result + 1] = status.name .. " " .. value
        else error("unpresented intent operation") end
    end
    return "意图：" .. table.concat(result, "，")
end

function M.new(root, data, presentation, clickEvent)
    local self = { root = root, data = data, presentation = presentation, target = 1, mode = "menu", seed = 1 }
    local function child(name) return assert(root:GetChild(name), "missing UI control " .. name) end
    local function label(name, value) child(name).text = value end
    local function show(name, value) child(name):SetVisible(value) end
    local function cardText(id, upgraded)
        local display = assert(presentation[id], "missing card presentation " .. id)
        return display.name .. (upgraded and "＋" or "") .. "  费用 " .. (upgraded and display.upgradeCost or display.cost)
            .. "\n" .. (upgraded and display.upgradeText or display.text)
    end
    function self:render()
        local run = self.run
        local battle = run and run.combat
        local fighting = run and run.phase == "combat"
        local reward = run and run.phase == "reward"
        show("start", not run or run.phase == "defeat")
        child("start"):GetChild("label").text = run and "重新启程" or "启程"
        show("endTurn", fighting == true)
        show("skip", reward == true)
        show("continue", run and run.phase == "map" or false)
        show("result", not fighting)
        if not run then
            label("result", "战斗演练\n点击启程，试用旅行者的初始牌组")
            label("player", "生命 · 能量 · 格挡") label("piles", "抽牌 / 弃牌 / 消耗")
            label("statuses", "")
        else
            local player = fighting and battle.player
            label("player", "生命 " .. number(player and player.hp or run.hp) .. "/" .. run.maxHp
                .. "   格挡 " .. number(player and player.block or 0) .. "   能量 " .. number(fighting and battle.energy or 0))
            label("piles", "金币 " .. run.gold .. "  牌组 " .. #run.deck
                .. (fighting and "\n抽 " .. #battle.draw .. " / 弃 " .. #battle.discard .. " / 消耗 " .. #battle.exhaust or ""))
            label("statuses", player and statuses(player) or "")
            if reward then label("result", "战斗胜利 · 金币 ＋" .. run.rewards.gold .. "\n选择一张牌加入牌组，或跳过")
            elseif run.phase == "defeat" then label("result", "旅途暂歇\n重新启程，重建牌组")
            elseif run.phase == "map" then label("result", "奖励已处理 · 牌组 " .. #run.deck .. " 张\n可再次挑战，检查新增卡牌") end
        end
        for i = 1, 5 do
            local box = child("enemy" .. i)
            local enemy = fighting and battle.enemies[i]
            box:SetVisible(enemy ~= nil and enemy ~= false)
            if enemy then box:GetChild("label").text = (self.target == i and "【目标】" or "") .. enemy.name
                .. "\n生命 " .. number(enemy.hp) .. "/" .. enemy.maxHp .. "  格挡 " .. number(enemy.block)
                .. "\n" .. intentText(battle, i) .. "\n" .. statuses(enemy) end
        end
        local rewards = reward and Run.rewardOptions(run) or {}
        for i = 1, 10 do
            local box = child("card" .. i)
            local instance = fighting and battle.hand[i]
            local id = instance and instance.cardId or rewards[i]
            box:SetVisible(id ~= nil and id ~= false)
            if id then box:GetChild("label").text = cardText(id, instance and instance.upgraded) end
        end
    end
    local function notice(value) label("notice", value) end
    local function refresh()
        if self.run and self.run.phase == "combat" then
            local enemies = self.run.combat.enemies
            if not enemies[self.target] or enemies[self.target].hp <= 0 then
                for i, enemy in ipairs(enemies) do if enemy.hp > 0 then self.target = i break end end
            end
        end
        self:render()
    end
    function self:start()
        self.run = Run.new(data, self.seed)
        self.seed = (self.seed + 1) % 65536
        assert(Run.startCombat(self.run, "cultist_solo"))
        self.target = 1
        notice("先选择敌人，再点击手牌；结束回合后敌人按意图行动。")
        refresh()
        print("ABYSS_UI combat_started")
    end
    function self:playSlot(index)
        local run = self.run
        if not run then return end
        if run.phase == "reward" then
            local ok = Run.claimCardReward(run, index)
            if ok then notice("卡牌已加入牌组。") end
        elseif run.phase == "combat" then
            local instance = run.combat.hand[index]
            if not instance then return end
            local ok, reason = Run.play(run, instance.uid, self.target)
            notice(ok and "出牌完成。" or reasons[reason] or "当前无法使用这张牌。")
        end
        refresh()
    end
    function self:endTurn()
        if not self.run then return end
        local ok = Run.endTurn(self.run)
        if ok then notice("新回合：查看敌人意图，规划能量与格挡。") end
        refresh()
    end
    local function bind(name, fn) child(name):GetChild("hit"):AddCursorEventListener(clickEvent, fn) end
    bind("start", function() if not self.run or self.run.phase == "defeat" then self:start() end end)
    bind("endTurn", function() self:endTurn() end)
    bind("skip", function()
        if self.run and Run.claimCardReward(self.run, 0) then notice("已跳过卡牌奖励。") refresh() end
    end)
    bind("continue", function()
        if self.run and self.run.phase == "map" then assert(Run.startCombat(self.run, "cultist_solo")) refresh() end
    end)
    for i = 1, 10 do local slot = i bind("card" .. i, function() self:playSlot(slot) end) end
    for i = 1, 5 do local target = i bind("enemy" .. i, function()
        if self.run and self.run.phase == "combat" and self.run.combat.enemies[target]
            and self.run.combat.enemies[target].hp > 0 then self.target = target refresh() end
    end) end
    refresh()
    return self
end
return M
