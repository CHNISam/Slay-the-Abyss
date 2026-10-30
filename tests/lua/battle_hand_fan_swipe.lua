-- 搓牌（横向浏览手牌）灵敏度：指下最近一张、横搓不出牌、上推仍可出牌。
local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local setup = H.setup
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(why)) end
end
local five={"defend","defend","defend","defend","defend"}
local function settled(deck)
    local host,ui,panel,event,tap=setup(deck)
    for _=1,40 do host:update(0.1) end
    return host,ui,panel,event,tap
end
local function slotX(panel,i) return panel:GetChild("card"..i).x end

test("lateral swipe retargets hover to each neighbour under the finger",function()
    local host,ui,panel,event=settled(five)
    local y=panel:GetChild("card1").y
    local xs={} for i=1,5 do xs[i]=slotX(panel,i) end
    event("card1","down",7,xs[1],y)
    for i=2,5 do
        event("card1","drag",7,xs[i],y)
        assert(ui.hover==i,"finger over slot "..i.." hovered "..tostring(ui.hover))
        assert(ui.gesture and not ui.gesture.moving,"browsing must not lift a card")
        assert(ui.gesture.uid==host.run.combat.hand[i].uid)
    end
    event("card1","drag",7,xs[3]+4,y)
    assert(ui.hover==3,"swiping back follows the finger")
end)

test("pure lateral browse release plays nothing and leaves no C-mode selection",function()
    local host,ui,panel,event=settled(five)
    local battle=host.run.combat
    local y=panel:GetChild("card1").y
    event("card1","down",7,slotX(panel,1),y)
    event("card1","drag",7,slotX(panel,4),y)
    event("card1","up",7,slotX(panel,4),y); event("card1","click",7,slotX(panel,4),y)
    assert(battle.energy==3 and #battle.hand==5 and battle.player.block==0)
    assert(ui.selected==nil and ui.gesture==nil,"browse release selected "..tostring(ui.selected))
    assert(ui.hover==4,"released browse keeps the last hovered card")
end)

test("browse then push up plays the browsed card, not the pressed one",function()
    local host,ui,panel,event=settled(five)
    local battle=host.run.combat
    local y=panel:GetChild("card1").y
    local target=battle.hand[3].uid
    event("card1","down",7,slotX(panel,1),y)
    event("card1","drag",7,slotX(panel,3),y)
    event("card1","drag",7,slotX(panel,3),y+60)
    assert(ui.gesture.moving and ui.selected==target,"push up must lift browsed card")
    local area=panel:GetChild("playArea")
    event("dragLayer","drag",7,area.x,area.y); event("dragLayer","up",7,area.x,area.y)
    assert(battle.energy==2 and battle.player.block==5 and #battle.hand==4)
    for _,c in ipairs(battle.hand) do assert(c.uid~=target,"browsed card was not played") end
end)

test("vertical drag without browsing keeps the original 8px lift",function()
    local host,ui,panel,event=settled(five)
    local x,y=slotX(panel,2),panel:GetChild("card2").y
    event("card2","down",7,x,y); event("card2","drag",7,x+2,y+9)
    assert(ui.gesture.moving and ui.selected==host.run.combat.hand[2].uid)
end)

test("C-mode tap still selects then plays",function()
    local host,ui,panel,event,tap=settled(five)
    local battle=host.run.combat
    tap("card2",7)
    assert(ui.selected==battle.hand[2].uid and battle.energy==3)
    tap("playArea",8)
    assert(battle.energy==2 and battle.player.block==5)
end)

print(passed.." passed, "..failed.." failed")
if failed>0 then os.exit(1) end
