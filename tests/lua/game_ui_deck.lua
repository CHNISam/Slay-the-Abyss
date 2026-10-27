local F = dofile("tests/lua/support/game_ui_fixture.lua")
local GameUI, Combat, Nodes, Data = F.GameUI, F.Combat, F.Nodes, F.Data
local Presentation, Layout, Viewport, Theme = F.Presentation, F.Layout, F.Viewport, F.Theme
local preview, control, fixture = F.preview, F.control, F.fixture
local statValue, resultText, mapControl, click, win = F.statValue, F.resultText, F.mapControl, F.click, F.win
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok game UI " .. count .. " - " .. name) end

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function deckGrid(root) return root:GetChild("deckPanel"):GetChild("grid") end
local function openDeck(ui, root)
    assert(root:GetChild("deckEntry").visible)
    ui:refresh()
    local entry = root:GetChild("deckEntry"):GetChild("open"):GetChild("hit")
    for _, state in ipairs({ "normal", "hover", "pressed", "disabled" }) do
        assert(entry:GetChild(state):GetChild("label").text == "卡组 " .. #ui.run.deck, "deck button carries the deck size")
    end
    assert(entry.click())
    ui:update(0)
    assert(root:GetChild("deckPanel").visible)
    return deckGrid(root)
end
local function closeDeck(root) return root:GetChild("deckPanel"):GetChild("close"):GetChild("hit").click() end

test("deck overlay reads permanent UID and upgraded text and never changes the run or route", function()
    local ui, root = fixture()
    assert(not ui:openDeck() and not root:GetChild("deckEntry").visible)
    ui:start()
    ui.run.deck[1].upgraded = true
    for i = 11, 40 do ui.run.deck[i] = {uid=100+i,cardId=ui.run.deck[1].cardId,upgraded=i%2==0} end
    local beforeRun, beforeMap = Combat.copy(ui.run), Combat.copy(ui.map)
    local grid = openDeck(ui, root)
    assert(grid.itemCount == 40 and grid.scrollProgress == 0)
    local first = grid.items[0]
    assert(not first:GetChild('hit').visible,'read-only deck must leave scroll gestures free')
    assert(first:GetChild("uid").text == "UID " .. ui.run.deck[1].uid)
    local face = first:GetChild("face")
    local display = Presentation[ui.run.deck[1].cardId]
    assert(face:GetChild("name").text:gsub('\n',' ') == display.name .. "＋")
    assert(face:GetChild("label").text == display.upgradeText)
    local last = grid:recycle(0, 39)
    assert(last == first and last:GetChild("uid").text == "UID 140")
    assert(last:GetChild("face"):GetChild("label").text == display.upgradeText)
    assert(not ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    local scroll = ui.mapUI.scroll
    assert(root:GetChild("mapPanel").visible and not ui.mapUI.visible)
    assert(not ui.mapUI:scrollBy(100) and ui.mapUI.scroll == scroll)
    mapControl(root:GetChild("mapPanel"),"focus"):GetChild("hit").click()
    assert(ui.mapUI.scroll == scroll)
    assert(not ui:start() and not ui:settle())
    assert(same(beforeRun,ui.run) and same(beforeMap,ui.map), "view changed rules or RNG")
    local delayed = grid.refreshCallback
    assert(closeDeck(root))
    delayed(first,0) -- old virtualized callbacks must not repopulate a closed overlay
    assert(not root:GetChild("deckPanel").visible and grid.itemCount == 0)
    assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id), "map input did not resume")
end)

