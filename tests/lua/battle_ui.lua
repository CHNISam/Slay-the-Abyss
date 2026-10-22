package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")

-- Compose the controller with the actual generated native tree, not a permissive mock.
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn) assert(event == "click") self.click = fn end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) self.sizeDeltaX, self.sizeDeltaY = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(source, id) assert(source == "static" and type(id) == "number") self.imageId = id end
    function c:SetAsLastSibling() self.raised = true end
    return c
end
local function setup()
    local root = control({name="root", size={1280,720}, children=assert(ABYSS_TEST_LAYOUT).controls})
    local stage = root:GetChild("stage")
    local ui = UI.new(root, Data, Presentation, "click", {imageSource="static", color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end})
    local function click(name)
        local box = stage:GetChild(name)
        if box.click then if box.interactable then box.click() end else box:GetChild("hit").click() end
    end
    local function play(slot, target)
        click("card" .. slot)
        local instance = ui.run.phase == "combat" and ui.run.combat.hand[slot]
        if instance and ui.selected == instance.uid then
            local _, reason = Combat.canPlay(ui.run.combat, instance.uid, nil)
            click(reason == "invalid_target" and "enemy" .. (target or 1) or "card" .. slot)
        end
    end
    return ui, stage, click, play, root
end
local count = 0
local function test(name, fn) fn() count=count+1 print("ok UI " .. count .. " - " .. name) end

