package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local L = Theme.layout
-- Dynamic card numbers and status details on the full generated native tree.
-- The oracle for every preview is the core's own resolution of the same play.
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn)
        self.listeners = self.listeners or {}
        self.listeners[event] = fn
        if event == "click" then self.click = fn end
    end
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
local function setup(deck, enemies, drag)
    local root = control({name="root", size={1280,720}, children=Layout})
    local panel = root:GetChild("stage"):GetChild("battlePanel")
    local ui = UI.new(panel, Data, Presentation, "click", {
        imageSource="static", color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
        cursorEvents=drag and {CursorDown="down",CursorDrag="drag",CursorUp="up",CursorEndDrag="endDrag"} or nil
    }, {embedded=true})
    ui.run = Run.new(Data, 1)
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, {deck=deck, enemies=enemies})
    ui:resize(1280, 720) ui:render()
    -- Native listener on a control path such as {"enemy1","statusRow","hit"}.
    local function event(path, kind, x, y, touch, optional)
        local box = panel
        for _, name in ipairs(type(path) == "table" and path or {path}) do box = box:GetChild(name) end
        local hit = box.listeners and box or box:GetChild("hit")
        local callback = hit.listeners and hit.listeners[kind]
        if optional and not callback then return end
        assert(callback, "missing native listener " .. kind)
        callback({touchId=touch or 7, GetUIPos=function() return 640 + (x or 0), 360 + (y or 0) end})
    end
    -- One physical tap: Down/Up where the control listens for them, then Click.
    local function tap(path, touch)
        if drag then event(path, "down", 0, 0, touch) event(path, "up", 0, 0, touch, true) end
        event(path, "click", 0, 0, touch)
    end
    return ui, panel, event, tap
end
local function drain(ui)
    for _ = 1, 600 do if not ui.busy then return end ui:update(0.05) end
    assert(not ui.busy, "feedback must finish")