test("grid discovers runtime index origin, including deferred callbacks, and reopens with fresh ownership", function()
    local ui, root = fixture()
    ui:start()
    local grid = deckGrid(root)
    grid.indexBase, grid.deferRefresh = 1, true
    assert(ui:openDeck())
    local calibration = grid.refreshCallback
    ui:update(0)
    assert(grid.itemCount == 1)
    grid:flush() ui:update(0) grid:flush()
    assert(grid.itemCount == #ui.run.deck)
    assert(grid.items[0]:GetChild("uid").text == "UID " .. ui.run.deck[1].uid)
    local oldUid = grid.items[1]:GetChild("uid").text
    calibration(grid.items[1],1)
    assert(not ui.deckUI.pending and grid.items[1]:GetChild("uid").text == oldUid)
    local stale = grid.refreshCallback
    assert(closeDeck(root))
    table.remove(ui.run.deck,1)
    assert(ui:openDeck()) grid:flush() ui:update(0) grid:flush()
    local card = grid.items[0]
    local text = card:GetChild("uid").text
    stale(card,1)
    assert(card:GetChild("uid").text == text and text == "UID " .. ui.run.deck[1].uid)
    assert(not ui:openDeck(), "duplicate open must not reset the scroller")
    assert(closeDeck(root))
end)

test("battle overlay cancels pending drag and blocks cards, potions, turn and reward commands", function()
    local ui, root = fixture()
    ui:start() assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    local battle = ui.run.combat
    local instance = battle.hand[1]
    ui.battleUI.gesture = {run=ui.run,battle=battle,turn=battle.turn,uid=instance.uid}
    ui.battleUI.selected = instance.uid
    local before = Combat.copy(ui.run)
    openDeck(ui,root)
    assert(not ui.battleUI.gesture and not ui.battleUI.selected)
    assert(root:GetChild("battlePanel").visible and not ui.battleUI.active)
    ui.battleUI:playSlot(1) ui.battleUI:playSelected(1) ui.battleUI:endTurn() ui.battleUI:usePotion(1)
    root:GetChild("battlePanel"):GetChild("skip").click()
    assert(same(before,ui.run))
    assert(closeDeck(root) and ui.battleUI.active)
    ui.battleUI:endTurn()
    assert(ui.battleUI.busy and not ui:openDeck(), "feedback must finish before deck opens")
    for _ = 1, 200 do if not ui.battleUI.busy then break end ui:update(0.05) end
    if ui.run.phase == "combat" then assert(ui:openDeck()) end
    ui.run.phase = "defeat" ui:refresh()
    assert(not root:GetChild("deckPanel").visible and not ui:openDeck())
end)

test("node overlay preserves the node presentation while preventing underlying transactions", function()
    local ui, root = fixture()
    ui:start()
    ui.run.hp = 20 -- Rest is enabled only below full health in the approved camp UI.
    local available = Nodes.available(ui.run,ui.map)[1]
    for _, node in ipairs(ui.map.nodes) do if node.id == available.id then node.type = "camp" end end
    assert(ui.mapUI:choose(available.id) and ui.mode == "node")
    local before = Combat.copy(ui.run)
    openDeck(ui,root)
    assert(root:GetChild("nodePanel").visible and not ui.nodeUI.visible)
    assert(not ui.nodeUI:press("campView/rest") and not ui.nodeUI:press("confirm"))
    assert(same(before,ui.run))
    assert(closeDeck(root) and ui.nodeUI:press("campView/rest"))
    assert(ui.mode == "node" and ui.nodeUI:holding())
    assert(not ui.nodeUI:press("confirm")) -- committed rest result owns input until its feedback ends
    ui:update(require('abyss_theme').layout.nativeNode.roomMotion.restDuration+0.01)
    assert(ui.nodeUI:press("confirm"))
    assert(ui.mode == "map")
end)

test("deck costs and descriptions use permanent upgraded instances instead of temporary hand growth", function()
    local ui, root = fixture()
    ui:start()
    ui.run.deck = {
        {uid=101,cardId="barricade",upgraded=true}, {uid=102,cardId="whirlwind",upgraded=true},
        {uid=103,cardId="rampage",upgraded=true}, {uid=104,cardId="rampage",upgraded=false},
    }
    assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    for _, card in ipairs(ui.run.combat.hand) do if card.cardId == "rampage" then card.damageBonus = 123 end end
    local before = Combat.copy(ui.run)
    local grid = openDeck(ui,root)
    local face = grid.items[0]:GetChild("face")
    assert(face:GetChild("cost").text == "2" and face:GetChild("label").text == Presentation.barricade.upgradeText)
    assert(grid.items[1]:GetChild("face"):GetChild("cost").text == "X")
    assert(grid.items[2]:GetChild("face"):GetChild("label").text == Presentation.rampage.upgradeText)
    assert(grid.items[3]:GetChild("face"):GetChild("label").text == Presentation.rampage.text)
    assert(same(before,ui.run))
    assert(closeDeck(root))
    ui.run.phase = "map" ui.run.deck = {} ui:refresh()
    grid = openDeck(ui,root)
    assert(grid.itemCount == 0 and not ui.deckUI.pending)
    assert(closeDeck(root))
end)

test("reward view cannot claim or skip beneath the deck overlay and resumes after closing", function()
    local ui, root = fixture()
    ui:start() assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    win(ui,root)
    click(root,'battlePanel','cardReward')
    local before = Combat.copy(ui.run)
    local grid = openDeck(ui,root)
    assert(grid.itemCount == #ui.run.deck and grid.itemCount ~= #ui.run.rewards.cards)
    ui.battleUI:playSlot(1)
    root:GetChild("battlePanel"):GetChild("skip").click()
    assert(same(before,ui.run))
    assert(closeDeck(root))
    click(root,"battlePanel","skip")
    assert(ui.mode == "battle" and ui.run.phase=='reward' and not ui.run.rewards.cardResolved and #ui.run.deck == #before.deck)
    click(root,'battlePanel','continue');assert(ui.mode=='map')
end)

print("LUA_GAME_UI_DECK_PASS " .. count)
