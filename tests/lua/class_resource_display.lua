package.path="src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;"..package.path
local F=require("support.game_ui_fixture")
local X=require("support.experimental_ui_fixture")
local Run=require("abyss_run")
local Orbs=require("abyss_orbs")
local Events=require("abyss_events")
local Combat=require("abyss_combat")
local n=0
local function test(name,fn)fn();n=n+1;print("ok class resource "..n.." - "..name)end
local function start(id,card)
    local ui,root=X.new();assert(ui:start(id))
    ui.run.deck={};for i=1,12 do ui.run.deck[i]={uid=i,cardId=card,upgraded=false} end
    ui.run.nextDeckUid=13;assert(Run.startCombat(ui.run,"cultist_solo"));ui:refresh()
    return ui,root
end
test("orb view returns actual ordered passive and evoke values without mutations or RNG",function()
    local ui=start("defect","defend_blue");local s=ui.run.combat
    s.player.statuses.focus=2;s.orbs.focus=2
    s.orbs.balls={{kind="lightning"},{kind="frost"},{kind="dark",stored=21}}
    local seed,counter,events=s.seed,s.cardRandomRng.counter,#s.events
    local view=Orbs.view(s)
    assert(view.focus==2 and view.slots==3)
    assert(view.balls[1].passive==5 and view.balls[1].evoke==10)
    assert(view.balls[2].passive==4 and view.balls[2].evoke==7)
    assert(view.balls[3].passive==8 and view.balls[3].evoke==21)
    view.balls[3].evoke=99;assert(s.orbs.balls[3].stored==21)
    assert(s.seed==seed and s.cardRandomRng.counter==counter and #s.events==events)
end)
test("event frame preserves the orb order and dark storage at that event",function()
    local ui=start("defect","defend_blue");local s=ui.run.combat
    local frame=Events.frame(s);assert(frame.orbs.balls[1].kind=="lightning")
    s.orbs.balls[1].kind="dark";s.orbs.balls[1].stored=40
    assert(frame.orbs.balls[1].kind=="lightning" and frame.orbs.balls[1].stored==nil)
end)
test("actual Cold Snap updates the HUD and portrait opens ordered orb details",function()
    local ui,root=start("defect","cold_snap")
    F.click(root,"battlePanel","card1");F.click(root,"battlePanel","enemy1")
    assert(root:GetChild("battlePanel"):GetChild("title").text:find("球 2/3",1,true))
    F.click(root,"battlePanel","hero")
    local info=root:GetChild("battlePanel"):GetChild("statusInfo")
    assert(info.visible);assert(info:GetChild("name1").text:find("球位 2 / 3",1,true))
    assert(info:GetChild("name2").text:find("1 · 闪电",1,true))
    assert(info:GetChild("text2").text:find("伤害 3",1,true))
    assert(info:GetChild("name3").text:find("2 · 冰霜",1,true))
    assert(info:GetChild("text3").text:find("格挡 2",1,true))
end)
test("actual Eruption displays Wrath and portrait explains its current effects",function()
    local ui,root=start("watcher","eruption");local slot
    for i,card in ipairs(ui.run.combat.hand)do if card.cardId=="eruption"then slot=i;break end end
    F.click(root,"battlePanel","card"..slot);F.click(root,"battlePanel","enemy1")
    assert(root:GetChild("battlePanel"):GetChild("title").text:find("愤怒",1,true))
    F.click(root,"battlePanel","hero")
    local info=root:GetChild("battlePanel"):GetChild("statusInfo")
    assert(info.visible and info:GetChild("name1").text=="愤怒")
    assert(info:GetChild("text1").text:find("均翻倍",1,true))
end)
test("real mandatory discard updates the Silent HUD and portrait counter",function()
    local ui,root=start("silent","survivor")
    F.click(root,"battlePanel","card1");F.click(root,"battlePanel","playArea")
    assert(ui.run.combat.pendingDiscard and ui.choiceUI.visible)
    F.click(root,"choicePanel","card1");F.click(root,"choicePanel","confirm")
    assert(ui.run.combat.discardedThisTurn==1)
    assert(root:GetChild("battlePanel"):GetChild("title").text:find("弃 1",1,true))
    local before=Events.frame(ui.run.combat)
    F.click(root,"battlePanel","hero")
    local info=root:GetChild("battlePanel"):GetChild("statusInfo")
    assert(info.visible and info:GetChild("name1").text=="本回合弃牌 1")
    assert(before.discardedThisTurn==1)
end)
print("CLASS_RESOURCE_DISPLAY_PASS "..n)
