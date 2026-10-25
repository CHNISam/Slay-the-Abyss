package.path="src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;"..package.path
local F=require("support.game_ui_fixture")
local X=require("support.experimental_ui_fixture")
local Run=require("abyss_run")
local Combat=require("abyss_combat")
local function eq(a,b)assert(a==b,tostring(a).." ~= "..tostring(b))end
local n=0
local function test(name,fn)fn();n=n+1;print("ok game_ui_classes "..n.." - "..name)end
local function hit(root,path)
    local c=root
    for id in path:gmatch("[^/]+")do c=assert(c:GetChild(id),id)end
    return c:GetChild("hit")
end
test("default host keeps the ordinary Ironclad start",function()
    local ui=X.new({enabled=false});assert(ui:start());eq(ui.run.characterProfile,nil);eq(ui.run.maxHp,80)
    local ok,reason=ui:start("silent");eq(ok,false) -- a live run cannot restart through a class command
end)
for index,id in ipairs({"ironclad","silent","defect","watcher"})do
    test(id.." starts through the class panel with real battle and deck rendering",function()
        local ui,root=X.new();assert(ui:start());eq(ui.run,nil);eq(ui.characterOpen,true)
        assert(hit(root,"characterPanel/character"..index).click());eq(ui.run.characterProfile.id,id)
        eq(ui.characterOpen,false);eq(ui.mode,"map")
        assert(ui:openDeck());ui:update(0);assert(ui:closeDeck())
        assert(Run.startCombat(ui.run,"cultist_solo"));ui:refresh()
        eq(ui.mode,"battle");assert(#ui.run.combat.hand>0)
        for i=1,#ui.run.combat.hand do
            local card=root:GetChild("battlePanel"):GetChild("card"..i)
            assert(card:GetChild("name").text~="");assert(card:GetChild("label").text~="")
        end
    end)
end
test("cancel does not sample a seed or create a run",function()
    local ui,root=X.new();local seed=ui.seed
    assert(ui:start());assert(hit(root,"characterPanel/cancel").click());eq(ui.run,nil);eq(ui.seed,seed)
    eq(ui.characterOpen,false);eq(ui:closeCharacters(),false)
end)
local cursor={CursorDown="down",CursorUp="up",CursorExit="exit",CursorEndDrag="enddrag"}
test("opening and closing the class panel invalidates an old menu press",function()
    local ui,root=X.new({cursor=cursor});local start=hit(root,"menuPanel/start")
    start.listeners.down({touchId=1});assert(ui:start());assert(ui:closeCharacters())
    start.listeners.up({touchId=1});eq(start.click({touchId=1}),false);eq(ui.run,nil);eq(ui.characterOpen,false)
end)
test("a class choice requires its own touch and expires after cancel or resize",function()
    local ui,root=X.new({cursor=cursor});assert(ui:start());local choice=hit(root,"characterPanel/character2")
    choice.listeners.down({touchId=2});choice.listeners.up({touchId=3});eq(choice.click({touchId=3}),false);eq(ui.run,nil)
    assert(ui:closeCharacters());assert(ui:start());choice.listeners.up({touchId=2});eq(choice.click({touchId=2}),false)
    choice.listeners.down({touchId=4});ui:resize(1600,900);choice.listeners.up({touchId=4});eq(choice.click({touchId=4}),false)
    choice.listeners.down({touchId=5});choice.listeners.up({touchId=5});assert(choice.click({touchId=5}));eq(ui.run.characterProfile.id,"silent")
    eq(choice.click({touchId=5}),false)
end)
test("class modal blocks underlying start, exit, and settlement",function()
    local ui=X.new({settle=function()error("must not settle")end});assert(ui:start())
    eq(ui:openExit(),false);eq(ui:start(),false);eq(ui:settle(),false);eq(ui.run,nil)
end)
print("GAME_UI_CLASSES_PASS "..n)
