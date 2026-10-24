package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")

-- Compose the controller with the actual generated native tree, not a permissive mock.
-- These methods capture no node state. Keep them as own fields so overrides
-- and pairs/rawget see the same control shape without per-node closures.
local Control = {}
function Control:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
function Control:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
function Control:AddCursorEventListener(event, fn)
    self.listeners = self.listeners or {}
    self.listeners[event] = fn
    if event == "click" then self.click = fn end
end
function Control:SetAnchoredPosition(x, y) self.x, self.y = x, y end
function Control:SetSizeDelta(x, y) self.sizeDeltaX, self.sizeDeltaY = x, y end
function Control:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
function Control:SetImage(...)
    assert(select("#", ...) == 2, "SetImage expects exactly source and id")
    local source, id = ...
    assert(source == "static" and type(id) == "number") self.imageId = id
end
function Control:SetAsLastSibling() self.raised = true end

local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    c.GetChild = Control.GetChild
    c.SetVisible = Control.SetVisible
    c.AddCursorEventListener = Control.AddCursorEventListener
    c.SetAnchoredPosition = Control.SetAnchoredPosition
    c.SetSizeDelta = Control.SetSizeDelta
    c.SetLocalScale = Control.SetLocalScale
    c.SetImage = Control.SetImage
    c.SetAsLastSibling = Control.SetAsLastSibling
    return c
end
local function setup(options)
    local root = control({name="root", size={1280,720}, children=assert(ABYSS_TEST_LAYOUT).controls})
    local stage = root:GetChild("stage")
    if options and options.embedded then root = stage end
    local ui = UI.new(root, Data, Presentation, "click", {imageSource="static", color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
        cursorEvents=options and options.dragEvents and {CursorDown="down",CursorDrag="drag",CursorUp="up",CursorEndDrag="endDrag"} or nil}, options)
    local function click(name)
        local box = stage:GetChild(name)
        if box.click then if box.interactable then box.click() end else box:GetChild("hit").click() end
        if not (options and options.manualPlayback) and ui.feedback and ui.feedback.busy then
            for _ = 1, 400 do if not ui.busy then break end ui:update(0.05) end
            assert(not ui.busy, "presentation must release input")
        end
    end
    local function play(slot, target)
        click("card" .. slot)
        local instance = ui.run.phase == "combat" and ui.run.combat.hand[slot]
        if instance and ui.selected == instance.uid then
            local _, reason = Combat.canPlay(ui.run.combat, instance.uid, nil)
            click(reason == "invalid_target" and "enemy" .. (target or 1) or "playArea")
        end
    end
    return ui, stage, click, play, root
