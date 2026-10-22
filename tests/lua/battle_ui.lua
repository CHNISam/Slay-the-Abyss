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
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn) assert(event == "click") self.click = fn end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) self.sizeDeltaX, self.sizeDeltaY = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number") self.imageId = id
    end
    function c:SetAsLastSibling() self.raised = true end
    return c
end
local function setup(options)
    local root = control({name="root", size={1280,720}, children=assert(ABYSS_TEST_LAYOUT).controls})
    local stage = root:GetChild("stage")
    if options and options.embedded then root = stage end
    local ui = UI.new(root, Data, Presentation, "click", {imageSource="static", color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end}, options)
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

test("menu starts a real battle with shared-theme cards, energy and current intents", function()
    local ui, stage, click = setup()
    assert(ui.run == nil and stage.children.start.visible and not stage.children.card1.visible)
    click("start")
    assert(ui.run.phase == "combat" and #ui.run.deck == 10)
    assert(stage.children.card1.visible and not stage.children.card6.visible)
    assert(stage.children.card1.children.label.text ~= "")
    assert(stage.children.energy.text == "3/3")
    assert(stage.children.enemy1.children.intent.text == "6")
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
    assert(stage.children.enemy1.children.intent.text == "3")
    click("enemy1")
    assert(stage.children.notice.text:find("力量 3", 1, true))
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

test("enemy intent click never confirms a selected non-target card", function()
    local ui, stage, click = setup() click("start")
    local battle, slot = ui.run.combat
    for i, instance in ipairs(battle.hand) do if instance.cardId == "defend" then slot = i break end end
    assert(slot, "fixture should contain defend")
    click("card" .. slot)
    local selected = ui.selected
    assert(stage.children.notice.text == "再次点击这张牌确认出牌。")
    local energy, hand, block = battle.energy, #battle.hand, battle.player.block
    local discard, events, seed = #battle.discard, #battle.events, battle.seed
    click("enemy1")
    assert(ui.selected == selected and stage.children["card" .. slot].children.glow.visible)
    assert(battle.energy == energy and #battle.hand == hand and battle.player.block == block)
    assert(#battle.discard == discard and #battle.events == events and battle.seed == seed)
    assert(stage.children.notice.text:find("意图：", 1, true))
    click("card" .. slot)
    assert(ui.selected == nil and battle.energy == energy - 1 and #battle.hand == hand - 1)
    assert(battle.player.block == block + 5 and battle.discard[#battle.discard].uid == selected)
end)

test("reward HUD shows committed relic healing and clears battle-only counters", function()
    local ui, stage, click, play = setup() click("start")
    local battle = ui.run.combat
    battle.player.hp, battle.enemies[1].hp = 50, 1 -- deterministic injured victory fixture
    local slot
    for i, instance in ipairs(battle.hand) do
        if Combat.cardDefinition(battle, instance).type == "attack" then slot = i break end
    end
    assert(slot, "fixture should contain attack")
    play(slot) -- actual selection and target callbacks resolve Run.play/finishCombat
    assert(ui.run.phase == "reward" and ui.run.hp == 56 and battle.player.hp == 50)
    assert(stage.children.player.text == "生命 56/80")
    assert(stage.children.energy.text == "0/3" and stage.children.draw.text == "0" and stage.children.discard.text == "0")
    local disc, empty = stage.children.energyDisc.imageColor, Theme.color.energyEmpty
    assert(disc.r == empty.r and disc.g == empty.g and disc.b == empty.b and disc.a == empty.a)
    assert(not stage.children.piles.text:find("消耗", 1, true) and stage.children.statuses.text == "")
    assert(not stage.children.hero.visible and not stage.children.enemy1.visible)
    click("skip")
    assert(ui.run.phase == "map" and stage.children.player.text == "生命 56/80" and stage.children.energy.text == "0/3")
    click("continue")
    assert(ui.run.phase == "combat" and ui.run.combat.player.hp == 56 and stage.children.player.text == "生命 56/80")
    assert(stage.children.energy.text == "3/3" and stage.children.hero.visible)
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
test("intent previews use core modifiers without changing combat state or consuming effects", function()
    local ui, stage, click = setup() click("start")
    local battle = ui.run.combat
    local enemy = battle.enemies[1]
    Combat.addStatus(enemy, "strength", 2) Combat.addStatus(enemy, "weak", 2)
    Combat.addStatus(battle.player, "vulnerable", 2)
    local hp, seed, events = enemy.hp, battle.seed, #battle.events
    ui:render() ui:render()
    assert(stage.children.enemy1.children.intent.text == "9")
    assert(stage.children.enemy1.children.statuses.text:find("力量 2", 1, true))
    assert(enemy.hp == hp and battle.seed == seed and #battle.events == events)
    click("endTurn")
    local actual
    for i = events + 1, #battle.events do
        local event = battle.events[i]
        if event.kind == "damage" and event.detail.source == enemy.id then actual = event.detail.amount + event.detail.blocked end
    end
    assert(actual == 9)
    enemy.intents[enemy.intentIndex] = {kind="defend", effects={
        {op="gainStatus", status="dexterity", value=3}, {op="block", value=10}, {op="damage", value=6, times=2}}}
    Combat.addStatus(enemy, "frail", 2)
    ui:render()
    assert(stage.children.enemy1.children.intent.text == "9")
    click("enemy1")
    local preview = stage.children.notice.text
    assert(preview:find("格挡 9", 1, true) and preview:find("9×2 点伤害", 1, true))
    assert(not enemy.statuses.dexterity and enemy.block == 0)
end)

test("exact actor HP and block remain readable native text after rendering and enemy actions", function()
    local ui, stage, click = setup() click("start")
    local battle = ui.run.combat
    local function check(box, actor)
        assert(box.children.hp.text == tostring(actor.hp) .. "/" .. tostring(actor.maxHp))
        for _, name in ipairs({"name", "hp", "block", "statuses"}) do
            assert(box.children[name].sizeDeltaY >= Theme.layout.nativeText.lineHeight, name .. " native line height")
        end
        assert(box.children.name.text ~= "")
    end
    check(stage.children.hero, battle.player)
    check(stage.children.enemy1, battle.enemies[1])
    click("endTurn")
    check(stage.children.hero, battle.player)
    check(stage.children.enemy1, battle.enemies[1])
end)

test("potion slots stay fixed after consumption and repeated queued clicks cannot consume the next bottle", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 1)
    ui.run.potions = {"fire_potion", "energy_potion", "fire_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo")) ui:render()
    local battle = ui.run.combat
    local hp, energy = battle.enemies[1].hp, battle.energy
    assert(stage.children.potion1.children.normal.children.label.text == "火焰药水\n固定伤害 20")
    local queued = stage.children.potion1.click
    click("potion1") queued()
    assert(ui.run.combat == battle and battle.enemies[1].hp == hp - 20)
    assert(#ui.run.potions == 2 and battle.energy == energy)
    assert(stage.children.potion1.children.normal.children.label.text == "空药水槽")
    assert(not stage.children.potion1.interactable)
    click("potion2")
    assert(battle.energy == energy + 2 and #ui.run.potions == 1)
    click("potion3")
    assert(battle.enemies[1].hp == hp - 40 and #ui.run.potions == 0)
end)

test("potion victory commits rewards and relic healing then hides combat potion input", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 1) ui.run.potions = {"fire_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat.enemies[1].hp, ui.run.combat.player.hp = 20, 30
    ui:render() click("potion1")
    assert(ui.run.phase == "reward" and ui.run.hp == 36 and #ui.run.potions == 0)
    assert(stage.children.player.text == "生命 36/80" and stage.children.skip.visible)
    assert(not stage.children.potion1.visible and not stage.children.endTurn.visible)
    local gold = ui.run.gold
    stage.children.potion1.click()
    assert(ui.run.gold == gold and ui.run.phase == "reward")
end)

test("embedded battle uses host controls and scaling and reports each successful command once", function()
    local changes = 0
    local ui, stage, click, play, root = setup({embedded=true, onChange=function(view)
        assert(view.run) changes = changes + 1
    end})
    assert(root == stage and not root.children.start.visible and not root.children.continue.visible)
    root.children.start.click() assert(not ui.run)
    ui.run = Run.new(Data, 1) ui.run.potions = {"energy_potion", "fire_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo")) ui:render()
    ui:resize(1920, 1080)
    assert(ui.canvasWidth == 1920 and root.localScaleX == nil)
    click("card1") assert(changes == 0)
    local instance = ui.run.combat.hand[1]
    local _, reason = Combat.canPlay(ui.run.combat, instance.uid, nil)
    click(reason == "invalid_target" and "enemy1" or "card1") assert(changes == 1)
    click("potion1") assert(changes == 2)
    click("endTurn") assert(changes == 3)
    ui.run.combat.enemies[1].hp = 1
    click("potion2") assert(changes == 4 and ui.run.phase == "reward")
    assert(root.children.skip.visible and not root.children.continue.visible)
    click("skip") assert(changes == 5 and ui.run.phase == "map")
    root.children.continue.click()
    assert(changes == 5 and ui.run.phase == "map")
end)

test("inactive battle rejects stale card enemy potion end-turn reward and menu callbacks", function()
    local changes = 0
    local ui, stage, click = setup({onChange=function() changes = changes + 1 end}) click("start")
    ui.run.potions = {"energy_potion"}
    ui.potionBattle = nil ui:render()
    click("card1")
    local battle, selected, target = ui.run.combat, ui.selected, ui.target
    local hp, energy, hand, turn, seed, events = battle.enemies[1].hp, battle.energy, #battle.hand, battle.turn, battle.seed, #battle.events
    local before = changes
    ui:setActive(false)
    assert(not ui.root.visible and not stage.children.endTurn.interactable)
    stage.children.card1.children.hit.click() stage.children.enemy1.children.hit.click()
    stage.children.potion1.click() stage.children.endTurn.click() ui:playSelected(1)
    assert(battle.enemies[1].hp == hp and battle.energy == energy and #battle.hand == hand and battle.turn == turn)
    assert(battle.seed == seed and #battle.events == events and ui.selected == selected and ui.target == target)
    assert(#ui.run.potions == 1 and changes == before)
    ui.run.phase = "reward" ui.run.rewards = {gold=0, cards={"strike"}}
    stage.children.skip.click() stage.children.card1.children.hit.click()
    assert(ui.run.phase == "reward" and changes == before)
    ui.run.phase = "defeat" stage.children.start.click()
    assert(ui.run.phase == "defeat" and changes == before)
end)

test("host run replacement clears selected UID target and consumed potion mapping before restart", function()
    local ui, stage, click = setup({embedded=true})
    ui.run = Run.new(Data, 1) ui.run.potions = {"energy_potion", "fire_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo")) ui:render()
    click("card1") click("potion1") ui.target = 5
    assert(ui.selected and not ui.potionSlots[1])
    ui.run = Run.new(Data, 1) ui.run.potions = {"energy_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui:render()
    assert(not ui.selected and ui.target == 1 and ui.potionSlots[1].slot == 1)
    assert(stage.children.potion1.interactable and not stage.children.card1.children.glow.visible)
    click("potion1") assert(ui.run.combat.energy == 5 and #ui.run.potions == 0)
end)

test("runtime potion touch regions clear boss and five-enemy portraits intents and notice", function()
    local ui, stage, click = setup() click("start")
    local function overlaps(a, ax, ay, b, bx, by)
        return math.abs(ax - bx) < (a.sizeDeltaX + b.sizeDeltaX) / 2
            and math.abs(ay - by) < (a.sizeDeltaY + b.sizeDeltaY) / 2
    end
    for _, enemies in ipairs({{"guardian"}, {"cultist", "red_louse", "green_louse", "jaw_worm", "sentry"}}) do
        ui.run.combat = Combat.new(Data, {enemies=enemies}) ui:render()
        for i = 1, 3 do
            local potion = stage.children["potion" .. i]
            local notice = stage.children.notice
            assert(not overlaps(potion, potion.x, potion.y, notice, notice.x, notice.y))
            for j = 1, #enemies do
                local enemy = stage.children["enemy" .. j]
                for _, name in ipairs({"hit", "intent", "intentIcon"}) do
                    local part = enemy.children[name]
                    assert(not overlaps(potion, potion.x, potion.y, part, enemy.x + part.x, enemy.y + part.y))
                    assert(not overlaps(notice, notice.x, notice.y, part, enemy.x + part.x, enemy.y + part.y))
                end
            end
        end
    end
end)
test("targeted potion shows its effect and current enemy selection before damaging only that enemy", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 1) ui.run.potions = {"fire_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, {enemies={"cultist", "jaw_worm"}})
    ui:render()
    local battle = ui.run.combat
    local hp1, hp2, energy, hand, events = battle.enemies[1].hp, battle.enemies[2].hp, battle.energy, #battle.hand, #battle.events
    local function marked(index)
        local colour, gold = stage.children["enemy" .. index].children.border.imageColor, Theme.color.goldBright
        return colour.r == gold.r and colour.g == gold.g and colour.b == gold.b
    end
    assert(not ui.selected and marked(1) and not marked(2))
    for _, state in ipairs({"normal", "hover", "pressed", "disabled"}) do
        assert(stage.children.potion1.children[state].children.label.text == "火焰药水\n固定伤害 20")
    end
    click("enemy2")
    assert(ui.target == 2 and marked(2) and not marked(1))
    assert(stage.children.notice.text:find("药水目标：" .. battle.enemies[2].name, 1, true))
    assert(battle.enemies[1].hp == hp1 and battle.enemies[2].hp == hp2)
    assert(battle.energy == energy and #battle.hand == hand and #battle.events == events)
    -- A selected self card still cannot execute merely by choosing a potion target.
    local defend
    for i, instance in ipairs(battle.hand) do if instance.cardId == "defend" then defend = i break end end
    assert(defend) click("card" .. defend)
    local selected = ui.selected
    click("enemy1") click("enemy2")
    assert(ui.selected == selected and battle.energy == energy and #battle.hand == hand and battle.player.block == 0)
    assert(marked(2) and not marked(1))
    click("potion1")
    assert(battle.enemies[1].hp == hp1 and battle.enemies[2].hp == hp2 - 20 and #ui.run.potions == 0)
    assert(not marked(1) and not marked(2) and ui.selected == selected)
end)
print("LUA_UI_PASS " .. count)
