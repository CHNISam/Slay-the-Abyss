package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local cursor = {CursorDown="down", CursorUp="up", CursorExit="exit", CursorEndDrag="endDrag"}
local count, failed = 0, 0
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " battle_speed_gestures " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function fixture(pointer)
    local root = F.Viewport.apply(F.control({children = F.Layout}),1280,720)
    local host = F.GameUI.new(root,F.Data,F.Presentation,"click", {
        seed=1,originalCharacters=true,prologue=false,cursorEvents=pointer and cursor or nil,imageSource="static",
        color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
    })
    root.ui=host
    return host,root,root:GetChild("menuPanel"):GetChild("battleSpeed"):GetChild("hit")
end
local function fire(hit,kind,id)
    return assert(hit.listeners[kind],kind)(id and {touchId=id} or nil)
end
local function gesture(hit,id) fire(hit,"down",id);fire(hit,"up",id) end
local function unchanged(host,seed)
    assert(host.fastMode==false and host.battleUI.feedback.fastMode==false,
        "an unavailable or stale setting command changed speed")
    assert(host.seed==seed and host.run==nil and host.map==nil,
        "a setting command created a run or consumed its seed")
end
test("click-only title control toggles both ways and rejects invalid setter values",function()
    local host,root,hit=fixture(false)
    assert(hit.click() and host.fastMode==true and host.battleUI.fastMode==true)
    assert(hit.click() and host.fastMode==false and host.battleUI.fastMode==false)
    assert(not host:setFastMode("fast"))
    assert(root:GetChild("menuPanel"):GetChild("battleSpeed"):GetChild("label").text=="战斗速度：普通")
    unchanged(host,1)
end)
test("orphan touch and replayed Click cannot toggle a pointer-capable title control",function()
    local host,_,hit=fixture(true)
    assert(not fire(hit,"click",1));unchanged(host,1)
    gesture(hit,1);assert(fire(hit,"click",1) and host.fastMode==true)
    assert(not fire(hit,"click",1) and host.fastMode==true,"one physical gesture must grant one toggle")
end)
test("a foreign pointer cannot steal or cancel the owner's setting gesture",function()
    local host,_,hit=fixture(true)
    fire(hit,"down",1);fire(hit,"down",2);fire(hit,"up",2);fire(hit,"exit",2)
    assert(not fire(hit,"click",2));unchanged(host,1)
    fire(hit,"up",1);assert(fire(hit,"click",1) and host.fastMode==true)
end)
test("drag cancellation and viewport resize retire the setting gesture",function()
    local host,_,hit=fixture(true)
    gesture(hit,1);fire(hit,"endDrag",1);assert(not fire(hit,"click",1));unchanged(host,1)
    fire(hit,"down",2);host:resize(1600,900);fire(hit,"up",2)
    assert(not fire(hit,"click",2));unchanged(host,1)
    gesture(hit,3);assert(fire(hit,"click",3) and host.fastMode==true)
end)
local transitions={
    {name="exit",open=function(h)return h:openExit()end,close=function(h)return h:closeExit()end},
    {name="character choice",open=function(h)return h:start()end,close=function(h)return h:closeCharacters()end},
}
for _,transition in ipairs(transitions)do
    test(transition.name.." modal retires the title pointer and permits a fresh gesture after closing",function()
        local host,_,hit=fixture(true)
        gesture(hit,1);assert(transition.open(host))
        assert(not fire(hit,"click",1));unchanged(host,1)
        assert(transition.close(host))
        assert(not fire(hit,"click",1));unchanged(host,1)
        gesture(hit,2);assert(fire(hit,"click",2) and host.fastMode==true)
    end)
    test(transition.name.." modal rejects the public speed command as well as underlying pointer input",function()
        local host,_,hit=fixture(true)
        assert(transition.open(host))
        gesture(hit,3);assert(not fire(hit,"click",3));unchanged(host,1)
        assert(not host:setFastMode(true),"public setter bypassed the "..transition.name.." modal")
        unchanged(host,1)
    end)
end
test("disabling the host retires setting input and public commands",function()
    local host,_,hit=fixture(true)
    gesture(hit,1);assert(host:disable())
    assert(not fire(hit,"click",1) and not host:setFastMode(true))
    unchanged(host,1)
end)
for _,phase in ipairs({"defeat","victory"})do
    test(phase.." result hides the title-only speed control so it cannot overlap settlement",function()
        local host,root,hit=fixture(false)
        assert(host:start("traveler"))
        -- Isolate the terminal renderer, rather than claiming an earned ending.
        host.run.phase=phase;host:refresh()
        assert(host.mode==phase and root:GetChild("menuPanel").visible)
        assert(not root:GetChild("menuPanel"):GetChild("battleSpeed").visible,
            "the title speed control overlaps settlement on a result page")
        assert(not hit.click() and not host:setFastMode(true))
        assert(host.fastMode==false)
    end)
end
assert(failed==0,failed.." battle speed gesture regressions failed")
print("LUA_GAME_UI_BATTLE_SPEED_GESTURES_PASS "..count)
