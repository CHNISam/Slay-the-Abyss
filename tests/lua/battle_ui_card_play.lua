local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print("PASS "..name)
    else failed=failed+1;print("FAIL "..name..": "..tostring(why)) end
end
test("two taps on Defend cancel selection without spending energy",function()
    local host,ui,panel,event,tap=H.setup()
    tap("card1",7);assert(ui.selected==host.run.combat.hand[1].uid)
    tap("card1",7)
    assert(ui.selected==nil and host.run.combat.energy==3 and host.run.combat.player.block==0)
end)
test("Defend drops on open battlefield once; late Up EndDrag Click stay inert",function()
    local host,ui,panel,event,tap,drain=H.setup()
    local b=host.run.combat
    event("card1","down",7);event("card1","drag",7,0,0);event("dragLayer","up",7,0,0)
    drain()
    event("card1","up",7,0,0);event("card1","endDrag",7,0,0);event("card1","click",7)
    assert(b.energy==2 and b.player.block==5 and #b.hand==1 and ui.selected==nil)
end)
test("attack released on open ground never chooses a nearest enemy",function()
    local host,ui,panel,event=H.setup({"strike"},{"cultist","jaw_worm"})
    local gap = -285 -- between the player and the widened enemy row
    event("card1","down",7);event("card1","drag",7,gap,0);event("dragLayer","up",7,gap,0)
    assert(host.run.combat.energy==3 and #host.run.combat.hand==1 and ui.selected==nil)
end)
test("outside field and returning to hand cancel even after crossing field",function()
    for _,p in ipairs({{700,0},{0,280},{0,-240},{0,350}}) do
        local host,ui,panel,event=H.setup()
        event("card1","down",7);event("card1","drag",7,0,0);event("dragLayer","up",7,p[1],p[2])
        assert(host.run.combat.energy==3 and host.run.combat.player.block==0)
    end
end)
test("explicit field tap plays selected Defend once and cannot borrow another selection",function()
    local host,ui,panel,event,tap,drain=H.setup()
    local b=host.run.combat
    tap("card1",7);tap("playArea",8);drain()
    assert(b.energy==2 and b.player.block==5 and #b.hand==1)
    tap("card1",7);event("playArea","click",8)
    assert(b.energy==2 and ui.selected==b.hand[1].uid)
    event("playArea","down",8);event("playArea","up",8)
    tap("card1",9);tap("card1",9)
    event("playArea","click",8)
    assert(b.energy==2 and b.player.block==5)
end)
test("target card toggles off on second tap and explicit enemy tap or drag hits only chosen enemy",function()
    for _,mode in ipairs({"tap","drag"}) do
        local host,ui,panel,event,tap=H.setup({"strike"},{"cultist","jaw_worm"})
        local b=host.run.combat
        local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
        tap("card1",7);tap("card1",7)
        assert(ui.selected==nil and b.energy==3)
        if mode=="tap" then tap("card1",7);tap("enemy2",8)
        else
            local enemy=panel:GetChild("enemy2")
            event("card1","down",7);event("card1","drag",7,enemy.x,enemy.y)
            event("dragLayer","up",7,enemy.x,enemy.y)
        end
        assert(b.energy==2 and b.enemies[1].hp==hp1 and b.enemies[2].hp==hp2-6)
    end
end)
test("field confirmation rejects changed hand slot, energy, phase, overlay and foreign touch",function()
    for _,kind in ipairs({"slot","energy","phase","overlay","touch","endDrag"}) do
        local host,ui,panel,event,tap,drain,deck=H.setup()
        local b=host.run.combat
        tap("card2",7);event("playArea","down",8)
        if kind=="slot" then table.remove(b.hand,1)
        elseif kind=="energy" then b.energy=0
        elseif kind=="phase" then b.phase="enemy"
        elseif kind=="overlay" then deck()
        elseif kind=="endDrag" then event("playArea","endDrag",8) end
        local energy,hand=b.energy,#b.hand
        event("playArea","up",kind=="touch" and 9 or 8)
        event("playArea","click",kind=="touch" and 9 or 8)
        assert(b.energy==energy and #b.hand==hand and b.player.block==0,kind)
    end
end)
test("field confirmation cannot play an attack or a long-pressed card",function()
    local host,ui,panel,event,tap=H.setup({"strike"})
    tap("card1",7);tap("playArea",8)
    assert(host.run.combat.energy==3 and not panel:GetChild("playArea").visible)
    host,ui,panel,event,tap=H.setup({"inflame"})
    event("card1","down",7);host:update(0.4)
    event("card1","up",7);event("card1","click",7);tap("playArea",8)
    assert(host.run.combat.energy==3 and #host.run.combat.hand==1)
end)
test("field touch is a tap: dragging or lifting outside cannot confirm",function()
    for _,kind in ipairs({"outside","swipe","return","foreign"}) do
        local host,ui,panel,event,tap=H.setup()
        tap("card1",7);event("playArea","down",8,0,0)
        if kind=="return" then event("playArea","drag",8,100,0)
        elseif kind=="foreign" then event("playArea","drag",9,100,0) end
        local x=kind=="outside" and 700 or kind=="swipe" and 100 or 0
        event("playArea","up",8,x,0);event("playArea","click",8,x,0)
        assert(host.run.combat.energy==(kind=="foreign" and 2 or 3),kind)
    end
end)
test("enemy confirmation from an earlier selection cannot submit a newly selected card",function()
    local host,ui,panel,event,tap=H.setup({"strike"},{"cultist","jaw_worm"})
    tap("card1",7);event("enemy2","down",8);event("enemy2","up",8)
    tap("card1",9);tap("card1",9)
    event("enemy2","click",8)
    assert(host.run.combat.energy==3 and #host.run.combat.hand==1)
end)
test("click-only hosts toggle cards and confirm only on the distinct field",function()
    local host,ui,panel=H.setup()
    local card=panel:GetChild("card1"):GetChild("hit")
    local field=panel:GetChild("playArea"):GetChild("hit")
    card.click();card.click()
    assert(ui.selected==nil and host.run.combat.energy==3)
    card.click();field.click()
    assert(host.run.combat.energy==2 and host.run.combat.player.block==5)
end)
print("LUA_CARD_PLAY "..passed.." passed; "..failed.." failed")
if failed>0 then error("Card play regressions: "..failed) end
