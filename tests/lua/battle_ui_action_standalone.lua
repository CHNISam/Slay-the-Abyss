local H = dofile("tests/lua/support/battle_action_fixture.lua")
local F, Run, UI = H.F, H.Run, require("abyss_battle_ui")
local test, finish = H.suite("LUA_ACTION_STANDALONE")
local function find(specs, name)
    for _,spec in ipairs(specs) do
        if spec.name==name then return spec end
        local child=find(spec.children or {},name);if child then return child end
    end
end
local function setup(pointer)
    -- The generated game panel uses the same battleLayout stage children.
    local stage=F.Combat.copy(assert(find(F.Layout,"battlePanel")))
    stage.name,stage.visible="stage",true
    local root=F.control({children={{name="backdrop"},stage}})
    local u=UI.new(root,F.Data,F.Presentation,"click",{imageSource="static",color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
        cursorEvents=pointer~=false and {CursorDown="down",CursorUp="up",CursorDrag="drag",CursorEndDrag="endDrag"} or nil})
    local p=root:GetChild("stage");u:resize(1280,720)
    local emit,tap=H.controls(p)
    local function drain() for _=1,400 do if not u.busy then return end;u:update(0.05) end;assert(not u.busy) end
    return u,p,emit,tap,drain
end
local function boundary(hp,deck,enemies,pointer)
    local u,p,e,t,d=setup(pointer)
    u.run=Run.new(F.Data,1);assert(Run.startCombat(u.run,"cultist_solo"))
    u.run.combat=F.Combat.new(F.Data,{hp=hp,deck=deck,enemies=enemies});u:render()
    return u,p,e,t,d
end
test("initial nil-run start accepts a fresh complete gesture",function()
    local u,p,e,t=setup();t("start",7);assert(u.run.phase=="combat")
end)
test("initial nil-run start cannot survive resize and accepts a fresh retry",function()
    local u,p,e,t=setup();e("start","down",7);u:resize(1600,900)
    e("start","up",7);e("start","click",7);assert(u.run==nil)
    t("start",7);assert(u.run.phase=="combat")
end)
test("defeat restart cannot survive resize and accepts a fresh retry",function()
    local u,p,e,t,d=boundary(1,{"defend"},{"jaw_worm"});t("endTurn",8);d();assert(u.run.phase=="defeat")
    local old=u.run;e("start","down",7);u:resize(1600,900)
    e("start","up",7);e("start","click",7);assert(u.run==old and u.run.phase=="defeat")
    t("start",7);assert(u.run~=old and u.run.phase=="combat")
end)
test("continue cannot survive resize and accepts a fresh retry",function()
    local u,p,e,t,d=boundary(80,{"bludgeon"},{"acid_slime_s"})
    t("card1",8);t("enemy1",8);d();assert(u.run.phase=="reward");t("skip",8)
    assert(u.run.phase=="map");local old=u.run.combat;e("continue","down",7);u:resize(1600,900)
    e("continue","up",7);e("continue","click",7);assert(u.run.phase=="map")
    t("continue",7);assert(u.run.phase=="combat" and u.run.combat~=old)
end)
test("standalone no-pointer host preserves start restart and continue",function()
    local u,p=setup(false);p:GetChild("start").click();assert(u.run.phase=="combat")
    local v,q,e,t,d=boundary(1,{"defend"},{"jaw_worm"},false)
    q:GetChild("endTurn").click();d();local old=v.run;assert(v.run.phase=="defeat")
    q:GetChild("start").click();assert(v.run~=old and v.run.phase=="combat")
    local w,r,ee,tt,dd=boundary(80,{"bludgeon"},{"acid_slime_s"},false)
    r:GetChild("card1"):GetChild("hit").click();r:GetChild("enemy1"):GetChild("hit").click();dd()
    assert(w.run.phase=="reward");r:GetChild("skip").click();assert(w.run.phase=="map")
    r:GetChild("continue").click();assert(w.run.phase=="combat")
end)
test("metadata-free start gesture and harmless redraw remain valid",function()
    local u,p,e=setup();e("start","down",nil);u:render();e("start","up",nil);u:render()
    e("start","click",nil);assert(u.run.phase=="combat")
end)
finish()