end
-- Read a unit's statuses the way a player does: open its detail panel, then close it.
local function details(stage, box)
    box.children.statusRow.children.hit.click()
    local info, lines = stage.children.statusInfo, {}
    assert(info.visible)
    for i = 1, Theme.layout.statusInfo.rows do
        if info.children["name" .. i].visible then lines[#lines + 1] = info.children["name" .. i].text end
    end
    info.children.hit.click()
    assert(not info.visible)
    return table.concat(lines, " | ")
end
local count = 0
local function test(name, fn) fn() count=count+1 print("ok UI " .. count .. " - " .. name) end

test("Dazed uses existing status art disabled theme blank cost and cannot command play", function()
    local ui,stage,click=setup()
    ui.run=Run.new(Data,42)
    ui.run.deck={{uid=1,cardId="dazed",upgraded=false}}
    assert(Run.startCombat(ui.run,"cultist_solo"));ui:render()
    local card=stage.children.card1.children
    assert(card.name.text==Presentation.dazed.name and card.cost.text=="" and card.type.text=="状态")
    assert(card.art.imageId==Theme.icon.cardArt.status)
    assert(card.artPlate.imageColor.r==Theme.color.panelSunken.r)
    assert(card.border.imageColor.r==Theme.color.line.r)
    local battle,energy=ui.run.combat,ui.run.combat.energy
    click("card1");click("enemy1");assert(ui.selected==nil)
    assert(battle.energy==energy and #battle.hand==1 and #battle.discard==0)
end)

test("menu starts a real battle with shared-theme cards, energy and current intents", function()
    local ui, stage, click = setup()
    assert(ui.run == nil and stage.children.start.visible and not stage.children.card1.visible)
    click("start")
    assert(ui.run.phase == "combat" and #ui.run.deck == 10)
    assert(stage.children.card1.visible and not stage.children.card6.visible)
    assert(stage.children.card1.children.label.text ~= "")
    assert(stage.children.energy.text == "3/3")
    assert(stage.children.enemy1.children.intent.text == "")
    click("enemy1")
    assert(stage.children.notice.text:find("自身获得 3 层仪式",1,true))
    click("endTurn")
    -- Ritual alone: one buff chip with its stack count, and no Strength chip yet.
    local row = stage.children.enemy1.children.statusRow.children
    assert(row.icon1.visible and row.icon1.imageId == Theme.icon.status.ritual and row.count1.text == "3")
    assert(row.icon1.imageColor.r == Theme.color.buff.r and not row.icon2.visible and not row.count2.visible)
    assert(stage.children.enemy1.children.intent.text == "6")
    assert(stage.children.enemy1.children.portrait.imageId == Theme.icon.enemy.cultist)
    assert(stage.children.hero.children.hpFill.fillAmount == 1)
end)
test("Jaw Worm real encounter presents combined Thrash and Bellow effects without changing rules", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 42)
    assert(Run.startCombat(ui.run, "jaw_solo"))
    ui:render()
    local battle, enemy = ui.run.combat, ui.run.combat.enemies[1]
    assert(stage.children.enemy1.children.intent.text == "11")
    -- Explicit project roll control, not an original STS seed claim.
    battle.seed = 0 -- next LCG value 13849 => roll 49 => Thrash
    assert(Combat.endTurn(battle)); ui:render()
    assert(Combat.intent(battle,1).id == "jaw_worm_2")
    assert(stage.children.enemy1.children.intent.text == "7")
    click("enemy1")
    assert(stage.children.notice.text:find("7 点伤害",1,true) and stage.children.notice.text:find("获得 5 点格挡",1,true))
    enemy.intentIndex = 3 -- inspect the declared Bellow face independently of another roll
    ui:render(); click("enemy1")
    assert(stage.children.notice.text:find("自身获得 3 层力量",1,true) and stage.children.notice.text:find("获得 6 点格挡",1,true))
    assert(enemy.statuses.strength == nil and enemy.block == 0, "preview mutated the actor")
end)

test("selection never spends energy; target click or explicit battlefield click issues one real command", function()
    local ui, stage, click, play = setup() click("start")
    local battle = ui.run.combat
    local id, energy = battle.hand[1].uid, battle.energy
    click("card1")
    assert(#battle.hand == 5 and battle.energy == energy and ui.selected == id)
    assert(stage.children.card1.children.glow.visible and stage.children.card1.localScaleX == Theme.motion.hoverScale)
    local _, reason = Combat.canPlay(battle, id, nil)
    click(reason == "invalid_target" and "enemy1" or "playArea")
    assert(#battle.hand == 4 and battle.discard[1].uid == id and ui.selected == nil)
    -- Energy preparation uses float arithmetic to detect overflow before wrapping.
    assert(battle.energy % 1 == 0, "energy must retain its integer value contract")
    assert(not stage.children.card5.visible and stage.children.energy.text == string.format("%.0f/3", battle.energy))
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
    assert(stage.children.enemy1.children.intent.text == "6")
    click("enemy1")
    assert(stage.children.notice.text:find("6 点伤害", 1, true))
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
            assert(ui.selected == nil and #battle.hand == 5)
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
    assert(stage.children.notice.text == "点击战场出牌区域；再点原牌取消")
    local energy, hand, block = battle.energy, #battle.hand, battle.player.block
    local discard, events, seed = #battle.discard, #battle.events, battle.seed
    click("enemy1")
    assert(ui.selected == selected and stage.children["card" .. slot].children.glow.visible)
    assert(battle.energy == energy and #battle.hand == hand and battle.player.block == block)
    assert(#battle.discard == discard and #battle.events == events and battle.seed == seed)
    assert(stage.children.notice.text:find("意图：", 1, true))
    click("playArea")
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
    assert(stage.children.player.text == "56/80")
    assert(stage.children.energy.text == "0/3" and stage.children.draw.text == "0" and stage.children.discard.text == "0")
    local disc, empty = stage.children.energyDisc.imageColor, Theme.color.energyEmpty
    assert(disc.r == empty.r and disc.g == empty.g and disc.b == empty.b and disc.a == empty.a)
    assert(not stage.children.piles.text:find("消耗", 1, true) and stage.children.statuses.text == "")
    assert(not stage.children.hero.visible and not stage.children.enemy1.visible)
    click("continue")
    assert(ui.run.phase == "map" and stage.children.player.text == "56/80" and stage.children.energy.text == "0/3")
    click("continue")
    assert(ui.run.phase == "combat" and ui.run.combat.player.hp == 56 and stage.children.player.text == "56/80")
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
    assert(ui.run.phase == "reward" and stage.children.cardReward.visible)
    assert(stage.children.rewardList.visible and not stage.children.rewardStage.visible)
    assert(not stage.children.endTurn.visible and not stage.children.enemy1.visible)
    local chosen = ui.run.rewards.cards[1]
    click('cardReward')
    click("card1")
    assert(ui.run.phase == "reward" and #ui.run.deck == 11 and stage.children.continue.visible)
    click("continue");assert(ui.run.phase=='map');click('continue')
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
    enemy.ai=nil; enemy.intentIndex=1 -- isolate preview arithmetic from the Ritual opener.
    Combat.addStatus(enemy, "strength", 2) Combat.addStatus(enemy, "weak", 2)
    Combat.addStatus(battle.player, "vulnerable", 2)
    local hp, seed, events = enemy.hp, battle.seed, #battle.events
    ui:render() ui:render()
    assert(stage.children.enemy1.children.intent.text == "9")
    stage.children.enemy1.children.statusRow.children.hit.click()
    local info = stage.children.statusInfo.children
    assert(stage.children.statusInfo.visible and info.name1.text == "力量 2" and info.name2.text == "虚弱 2")
    stage.children.statusInfo.children.hit.click()
    assert(not stage.children.statusInfo.visible)
    assert(enemy.hp == hp and battle.seed == seed and #battle.events == events)
    local playerHp = battle.player.hp
    click("endTurn")
    assert(playerHp - battle.player.hp == 9)
    enemy.intents[enemy.intentIndex] = {kind="defend", effects={
        {op="gainStatus", status="dexterity", value=3}, {op="block", value=10}, {op="damage", value=6, times=2}}}
    Combat.addStatus(enemy, "frail", 2)
    ui:render()
    assert(stage.children.enemy1.children.intent.text == "")
    click("enemy1")
    local preview = stage.children.notice.text
    assert(preview:find("获得 9 点格挡", 1, true) and preview:find("攻击 2 次，每次 9 点伤害", 1, true))
    assert(not enemy.statuses.dexterity and enemy.block == 0)
end)

test("exact actor HP and block remain readable native text after rendering and enemy actions", function()
    local ui, stage, click = setup() click("start")
    local battle = ui.run.combat
    local function check(box, actor)
        assert(box.children.hp.text == tostring(actor.hp) .. "/" .. tostring(actor.maxHp))
        for _, name in ipairs({"name", "hp", "block"}) do
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

test("block chip sits beside the HP bar with dark digits on solid blue, even in a five-enemy row", function()
    local ui, stage = setup()
    ui.run = Run.new(Data, 1)
    -- Explicit capacity fixture: real gremlin_gang now has four actors. Keep
    -- all five UI slots under test without claiming this is a legal encounter.
    ui.run.floor, ui.run.phase = 5, "combat"
    ui.run.combat = Combat.new(Data, {seed=1, deck=ui.run.deck,
        enemies={"mad_gremlin", "sneaky_gremlin", "fat_gremlin", "wizard_gremlin", "shield_gremlin"}})
    local battle = ui.run.combat
    assert(#battle.enemies == 5)
    battle.player.block = 6
    for _, enemy in ipairs(battle.enemies) do enemy.block = 7 end
    ui:render()
    local function check(box, block)
        local c = box.children
        local chipRight = c.blockIcon.x + c.blockIcon.sizeDeltaX / 2
        local barLeft = c.hpBorder.x - c.hpBorder.sizeDeltaX / 2
        assert(c.blockIcon.visible and c.blockEdge.visible and c.block.visible)
        assert(chipRight < barLeft, box.name .. " chip overlaps the HP bar")
        assert(c.hp.x == c.hpFill.x and c.hp.sizeDeltaX == c.hpFill.sizeDeltaX, "HP text stays on its bar")
        assert(c.block.text == tostring(block))
        assert(c.block.x == c.blockIcon.x and c.blockEdge.x == c.blockIcon.x)
        assert(c.blockIcon.imageColor.b == Theme.color.block.b and c.block.fontColor.r == Theme.color.textOnLight.r)
        assert(c.hpBorder.imageColor.b == Theme.color.block.b and c.hpFill.imageColor.b == Theme.color.hpShielded.b)
        return c.blockEdge.x - c.blockEdge.sizeDeltaX / 2, c.hpBorder.x + c.hpBorder.sizeDeltaX / 2
    end
    check(stage.children.hero, 6)
    local previousRight
    for i = 1, 5 do
        local box = stage.children["enemy" .. i]
        local left, right = check(box, 7)
        if previousRight then assert(box.x + left > previousRight, "enemy" .. i .. " chip collides with its neighbour") end
        previousRight = box.x + right
    end
    battle.player.block = 0
    ui:render()
    local hero = stage.children.hero.children
    assert(not hero.blockIcon.visible and not hero.block.visible and not hero.blockEdge.visible)
    assert(hero.hpFill.imageColor.r == Theme.color.hp.r and hero.hpBorder.imageColor.r == Theme.color.line.r)
    assert(hero.hpFill.sizeDeltaX == Theme.layout.hpBar.size[1] and hero.hpFill.x == 0)
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
    assert(Run.potionCount(ui.run) == 2 and battle.energy == energy)
    assert(stage.children.potion1.children.normal.children.label.text == "空药水槽")
    assert(not stage.children.potion1.interactable)
    click("potion2")
    assert(battle.energy == energy + 2 and Run.potionCount(ui.run) == 1)
    click("potion3")
    assert(battle.enemies[1].hp == hp - 40 and #ui.run.potions == 0)
end)

test("refilling a middle potion slot refreshes only its physical button", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 1)
    ui.run.potions = {"fire_potion", "energy_potion", "regen_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo")) ui:render()
    click("potion2")
    assert(ui.run.potions[1] == "fire_potion" and ui.run.potions[3] == "regen_potion")
    assert(stage.children.potion2.children.normal.children.label.text == "空药水槽")
    local ok, slot = Run.obtainPotion(ui.run, "block_potion")
    assert(ok and slot == 2) ui:render()
    assert(stage.children.potion2.children.normal.children.label.text:find("护盾药水", 1, true))
    assert(stage.children.potion1.children.normal.children.label.text:find("火焰药水", 1, true))
    assert(stage.children.potion3.children.normal.children.label.text:find("再生药水", 1, true))
    click("potion2")
    assert(ui.run.combat.player.block == 12 and not ui.run.potions[2])
    assert(Run.potionCount(ui.run) == 2)
end)

test("potion victory commits rewards and relic healing then hides combat potion input", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 1) ui.run.potions = {"fire_potion"}
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat.enemies[1].hp, ui.run.combat.player.hp = 20, 30
    ui:render() click("potion1")
    assert(ui.run.phase == "reward" and ui.run.hp == 36 and #ui.run.potions == 0)
    assert(stage.children.player.text == "36/80" and stage.children.cardReward.visible)
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
    click(reason == "invalid_target" and "enemy1" or "playArea") assert(changes == 1)
    click("potion1") assert(changes == 2)
    click("endTurn") assert(changes == 3)
    ui.run.combat.enemies[1].hp = 1
    click("potion2") assert(changes == 4 and ui.run.phase == "reward")
    assert(root.children.cardReward.visible and root.children.continue.visible and not root.children.skip.visible)
    click('cardReward');click('skip');assert(changes==4 and ui.run.phase=='reward')
    click("continue") assert(changes == 5 and ui.run.phase == "map")
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
test("a targeted bottle in slot three remains selectable when both earlier slots are empty", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data, 1) ui.run.potions = { [3] = "fire_potion" }
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, {enemies={"cultist", "jaw_worm"}})
    ui:render()
    assert(ui.potionTargetAvailable and not stage.children.potion1.interactable and not stage.children.potion2.interactable)
    assert(stage.children.potion3.interactable)
    local hp1, hp2 = ui.run.combat.enemies[1].hp, ui.run.combat.enemies[2].hp
    click("enemy2") assert(ui.target == 2)
    click("potion3")
    assert(ui.run.combat.enemies[1].hp == hp1 and ui.run.combat.enemies[2].hp == hp2 - 20)
    assert(Run.potionCount(ui.run) == 0)
end)

test("real attack holds HP until flight finishes and rejects repeat input until playback drains", function()
    local ui, stage, click = setup({manualPlayback=true}) click("start")
    local battle = ui.run.combat
    local slot
    for i, card in ipairs(battle.hand) do if card.cardId == "strike" then slot = i break end end
    assert(slot) local hp = battle.enemies[1].hp
    click("card" .. slot) click("enemy1")
    assert(ui.busy, "real card play must wait for presentation")
    assert(battle.enemies[1].hp == hp - 6, "rules still resolve synchronously")
    assert(stage.children.enemy1.children.hp.text == hp .. "/" .. battle.enemies[1].maxHp,
        "HP must not jump to the final result before impact")
    local turn, energy = battle.turn, battle.energy
    click("endTurn") click("enemy1") click("card1")
    assert(battle.turn == turn and battle.energy == energy)
    ui:update(Theme.motion.base)
    assert(stage.children.enemy1.children.hp.text == (hp - 6) .. "/" .. battle.enemies[1].maxHp)
    for _ = 1, 80 do ui:update(0.05) end
    assert(not ui.busy and stage.children.endTurn.interactable)
end)
local function drain(ui, inspect)
    local previous
    for _ = 1, 2000 do
        if not ui.busy then return end
        local entry = ui.feedback.current
        if entry ~= previous then if inspect then inspect(entry) end previous = entry end
        ui:update(inspect and 0.02 or 0.2)
    end
    error("queue did not release input")
end
local function feedbackBattle(deck, enemies, options)
    options = options or {} options.manualPlayback = true
    local ui, stage, click = setup(options)
    ui.run = Run.new(Data, 11)
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, {deck=deck, enemies=enemies, seed=11})
    ui:render()
    return ui, stage, click, ui.run.combat
end
test("Block badges reserve native glyph width for every digit from 1 through 999", function()
    local ui, stage, _, battle = feedbackBattle({"defend"}, {"cultist", "cultist", "cultist", "cultist", "cultist"})
    for _, value in ipairs({1, 10, 99, 100, 999}) do
        battle.player.block = value
        for _, enemy in ipairs(battle.enemies) do enemy.block = value end
        ui:render()
        for _, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
            local c = stage.children[name].children
            assert(c.block.text == tostring(value), name .. " exact digits")
            -- Native text uses wider digits than the mock; autoSize does not
            -- save a 28px rectangle that clips the second digit of Block 10.
            assert(c.block.sizeDeltaX >= #tostring(value) * Theme.font.body, name .. " clips Block " .. value)
            assert(c.blockIcon.sizeDeltaX >= c.block.sizeDeltaX, name .. " number spills off its chip")
            assert(c.hp.sizeDeltaX >= #c.hp.text * Theme.font.small, name .. " clips HP while showing Block " .. value)
            assert(c.blockEdge.x + c.blockEdge.sizeDeltaX / 2 <= c.hpBorder.x - c.hpBorder.sizeDeltaX / 2
                or c.blockEdge.y - c.blockEdge.sizeDeltaY / 2 >= c.hpBorder.y + c.hpBorder.sizeDeltaY / 2,
                name .. " chip overlaps HP")
        end
    end
end)

test("animated block badges keep HP and neighbouring columns clear for player, one to five enemies and boss", function()
    for count = 1, 6 do
        local enemies = {}
        for i = 1, math.min(count, 5) do enemies[i] = "cultist" end
        if count == 6 then enemies = {"guardian"} end
        -- Both standalone click-only fallback and embedded/drag-capable hosts use this feedback path.
        local ui, stage, click, battle = feedbackBattle({"defend"}, enemies,
            {embedded=count % 2 == 0, dragEvents=count % 2 == 0})
        ui:resize(count % 2 == 0 and 1920 or 1280, count % 2 == 0 and 1080 or 720)
        for _, enemy in ipairs(battle.enemies) do
            enemy.block, enemy.ai, enemy.intentIndex = 7, nil, 1
            enemy.intents = {{kind="defend", effects={{op="block",value=5}}}}
        end
        ui:render()
        local popped = {}
        local function bounds(box)
            local c = box.children
            local barLeft = c.hpBorder.x - c.hpBorder.sizeDeltaX / 2
            local left = barLeft
            if c.block.visible then
                for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
                    local part = c[name]
                    local half = part.sizeDeltaX * (part.localScaleX or 1) / 2
                    local above = part.y - part.sizeDeltaY * (part.localScaleY or 1) / 2
                        >= c.hpBorder.y + c.hpBorder.sizeDeltaY / 2
                    assert(part.x + half <= barLeft + 0.000001 or above, box.name .. "/" .. name .. " animated over HP")
                    left = math.min(left, part.x - half)
                    assert(part.localScaleY == c.blockIcon.localScaleY, "chip parts animate together")
                end
                if (c.blockIcon.localScaleY or 1) > 1 then popped[box.name] = true end
                local displayed = ui.displayBattle or battle
                local actor = box.name == "hero" and displayed.player or displayed.enemies[tonumber(box.name:match("%d+"))]
                assert(c.block.text == string.format("%.0f", actor.block), "animation preserves exact Block digits")
            end
            return box.x + left, box.x + c.hpBorder.x + c.hpBorder.sizeDeltaX / 2
        end
        local function inspect()
            bounds(stage.children.hero)
            local previousRight
            for i = 1, #battle.enemies do
                local left, right = bounds(stage.children["enemy" .. i])
                assert(not previousRight or left > previousRight, "animated chip crosses neighbouring HP")
                previousRight = right
            end
        end
        local function playback()
            for _ = 1, 800 do
                ui:update(0.02) inspect()
                if not ui.busy and next(ui.feedback.effects) == nil then return end
            end
            error("block playback did not finish")
        end
        click("card1") click("playArea") playback()
        assert(popped.hero, "actual Defend must retain vertical badge feedback")
        click("endTurn") playback()
        for i = 1, #battle.enemies do
            local box = stage.children["enemy" .. i]
            assert(popped[box.name], "each enemy must play actual block feedback")
            for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
                assert(box.children[name].localScaleX == 1 and box.children[name].localScaleY == 1, "badge resets after playback")
            end
        end
    end
end)
test("block gain and absorption have blue shield feedback without HP shake on a fully blocked hit", function()
    local ui, stage, click, battle = feedbackBattle({"defend"}, {"cultist"})
    -- This feedback fixture needs a six-damage attack, independent of Cultist's opening Ritual.
    battle.enemies[1].ai=nil; battle.enemies[1].intentIndex=1
    battle.player.block = 2 ui:render()
    click("card1") click("playArea")
    assert(battle.player.block == 7 and stage.children.hero.children.block.text == "2")
    assert(ui.feedback.flight.tx == Theme.layout.player.position[1], "self card must fly to the player, regardless of selected enemy")
    ui:update(Theme.motion.base)
    assert(stage.children.hero.children.block.text == "7")
    assert(stage.children.hero.children.shield.visible)
    drain(ui)
    local hp = battle.player.hp
    click("endTurn")
    local hits = 0
    drain(ui, function(entry)
        if entry.kind == "damage" then
            hits = hits + 1
            assert(entry.detail.blocked == 6 and entry.detail.amount == 0)
            assert(stage.children.hero.children.shield.visible and stage.x == 0)
            assert(stage.children.hero.children.floating.text == "格挡 6")
            local c = stage.children.hero.children
            for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
                local part = c[name]
                assert(part.x + part.sizeDeltaX * (part.localScaleX or 1) / 2
                    <= c.hpBorder.x - c.hpBorder.sizeDeltaX / 2, "absorbing damage must not expand badge into HP")
            end
        end
    end)
    assert(hits == 1 and battle.player.hp == hp and battle.player.block == 0)
end)
test("cancelling block playback resets every badge part without hiding the committed value", function()
    local ui, stage, click, battle = feedbackBattle({"defend"}, {"cultist"})
    click("card1") click("playArea")
    local c = stage.children.hero.children
    for _ = 1, 50 do
        ui:update(0.02)
        if (c.blockIcon.localScaleY or 1) > 1 then break end
    end
    assert(c.blockIcon.localScaleY > 1, "cancel while vertical feedback is active")
    ui.feedback:cancel()
    assert(not ui.busy and c.block.text == string.format("%.0f", battle.player.block))
    for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
        assert(c[name].visible and c[name].localScaleX == 1 and c[name].localScaleY == 1)
    end
end)
test("multiple enemies and multi-hit intents show each actor and actual HP in order, even after a long frame", function()
    local ui, stage, click, battle = feedbackBattle({"defend"}, {"jaw_worm", "cultist"})
    battle.enemies[1].intents = {{id="multi",kind="attack",effects={{op="damage",value=2,times=3}}}}
    battle.enemies[1].ai=nil; battle.enemies[1].intentIndex=1 -- explicit custom intent fixture
    battle.enemies[2].intents = {{id="cast",kind="defend",effects={{op="block",value=5},{op="applyStatus",status="weak",value=2}}}}
    battle.enemies[2].ai=nil; battle.enemies[2].intentIndex=1 -- explicit custom intent fixture
    ui:render() local hp = battle.player.hp
    click("endTurn")
    assert(battle.player.hp == hp - 6 and battle.phase == "player")
    assert(ui.busy and stage.children.feedback.children.banner.text == "敌方回合")
    ui:update(100)
    assert(ui.busy and ui.feedback.current.kind == "intent", "a long frame must not skip the enemy turn")
    local kinds, hits = {}, 0
    drain(ui, function(entry)
        kinds[#kinds+1] = entry.kind
        if entry.kind == "intent" then
            local index = entry.detail.enemy == battle.enemies[1].id and 1 or 2
            local border = stage.children["enemy" .. index].children.border.imageColor
            assert(border.r == Theme.color.goldBright.r)
            assert((stage.children["enemy" .. index].children.intent.text ~= "") == (index == 1))
        elseif entry.kind == "damage" then
            hits = hits + 1
            assert(stage.children.hero.children.hp.text == (hp - hits * 2) .. "/80")
            assert(stage.children.hero.children.impact.visible)
        elseif entry.kind == "block" then assert(stage.children.enemy2.children.shield.visible)
        elseif entry.kind == "status" and entry.detail.status == "weak" then
            -- Playback frames drive the chips: Weak appears as a debuff chip with 2 stacks.
            local row = stage.children.hero.children.statusRow.children
            assert(row.icon1.visible and row.icon1.imageId == Theme.icon.status.weak and row.count1.text == "2")
            assert(row.icon1.imageColor.r == Theme.color.debuff.r)
        end
    end)
    assert(table.concat(kinds,",") == "intent,damage,damage,damage,intent,block,status,reshuffle,player_turn")
    assert(hits == 3 and not ui.busy)
end)
test("multi-hit player cards, area damage, ability and debuff cards use real events and distinct feedback", function()
    for _, id in ipairs({"twin_strike", "cleave", "inflame", "thunderclap"}) do
        local ui, stage, click, battle = feedbackBattle({id}, {"jaw_worm", "cultist"})
        click("card1")
        local _, reason = Combat.canPlay(battle, battle.hand[1].uid, nil)
        click(reason == "invalid_target" and "enemy1" or "playArea")
        assert(ui.busy and stage.children.feedback.children.playedCard.visible)
        if id == "inflame" then assert(ui.feedback.flight.tx == Theme.layout.player.position[1])
        elseif id ~= "twin_strike" then assert(ui.feedback.flight.tx == (Theme.layout.enemyRow.xFrom + Theme.layout.enemyRow.xTo) / 2) end
        assert(stage.children.feedback.children.playedCard.children.plate.imageColor.r == Theme.color.cardType[battle.catalog.cards[id].type].r)
        local hits, statuses = 0, 0
        drain(ui, function(entry)
            if entry.kind == "damage" then hits = hits + 1 end
            if entry.kind == "status" then
                statuses = statuses + 1
                local target = entry.detail.target == "player" and stage.children.hero or stage.children[entry.detail.target == battle.enemies[1].id and "enemy1" or "enemy2"]
                local chip = target.children.statusRow.children
                assert(target.children.floating.text ~= "" and chip.icon1.visible and chip.count1.text ~= "")
            end
        end)
        assert(hits == (id == "inflame" and 0 or 2))
        assert(statuses == (id == "inflame" and 1 or id == "thunderclap" and 2 or 0))
    end
end)
test("poison identifies its source and killed enemies never act; retaliation shows the defender as source", function()
    local ui, stage, click, battle = feedbackBattle({"strike"}, {"jaw_worm", "cultist"})
    battle.enemies[1].hp = 1 Combat.addStatus(battle.enemies[1], "poison", 2)
    ui:render() click("endTurn")
    local poison, death, intent = 0, 0, 0
    drain(ui, function(entry)
        if entry.kind == "status_damage" then
            poison = poison + 1
            assert(entry.detail.status == "poison" and entry.detail.source == battle.enemies[1].id)
            assert(stage.children.enemy1.children.floating.text:find("中毒",1,true))
        elseif entry.kind == "death" then death = death + 1
        elseif entry.kind == "intent" then intent = intent + 1 assert(entry.detail.enemy == battle.enemies[2].id) end
    end)
    assert(poison == 1 and death == 1 and intent == 1 and not stage.children.enemy1.visible)
    ui, stage, click, battle = feedbackBattle({"strike"}, {"cultist"})
    Combat.addStatus(battle.enemies[1], "thorns", 3)
    ui:render() click("card1") click("enemy1")
    local retaliation = 0
    drain(ui, function(entry)
        if entry.kind == "status_damage" then
            retaliation = retaliation + 1
            assert(entry.detail.source == battle.enemies[1].id and entry.detail.target == "player")
            assert(stage.children.hero.children.floating.text:find("荆棘",1,true))
        end
    end)
    assert(retaliation == 1)
end)
test("playback preserves every rule field and RNG against direct commands and cannot replay consumed events", function()
    for seed = 1, 6 do
        local ui, stage, click = setup({manualPlayback=true})
        ui.seed = seed click("start")
        local direct = Combat.copy(ui.run)
        local ignored = {events=true, data=true, catalog=true, statusDefinitions=true}
        local function same(a,b,path)
            if type(a) ~= "table" then assert(a == b, path) return end
            assert(type(b) == "table",path)
            for k,v in pairs(a) do if not ignored[k] then same(v,b[k],path .. "." .. tostring(k)) end end
            for k in pairs(b) do if not ignored[k] then assert(a[k] ~= nil,path .. "." .. tostring(k)) end end
        end
        same(ui.run.data,direct.data,"immutable data")
        same(ui.run.combat.catalog,direct.combat.catalog,"immutable catalog")
        for _ = 1, 20 do
            if ui.run.phase ~= "combat" then break end
            local battle, slot = ui.run.combat
            for i, card in ipairs(battle.hand) do if Combat.canPlay(battle,card.uid,1) then slot = i break end end
            if slot then
                local uid = battle.hand[slot].uid
                assert(Run.play(direct,uid,1))
                click("card" .. slot)
                local _, reason = Combat.canPlay(battle, uid, nil)
                click(reason == "invalid_target" and "enemy1" or "playArea")
            else assert(Run.endTurn(direct)) click("endTurn") end
            same(ui.run,direct,"committed")
            drain(ui) same(ui.run,direct,"after playback")
            assert(#battle.events == 0, "consumed frames must not accumulate")
            for _ = 1, 4 do ui:update(0.2) end
            same(ui.run,direct,"idle")
        end
    end
end)
test("effect setter failure restores final HP and input, and idle failure cannot repeat host notifications", function()
    local changes = 0
    local ui, stage, click, battle = feedbackBattle({"strike"},{"cultist"},{onChange=function() changes=changes+1 end})
    click("card1") click("enemy1")
    local impact = stage.children.enemy1.children.impact
    local setter = impact.SetVisible
    impact.SetVisible = function() error("INJECTED_EFFECT_FAILURE") end
    drain(ui)
    assert(changes == 1 and not ui.busy and stage.children.endTurn.interactable)
    assert(stage.children.enemy1.children.hp.text == battle.enemies[1].hp .. "/" .. battle.enemies[1].maxHp)
    for _ = 1, 10 do ui:update(0.1) end
    assert(changes == 1 and stage.x == 0)
    impact.SetVisible = setter
    click("endTurn") drain(ui)
    assert(changes == 2)
end)
test("a replacement run cancels stale playback and late updates cannot change or lock the new run", function()
    local changes = 0
    local ui, stage, click = feedbackBattle({"strike"},{"cultist"},{onChange=function() changes=changes+1 end})
    click("card1") click("enemy1") assert(ui.busy)
    ui.run = Run.new(Data,17) assert(Run.startCombat(ui.run,"cultist_solo"))
    local energy, hp = ui.run.combat.energy, ui.run.combat.enemies[1].hp
    ui:render()
    assert(not ui.busy and changes == 0 and stage.children.endTurn.interactable)
    for _ = 1, 100 do ui:update(0.1) end
    assert(ui.run.combat.energy == energy and ui.run.combat.enemies[1].hp == hp and not ui.busy)
end)
test("prepare failure does not execute a command and sound failure cannot interrupt feedback", function()
    local ui, stage, click, battle = feedbackBattle({"strike"},{"cultist"})
    click("card1")
    local energy, hp, seed = battle.energy, battle.enemies[1].hp, battle.seed
    local oldRender = ui.render
    ui.render = function() error("PREPARE_FAILURE") end
    ui:playSelected(1)
    assert(not ui.busy and battle.energy == energy and battle.enemies[1].hp == hp and battle.seed == seed)
    ui.render = oldRender ui:render()
    click("enemy1") drain(ui)
    assert(battle.enemies[1].hp == hp - 6 and not ui.busy)
    -- Exercise the same production feedback adapter with an audio service that throws.
    local Feedback = require("abyss_feedback")
    local Events = require("abyss_events")
    local s = Combat.new(Data,{deck={"strike"}})
    local before, first = Events.frame(s), #s.events+1
    assert(Combat.play(s,s.hand[1].uid,1))
    local finished = 0
    local feedback = Feedback.new(stage,{imageSource="static",color=function(...) return {...} end,sound=function() error("AUDIO_UNAVAILABLE") end},function() end,function() finished=finished+1 end)
    feedback:begin(before,s,first,Presentation)
    for _ = 1, 40 do feedback:update(0.05) end
    assert(finished == 1 and not feedback.busy)
end)
test("idle effect cleanup cannot paint the prior encounter into a replacement battle", function()
    local ui, stage, click = feedbackBattle({"strike"},{"cultist"})
    click("card1") click("enemy1") drain(ui)
    assert(not ui.busy and next(ui.feedback.effects))
    ui.run = Run.new(Data,19) assert(Run.startCombat(ui.run,"cultist_solo")) ui:render()
    ui:update(0.02)
    assert(next(ui.feedback.effects) == nil and not stage.children.enemy1.children.floating.visible)
    assert(stage.children.enemy1.children.hpGhost.fillAmount == 1 and stage.x == 0)
end)
local function dragBattle(deck, enemies)
    local ui, stage, click = setup({manualPlayback=true, dragEvents=true})
    click("start")
    ui.run.combat = Combat.new(Data,{deck=deck or {"defend","defend"},enemies=enemies or {"cultist"}})
    ui:resize(1280,720) ui:render()
    local function event(control, kind, x, y, touch)
        local hit = stage.children[control]
        if hit.children.hit then hit = hit.children.hit end
        local callback = hit.listeners and hit.listeners[kind]
        assert(callback, "native " .. kind .. " listener missing on " .. control)
        local k = math.min(ui.canvasWidth/1280,ui.canvasHeight/720)
        callback({touchId=touch or 0,GetUIPos=function() return ui.canvasWidth/2+x*k,ui.canvasHeight/2+y*k end})
    end
    local function grab(slot, touch)
        local box = stage.children["card" .. slot]
        event("card" .. slot,"down",box.x,box.y,touch)
    end
    return ui,stage,click,event,grab,ui.run.combat
end
test("native drag releases representative no-target rule cards into open ground once, with real commands",function()
    for _,id in ipairs({"defend","inflame","cleave","thunderclap"}) do
        local ui,stage,click,event,grab,battle = dragBattle({id})
        local uid,energy = battle.hand[1].uid,battle.energy
        grab(1) event("card1","drag",0,0)
        assert(stage.children.dragLayer.visible and stage.children.dragLayer.children.line.visible)
        assert(stage.children.card1.x == 0 and stage.children.card1.y > -100)
        event("card1","up",0,0)
        local cost = battle.catalog.cards[id].cost
        assert(#battle.hand == 0 and battle.energy == energy-cost and ui.selected == nil and ui.busy)
        event("card1","endDrag",0,0) click("card1")
        assert(battle.discard[1] and battle.discard[1].uid == uid or battle.exhaust[1] and battle.exhaust[1].uid == uid or id == "inflame")
        drain(ui)
        assert(not stage.children.dragLayer.visible and #battle.hand == 0)
    end
end)
test("targeted drags cancel in hand and hit the explicitly aimed enemy",function()
    local ui,stage,click,event,grab,battle = dragBattle({"strike"},{"cultist","jaw_worm"})
    local energy,hp1,hp2 = battle.energy,battle.enemies[1].hp,battle.enemies[2].hp
    grab(1) event("card1","drag",-200,0) event("card1","drag",0,-240) event("card1","up",0,-240)
    assert(#battle.hand == 1 and battle.energy == energy and not ui.busy)
    click("enemy1") -- queued release click must never select or play a target
    assert(battle.enemies[1].hp == hp1)
    grab(1) event("card1","drag",stage.children.enemy2.x,stage.children.enemy2.y)
    assert(stage.children.enemy2.children.border.imageColor.r == Theme.color.goldBright.r)
    event("dragLayer","up",stage.children.enemy2.x,stage.children.enemy2.y)
    assert(battle.enemies[1].hp == hp1 and battle.enemies[2].hp == hp2-6 and #battle.hand == 0)
end)
test("aiming parks the card below the line and padded enemy hit areas support touch",function()
    local enemies = {"mad_gremlin","sneaky_gremlin","fat_gremlin","shield_gremlin","wizard_gremlin"}
    local ui,stage,click,event,grab,battle = dragBattle({"strike"},enemies)
    local D,h = Theme.layout.cardDrag,Theme.layout.card.size[2]*Theme.layout.cardDrag.scale
    local layer,third = stage.children.dragLayer,stage.children.enemy3
    -- Grab the card's lower edge and aim at the HP bar: the old portrait-only test missed this.
    local box = stage.children.card1
    event("card1","down",box.x,box.y-80)
    event("card1","drag",third.x+40,third.y-70)
    assert(ui.gesture.moving and box.y + h/2 <= D.lineY and box.localScaleX == D.scale, "aiming card must park below the line")
    assert(third.children.border.imageColor.r == Theme.color.goldBright.r)
    assert(layer.children.reticle.visible and layer.children.reticle.x == third.x and layer.children.aim1.visible)
    assert(layer.children.hint.text == "", "aiming shows the reticle, not a caption over the card")
    for i = 1, 5 do if i ~= 3 then assert(stage.children["enemy" .. i].children.border.imageColor.r ~= Theme.color.goldBright.r) end end
    local hp = {} for i, enemy in ipairs(battle.enemies) do hp[i] = enemy.hp + enemy.block end
    event("dragLayer","up",third.x+40,third.y-70)
    assert(#battle.hand == 0 and battle.enemies[3].hp + battle.enemies[3].block < hp[3])
    for i = 1, 5 do if i ~= 3 then assert(battle.enemies[i].hp + battle.enemies[i].block == hp[i]) end end
end)
test("open ground, hand, top bar and outside canvas never auto-target or commit",function()
    for _,point in ipairs({{-200,40},{0,-240},{0,280},{512,-206},{700,0},{0,350}}) do
        local ui,stage,click,event,grab,battle = dragBattle({"strike"},{"cultist","jaw_worm"})
        grab(1) event("card1","drag",0,0) event("dragLayer","up",point[1],point[2])
        assert(battle.energy == 3 and #battle.hand == 1 and ui.selected == nil)
    end
end)

test("non-target release outside the battlefield cancels even after arming",function()
    for _,point in ipairs({{0,-170},{0,-240},{0,280},{512,-206},{700,0},{0,350}}) do
        local ui,stage,click,event,grab,battle = dragBattle()
        grab(1) event("card1","drag",0,0) event("dragLayer","up",point[1],point[2])
        assert(battle.energy == 3 and #battle.hand == 2 and battle.player.block == 0)
    end
end)

test("drag validates current availability and ignores other touches and stale encounters",function()
    for _,kind in ipairs({"energy","phase","busy","inactive","replacement","unplayable","removed"}) do
        local ui,stage,click,event,grab,battle = dragBattle(kind == "unplayable" and {"clash","defend"} or {"defend"})
        local slot = 1
        if kind == "unplayable" then for i,card in ipairs(battle.hand) do if card.cardId == "clash" then slot = i end end end
        local energy,handBefore = battle.energy,#battle.hand
        grab(slot,7) event("card" .. slot,"drag",0,0,7)
        event("card" .. slot,"up",0,0,8)
        assert(#battle.hand == handBefore and battle.energy == energy)
        if kind == "energy" then battle.energy = 0
        elseif kind == "phase" then battle.phase = "enemy"
        elseif kind == "busy" then ui.busy = true
        elseif kind == "inactive" then ui:setActive(false)
        elseif kind == "replacement" then ui.run.combat = Combat.new(Data,{deck={"defend"}}) ui:render()
        elseif kind == "removed" then table.remove(battle.hand,1) end
        local hand,remaining = #battle.hand,battle.energy
        event("card" .. slot,"up",0,0,7) event("card" .. slot,"endDrag",0,0,7)
        assert(#battle.hand == hand and battle.energy == remaining and battle.player.block == 0,kind)
        assert(#battle.discard == 0 and #battle.exhaust == 0,kind)
    end
end)
test("drag coordinates follow actual canvas scaling and rapid consecutive cards do not reuse slots",function()
    for _,size in ipairs({{1280,720},{1600,900},{1920,1080},{1560,720}}) do
        local ui,stage,click,event,grab,battle = dragBattle()
        ui:resize(size[1],size[2])
        local first = battle.hand[1].uid
        grab(1) event("card1","drag",0,0) event("card1","up",0,0)
        drain(ui) event("card1","endDrag",0,0) click("card1")
        assert(#battle.hand == 1 and battle.discard[1].uid == first and battle.player.block == 5)
        grab(1) event("card1","drag",0,0) event("card1","up",0,0)
        assert(#battle.hand == 0 and battle.player.block == 10 and battle.energy == 1)
    end
end)
test("resize cancels a moving drag, hides the capture layer and permits a fresh tap",function()
    local ui,stage,click,event,grab,battle = dragBattle()
    grab(1) event("card1","drag",0,0)
    assert(stage.children.dragLayer.visible)
    ui:resize(1600,900)
    assert(not stage.children.dragLayer.visible and stage.children.card1.y < -100)
    event("card1","up",0,0) click("card1")
    assert(#battle.hand == 2)
    for _ = 1, 2 do
        grab(1) event("card1","up",stage.children.card1.x,stage.children.card1.y)
        event("card1","click",stage.children.card1.x,stage.children.card1.y)
    end
    assert(#battle.hand == 2 and battle.player.block == 0 and ui.selected == nil)
end)
test("mixed enemy moves show a compound intent badge like STS ATTACK_DEBUFF", function()
    local ui, stage, click = setup() click("start")
    local function show(enemyId, intentId)
        ui.run.combat = Combat.new(Data, {enemies={enemyId}})
        local enemy = ui.run.combat.enemies[1]
        for i, intent in ipairs(enemy.intents) do if intent.id == intentId then enemy.intentIndex = i end end
        assert(enemy.intents[enemy.intentIndex].id == intentId, "missing intent " .. intentId)
        ui:render()
        return stage.children.enemy1.children
    end
    local box = show("acid_slime_m", "acid_slime_m_1") -- damage + Slimed into discard
    assert(box.intentIcon.imageId == Theme.icon.intent.attack)
    assert(box.intentBadge.visible and box.intentBadge.imageId == Theme.icon.intent.debuff)
    assert(box.intent.text ~= "", "mixed attacks retain their damage number")
    assert(box.intentBadge.x > box.intentIcon.x and box.intentBadge.y < box.intentIcon.y,
        "compound badge must sit on the main icon's lower-right corner")
    assert(box.intentBadge.imageColor.r == Theme.color.debuff.r)
    box = show("gremlin_nob", "gremlin_nob_2") -- damage + Vulnerable
    assert(box.intentBadge.visible and box.intentBadge.imageId == Theme.icon.intent.debuff)
    box = show("jaw_worm", "jaw_worm_2") -- Thrash: damage + block
    assert(box.intentBadge.visible and box.intentBadge.imageId == Theme.icon.intent.defend)
    box = show("jaw_worm", "jaw_worm_3") -- Bellow: strength + block
    assert(box.intentIcon.imageId == Theme.icon.intent.buff)
    assert(box.intentBadge.visible and box.intentBadge.imageId == Theme.icon.intent.defend)
    assert(box.intent.text == "", "non-attack intent must not display future status stacks")
    box = show("jaw_worm", "jaw_worm_1") -- Chomp: damage only
    assert(not box.intentBadge.visible)
end)
test("stateful sleeping enemy shows approved sleep icon and wake intent", function()
    local ui, stage, click = setup()
    ui.run = Run.new(Data,42)
    ui.run.floor = 6 -- isolated elite entry; not a claimed completed route
    assert(Run.startCombat(ui.run,"elite_lagavulin"))
    ui:render()
    local box = stage.children.enemy1
    assert(box.children.intent.text == "" and box.children.intentLabel.text == "沉睡")
    assert(box.children.intentIcon.imageId == Theme.icon.intent.sleep)
    click("enemy1")
    assert(stage.children.notice.text:find("沉睡",1,true))
    Combat.damage(ui.run.combat,ui.run.combat.player,ui.run.combat.enemies[1],9,true)
    ui:render()
    assert(box.children.intent.text == "" and box.children.intentLabel.text == "苏醒")
    assert(box.children.intentIcon.imageId == Theme.icon.intent.unknown)
    assert(Combat.endTurn(ui.run.combat))
    ui:render()
    assert(box.children.intent.text == "18")
    assert(box.children.intentIcon.imageId == Theme.icon.intent.attack)
end)
test("Guardian shows real mode budget and switches visible intention before its Close Up",function()
    local ui,stage,click=setup()
    ui.run=Run.new(Data,42); ui.run.floor=Data.rules.map.bossFloor -- isolated Boss entry, not full-run evidence
    assert(Run.startCombat(ui.run,"boss_guardian")); ui:render()
    local box=stage.children.enemy1
    assert(details(stage,box):find("模式转换 30",1,true))
    assert(box.children.intent.text=="")
    Combat.damage(ui.run.combat,ui.run.combat.player,ui.run.combat.enemies[1],30,true)
    ui:render(); assert(box.children.intent.text=="")
    assert(box.children.intentIcon.imageId==Theme.icon.intent.buff)
    click("enemy1"); assert(stage.children.notice.text:find("自身获得 3 层尖刺甲壳",1,true))
    assert(Combat.endTurn(ui.run.combat)); ui:render()
    assert(details(stage,box):find("尖刺甲壳 3",1,true))
    assert(box.children.intent.text=="9")
end)
test("committed encounter identity preserves target across real animation frames", function()
    local ui, stage, click, battle = feedbackBattle({"defend","strike"}, {"cultist","cultist"})
    click("enemy2")
    local slot
    for i,c in ipairs(battle.hand) do if c.cardId == "defend" then slot=i end end
    click("card" .. slot)
    local selected = ui.selected
    ui:render()
    assert(ui.target == 2 and ui.selected == selected, "same encounter selection lost")
    click("playArea")
    assert(ui.busy and ui.displayBattle ~= battle)
    assert(ui.target == 2, "target reset by initial animation snapshot")
    local frames = 0
    while ui.busy and frames < 300 do
        ui:update(0.02); frames=frames+1
        assert(ui.target == 2, "target reset by animation frame")
    end
    assert(not ui.busy and frames > 0)
end)
test("same-run battle replacement clears valid-looking old selection and target", function()
    local ui, stage, click, battle = feedbackBattle({"strike"}, {"cultist","cultist"})
    click("enemy2"); click("card1")
    assert(ui.target == 2 and ui.selected)
    ui.run.combat = Combat.new(Data, {deck={"strike"}, enemies={"cultist","cultist"}})
    ui:render()
    assert(ui.target == 1 and ui.selected == nil, "old encounter selection retained")
end)
test("reward pick is a centred stage apart from the bottom hand", function()
    local ui, stage, click = setup() click("start")
    local R = Theme.layout.rewardPick
    local hand = {}
    for i = 1, 5 do hand[i] = stage.children["card" .. i].y end
    assert(stage.children.card1.y < -150 and not stage.children.rewardStage.visible and stage.children.energy.visible)
    ui.run.phase, ui.run.rewards = "reward", {gold = 12, goldClaimed=false, manualContinue=true, cardResolved=false, cards = {"strike", "defend", "bash"}}
    ui:render()
    assert(stage.children.rewardList.visible and not stage.children.rewardStage.visible)
    click('cardReward')
    local deck = #ui.run.deck
    assert(stage.children.rewardStage.visible and not stage.children.endTurn.visible and not stage.children.energy.visible)
    assert(stage.children.rewardStage.children.subtitle.text:find("点击卡牌加入牌组", 1, true))
    assert(stage.children.card1.visible and stage.children.card3.visible and not stage.children.card4.visible)
    -- Settle the entrance, then the three cards share one row at the middle of the screen.
    for _ = 1, 40 do ui:update(0.05) end
    for i = 1, 3 do
        local box = stage.children["card" .. i]
        assert(math.abs(box.x - (i - 2) * R.step) < 0.01 and math.abs(box.y - R.y) < 0.01)
        assert(box.localScaleX == R.scale and not box.children.glow.visible)
        assert(box.rotation == nil or box.rotation == 0)
    end
    local width = Theme.layout.card.size[1] * R.hoverScale
    assert(R.step - width > 16, "hovered card must not overlap its neighbour")
    -- Hover grows only the hovered card; leaving restores it without moving the others.
    ui:setHover(2) for _ = 1, 40 do ui:update(0.05) end
    assert(stage.children.card2.localScaleX == R.hoverScale and stage.children.card2.children.glow.visible)
    assert(stage.children.card1.localScaleX == R.scale and stage.children.card2.y == R.y + R.hoverLift)
    ui:setHover(nil) for _ = 1, 40 do ui:update(0.05) end
    assert(stage.children.card2.localScaleX == R.scale and stage.children.card2.y == R.y)
    -- One click claims once; a second click on the same slot cannot claim again.
    click("card2")
    assert(ui.run.phase == "reward" and #ui.run.deck == deck + 1 and not stage.children.rewardStage.visible)
    click("card2") assert(#ui.run.deck == deck + 1)
    ui:setHover(1) assert(ui.hover == nil)
    -- Battle hands are untouched: a fresh fight deals the bottom arc again.
    click("continue");assert(ui.run.phase=='map');click('continue')
    assert(ui.run.phase == "combat" and stage.children.energy.visible and stage.children.card1.y == hand[1])
end)
test("skip returns to the list without consuming the unclaimed card row", function()
    local ui, stage, click = setup() click("start")
    ui.run.phase, ui.run.rewards = "reward", {gold = 0, goldClaimed=true, manualContinue=true, cardResolved=false, cards = {"strike", "defend", "bash"}}
    ui:render() local deck = #ui.run.deck
    click('cardReward')
    assert(stage.children.skip.visible and stage.children.skip.y == Theme.layout.rewardPick.skip[2])
    click("skip")
    assert(ui.run.phase == "reward" and #ui.run.deck == deck and not stage.children.rewardStage.visible)
    assert(stage.children.rewardList.visible and stage.children.cardReward.visible and not ui.run.rewards.cardResolved)
    click("skip") assert(#ui.run.deck == deck)
end)
print("LUA_UI_PASS " .. count)
