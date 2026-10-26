-- Independent bounded review of the card Drag source ownership patch.
-- Uses production Run/Combat + generated controls. Two held-token cases are
-- deliberately injected diagnostic states, not claimed as platform sequences.
local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(why)) end
end
local function setup(deck)
    local h,u,p,e,t,d,c = H.setup(deck or {"strike","strike"},{"cultist","jaw_worm"})
    h.run.combat.enemies[2].statuses.vulnerable=2
    h:refresh()
    return h,u,p,e,t,d,c
end
local function label(p,i) return p:GetChild("card"..i):GetChild("label").text end
local function posEvent(u,id,x,y)
    local k=math.min(u.canvasWidth/1280,u.canvasHeight/720)
    return {touchId=id,GetUIPos=function() return u.canvasWidth/2+x*k,u.canvasHeight/2+y*k end}
end
test("saved foreign control callback after cancellation cannot change the new card preview",function()
    local h,u,p,e,t,d,c=setup()
    local oldDrag=p:GetChild("card1"):GetChild("hit").listeners.drag
    e("card1","down",41);c()
    local one,two=p:GetChild("enemy1"),p:GetChild("enemy2")
    e("card2","down",41);e("card2","drag",41,one.x,one.y)
    local g=u.gesture;local before=label(p,2);local x,y=g.x,g.y
    oldDrag(posEvent(u,41,two.x,two.y))
    assert(g.x==x and g.y==y and label(p,2)==before,"foreign Drag changed preview/coordinates")
    assert(p:GetChild("dragLayer"):GetChild("reticle").x==x,"foreign Drag moved reticle")
    local b=h.run.combat;local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
    e("card1","up",41,two.x,two.y)
    assert(u.gesture==g and b.energy==3,"foreign Up consumed ownership")
    e("card2","up",41,one.x,one.y)
    assert(b.enemies[1].hp==hp1-6 and b.enemies[2].hp==hp2 and b.energy==2)
end)
test("foreign Drag cannot arm a stationary card while genuine own Drag still can",function()
    local h,u,p,e=setup();local two=p:GetChild("enemy2")
    e("card2","down",41);local g=u.gesture
    e("card1","drag",41,two.x,two.y)
    assert(not g.moving and u.selected==nil,"foreign source armed card")
    e("card2","drag",41,two.x,two.y)
    assert(g.moving and label(p,2):find("9↑",1,true))
end)
test("same UID and slot survives explicit and presentation-only redraw generations",function()
    local h,u,p,e=setup();local one,two=p:GetChild("enemy1"),p:GetChild("enemy2")
    e("card1","down",41);local g=u.gesture;local render=u.rewardRender
    h:refresh();u:render(true);u:render()
    assert(u.rewardRender>render and u.gesture==g and g.input.held==g)
    e("card1","drag",41,two.x,two.y)
    assert(g.moving and label(p,1):find("9↑",1,true))
    h:refresh();u:render(true)
    assert(u.gesture==g and g.input.held==g)
    local b=h.run.combat;local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
    e("dragLayer","up",41,one.x,one.y)
    assert(b.energy==2 and b.enemies[1].hp==hp1-6 and b.enemies[2].hp==hp2,
        "legitimate Up did not recompute final target")
end)
test("same card type at fixed slot but changed UID invalidates Drag before mutation",function()
    local h,u,p,e=setup();local b=h.run.combat;local two=p:GetChild("enemy2")
    assert(b.hand[1].cardId==b.hand[2].cardId and b.hand[1].uid~=b.hand[2].uid)
    e("card1","down",41);local g=u.gesture;local x,y=g.x,g.y
    b.hand[1],b.hand[2]=b.hand[2],b.hand[1]
    e("card1","drag",41,two.x,two.y)
    assert(g.x==x and g.y==y and not g.moving,"reused slot moved wrong UID")
    e("card1","up",41,two.x,two.y)
    assert(u.gesture==nil and b.energy==3)
    h:refresh();e("card1","down",41);e("card1","drag",41,two.x,two.y)
    assert(u.gesture.uid==b.hand[1].uid and u.gesture.moving)
end)
for _,kind in ipairs({"revoked","replaced"}) do
    test("diagnostic current held token is "..kind..": overlay cannot move stale g",function()
        local h,u,p,e=setup();local two=p:GetChild("enemy2")
        e("card1","down",41);local g=u.gesture;local x,y=g.x,g.y
        g.input.held=kind=="replaced" and {} or nil
        e("dragLayer","drag",41,two.x,two.y)
        assert(g.x==x and g.y==y and not g.moving,"overlay ignored current held token")
        g.input.held=g -- restore diagnostic precondition, then normal flow must work
        e("card1","drag",41,two.x,two.y)
        assert(g.moving and label(p,1):find("9↑",1,true))
    end)