end
local function eq(a, b, message) assert(a == b, (message or "") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function label(panel, slot) return panel:GetChild("card" .. (slot or 1)):GetChild("label").text end
local function battle(deck, enemies)
    local s = Combat.new(Data, {deck=deck, enemies=enemies})
    for _, enemy in ipairs(s.enemies) do enemy.hp, enemy.maxHp = 200, 200 end
    return s
end
-- HP each enemy loses when the core actually plays hand[1] on a copy of the state.
local function resolve(s, target)
    local copy = Combat.copy(s)
    for _, enemy in ipairs(copy.enemies) do enemy.ai = nil end -- reactions are not under test
    local before = {}
    for i, enemy in ipairs(copy.enemies) do before[i] = enemy.hp end
    assert(Combat.play(copy, copy.hand[1].uid, target))
    local lost = {}
    for i, enemy in ipairs(copy.enemies) do lost[i] = before[i] - enemy.hp end
    return lost, copy
end
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok card preview " .. count .. " - " .. name) end

test("single-target damage follows Strength and Weak, and each target's own Vulnerable", function()
    local s = battle({"strike"}, {"jaw_worm", "cultist"})
    local neutral = Combat.cardPreview(s, s.hand[1])[1]
    eq(neutral.low, 6) eq(neutral.high, 6) eq(neutral.op, "damage")
    Combat.addStatus(s.player, "strength", 4) Combat.addStatus(s.player, "weak", 1)
    Combat.addStatus(s.enemies[2], "vulnerable", 2)
    -- (6+4)*0.75 = 7.5 -> 7; against Vulnerable 7.5*1.5 = 11.25 -> 11.
    local unaimed = Combat.cardPreview(s, s.hand[1])[1]
    eq(unaimed.low, 7) eq(unaimed.high, 7)
    for target = 1, 2 do
        local aimed = Combat.cardPreview(s, s.hand[1], target)[1]
        local lost = resolve(s, target)
        eq(aimed.low, aimed.high) eq(aimed.low, lost[target], "target " .. target)
        eq(lost[3 - target], 0)
    end
    -- A dead aim returns to player-only modifiers, never another enemy's powers.
    s.enemies[2].hp = 0
    local alive = Combat.cardPreview(s, s.hand[1], 2)[1]
    eq(alive.low, 7) eq(alive.high, 7)
end)

test("multi-hit cards show the per-hit value and the core lands exactly that many times", function()
    for _, upgraded in ipairs({false, true}) do
        local s = battle({{cardId="twin_strike", upgraded=upgraded}}, {"jaw_worm"})
        Combat.addStatus(s.player, "strength", 2) Combat.addStatus(s.enemies[1], "vulnerable", 1)
        local unaimed = Combat.cardPreview(s, s.hand[1])[1]
        local definition = Combat.cardDefinition(s, s.hand[1])
        eq(unaimed.low, definition.effects[1].value + 2)
        eq(unaimed.high, unaimed.low)
        local hit = Combat.cardPreview(s, s.hand[1], 1)[1]
        eq(hit.low, math.floor((definition.effects[1].value + 2) * 1.5))
        eq(resolve(s, 1)[1], hit.low * definition.effects[1].times, "total of every hit")
    end
end)

test("area attacks preview every living enemy and match the core's per-enemy damage", function()
    for _, id in ipairs({"cleave", "thunderclap"}) do
        local s = battle({id}, {"jaw_worm", "cultist", "jaw_worm"})
        Combat.addStatus(s.player, "strength", 1)
        Combat.addStatus(s.enemies[2], "vulnerable", 1)
        local preview = Combat.cardPreview(s, s.hand[1], 1)[1] -- aim never narrows an area hit
        eq(preview.op, "damageAll")
        local lost = resolve(s, 1)
        eq(preview.low, lost[1], id .. " plain") eq(preview.low, lost[3], id .. " plain")
        eq(preview.high, preview.low, id .. " displays the first monster slot, not a range")
        eq(preview.targets[1], lost[1]) eq(preview.targets[2], lost[2]) eq(preview.targets[3], lost[3])
        s.enemies[2].hp = 0
        local rest = Combat.cardPreview(s, s.hand[1])[1]
        eq(rest.low, rest.high, id .. " dead enemies excluded")
    end
end)

test("block numbers follow Dexterity and Frail and equal the block the core grants", function()
    for _, id in ipairs({"defend", "shrug_it_off", "iron_wave", "impervious", "ghostly_armor"}) do
        local s = battle({id}, {"jaw_worm"})
        Combat.addStatus(s.player, "dexterity", 3) Combat.addStatus(s.player, "frail", 1)
        local preview = Combat.cardPreview(s, s.hand[1])[1]
        local definition = Combat.cardDefinition(s, s.hand[1])
        eq(preview.op, "block")
        eq(preview.low, math.floor((definition.effects[1].value + 3) * 0.75), id)
        local _, after = resolve(s, 1)
        eq(after.player.block, preview.low, id .. " granted block")
    end
end)

test("Iron Wave previews block and damage separately; Body Slam previews its current block", function()
    local s = battle({"iron_wave"}, {"jaw_worm"})
    Combat.addStatus(s.player, "strength", 2) Combat.addStatus(s.player, "dexterity", 1)
    local preview = Combat.cardPreview(s, s.hand[1])
    eq(preview[1].low, 6) eq(preview[2].low, 7) eq(resolve(s, 1)[1], 7)
    s = battle({"body_slam"}, {"jaw_worm"})
    s.player.block = 9 Combat.addStatus(s.player, "strength", 1)
    preview = Combat.cardPreview(s, s.hand[1])[1]
    eq(preview.op, "damageEqualToBlock") eq(preview.low, 10) eq(resolve(s, 1)[1], 10)
end)

test("negative Strength floors damage at zero and previews never mutate the battle", function()
    local s = battle({"strike", "defend", "cleave", "body_slam", "twin_strike"}, {"jaw_worm", "cultist"})
    Combat.addStatus(s.player, "strength", -20) Combat.addStatus(s.player, "dexterity", -20)
    local before = Combat.copy(s)
    for _, instance in ipairs(s.hand) do
        for _, entry in pairs(Combat.cardPreview(s, instance, 2)) do eq(entry.low, 0) eq(entry.high, 0) end
    end
    local function same(a, b)
        assert(type(a) == type(b))
        if type(a) ~= "table" then assert(a == b) return end
        for k, v in pairs(a) do same(v, b[k]) end
        for k in pairs(b) do assert(a[k] ~= nil, tostring(k)) end
    end
    same(s, before)
end)

test("source-backed hand and aimed values reset when target powers disappear or aiming is cancelled", function()
    local ui, panel, event = setup({"strike", "strike"}, {"jaw_worm", "cultist"}, true)
    local s = ui.run.combat
    Combat.addStatus(s.player, "strength", 2)
    ui:render(); eq(label(panel), "对目标造成 8 点伤害。")
    Combat.addStatus(s.player, "weak", 1)
    Combat.addStatus(s.enemies[2], "vulnerable", 1)
    ui:render(); eq(label(panel), "对目标造成 6 点伤害。")
    local card = panel:GetChild("card1")
    event("card1", "down", card.x, card.y)
    event("card1", "drag", L.enemyRow.xTo, L.enemyRow.y)
    eq(label(panel), "对目标造成 9 点伤害。")
    eq(label(panel, 2), "对目标造成 6 点伤害。", "the other card keeps player-only modifiers")
    s.enemies[2].statuses.vulnerable = nil -- The duration owner has removed the power.
    ui:render(); eq(label(panel), "对目标造成 6 点伤害。", "removed target power is not cached")
    Combat.addStatus(s.enemies[2], "vulnerable", 1)
    ui:render(); eq(label(panel), "对目标造成 9 点伤害。")
    event("card1", "endDrag", card.x, L.cardDrag.cancelY - 20)
    ui:render(); eq(label(panel), "对目标造成 6 点伤害。")
    s.player.statuses.weak = nil
    ui:render(); eq(label(panel), "对目标造成 8 点伤害。")
    Combat.addStatus(s.player, "strength", -2)
    ui:render(); eq(label(panel), "对目标造成 6 点伤害。")
    eq(s.energy, 3); eq(#s.hand, 2)
end)

test("hand labels update live for every modifier and show the aimed target while dragging", function()
    local ui, panel, event = setup({"strike", "defend", "cleave", "twin_strike", "body_slam"}, {"jaw_worm", "cultist"}, true)
    local s = ui.run.combat
    for _, enemy in ipairs(s.enemies) do enemy.ai, enemy.hp, enemy.maxHp = nil, 200, 200 end
    local slot = {}
    for i, instance in ipairs(s.hand) do slot[instance.cardId] = i end
    ui:render()
    eq(label(panel, slot.strike), "对目标造成 6 点伤害。")
    eq(label(panel, slot.defend), "为自己增加 5 点格挡。")
    eq(label(panel, slot.body_slam), "对目标造成与自己当前格挡等量的伤害。（当前 0 点）")
    Combat.addStatus(s.player, "strength", 3) Combat.addStatus(s.player, "dexterity", 2)
    Combat.addStatus(s.enemies[2], "vulnerable", 1)
    s.player.block = 4
    ui:render()
    eq(label(panel, slot.strike), "对目标造成 9 点伤害。")
    eq(label(panel, slot.cleave), "对每个敌人造成 11 点伤害。")
    eq(label(panel, slot.twin_strike), "对目标连续攻击 2 次，每次造成 8 点伤害。")
    eq(label(panel, slot.defend), "为自己增加 7 点格挡。")
    eq(label(panel, slot.body_slam), "对目标造成与自己当前格挡等量的伤害。（当前 7 点）")
    Combat.addStatus(s.player, "weak", 1) Combat.addStatus(s.player, "frail", 1)
    ui:render()
    eq(label(panel, slot.strike), "对目标造成 6 点伤害。")
    eq(label(panel, slot.defend), "为自己增加 5 点格挡。")
    -- Aiming at each column shows that target's exact number; releasing deals it.
    local card = panel:GetChild("card" .. slot.strike)
    event("card" .. slot.strike, "down", card.x, card.y)
    local function aim(index)
        event("card" .. slot.strike, "drag", index == 1 and L.enemyRow.xFrom or L.enemyRow.xTo, L.enemyRow.y)
    end
    aim(1) eq(label(panel, slot.strike), "对目标造成 6 点伤害。")
    aim(2) eq(label(panel, slot.strike), "对目标造成 10 点伤害。")
    -- Other hand cards retain player-only modifiers while one card is aimed.
    eq(label(panel, slot.twin_strike), "对目标连续攻击 2 次，每次造成 6 点伤害。")
    local hp = s.enemies[2].hp
    event("card" .. slot.strike, "up", L.enemyRow.xTo, L.enemyRow.y)
    drain(ui)
    eq(hp - s.enemies[2].hp, 10, "released damage equals the aimed label")
end)

test("the reported Weak versus Vulnerable scene shows 4 in hand and 6 only while aimed",function()
    local ui,panel,event=setup({"strike","defend"},{"jaw_worm","cultist"},true)
    local s=ui.run.combat
    Combat.addStatus(s.player,"weak",1)
    Combat.addStatus(s.enemies[2],"vulnerable",1)
    local slot
    for i,card in ipairs(s.hand) do if card.cardId=="strike" then slot=i end end
    ui:render();eq(label(panel,slot),"对目标造成 4 点伤害。")
    local card=panel:GetChild("card"..slot)
    event("card"..slot,"down",card.x,card.y)
    event("card"..slot,"drag",L.enemyRow.xTo,L.enemyRow.y)
    eq(label(panel,slot),"对目标造成 6 点伤害。")
    event("card"..slot,"endDrag",card.x,L.cardDrag.cancelY-20)
    ui:render();eq(label(panel,slot),"对目标造成 4 点伤害。")
    assert(s.energy==3 and #s.hand==2)
end)

test("rewards keep printed numbers; only combat hands are live", function()
    local ui, panel = setup({"strike"}, {"jaw_worm"})
    Combat.addStatus(ui.run.combat.player, "strength", 5)
    ui:render() eq(label(panel), "对目标造成 11 点伤害。")
    ui.run.phase = "reward" ui.run.rewards = {cards={"strike", "defend"}, gold=0}
    ui:render()
    panel:GetChild('cardReward').click()
    eq(label(panel, 1), Presentation.strike.text) eq(label(panel, 2), Presentation.defend.text)
end)

local function chips(box)
    local row, result = box:GetChild("statusRow"), {}
    for i = 1, L.statusIcon.perRow * L.statusIcon.rows do
        local icon, count = row:GetChild("icon" .. i), row:GetChild("count" .. i)
        if count.visible then result[#result + 1] = {icon = icon.visible and icon.imageId or nil, count = count.text,
            colour = icon.imageColor, x = icon.x, y = icon.y} end
    end
    return result
end
local function info(panel)
    local box, rows = panel:GetChild("statusInfo"), {}
    for i = 1, L.statusInfo.rows do
        if box:GetChild("name" .. i).visible then
            local note = box:GetChild("note" .. i)
            rows[#rows + 1] = {name = box:GetChild("name" .. i).text, text = box:GetChild("text" .. i).text,
                tag = box:GetChild("tag" .. i).text, note = note.visible and note.text or nil}
        end
    end
    return box.visible, rows, box
end

test("player and every enemy show status icons, stacks and full current effects", function()
    local ui, panel, _, tap = setup({"strike"}, {"jaw_worm", "cultist", "cultist"})
    local s = ui.run.combat
    Combat.addTemporaryStrength(s.player, 2) Combat.addStatus(s.player, "vulnerable", 1)
    Combat.addStatus(s.enemies[1], "weak", 2) Combat.addStatus(s.enemies[1], "poison", 4)
    Combat.addStatus(s.enemies[2], "artifact", 1) Combat.addStatus(s.enemies[2], "strength", -1)
    Combat.addStatus(s.enemies[3], "thorns", 3)
    ui:render()
    local hero = chips(panel:GetChild("hero"))
    eq(#hero, 2)
    eq(hero[1].icon, Theme.icon.status.strength) eq(hero[1].count, "2") eq(hero[1].colour.r, Theme.color.buff.r)
    eq(hero[2].icon, Theme.icon.status.vulnerable) eq(hero[2].count, "1") eq(hero[2].colour.r, Theme.color.debuff.r)
    assert(hero[1].y == hero[2].y and hero[2].x - hero[1].x == L.statusIcon.size + L.statusIcon.gap, "one centred row")
    eq(hero[1].x + hero[2].x, 0, "row centred under the bar")
    local second = chips(panel:GetChild("enemy2"))
    eq(second[1].icon, Theme.icon.status.artifact) eq(second[2].count, "-1")
    eq(second[2].colour.r, Theme.color.debuff.r, "negative Strength reads as a debuff")
    tap({"hero", "hit"})
    local open, rows, box = info(panel)
    assert(open and box:GetChild("title").text == "旅行者")
    eq(box:GetChild("summary").text, "生命 " .. s.player.hp .. "/" .. s.player.maxHp)
    eq(box:GetChild("guard").text, "格挡 0")
    -- Hierarchy: buff section, then debuff section; name + duration, effect, condition.
    eq(box:GetChild("section1").text, "增益") eq(box:GetChild("section2").text, "减益")
    eq(rows[1].name, "力量 2") eq(rows[1].tag, "本回合") eq(rows[1].text, "攻击每段伤害 +2")
    eq(rows[1].note, "其中 2 层在回合结束时移除")
    eq(rows[2].name, "易伤 1") eq(rows[2].tag, "剩余 1 回合") eq(rows[2].text, "受到的攻击伤害 +50%")
    tap({"statusInfo", "hit"}) assert(not panel:GetChild("statusInfo").visible)
    local expected = {
        {{"中毒 4", "每回合 -1", "回合开始时失去 4 点生命"}, {"虚弱 2", "剩余 2 回合", "造成的攻击伤害 -25%"}},
        {{"人工制品 1", "剩余 1 次", "抵挡接下来 1 次减益效果"}, {"力量 -1", "本场战斗", "攻击每段伤害 -1"}},
        {{"荆棘 3", "本场战斗", "受到攻击时，对攻击者造成 3 点伤害"}},
    }
    for i, lines in ipairs(expected) do
        tap({"enemy" .. i, "statusRow", "hit"})
        open, rows, box = info(panel)
        assert(open and box:GetChild("title").text == s.enemies[i].name)
        eq(#rows, #lines)
        for r = 1, #rows do eq(rows[r].name, lines[r][1]) eq(rows[r].tag, lines[r][2]) eq(rows[r].text, lines[r][3]) end
        tap({"statusInfo", "hit"})
    end
    -- Every status has its own plain sentence with the live number: never the raw
    -- data description, never jargon, and short enough for the two-line text box.
    local I = L.statusInfo
    local perLine = math.floor((I.width - I.pad * 2 - I.icon - I.gap) / Theme.font.small)
    for id, definition in pairs(s.catalog.statuses) do
        s.enemies[3].statuses = {[id] = 5}
        ui:render()
        tap({"enemy3", "statusRow", "hit"})
        open, rows = info(panel)
        assert(open and #rows == 1, id)
        local row = rows[1]
        local text = row.text .. "|" .. row.tag .. "|" .. (row.note or "")
        for _, jargon in ipairs({"所示", "等量", "层数是", "与层数", "（当前"}) do
            assert(not text:find(jargon, 1, true), id .. " contains " .. jargon .. ": " .. text)
        end
        assert(definition.stack == "none" or id == "entangled" or text:find("5", 1, true), id .. " hides its number: " .. text)
        assert(row.text ~= "" and utf8.len(row.text) <= perLine * 2, id .. " effect overflows two lines: " .. row.text)
        assert(not row.note or utf8.len(row.note) <= perLine * 2, id .. " condition overflows two lines: " .. tostring(row.note))
        assert(utf8.len(row.tag) <= math.floor(I.tagWidth / Theme.font.small), id .. " duration tag too long: " .. row.tag)
        tap({"statusInfo", "hit"})
    end
end)

test("crowded and narrow units overflow to +N and the panel pages through every status", function()
    local ui, panel, _, tap = setup({"strike"}, {"jaw_worm", "cultist", "cultist", "cultist", "jaw_worm"})
    local s = ui.run.combat
    local ids = {"strength", "dexterity", "vulnerable", "weak", "frail", "poison", "thorns", "regen",
        "artifact", "barricade", "ritual", "enrage"}
    for _, id in ipairs(ids) do Combat.addStatus(s.player, id, 1) Combat.addStatus(s.enemies[1], id, 1) end
    ui:render()
    local hero = chips(panel:GetChild("hero"))
    eq(#hero, L.statusIcon.perRow * L.statusIcon.rows)
    eq(hero[#hero].icon, nil) eq(hero[#hero].count, "+" .. (#ids - #hero + 1))
    local narrow = chips(panel:GetChild("enemy1"))
    assert(#narrow <= #hero and #narrow % L.statusIcon.rows == 0, "enemy columns respect the shared status row limit")
    eq(narrow[#narrow].count, "+" .. (#ids - #narrow + 1))
    for _, chip in ipairs(narrow) do
        assert(math.abs(chip.x) + L.statusIcon.size / 2 <= panel:GetChild("enemy1"):GetChild("statusRow"):GetChild("hit").sizeDeltaX / 2,
            "chips stay inside a narrow column")
    end
    tap({"hero", "statusRow", "hit"})
    local open, rows, box = info(panel)
    assert(open and #rows > 0 and #rows <= L.statusInfo.rows)
    local pages = tonumber(box:GetChild("more").text:match("^第 1/(%d+) 页"))
    assert(pages and pages > 1, "a crowded unit pages instead of hiding statuses: " .. box:GetChild("more").text)
    local seen, kinds = {}, {}
    for page = 1, pages do
        if page > 1 then tap({"statusInfo", "page"}) open, rows, box = info(panel) end
        assert(open and box:GetChild("more").text:find("第 " .. page .. "/" .. pages .. " 页", 1, true))
        local room = Theme.canvas.base[2] - L.topBar.height - Theme.space.s - Theme.canvas.safe.y
        assert(box:GetChild("plate").sizeDeltaY <= room, "page " .. page .. " fits under the top bar")
        for _, row in ipairs(rows) do seen[#seen + 1] = row.name end
        kinds[box:GetChild("section1").text] = true
    end
    eq(#seen, #ids, "every status is reachable across pages")
    assert(kinds["增益"], "buff section labels its rows")
    local barricade
    for _, name in ipairs(seen) do if name == "壁垒" then barricade = true end end
    assert(barricade, "stack \"none\" shows no count")
    tap({"statusInfo", "page"}) open = info(panel)
    assert(open and box:GetChild("more").text:find("第 1/", 1, true), "the last page turns back to the first")
    tap({"statusInfo", "hit"}) assert(not panel:GetChild("statusInfo").visible)
    s.enemies[2].statuses = {} ui:render()
    tap({"enemy2", "statusRow", "hit"})
    open, rows, box = info(panel)
    assert(open and #rows == 0 and box:GetChild("section1").text == "暂无状态")
    eq(box:GetChild("more").text, "点按任意处关闭")
    tap({"statusInfo", "page"}) assert(not panel:GetChild("statusInfo").visible, "a single page closes on its own tap")
end)

for _, drag in ipairs({false, true}) do
    local mode = drag and "pointer" or "click-only"
    test(mode .. ": status taps never play, target or end the turn, and an open panel swallows the next tap", function()
        local ui, panel, event, tap = setup({"strike", "strike", "defend"}, {"jaw_worm", "cultist"}, drag)
        local s = ui.run.combat
        for _, enemy in ipairs(s.enemies) do enemy.ai = nil end
        local strike
        for i, instance in ipairs(s.hand) do if instance.cardId == "strike" then strike = strike or i end end
        local other = strike == 1 and 2 or 1
        local function snapshot() return {energy = s.energy, hand = #s.hand, turn = s.turn, hp1 = s.enemies[1].hp,
            hp2 = s.enemies[2].hp, block = s.player.block, events = #s.events} end
        local before = snapshot()
        local function unchanged(where)
            local now = snapshot()
            for k, v in pairs(before) do eq(now[k], v, mode .. " " .. where .. " " .. k) end
        end
        -- Select the targeted Strike, then tap an enemy's status row: details only.
        tap("card" .. strike) eq(ui.selected, s.hand[strike].uid)
        tap({"enemy2", "statusRow", "hit"})
        assert(panel:GetChild("statusInfo").visible and ui.selected == s.hand[strike].uid)
        eq(ui.target, 1, "status rows never move the potion/card target")
        unchanged("status row")
        -- With the panel open, a tap on an enemy, a card or End Turn only closes it.
        for _, path in ipairs({"enemy2", "card" .. other, "endTurn"}) do
            tap(path)
            assert(not panel:GetChild("statusInfo").visible, path .. " closed the panel")
            unchanged(path)
            eq(ui.selected, s.hand[strike].uid, path .. " kept the selection")
            tap({"hero", "hit"}) assert(panel:GetChild("statusInfo").visible)
        end
        if drag then
            -- A drag that starts on a card while the panel is open never becomes a play.
            local card = panel:GetChild("card" .. other)
            event("card" .. other, "down", card.x, card.y)
            assert(not panel:GetChild("statusInfo").visible and ui.gesture == nil)
            event("card" .. other, "drag", L.enemyRow.xTo, L.enemyRow.y)
            event("card" .. other, "up", L.enemyRow.xTo, L.enemyRow.y)
            event("card" .. other, "click", L.enemyRow.xTo, L.enemyRow.y)
            unchanged("drag")
        else tap({"statusInfo", "hit"}) end
        assert(not panel:GetChild("statusInfo").visible)
        -- Closed again, the ordinary flow is untouched: the selected Strike hits enemy 2.
        tap("enemy2") drain(ui)
        eq(s.enemies[2].hp, before.hp2 - 6) eq(#s.hand, before.hand - 1)
    end)
end

test("the panel follows live values and closes for playback, a dead unit or a new battle", function()
    local ui, panel, _, tap = setup({"strike", "strike", "strike"}, {"jaw_worm", "cultist"})
    local s = ui.run.combat
    for _, enemy in ipairs(s.enemies) do enemy.ai = nil end
    tap({"enemy1", "statusRow", "hit"})
    Combat.addStatus(s.enemies[1], "vulnerable", 2) ui:render()
    local open, rows = info(panel)
    assert(open) eq(rows[1].name, "易伤 2")
    ui:endTurn() -- a command starts playback: details never cover the animation
    assert(ui.busy and not panel:GetChild("statusInfo").visible)
    drain(ui)
    tap({"enemy2", "statusRow", "hit"}) assert(panel:GetChild("statusInfo").visible)
    s.enemies[2].hp = 0 ui:render()
    assert(not panel:GetChild("statusInfo").visible, "a dead unit's panel closes")
    tap({"hero", "hit"}) assert(panel:GetChild("statusInfo").visible)
    ui.run.combat = Combat.new(Data, {deck={"strike"}, enemies={"cultist"}}) ui:render()
    assert(not panel:GetChild("statusInfo").visible, "a replacement battle closes stale details")
end)

print("LUA_CARD_PREVIEW_PASS " .. count)
