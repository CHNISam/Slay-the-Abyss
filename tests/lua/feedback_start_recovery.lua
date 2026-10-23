package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Run = require("abyss_run")
local Feedback = require("abyss_feedback")
local Events = require("abyss_events")
local count, failed = 0, 0
local function test(name, fn)
    count = count + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " feedback_start_recovery " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(err)))
end
local function same(actual, expected)
    assert(type(actual) == type(expected), "state type changed")
    if type(actual) ~= "table" then assert(actual == expected, "state value changed") return end
    for key, value in pairs(expected) do same(actual[key], value) end
    for key in pairs(actual) do assert(expected[key] ~= nil, "unexpected state field") end
end
local function find(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then return entry end
        local found = find(entry.children or {}, name)
        if found then return found end
    end
end
local function adapter(present, complete)
    local h = {completed = {}, stage = F.control(assert(find(F.Layout, "battlePanel")))}
    h.feedback = Feedback.new(h.stage, {imageSource = "static", color = function(r,g,b,a) return {r=r,g=g,b=b,a=a} end},
        present or function() end, function(failure)
            h.completed[#h.completed + 1] = failure or "ok"
            if complete then complete(h, failure) end
        end)
    return h
end
local function batch()
    local battle = F.Combat.new(F.Data, {deck = {"strike"}, enemies = {"cultist"}, seed = 11})
    local before, first = Events.frame(battle), #battle.events + 1
    assert(F.Combat.play(battle, battle.hand[1].uid, 1))
    return before, battle, first
end
local function drain(feedback)
    for _ = 1, 200 do if not feedback.busy then return end feedback:update(0.05) end
    assert(not feedback.busy, "feedback never released")
end

test("early native reset failure restores host input after a committed command", function()
    -- This setter fails before start reaches its first visible step. The real host
    -- has already committed the command and locked input, so it must be notified.
    local host, root = F.fixture()
    assert(host:start())
    assert(Run.startCombat(host.run, "cultist_solo"))
    host.run.combat = F.Combat.new(F.Data, {deck = {"strike"}, enemies = {"cultist"}, seed = 11})
    host:refresh()
    local ui, battle = host.battleUI, host.run.combat
    local panel = root:GetChild("battlePanel")
    local hp, energy, events = battle.enemies[1].hp, battle.energy, battle.events
    panel:GetChild("card1"):GetChild("hit").click()
    assert(ui.selected == battle.hand[1].uid)
    local original, failures = panel.SetAnchoredPosition, 0
    panel.SetAnchoredPosition = function(self, x, y)
        if failures == 0 then failures = failures + 1 error("INJECTED_FEEDBACK_START_FAILURE") end
        return original(self, x, y)
    end
    panel:GetChild("enemy1"):GetChild("hit").click()
    assert(failures == 1, "the failure must occur during feedback startup")
    assert(battle.enemies[1].hp == hp - 6 and battle.energy == energy - 1 and #battle.hand == 0,
        "the successful command remains committed once")
    assert(not ui.busy and not ui.feedback.busy, "feedback startup failure must release host input")
    assert(ui.displayBattle == nil and panel:GetChild("endTurn").interactable,
        "the host must restore final state and controls after startup failure")
    assert(panel:GetChild("enemy1"):GetChild("hp").text == battle.enemies[1].hp .. "/" .. battle.enemies[1].maxHp,
        "the recovered view must show the committed HP")
    assert(battle.events == events and #events == 0, "committed frames are consumed exactly once")
    local after = F.Combat.copy(battle)
    for _ = 1, 10 do host:update(0.1) end
    same(battle, after)
    assert(not ui.busy, "late updates must not relock input")
    panel:GetChild("endTurn").click()
    assert(ui.busy, "a subsequent command can start normally")
    for _ = 1, 200 do if not ui.busy then break end host:update(0.05) end
    assert(not ui.busy and battle.turn == 2 and #events == 0, "a subsequent turn must finish normally")
end)

test("an empty event batch completes once without leaving a host waiting", function()
    local h = adapter()
    local before, battle = batch()
    h.feedback:begin(before, battle, #battle.events + 1, F.Presentation)
    assert(not h.feedback.busy and #h.completed == 1 and h.completed[1] == "ok", "an empty batch must complete once")
    h.feedback:cancel()
    for _ = 1, 10 do h.feedback:update(0.1) end
    assert(#h.completed == 1, "idle cancel/update must not repeat completion")
end)

test("first-frame presentation failure reports one completion and permits another batch", function()
    local fail = true
    local h = adapter(function() if fail then error("INJECTED_FIRST_PRESENT_FAILURE") end end)
    local before, battle, first = batch()
    local committed = F.Combat.copy(battle)
    h.feedback:begin(before, battle, first, F.Presentation)
    assert(not h.feedback.busy and #h.completed == 1 and h.completed[1]:find("INJECTED_FIRST_PRESENT_FAILURE", 1, true))
    fail = false
    h.feedback:cancel() h.feedback:update(0.1)
    assert(#h.completed == 1)
    same(battle, committed)
    before, battle, first = batch()
    h.feedback:begin(before, battle, first, F.Presentation)
    drain(h.feedback)
    assert(#h.completed == 2 and h.completed[2] == "ok")
end)

test("a throwing completion callback is not retried by recovery or idle updates", function()
    local h = adapter(nil, function() error("INJECTED_COMPLETION_FAILURE") end)
    local before, battle, first = batch()
    h.feedback:begin(before, battle, first, F.Presentation)
    drain(h.feedback)
    h.feedback:cancel()
    for _ = 1, 10 do h.feedback:update(0.1) end
    assert(#h.completed == 1 and h.completed[1] == "ok" and not h.feedback.busy)
end)

test("completion may start another batch without stale cleanup cancelling it", function()
    local secondBefore, secondBattle, secondFirst = batch()
    local h = adapter(nil, function(current)
        if #current.completed == 1 then
            current.feedback:begin(secondBefore, secondBattle, secondFirst, F.Presentation)
        end
    end)
    local before, battle, first = batch()
    local committed, secondCommitted = F.Combat.copy(battle), F.Combat.copy(secondBattle)
    h.feedback:begin(before, battle, first, F.Presentation)
    drain(h.feedback)
    assert(#h.completed == 2 and h.completed[1] == "ok" and h.completed[2] == "ok")
    same(battle, committed) same(secondBattle, secondCommitted)
    h.feedback:cancel() h.feedback:update(0.1)
    assert(#h.completed == 2)
end)

assert(failed == 0, failed .. " feedback startup recovery tests failed")
print("LUA_FEEDBACK_START_RECOVERY_PASS " .. count)
