package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Data = require("abyss_data")
local function control(name)
    local c = { name = name, visible = true, children = {}, text = "" }
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn) assert(event == "click") self.click = fn end
    return c
end
local function setup()
    local root, presentation = control("root"), {}
    for _, name in ipairs({"title", "player", "piles", "notice", "statuses", "result", "start", "continue", "endTurn", "skip"}) do
        root.children[name] = control(name)
    end
    for _, group in ipairs({ { "enemy", 5 }, { "card", 10 } }) do
        for i = 1, group[2] do root.children[group[1] .. i] = control(group[1] .. i) end
    end
    for _, c in pairs(root.children) do
        for _, name in ipairs({"label", "hit", "plate"}) do c.children[name] = control(name) end
    end
    for _, card in ipairs(Data.cards.cards) do
        presentation[card.id] = {name="DISPLAY_" .. card.id, cost=tostring(card.cost), text="checked effect",
            upgradeCost=tostring(card.upgrade.cost or card.cost), upgradeText="checked upgrade"}
    end
    local ui = UI.new(root, Data, presentation, "click")
    local function click(name) root:GetChild(name):GetChild("hit").click() end
    return ui, root, click
end
local count = 0
local function test(name, fn) fn() count=count+1 print("ok UI " .. count .. " - " .. name) end

test("menu waits for click and starts real starter battle with visible hand", function()
    local ui, root, click = setup()
    assert(ui.run == nil and root.children.start.visible)
    assert(not root.children.card1.visible and not root.children.enemy1.visible)
    click("start")
    assert(ui.run.phase == "combat" and #ui.run.deck == 10)
    assert(root.children.card1.visible and not root.children.card6.visible)
    assert(root.children.card1.children.label.text:find("DISPLAY_", 1, true))
    assert(root.children.player.text:find("能量 3", 1, true))
    assert(root.children.enemy1.children.label.text:find("意图：攻击 6", 1, true))
end)
test("card click mutates real rules and immediately refreshes piles and energy", function()
    local ui, root, click = setup() click("start")
    local battle = ui.run.combat
    local id = battle.hand[1].uid
    click("card1")
    assert(#battle.hand == 4 and battle.discard[1].uid == id)
    assert(not root.children.card5.visible)
    assert(root.children.player.text:find("能量 " .. battle.energy, 1, true))
    while #battle.hand > 0 and Combat.canPlay(battle, battle.hand[1].uid, 1) do click("card1") end
    if #battle.hand > 0 then
        local hp, energy, hand = battle.enemies[1].hp, battle.energy, #battle.hand
        click("card1")
        assert(battle.enemies[1].hp == hp and battle.energy == energy and #battle.hand == hand)
        assert(root.children.notice.text == "能量不足")
    end
    click("endTurn")
    assert(battle.turn == 2 and #battle.hand == 5)
    assert(root.children.enemy1.children.label.text:find("力量 3", 1, true))
end)
test("actual combat victory offers clickable reward entering next real deck", function()
    local ui, root, click = setup() click("start")
    for _ = 1, 40 do
        if ui.run.phase ~= "combat" then break end
        local battle = ui.run.combat
        for _ = 1, 10 do
            if ui.run.phase ~= "combat" then break end
            local slot
            for i, card in ipairs(battle.hand) do
                if Combat.canPlay(battle, card.uid, 1) then slot = i break end
            end
            if not slot then break end
            click("card" .. slot)
        end
        if ui.run.phase == "combat" then click("endTurn") end
    end
    assert(ui.run.phase == "reward" and root.children.skip.visible)
    assert(not root.children.endTurn.visible and not root.children.enemy1.visible)
    local chosen = ui.run.rewards.cards[1]
    click("card1")
    assert(ui.run.phase == "map" and #ui.run.deck == 11 and root.children.continue.visible)
    click("continue")
    local found = false
    for _, pile in ipairs({ui.run.combat.draw, ui.run.combat.hand}) do
        for _, card in ipairs(pile) do if card.cardId == chosen then found = true end end
    end
    assert(found and ui.run.phase == "combat")
end)
test("reward HUD shows committed relic healing and clears ended battle resources", function()
    local ui, root, click = setup() click("start")
    local battle = ui.run.combat
    battle.player.hp, battle.player.block = 50, 9
    battle.enemies[1].hp = 1
    Combat.addStatus(battle.player, "strength", 2)
    for i, card in ipairs(battle.hand) do
        if Combat.cardDefinition(battle, card).type == "attack" then click("card" .. i) break end
    end
    assert(ui.run.phase == "reward" and ui.run.hp == 56)
    assert(root.children.player.text:find("生命 56/80", 1, true))
    assert(root.children.player.text:find("格挡 0", 1, true))
    assert(root.children.player.text:find("能量 0", 1, true))
    assert(root.children.statuses.text == "")
    assert(not root.children.piles.text:find("抽 ", 1, true))
end)
print("LUA_UI_PASS " .. count)
