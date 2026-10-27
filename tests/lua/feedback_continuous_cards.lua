package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local tests, failed = 0, 0
local function test(name, fn)
    tests = tests + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " feedback_continuous_cards " .. tests .. " - " .. name .. (ok and "" or ": " .. tostring(err)))
end
local function same(a, b)
    assert(type(a) == type(b), "state type changed")
    if type(a) ~= "table" then assert(a == b, "state value changed") return end
    for k, v in pairs(b) do same(a[k], v) end
    for k in pairs(a) do assert(b[k] ~= nil, "unexpected state field") end
end
local function setup()
    local sounds = {}
    local host, root = F.fixture(nil, nil, nil, nil, nil, function(cue) sounds[#sounds + 1] = cue end)
    assert(host:start())
    assert(Run.startCombat(host.run, "cultist_solo"))
    -- Controlled deck, ordinary Run.play via the actual host card/target controls.
    host.run.combat = F.Combat.new(F.Data, {deck = {"strike", "defend", "strike"}, enemies = {"cultist", "cultist"}, seed = 11})
    host:refresh()
    return host, root:GetChild("battlePanel"), sounds
end
local function play(host, panel, id, target)
    local ui, battle = host.battleUI, host.run.combat
    local slot
    for i, card in ipairs(battle.hand) do if card.cardId == id then slot = i break end end
    assert(slot, "missing controlled card " .. id)
    panel:GetChild("card" .. slot):GetChild("hit").click()
    assert(ui.selected == battle.hand[slot].uid, "ordinary card selection failed")
    if target then panel:GetChild("enemy" .. target):GetChild("hit").click()
    else ui:playSelected() end
    assert(ui.busy and ui.feedback.busy, "the successful command owns the action gate")
end
local function release(host)
    for _ = 1, 100 do
        if not host.battleUI.busy then return end
        host:update(0.01)
    end
    error("card action did not release input")
end
local function count(list, cue)
    local n = 0
    for _, value in ipairs(list) do if value == cue then n = n + 1 end end
    return n
end

test("the next card keeps a previous target's nonblocking VFX without replaying its hit", function()
    local host, panel, sounds = setup()
    local ui, battle = host.battleUI, host.run.combat
    play(host, panel, "strike", 1)
    release(host)
    local firstId = battle.enemies[1].id
    local effect = assert(ui.feedback.effects[firstId], "input should resume before the damage VFX ends")
    local age = effect.age
    assert(age < Theme.motion.damagePop, "the floating number still has a visible tail")
    assert(panel:GetChild("endTurn").interactable, "the normal input gate has reopened")
    assert(count(sounds, "hit") == 1)
    play(host, panel, "defend")
    assert(ui.feedback.effects[firstId] == effect, "a second card must not cancel an unrelated unfinished effect")
    assert(effect.age == age, "starting the next batch must not rewind a VFX clock")
    host:update(0.01)
    assert(effect.age > age, "the existing VFX continues while the next card is playing")
    assert(panel:GetChild("enemy1"):GetChild("floating").visible)
    assert(count(sounds, "hit") == 1, "retaining an effect must not replay its audio")
    release(host)
    local committed = F.Combat.copy(battle)
    for _ = 1, 100 do host:update(0.01) end
    assert(next(ui.feedback.effects) == nil and next(ui.feedback.poses) == nil)
    assert(not ui.busy and not ui.feedback.busy)
    assert(count(sounds, "hit") == 1)
    same(battle, committed)
end)

test("successive targets retain independent VFX clocks and drain normally", function()
    local host, panel, sounds = setup()
    local ui, battle = host.battleUI, host.run.combat
    play(host, panel, "strike", 1)
    release(host)
    local id1, id2 = battle.enemies[1].id, battle.enemies[2].id
    local first = assert(ui.feedback.effects[id1])
    play(host, panel, "strike", 2)
    assert(ui.feedback.effects[id1] == first)
    for _ = 1, 40 do
        if ui.feedback.effects[id2] then break end
        host:update(0.01)
    end
    local second = assert(ui.feedback.effects[id2])
    assert(ui.feedback.effects[id1] == first and first.age > second.age)
    assert(count(sounds, "hit") == 2)
    release(host)
    for _ = 1, 100 do host:update(0.01) end
    assert(next(ui.feedback.effects) == nil)
    assert(not panel:GetChild("enemy1"):GetChild("floating").visible)
    assert(not panel:GetChild("enemy2"):GetChild("floating").visible)
end)

test("cancelling or replacing the battle clears retained VFX and does not leak sounds", function()
    local host, panel, sounds = setup()
    local ui = host.battleUI
    play(host, panel, "strike", 1)
    release(host)
    assert(next(ui.feedback.effects) ~= nil)
    ui.feedback:cancel()
    assert(next(ui.feedback.effects) == nil and next(ui.feedback.poses) == nil)
    assert(not panel:GetChild("enemy1"):GetChild("floating").visible)
    play(host, panel, "strike", 2)
    release(host)
    assert(next(ui.feedback.effects) ~= nil)
    host.run.combat = F.Combat.new(F.Data, {deck = {"defend"}, enemies = {"cultist"}, seed = 12})
    host:refresh()
    host:update(0.01)
    assert(next(ui.feedback.effects) == nil and next(ui.feedback.poses) == nil)
    local heard = #sounds
    for _ = 1, 20 do host:update(0.05) end
    assert(#sounds == heard, "old battle effects never replay")
end)

assert(failed == 0, failed .. " continuous-card feedback tests failed")
print("LUA_FEEDBACK_CONTINUOUS_CARDS_PASS " .. tests)
