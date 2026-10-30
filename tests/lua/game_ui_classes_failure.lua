package.path="src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;"..package.path
local F=require("support.game_ui_fixture")
local X=require("support.experimental_ui_fixture")
local GameUI=require("abyss_game_ui")
local Run=require("abyss_run")
local Combat=require("abyss_combat")
local Seed=require("abyss_new_run_seed")
local n=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();n=n+1;print("ok game_ui_classes_failure "..n.." - "..name) end
local function hit(root,path)
    local c=root
    for part in path:gmatch("[^/]+") do c=assert(c:GetChild(part),part) end
    return c.listeners and c.listeners.click and c or assert(c:GetChild("hit"),path)
end
local function click(root,path) return assert(hit(root,path).click,path)() end
local function canvas()
    local c=F.control({children=F.Layout})
    local root=F.Viewport.apply(c,1280,720)
    return c,root
end
local function startup(hostFlag,layoutFlag,profile)
    local c,root=canvas()
    local updates,signals,lines=nil,0,{}
    script={object=c,EnableUpdate=function(_,value)updates=value end,
        GetParam=function(_,name)
            if name=="nativeBgmEnabled" then return false end
            if name=="experimentalCharacters" and hostFlag~=nil then return hostFlag end
            error("undeclared script parameter "..name)
        end}
    Color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end
    Enum={CursorEventType={CursorClick="click"},ImageSource={StaticReference="static"},
        Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}}
    local actors=F.monsterActors()
    package.loaded.abyss_monster_actor_binding={enabled=true,templateIndex=actors.templateIndex,
        containerTemplateIndex=actors.containerTemplateIndex,powerTemplateIndex=actors.powerTemplateIndex}
    game={GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end,
        GetCursorUIPos=function()return 0,0 end,GetDevice=function()return 'pc'end,
        InstantiateClientUIControl=actors.instantiate,DestroyClientUIControl=actors.destroy,
        ServerSignal=function()return{SendSignal=function()signals=signals+1 end}end}
    local actualNew,actualPrint,actualSeed=GameUI.new,print,Seed.next
    local ui
    GameUI.new=function(...)
        local args={...}
        eq(args[5].campaignProfile,'competition-two-act') -- real native entry stays bounded
        if profile then
            eq(profile,'full-source') -- explicit legacy-class test host only
            args[5].campaignProfile=profile
        end
        -- Inject the missing formal controls at the GameUI boundary under test;
        -- real art adapters have already captured their separate valid hosts.
        if not layoutFlag then root.children.characterPanel=nil;root.children.choicePanel=nil end
        ui=actualNew(table.unpack(args));return ui
    end
    print=function(...)
        local values={};for i=1,select("#",...) do values[i]=tostring(select(i,...)) end
        lines[#lines+1]=table.concat(values," ");actualPrint(...)
    end
    Seed.next=function()return 1 end
    local ok,why=pcall(function()dofile("src/lua/abyss_ui.lua");OnStart()end)
    GameUI.new,print=actualNew,actualPrint
    assert(ok,why)
    return ui,root,function()return updates,signals end,lines,function()Seed.next=actualSeed end
end
local function diagnostic(root,phase)
    local menu=root:GetChild("menuPanel")
    eq(menu.visible,true);eq(menu.raised,true);eq(menu:GetChild("start").visible,false)
    eq(menu:GetChild("settle").visible,false)
    local summary=menu:GetChild("summary")
    eq(summary.visible,true);assert(summary.text:find("测试诊断 · "..phase,1,true),summary.text)
    for _,name in ipairs({"battlePanel","mapPanel","nodePanel","deckPanel","deckEntry","potionPanel","potionEntry",
        "characterPanel","choicePanel","prologuePanel","exitPanel","exitEntry","combatRewards"}) do
        local panel=root:GetChild(name)
        if panel then eq(panel.visible,false) end
    end
    return summary.text
end
local function failUpdate()
    game.GetUICanvasSize=function()error("injected update viewport failure")end
    OnUpdate(0.05)
end
local function drain(ui)
    for _=1,400 do if not ui.battleUI.busy then return end;ui:update(0.05) end
    error("feedback did not finish")
end
local function battle(ui,root,finishFeedback,competition)
    local character,card=competition and 'ironclad' or 'watcher',competition and 'warcry' or 'third_eye'
    assert(ui:start());assert(ui:selectCharacter('traveler'));assert(ui:selectElement(character));assert(ui:confirmCharacter())
    eq(ui.run.campaignProfile,competition and 'competition-two-act' or 'full-source')
    if ui.prologue then ui.prologue:cancel() end
    ui:refresh()
    if competition then
        assert(ui.run.nodeFlow.event.id=='neow')
        assert(click(root,'nodePanel/eventView/option1'))
        eq(#ui.run.nodeFlow.event.rewards,2)
        assert(click(root,'nodePanel/eventView/option1')) -- actual mini Lament keeps the base maximum
        assert(click(root,'nodePanel/eventView/option1'))
        eq(ui.run.phase,'map')
    end
    -- Exact unit entry deck; no natural acquisition, HP, energy or enemy overrides.
    ui.run.deck={}
    for i=1,12 do ui.run.deck[i]={uid=i,cardId=card,upgraded=true} end
    ui.run.nextDeckUid=13
    assert(Run.obtainPotion(ui.run,"block_potion"))
    if competition then
        local first=require('abyss_map').available(ui.map)[1]
        assert(first and first.floor==1 and ui.mapUI:choose(first.id))
    else assert(Run.startCombat(ui.run,"cultist_solo"))end
    ui:refresh()
    local slot
    for i,c in ipairs(ui.run.combat.hand) do if c.cardId==card then slot=i;break end end
    assert(slot);click(root,"battlePanel/card"..slot);click(root,"battlePanel/playArea")
    eq(ui.battleUI.busy,true)
    if competition then assert(ui.run.combat.pendingHandChoice)else assert(ui.run.combat.pendingScry)end
    if finishFeedback then drain(ui);eq(ui.choiceUI.visible,true) end
    return ui.run.combat
end
local function noRevival(ui,root,expectedRun,message)
    eq(ui:start("silent"),false);eq(ui:openExit(),false);eq(ui:openDeck(),false);eq(ui:openPotions(),false)
    eq(ui:confirmExit(),false);eq(ui:settle(),false);eq(ui:refresh(),false);eq(ui:update(0.05),false)
    eq(ui.run,expectedRun);eq(root:GetChild("menuPanel"):GetChild("summary").text,message)
    OnStart();OnUpdate(0.05)
    eq(root:GetChild("menuPanel"):GetChild("summary").text,message)
end
test("undeclared host flag keeps the unified production selection available",function()
    local ui,root,state,lines,restore=startup(nil,true)
    assert(ui);eq(state(),true);eq(root:GetChild("characterPanel").visible,false);eq(root:GetChild("choicePanel").visible,false)
    assert(F.start(ui));eq(ui.run.characterProfile,nil);eq(ui.run.maxHp,80);eq(#ui.run.deck,10)
    assert(table.concat(lines,"\n"):find("ABYSS_UI ready",1,true));restore()
end)
test("missing formal layout produces startup diagnostic and never reports ready",function()
    local ui,root,state,lines,restore=startup(true,false)
    eq(ui,nil);eq(state(),false);diagnostic(root,"startup")
    local output=table.concat(lines,"\n")
    assert(output:find("missing game panel characterPanel",1,true));assert(not output:find("ABYSS_UI ready",1,true))
    restore()
end)
test("update failure closes class overlay, disables old class and exit callbacks and keeps diagnostic visible",function()
    local ui,root,state,_,restore=startup(true,true,'full-source')
    assert(ui:start());eq(root:GetChild("characterPanel").visible,true)
    local oldChoice=hit(root,"characterPanel/character2").click
    local oldExit=hit(root,"exitEntry/open").click
    failUpdate();eq(state(),false);eq(ui.disabled,true)
    local message=diagnostic(root,"update")
    eq(oldChoice(),false);eq(oldExit(),false);eq(ui.run,nil)
    noRevival(ui,root,nil,message);eq(select(2,state()),0);restore()
end)
test("update failure closes mandatory choice and all old inputs preserve the pending combat",function()
    local ui,root,state,_,restore=startup(true,true,'full-source')
    local s=battle(ui,root,true);assert(click(root,"choicePanel/card1"))
    local p=s.pendingScry;local run=ui.run
    local oldConfirm=hit(root,"choicePanel/confirm").click
    local oldEndTurn=hit(root,"battlePanel/endTurn").listeners.click
    local hp,energy,turn,hand,draw,discard=s.player.hp,s.energy,s.turn,#s.hand,#s.draw,#s.discard
    failUpdate();eq(state(),false);eq(ui.disabled,true);local message=diagnostic(root,"update")
    eq(oldConfirm(),false);eq(ui.choiceUI:confirm(),false);oldEndTurn()
    eq(ui.battleUI:usePotion(1),false)
    eq(s.pendingScry,p);eq(s.player.hp,hp);eq(s.energy,energy);eq(s.turn,turn)
    eq(#s.hand,hand);eq(#s.draw,draw);eq(#s.discard,discard);eq(Run.potionCount(run),1)
    noRevival(ui,root,run,message);eq(select(2,state()),0);restore()
end)
test("update failure during feedback cancels presentation without replaying committed card effects",function()
    local ui,root,state,_,restore=startup(true,true,'full-source')
    local s=battle(ui,root,false);local p=s.pendingScry
    local block,energy,hand,draw=s.player.block,s.energy,#s.hand,#s.draw
    failUpdate();eq(state(),false);eq(ui.disabled,true);eq(ui.battleUI.busy,false);diagnostic(root,"update")
    eq(s.pendingScry,p);eq(s.player.block,block);eq(s.energy,energy);eq(#s.hand,hand);eq(#s.draw,draw)
    eq(ui:update(1),false);eq(s.player.block,block);eq(s.pendingScry,p);restore()
end)
test("update failure while exit confirmation is open hides it and rejects its old settlement callback",function()
    local ui,root,state,_,restore=startup(true,true,'full-source')
    battle(ui,root,true);assert(ui:openExit());eq(root:GetChild("exitPanel").visible,true)
    local oldConfirm=hit(root,"exitPanel/confirm").click
    failUpdate();eq(state(),false);local message=diagnostic(root,"update")
    eq(oldConfirm(),false);eq(select(2,state()),0);noRevival(ui,root,ui.run,message);restore()
end)
test("competition Geo update failure preserves mandatory choice, resources and disabled old inputs",function()
    local ui,root,state,_,restore=startup(true,true)
    local s=battle(ui,root,true,true);assert(click(root,"choicePanel/card1"))
    eq(ui.run.characterProfile,nil);eq(ui.run.maxHp,80)
    local p=s.pendingHandChoice;local run=ui.run
    local oldConfirm=hit(root,"choicePanel/confirm").click
    local oldEndTurn=hit(root,"battlePanel/endTurn").listeners.click
    local hp,energy,turn,hand,draw,discard=s.player.hp,s.energy,s.turn,#s.hand,#s.draw,#s.discard
    failUpdate();eq(state(),false);eq(ui.disabled,true);local message=diagnostic(root,"update")
    eq(oldConfirm(),false);eq(ui.choiceUI:confirm(),false);oldEndTurn()
    eq(ui.battleUI:usePotion(1),false)
    eq(s.pendingHandChoice,p);eq(s.player.hp,hp);eq(s.energy,energy);eq(s.turn,turn)
    eq(#s.hand,hand);eq(#s.draw,draw);eq(#s.discard,discard);eq(Run.potionCount(run),1)
    noRevival(ui,root,run,message);eq(select(2,state()),0);restore()
end)
print("GAME_UI_CLASSES_FAILURE_PASS "..n)
