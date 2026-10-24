local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local F,Run,setup = H.F,H.Run,H.setup
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(why)) end
end

test("consumed selection click cannot confirm itself or a later fresh selection",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    tap("card1",7)
    assert(ui.selected==battle.hand[1].uid)
    event("card1","click",7)
    assert(battle.energy==3 and #battle.hand==2 and battle.player.block==0)
    tap("card2",8)
    assert(ui.selected==battle.hand[2].uid)
    event("card1","click",7)
    assert(ui.selected==battle.hand[2].uid and battle.energy==3)
end)

test("missing click event cannot borrow an identified released pointer",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); event("card1","up",7)
    panel:GetChild("card1"):GetChild("hit").click()
    assert(ui.selected==nil and battle.energy==3)
    event("card1","click",7)
    assert(ui.selected==battle.hand[1].uid)
    panel:GetChild("card1"):GetChild("hit").click()
    assert(battle.energy==3 and battle.player.block==0)
end)

test("stale A events cannot cancel or consume live B ownership on the same slot",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); host:resize(1600,900)
    event("card1","down",8)
    event("card1","up",7); event("card1","endDrag",7); event("card1","click",7)
    event("card1","up",8)
    event("card1","click",7)
    assert(ui.selected==nil and battle.energy==3)
    event("card1","click",8)
    assert(ui.selected==battle.hand[1].uid and battle.energy==3)
    tap("playArea",8)
    assert(battle.energy==2 and battle.player.block==5)
end)

test("resize between stationary Up and Click cancels the released binding",function()
    local host,ui,panel,event,tap=setup()
    event("card1","down",7); event("card1","up",7)
    host:resize(1600,900)
    event("enemy1","down",8); event("card1","click",7)
    assert(ui.selected==nil and host.run.combat.energy==3)
    tap("card1",8); tap("playArea",8)
    assert(host.run.combat.energy==2)
end)

test("same-slot UID replacement between Up and Click cannot select the replacement",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); event("card1","up",7)
    local old=table.remove(battle.hand,1) -- explicit hand-mutation boundary, not a full-run claim
    event("card1","click",7)
    assert(ui.selected==nil and battle.energy==3 and battle.hand[1].uid~=old.uid)
    tap("card1",8); tap("playArea",8)
    assert(battle.energy==2 and #battle.hand==0)
end)

test("no coordinates and no touch IDs retain complete stationary C-mode sequences",function()
    for _,kind in ipairs({"no_coordinates","no_id"}) do
        local host,ui,panel,event,tap=setup()
        local hit=panel:GetChild("card1"):GetChild("hit")
        local function tapWithout()
            if kind=="no_coordinates" then
                hit.listeners.down({touchId=7}); hit.listeners.up({touchId=7}); hit.click({touchId=7})
            else tap("card1",nil) end
        end
        tapWithout()
        assert(ui.selected==host.run.combat.hand[1].uid,kind)
        local field=panel:GetChild("playArea"):GetChild("hit")
        if kind=="no_coordinates" then
            field.listeners.down({touchId=7});field.listeners.up({touchId=7});field.click({touchId=7})
        else tap("playArea",nil) end
        assert(host.run.combat.energy==2 and host.run.combat.player.block==5,kind)
    end
end)

test("unplayable stationary pointer tap retains energy feedback and fresh recovery",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    battle.energy=0; ui:render()
    tap("card1",7)
    assert(ui.selected==nil and battle.energy==0 and #battle.hand==2)
    assert(panel:GetChild("notice").text:find("能量不足",1,true))
    battle.energy=3; ui:render(); tap("card1",7); tap("playArea",8)
    assert(battle.energy==2 and battle.player.block==5)
end)

test("click-only hosts remain usable even when pointer enums are available",function()
    local host,ui,panel,event,tap=setup()
    local hit=panel:GetChild("card1"):GetChild("hit")
    hit.click(); panel:GetChild("playArea"):GetChild("hit").click()
    assert(host.run.combat.energy==2 and host.run.combat.player.block==5)
end)

test("selected attack and fresh target click still hit only that living target",function()
    local host,ui,panel,event,tap=setup({"strike"},{"cultist","jaw_worm"})
    local battle=host.run.combat
    local hp1,hp2=battle.enemies[1].hp,battle.enemies[2].hp
    tap("card1",7)
    event("enemy2","down",8); event("enemy2","click",8)
    assert(battle.energy==2 and #battle.hand==0 and battle.enemies[1].hp==hp1 and battle.enemies[2].hp==hp2-6)
end)

test("cancelled click cannot fall back through a different unobserved card slot",function()
    local host,ui,panel,event,tap=setup()
    event("card1","down",7); host:resize(1600,900)
    event("enemy1","down",8)
    event("card2","click",7)
    assert(ui.selected==nil and host.run.combat.energy==3)
    panel:GetChild("card2"):GetChild("hit").click()
    assert(ui.selected==nil)
    tap("card2",8); tap("playArea",8)
    assert(host.run.combat.energy==2 and host.run.combat.player.block==5)
end)

test("reward card after a real killing play requires a fresh pointer but remains claimable",function()
    local host,ui,panel,event,tap,drain=setup({"strike"},{"cultist"})
    -- Isolated one-HP enemy setup; the play, victory and reward are real commands.
    host.run.combat.enemies[1].hp=1; ui:render()
    tap("card1",7); event("enemy1","down",8); event("enemy1","click",8); drain()
    assert(host.run.phase=="reward")
    local before=#host.run.deck
    event("card1","click",7)
    assert(host.run.phase=="reward" and #host.run.deck==before)
    tap('cardReward',9)
    tap("card1",8)
    assert(host.run.phase=="reward" and #host.run.deck==before+1 and panel:GetChild('rewardList').visible)
end)

print("LUA_BATTLE_CLICK_OWNERSHIP "..passed.." passed; "..failed.." failed")
if failed>0 then error("Interrupted gesture ownership failures: "..failed) end