test("menu starts a real battle with shared-theme cards, energy and base intents", function()
    local ui, stage, click = setup()
    assert(ui.run == nil and stage.children.start.visible and not stage.children.card1.visible)
    click("start")
    assert(ui.run.phase == "combat" and #ui.run.deck == 10)
    assert(stage.children.card1.visible and not stage.children.card6.visible)
    assert(stage.children.card1.children.label.text ~= "")
    assert(stage.children.energy.text == "3/3")
    assert(stage.children.enemy1.children.intent.text == "6 基础")
    assert(stage.children.enemy1.children.portrait.imageId == Theme.icon.enemy.cultist)
    assert(stage.children.hero.children.hpFill.fillAmount == 1)
end)
test("selection never spends energy; target click or second self-card click issues one real command", function()
    local ui, stage, click, play = setup() click("start")
    local battle = ui.run.combat
    local id, energy = battle.hand[1].uid, battle.energy
    click("card1")
    assert(#battle.hand == 5 and battle.energy == energy and ui.selected == id)
    assert(stage.children.card1.children.glow.visible and stage.children.card1.localScaleX == Theme.motion.hoverScale)
    local _, reason = Combat.canPlay(battle, id, nil)
    click(reason == "invalid_target" and "enemy1" or "card1")
    assert(#battle.hand == 4 and battle.discard[1].uid == id and ui.selected == nil)
    assert(not stage.children.card5.visible and stage.children.energy.text == battle.energy .. "/3")
    while #battle.hand > 0 and Combat.canPlay(battle, battle.hand[1].uid, 1) do play(1) end
    local hp, hand, remaining = battle.enemies[1].hp, #battle.hand, battle.energy
    if hand > 0 then
        click("card1")
        assert(battle.enemies[1].hp == hp and #battle.hand == hand and battle.energy == remaining)
        assert(stage.children.notice.text == "能量不足")
        assert(stage.children.card1.children.cost.fontColor.r == Theme.color.danger.r)
        assert(stage.children.endTurn.children.normal.children.plate.imageColor.r == Theme.color.geo.r)
    end
    click("endTurn")
    assert(battle.turn == 2 and #battle.hand == 5)
    assert(stage.children.enemy1.children.intent.text:find("力量 3", 1, true))
end)
test("pending attack highlights valid live enemies and changing selection does not play", function()
    local ui, stage, click = setup() click("start")
    local battle = ui.run.combat
    for i, instance in ipairs(battle.hand) do
        local _, reason = Combat.canPlay(battle, instance.uid, nil)
        if reason == "invalid_target" then
            click("card" .. i)
            assert(stage.children.notice.text:find("点选一个敌人", 1, true))
            assert(stage.children.enemy1.children.border.imageColor.r == Theme.color.goldBright.r)
            local selected = ui.selected
            click("card" .. i)
            assert(ui.selected == selected and #battle.hand == 5)
            return
        end
    end
    error("fixture should contain attack")
end)
test("enemy phase and command lock block card and end-turn input", function()
    local ui, stage, click = setup() click("start")
    local battle = ui.run.combat
    battle.phase = "enemy" ui:render()
    assert(not stage.children.endTurn.interactable)
    local hand, turn, energy = #battle.hand, battle.turn, battle.energy
    click("card1") click("endTurn")
    assert(#battle.hand == hand and battle.turn == turn and battle.energy == energy)
    assert(stage.children.notice.text == "敌方行动中")
    battle.phase = "player" ui.busy = true ui:render()
    click("card1") ui:endTurn()
    assert(#battle.hand == hand and battle.turn == turn)
end)
test("resize scales the whole stage uniformly and covers wide-screen side bars", function()
    local ui, stage, _, _, root = setup()
    for _, size in ipairs({{1280,720,1},{1600,900,1.25},{1920,1080,1.5},{1560,720,1}}) do
        ui:resize(size[1], size[2])
        assert(stage.localScaleX == size[3] and stage.localScaleY == size[3])
        assert(root.children.backdrop.sizeDeltaX == size[1] and root.children.backdrop.sizeDeltaY == size[2])
    end
end)
test("runtime ten-card poses keep complete rotated and selected hit regions inside the phone safe area", function()
    local ui, stage, click = setup() click("start")
    local battle = ui.run.combat
    Combat.draw(battle, 5)
    assert(#battle.hand == 10)
    for selected = 0, 10 do
        ui.selected = selected > 0 and battle.hand[selected].uid or nil
        ui:render()
        for i = 1, 10 do
            local card = stage.children["card" .. i]
            local radians = math.abs(card.localRotationZ) * math.pi / 180
            local width, height = 148 * card.localScaleX, 208 * card.localScaleY
            local halfWidth = (width * math.cos(radians) + height * math.sin(radians)) / 2
            local halfHeight = (height * math.cos(radians) + width * math.sin(radians)) / 2
            assert(math.abs(card.x) + halfWidth <= 640 - 40 + 0.0001)
            assert(math.abs(card.y) + halfHeight <= 360 - 20 + 0.0001)
        end
    end
end)
test("five enemies retain separate touch targets and a boss uses the approved larger portrait", function()
    local ui, stage, click = setup() click("start")
    ui.run.combat = Combat.new(Data, {enemies={"cultist","red_louse","green_louse","jaw_worm","sentry"}})
    ui:render()
    local previous
    for i = 1, 5 do
        local box = stage.children["enemy" .. i]
        local width = box.children.hit.sizeDeltaX
        assert(width >= 44 and box.x + width / 2 <= 600)
        if previous then assert(previous.x + previous.children.hit.sizeDeltaX / 2 < box.x - width / 2) end
        previous = box
    end
    local battle = ui.run.combat
    local firstHp, fifthHp = battle.enemies[1].hp, battle.enemies[5].hp
    local targeted = false
    for i, instance in ipairs(battle.hand) do
        local _, reason = Combat.canPlay(battle, instance.uid, nil)
        if reason == "invalid_target" then
            click("card" .. i) click("enemy5") targeted = true break
        end
    end
    assert(targeted and battle.enemies[1].hp == firstHp and battle.enemies[5].hp < fifthHp)
    ui.run.combat = Combat.new(Data, {enemies={"guardian"}})
    ui:render()
    assert(stage.children.enemy1.children.plate.sizeDeltaX == 168)
    assert(stage.children.enemy1.children.portrait.imageId == Theme.icon.enemy.guardian)
end)
test("real victory displays feedback and claims a reward into the next battle deck", function()
    local ui, stage, click, play = setup() click("start")
    for _ = 1, 40 do
        if ui.run.phase ~= "combat" then break end
        local battle = ui.run.combat
        for _ = 1, 10 do
            if ui.run.phase ~= "combat" then break end
            local slot
            for i, card in ipairs(battle.hand) do if Combat.canPlay(battle, card.uid, 1) then slot = i break end end
            if not slot then break end
            play(slot)
        end
        if ui.run.phase == "combat" then click("endTurn") end
    end
    assert(ui.run.phase == "reward" and stage.children.skip.visible)
    assert(stage.children.result.text:find("战斗胜利", 1, true))
    assert(not stage.children.endTurn.visible and not stage.children.enemy1.visible)
    local chosen = ui.run.rewards.cards[1]
    click("card1")
    assert(ui.run.phase == "map" and #ui.run.deck == 11 and stage.children.continue.visible)
    click("continue")
    local found = false
    for _, pile in ipairs({ui.run.combat.draw, ui.run.combat.hand}) do
        for _, card in ipairs(pile) do if card.cardId == chosen then found = true end end
    end
    assert(found and ui.run.phase == "combat")
end)
test("real defeat shows danger feedback and restart creates a fresh run", function()
    local ui, stage, click = setup() click("start")
    for _ = 1, 30 do if ui.run.phase ~= "combat" then break end click("endTurn") end
    assert(ui.run.phase == "defeat" and stage.children.start.visible)
    assert(stage.children.result.text:find("旅途暂歇", 1, true))
    assert(stage.children.result.fontColor.r == Theme.color.danger.r)
    local old = ui.run
    click("start")
    assert(ui.run ~= old and ui.run.phase == "combat" and #ui.run.deck == 10)
end)
print("LUA_UI_PASS " .. count)
