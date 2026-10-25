return function(first,last,cardFirst,cardLast)
first,last=first or 1,last or math.huge
cardFirst,cardLast=cardFirst or 1,cardLast or 80
local registered=0
-- Exercise registered native controls with real GameUI, Run, Combat and Feedback.
-- The host event facade supplies coordinates; no play/feedback implementation is mocked.
local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local passed, failed = 0, 0
local function test(name, fn)
    registered=registered+1
    if registered<first or registered>last then return end

    local ok, why = pcall(fn)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(why)) end
end
local function position(x, y, touch)
    return {touchId = touch, GetUIPos = function() return x, y end}
end
local function setup()
    local host, ui, panel, event, tap, drain = H.setup()
    tap("card1", 7)
    return {host = host, ui = ui, panel = panel, event = event, tap = tap, drain = drain,
        battle = host.run.combat, field = panel:GetChild("playArea"):GetChild("hit")}
end
local function resources(s, energy, block, hand)
    assert(s.battle.energy == energy, "energy: " .. s.battle.energy .. " expected " .. energy)
    assert(s.battle.player.block == block, "block: " .. s.battle.player.block .. " expected " .. block)
    assert(#s.battle.hand == hand, "hand: " .. #s.battle.hand .. " expected " .. hand)
end
local function unchanged(s)
    resources(s, 3, 0, 2)
    assert(#s.battle.discard == 0 and #s.battle.exhaust == 0, "cancel must not move cards")
    assert(not s.ui.busy, "cancel must not start feedback")
end
local function confirm(s, down, up, touch)
    s.field.listeners.down(down)
    s.field.listeners.up(up)
    s.field.click({touchId = touch})
end

-- Removing the release guard must fail each value/axis case, not only the first NaN.
local invalid = {
    {name = "NaN x", x = 0/0, y = 426}, {name = "NaN y", x = 640, y = 0/0},
    {name = "+Infinity x", x = math.huge, y = 426}, {name = "+Infinity y", x = 640, y = math.huge},
    {name = "-Infinity x", x = -math.huge, y = 426}, {name = "-Infinity y", x = 640, y = -math.huge},
}
for _, p in ipairs(invalid) do
    test("field Up rejects " .. p.name .. " without spending or feedback", function()
        local s = setup()
        confirm(s, position(640,426,8), position(p.x,p.y,8), 8)
        unchanged(s)
        s.field.listeners.up(position(640,426,8))
        s.field.listeners.endDrag(position(640,426,8))
        s.field.click({touchId=8})
        unchanged(s)
    end)
    test("field Down rejects " .. p.name .. " even when Up is finite", function()
        local s = setup()
        confirm(s, position(p.x,p.y,8), position(640,426,8), 8)
        unchanged(s)
    end)
end
test("nonfinite x is still explicit when y is unavailable", function()
    for _, x in ipairs({0/0, math.huge, -math.huge}) do
        local s = setup()
        confirm(s, position(640,426,8), position(x,nil,8), 8)
        unchanged(s)
    end
end)
test("nonfinite y is still explicit when x is unavailable", function()
    for _, y in ipairs({0/0, math.huge, -math.huge}) do
        local s = setup()
        confirm(s, position(640,426,8), position(nil,y,8), 8)
        unchanged(s)
    end
end)
test("finite stationary field confirmation commits once and uses real feedback", function()
    local s = setup()
    confirm(s, position(640,426,8), position(640,426,8), 8)
    resources(s, 2, 5, 1)
    assert(s.ui.busy and #s.battle.discard == 1)
    s.field.listeners.up(position(640,426,8)); s.field.click({touchId=8})
    s.drain()
    resources(s, 2, 5, 1)
end)
test("finite small movement stays a tap but threshold displacement cancels", function()
    for _, x in ipairs({647,648}) do
        local s = setup()
        confirm(s, position(640,426,8), position(x,426,8), 8)
        if x == 647 then resources(s,2,5,1) else unchanged(s) end
    end
end)
test("finite field edge confirms and just outside cancels", function()
    for _, x in ipairs({40,39}) do
        local s = setup()
        confirm(s, position(40,426,8), position(x,426,8), 8)
        if x == 40 then resources(s,2,5,1) else unchanged(s) end
    end
end)
test("complete positionless field Down Up Click retains C mode", function()
    local s = setup()
    confirm(s, {touchId=8}, {touchId=8}, 8)
    resources(s,2,5,1)
end)
test("positionless field sequence without touch IDs retains C mode", function()
    local s = setup()
    confirm(s, {}, {}, nil)
    resources(s,2,5,1)
end)
test("missing coordinates on one side retain the existing fallback", function()
    for _, missingDown in ipairs({false,true}) do
        local s = setup()
        confirm(s, missingDown and {touchId=8} or position(640,426,8),
            missingDown and position(640,426,8) or {touchId=8}, 8)
        resources(s,2,5,1)
    end
end)
test("nil and nonnumeric positions remain unknown rather than nonfinite", function()
    for _, kind in ipairs({"nil","text"}) do
        local s = setup()
        local up = kind == "nil" and position(nil,nil,8) or position("640","426",8)
        confirm(s, position(640,426,8), up, 8)
        resources(s,2,5,1)
    end
end)
test("click-only host still confirms on the distinct field", function()
    local host, ui, panel = H.setup()
    panel:GetChild("card1"):GetChild("hit").click()
    panel:GetChild("playArea"):GetChild("hit").click()
    assert(host.run.combat.energy==2 and host.run.combat.player.block==5 and #host.run.combat.hand==1)
end)
test("invalid release cannot borrow a new selection and a fresh same-touch tap works", function()
    local s = setup()
    confirm(s, position(640,426,8), position(0/0,426,8), 8)
    unchanged(s)
    s.tap("card2",9)
    assert(s.ui.selected == s.battle.hand[2].uid)
    s.field.click({touchId=8}); s.field.listeners.up(position(640,426,8)); s.field.click({touchId=8})
    unchanged(s)
    confirm(s, position(640,426,8), position(640,426,8), 8)
    resources(s,2,5,1)
    s.drain(); s.tap("card1",9)
    s.field.listeners.endDrag(position(640,426,8)); s.field.click({touchId=8})
    resources(s,2,5,1)
    confirm(s, position(640,426,8), position(640,426,8), 8)
    resources(s,1,10,0)
end)
test("old canceled touch cannot cancel or confirm a fresh foreign gesture", function()
    local s = setup()
    confirm(s, position(640,426,8), position(math.huge,426,8), 8)
    unchanged(s)
    s.field.listeners.down(position(640,426,9))
    s.field.listeners.up(position(0/0,426,8)); s.field.listeners.endDrag(position(640,426,8))
    s.field.click({touchId=8}); unchanged(s)
    s.field.listeners.up(position(640,426,9)); s.field.click({touchId=9})
    resources(s,2,5,1)
end)
test("foreign invalid events do not discard the owning field tap", function()
    local s = setup()
    s.field.listeners.down(position(640,426,8))
    s.field.listeners.drag(position(math.huge,426,9))
    s.field.listeners.up(position(0/0,426,9)); s.field.listeners.endDrag(position(640,426,9))
    s.field.click({touchId=9}); unchanged(s)
    s.field.listeners.up(position(640,426,8)); s.field.click({touchId=8})
    resources(s,2,5,1)
end)
test("invalid Drag cancels even if the owning Up becomes finite", function()
    local s = setup()
    s.field.listeners.down(position(640,426,8))
    s.field.listeners.drag(position(640,-math.huge,8))
    s.field.listeners.up(position(640,426,8)); s.field.click({touchId=8})
    unchanged(s)
end)
test("EndDrag invalidates a released field token before Click", function()
    local s = setup()
    s.field.listeners.down(position(640,426,8)); s.field.listeners.up(position(640,426,8))
    s.field.listeners.endDrag(position(640,0/0,8)); s.field.click({touchId=8})
    unchanged(s)
end)
test("hand-slot replacement after invalid release cannot consume another card", function()
    local s = setup()
    confirm(s, position(640,426,8), position(640,math.huge,8), 8)
    unchanged(s)
    table.remove(s.battle.hand,1); s.host:refresh(); s.tap("card1",9)
    s.field.listeners.up(position(640,426,8)); s.field.click({touchId=8})
    resources(s,3,0,1)
    confirm(s, position(640,426,9), position(640,426,9), 9)
    resources(s,2,5,0)
end)
test("changed selection between Down and finite Up remains rejected", function()
    local s = setup()
    s.field.listeners.down(position(640,426,8)); s.tap("card2",9)
    s.field.listeners.up(position(640,426,8)); s.field.click({touchId=8})
    unchanged(s)
end)
test("a finite first coordinate sample is not replaced by a second getter read", function()
    local s, downReads, upReads = setup(), 0, 0
    local down = {touchId=8,GetUIPos=function()
        downReads=downReads+1; if downReads==1 then return 640,426 end; return math.huge,426
    end}
    local up = {touchId=8,GetUIPos=function()
        upReads=upReads+1; if upReads==1 then return 640,426 end; return 0/0,426
    end}
    confirm(s,down,up,8)
    resources(s,2,5,1)
    assert(downReads==1 and upReads==1,"each field event must be sampled only once")
end)
test("an invalid first coordinate sample cannot be replaced by a finite second read", function()
    local s, reads = setup(), 0
    local up = {touchId=8,GetUIPos=function()
        reads=reads+1; if reads==1 then return -math.huge,426 end; return 640,426
    end}
    confirm(s,position(640,426,8),up,8)
    unchanged(s)
    assert(reads==1,"invalid release must be sampled only once")
end)
print("LUA_PLAY_AREA_COORDINATES " .. passed .. " passed; " .. failed .. " failed")
if failed > 0 then error("Play-area coordinate regressions: " .. failed) end

return registered
end