end
test("owner Up and EndDrag each accept final coordinates without a last Drag",function()
    for _,kind in ipairs({"up","endDrag"}) do
        for _,source in ipairs({"card1","dragLayer"}) do
            local h,u,p,e=setup();local b=h.run.combat
            local one,two=p:GetChild("enemy1"),p:GetChild("enemy2")
            local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
            e("card1","down",41);e("card1","drag",41,one.x,one.y)
            e(source,kind,41,two.x,two.y)
            e("card1","up",41,two.x,two.y);e("card1","endDrag",41,two.x,two.y);e("card1","click",41)
            assert(b.energy==2 and #b.hand==1 and b.enemies[1].hp==hp1 and b.enemies[2].hp==hp2-9,
                source.." "..kind.." failed or consumed more than once")
        end
    end
end)
test("coordinate-less owner release cancels and resize permits a fresh same-slot retry",function()
    local h,u,p,e=setup();local two=p:GetChild("enemy2")
    e("card1","down",41);e("card1","drag",41,two.x,two.y)
    p:GetChild("dragLayer"):GetChild("hit").listeners.up({touchId=41})
    assert(u.gesture==nil and h.run.combat.energy==3 and #h.run.combat.hand==2)
    e("card1","down",41);local old=u.gesture;h:resize(1600,900)
    assert(u.gesture==nil and old.input.held==nil)
    e("card1","down",41);e("card1","drag",41,two.x,two.y)
    assert(u.gesture~=old and u.gesture.moving)
    e("dragLayer","up",41,two.x,two.y)
    assert(h.run.combat.energy==2)
end)
test("C-mode paired card and enemy DownClick remain valid; card missing Up stays rejected",function()
    local h,u,p,e,t=setup({"strike"});local b=h.run.combat;local hp=b.enemies[2].hp
    e("card1","down",41);e("card1","click",41)
    assert(u.selected==nil and b.energy==3,"card missing Up unexpectedly selected")
    e("card1","up",41);e("card1","click",41)
    assert(u.selected==b.hand[1].uid)
    e("enemy2","down",42);e("enemy2","click",42)
    assert(b.energy==2 and b.enemies[2].hp==hp-9)
end)
test("pure Click card and field retain existing C-mode behavior",function()
    local h,u,p,e=setup({"defend"});e("card1","click",nil);e("playArea","click",nil)
    assert(h.run.combat.energy==2 and h.run.combat.player.block==5 and #h.run.combat.hand==0)
end)
test("targeted potion still needs fresh confirmation and survives cancelled foreign card Drag",function()
    local h,u,p,e,t,d,c=setup();local b=h.run.combat
    assert(H.Run.obtainPotion(h.run,"fire_potion"));h:refresh()
    e("card1","down",41);c()
    e("enemy1","down",42);e("enemy1","click",42)
    local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
    p:GetChild("potion1").click()
    assert(h.run.potions[1]=="fire_potion" and u.potionAim and b.enemies[1].hp==hp1)
    local aim=u.potionAim;local two=p:GetChild("enemy2")
    e("card1","drag",41,two.x,two.y)
    assert(u.potionAim==aim and u.gesture==nil)
    e("enemy2","down",43);e("enemy2","click",43);d()
    e("enemy2","click",43)
    assert(h.run.potions[1]==nil and b.enemies[1].hp==hp1 and b.enemies[2].hp==hp2-20 and b.energy==3)
end)
print("INDEPENDENT_DRAG_REVIEW "..passed.." passed; "..failed.." failed")
if failed>0 then error("independent drag review failures: "..failed) end
