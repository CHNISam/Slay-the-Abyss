-- Run the actual native entry and real Host/Nodes/Run with capability-guarded
-- engine doubles. Only combat completion and prior Boss progress are staged;
-- no keys or historical wins are granted. This is not a natural playthrough.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,Run=require('abyss_map'),require('abyss_run')
local function fixture(experimental,bgm,characterProfile)
    local canvas=F.control({children=F.Layout})
    local host,signals
    local historyCalls=0
    signals={}
    local new=require('abyss_game_ui').new
    require('abyss_game_ui').new=function(...)
        local args={...}
        assert(args[5].characterProfile=='competition-candidate')
        if characterProfile then args[5].characterProfile=characterProfile end -- explicit development-only coverage below
        local function unavailableHistory()historyCalls=historyCalls+1;error('competition must not consult saved history')end
        args[5].readNeowHistory,args[5].readEndingHistory,args[5].writeEndingHistory=unavailableHistory,unavailableHistory,unavailableHistory
        host=new(table.unpack(args))
        host.historyCalls=function()return historyCalls end
        return host
    end
    script={object=canvas,EnableUpdate=function(self,value)self.updating=value end,
        GetParam=function(_,name)
            if name=='nativeBgmEnabled' then return bgm end
            assert(name=='experimentalCharacters','unexpected native parameter '..name)
            return experimental
        end}
    Enum={CursorEventType={CursorClick='click'},ImageSource={StaticReference='static'}}
    Color=setmetatable({FromRGB=function()end},{__call=function(_,r,g,b,a)return{r=r,g=g,b=b,a=a}end})
    game={GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end,
        ServerSignal=function(name)return{SendSignal=function()signals[#signals+1]=name end}end}
    Enum.Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}
    game.GetDevice=function()return 'desktop'end
    game.GetCursorUIPos=function()return 0,0 end
    dofile('tests/lua/support/native_monster_engine.lua')(game)
    local ok,why=pcall(function()dofile('src/lua/abyss_ui.lua');OnStart();OnStart()end)
    require('abyss_game_ui').new=new
    assert(ok,why);assert(host and script.updating,'formal startup failed')
    if not characterProfile then
        assert(host.characterSelection:allows('ironclad') and not host.characterSelection:allows('raiden'),
            'actual Alpha candidate exposes only this release\'s Geo traveler')
    end
    -- Seed2 exposes an implemented Sozu in the second Boss chest. Other source
    -- rolls still include unimplemented relics (TASK-14.1); no pool/probability change.
    host.seed='2'
    host.root=canvas:GetChild('stage')
    return host,host.root,signals
end
local function opening(host,root,bossCount)
    local run=host.run
    assert(run and run.campaignProfile=='competition-two-act' and host.map.floor==0)
    assert(not host.prologue and host.mode=='node' and not host.mapUI.navigationEnabled)
    local event=run.nodeFlow.event
    assert(event.id=='neow' and event.stage=='neow_intro' and event.neowBossCount==bossCount)
    assert(run.neowHistorySource==(bossCount==0 and 'fresh-start' or 'session-completed-run'))
    local baseMaxHp=run.maxHp
    assert(F.click(root,'nodePanel','eventView/option1'))
    event=run.nodeFlow.event
    assert(event.stage=='neow_blessing' and #event.rewards==(bossCount==0 and 2 or 4))
    -- Both source variants give category1 as the second offer. The fresh
    -- opening must choose its real +HP mini reward; a later session-qualified
    -- four-offer opening uses the real second offer, never fabricated history.
    if bossCount==0 then
        assert(event.rewards[2].type=='TEN_PERCENT_HP_BONUS' and event.rewards[2].drawback=='NONE')
    else assert(event.rewards[2].drawback=='NONE')end
    local rewardType,hpBonus=event.rewards[2].type,event.hpBonus
    assert(F.click(root,'nodePanel','eventView/option2'))
    event=run.nodeFlow.event
    if rewardType=='THREE_SMALL_POTIONS'then
        assert(event.stage=='neow_potions' and #event.potionOffers==3)
        assert(F.click(root,'nodePanel','eventView/option4')) -- source skip/continue, no bottle injection
        event=run.nodeFlow.event
    end
    assert(event.stage=='neow_result')
    if rewardType=='TEN_PERCENT_HP_BONUS'then assert(run.maxHp==baseMaxHp+hpBonus)end
    assert(F.click(root,'nodePanel','eventView/option1'))
    assert(host.run==run and host.mode=='map' and host.map.floor==0 and run.neowStatus=='complete')
    assert(host.mapUI.navigationEnabled and host.historyCalls()==0)
    return baseMaxHp
end
local function start(host,root,button,element)
    F.click(root,'menuPanel','start')
    assert(host.characterOpen and not host.run)
    F.click(root,'characterPanel',button)
    if element then F.click(root,'characterPanel','elements/element'..element)end
    assert(not host.run,'selection must not create a Run')
    F.click(root,'characterPanel','confirm')
    assert(not host.prologue and host.mode=='node','first confirmation opens the blessing, not the cancelled cinematic')
    local baseMaxHp=opening(host,root,0)
    -- The real entry has no history provider. Never synthesize qualification
    -- or mistake a seeded controlled route for a persisted natural victory.
    local history=host.run.endingHistory
    assert(history.known==false and history.unlocked==false and history.source=='competition-disabled')
    assert(history.readStatus=='disabled' and history.persistence=='disabled')
    assert(host.run.campaignProfile=='competition-two-act' and host.run.neowStatus=='complete')
    assert(not host.map.emeraldSelection and host.historyCalls()==0)
    assert(next(history.wins)==nil and host.run.endingUnlocked==false)
    for _,key in ipairs({'ruby','emerald','sapphire'})do assert(host.run.keys[key]==false)end
    return baseMaxHp
end
local function fight(host,root,floor)
    local nextNode=Map.available(host.map)[1]
    assert(nextNode.floor==floor and host.mapUI:choose(nextNode.id))
    assert(host.mode=='battle' and host.run.phase=='combat')
    -- Controlled final-damage boundary; encounter construction and rewards stay real.
    for _,enemy in ipairs(host.run.combat.enemies)do enemy.hp=0 end
    assert(Run.finishCombat(host.run));host:refresh()
    assert(host.run.phase=='reward' and host.run.rewards.cards)
    F.click(root,'battlePanel','continue')
    assert(host.mode=='map' and host.run.nodeFlow.complete)
end
local function bossComplete(host,bossFloor)
    local map,run=host.map,host.run
    -- Skip the intervening played rooms, retaining the actual generated map,
    -- legal path and chapter owners. Do not fabricate a chest or ending reward.
    while Map.available(map)[1].floor<bossFloor do
        assert(Map.choose(map,Map.available(map)[1].id))
    end
    run.floor,run.phase=map.floor,'map'
    run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='combat',complete=true,result='victory',
        mapSeed=map.seed,mapSignature=map.sourceSignature}
    host:refresh()
    fight(host,host.root,bossFloor)
end
local function chest(host,bossFloor,nextAct)
    local run,map=host.run,host.map
    bossComplete(host,bossFloor)
    assert(host.mapUI:choose(Map.available(map)[1].id))
    assert(host.nodeUI:press('treasureView/chest'))
    host.nodeUI:update(2)
    assert(host.nodeUI:press('back'))
    assert(run.phase=='act_transition',
        'FORMAL_CAMPAIGN_STOPPED floor='..run.floor..' phase='..run.phase..'; Boss chest must continue the campaign')
    assert(host.mode=='node' and run.act==nextAct-1)
    local uid,gold=run.deck[1].uid,run.gold
    assert(host.nodeUI:press('confirm'))
    assert(host.run==run and host.map==map and run.act==nextAct and host.mode=='map')
    assert(run.deck[1].uid==uid and run.gold==gold)
end

local host,root,signals=fixture(false,true)
assert(start(host,root,'traveler')==80)
assert(not host.run.characterProfile and host.run.maxHp==88,'fresh HP mini reward changes the actual maximum')
assert(#signals==2 and signals[1]=='ABYSS_BGM_STOP' and signals[2]=='ABYSS_BGM_MAP')
fight(host,root,1)
-- Injected historical flags must not resurrect a source key offer at OPEN.
host.run.endingUnlocked=true
while Map.available(host.map)[1].floor<9 do assert(Map.choose(host.map,Map.available(host.map)[1].id))end
host.run.floor,host.run.phase=host.map.floor,'map'
host.run.nodeFlow={id=host.map.currentNodeId,floor=host.map.floor,type='combat',complete=true,result='victory',
    mapSeed=host.map.seed,mapSignature=host.map.sourceSignature}
host:refresh();assert(host.mapUI:choose(Map.available(host.map)[1].id))
assert(host.nodeUI:press('treasureView/chest'));host.nodeUI:update(2)
assert(not host.run.nodeFlow.reward.sapphireKey)
for _,item in ipairs(host.run.nodeFlow.reward.items)do assert(item.kind~='sapphire' and not item.linkedSlot)end
local function noVisibleKeyPromise(control)
    if control.visible==false then return end
    assert(not (control.text and control.text:find('钥匙',1,true)),'competition chest advertised a key')
    for _,child in pairs(control.children)do noVisibleKeyPromise(child)end
end
noVisibleKeyPromise(root:GetChild('nodePanel'))
assert(host.nodeUI:press('back'))
chest(host,16,2)
fight(host,root,18)
bossComplete(host,33)
assert(host.mapUI:choose(Map.available(host.map)[1].id))
assert(host.run.floor==34 and host.run.phase=='node')
assert(host.nodeUI:press('treasureView/chest'));host.nodeUI:update(2)
local rewardKey
for index,item in ipairs(host.run.nodeFlow.reward.items)do
    if item.available then rewardKey='treasureView/rewardItem'..index;break end
end
assert(rewardKey,'seed must offer an implemented boss relic')
local stale=host.nodeUI.actions[rewardKey].handler
assert(host.nodeUI:press(rewardKey))
assert(host.run.floor==34 and host.map.floor==34 and host.run.phase=='victory' and host.mode=='victory')
assert(host.run.nodeFlow.result=='boss_treasure_complete' and host.run.ending=='two_act_complete')
assert(host.run.act==2 and host.map.act==2 and not host.run.pendingAct and not host.run.endingHistoryResult)
assert(not host:advanceAct() and not Run.advanceAct(host.run),'competition cannot reach Act3')
assert(not stale(),'stale chest choice cannot claim twice after completion')
assert(F.statValue(root,'floor')=='34 / 34')
assert(root:GetChild('menuPanel'):GetChild('title').text=='双幕挑战完成')
assert(F.resultText(root,'subtitle')=='第一幕与第二幕已完成。本局挑战到此结束。')
-- Restart means a new, ephemeral run; no _SPIRITS/_WIN or saved continuation.
local completed=host.run
F.click(root,'menuPanel','start');F.click(root,'characterPanel','traveler')
assert(host.run==completed,'selection preview cannot create a new run')
F.click(root,'characterPanel','confirm')
assert(host.run~=completed and host.run.act==1 and host.map.floor==0)
assert(not host.prologue,'a new run still does not play the cancelled cinematic')
opening(host,root,1)
assert(host.run.neowStatus=='complete' and not host.run.endingUnlocked)
assert(host.run.endingHistory.persistence=='disabled' and not host.run.endingHistoryResult and host.historyCalls()==0)
-- Defeat preserves an honest outcome and a /34 denominator.
assert(host.mapUI:choose(Map.available(host.map)[1].id))
host.run.combat.player.hp=0
assert(Run.finishCombat(host.run));host:refresh()
assert(host.mode=='defeat' and F.statValue(root,'floor')=='1 / 34')
assert(host:settle())
assert(signals[#signals-1]=='ABYSS_LOSE' and signals[#signals]=='ABYSS_BGM_STOP')
local submitted=#signals;assert(not host:settle() and #signals==submitted)
print('PASS formal two-act route, claim endpoint, new run, defeat and settlement')

-- The skip route enters the same endpoint, and settlement earns platform WIN
-- for this bounded challenge only, never a source full-campaign historical win.
local skipped,skipRoot,skipSignals=fixture(false,false)
start(skipped,skipRoot,'traveler');chest(skipped,16,2);bossComplete(skipped,33)
assert(skipped.mapUI:choose(Map.available(skipped.map)[1].id))
assert(skipped.nodeUI:press('back'))
assert(skipped.run.phase=='victory' and skipped.run.ending=='two_act_complete' and skipped.run.floor==34)
assert(F.statValue(skipRoot,'floor')=='34 / 34' and not skipped.run.pendingAct)
assert(skipped:settle() and skipSignals[#skipSignals]=='ABYSS_WIN')
assert(not skipped:settle() and not skipped:advanceAct() and skipped.historyCalls()==0)
print('PASS formal skip endpoint and one-shot victory settlement')

-- All eight forms, including Raiden, remain in full_source_campaign_entry.lua.
-- The public entry refuses every unavailable role and preserves in-memory menu/exit behavior.
local ui,panel,sent=fixture(false,false)
F.click(panel,'menuPanel','start')
for index=1,4 do
 local box=panel:GetChild('characterPanel'):GetChild('character'..index)
 assert(not box.visible and not box:GetChild('hit').canControllerFocus)
 assert(not box:GetChild('hit').click()and not ui.run)
end
assert(ui:selectCharacter('traveler')and ui:confirmCharacter())
opening(ui,panel,0)
assert(ui.run.campaignProfile=='competition-two-act'and not ui.run.characterProfile)
assert(ui.run.campaign and ui.run.act==1 and #sent==0)
local active=ui.run
F.click(panel,'exitEntry','open')
assert(ui.menuOpen and ui.exitOpen and ui.run==active)
F.click(panel,'runMenu','resume')
assert(not ui.exitOpen and ui.run==active,'resume means the same in-memory run, not persistence')
assert(ui:openExit())
assert(panel:GetChild('exitPanel'):GetChild('message').text:find('无法保存进度，退出后本局结束',1,true))
assert(ui:closeExit() and ui.run==active and ui.run.phase=='map')
assert(ui:openExit() and ui:confirmExit())
assert(ui.run==active and ui.run.phase=='map' and sent[#sent]=='ABYSS_LOSE')
assert(ui.historyCalls()==0 and not ui.run.endingHistoryResult)
print('PASS formal Traveler-only entry and in-memory menu/exit')
for index,id in ipairs({'ironclad'})do
    local ui,panel,sent=fixture(true,false)
    local baseMaxHp=start(ui,panel,'traveler',index)
    if id=='ironclad' then
        assert(not ui.run.characterProfile and baseMaxHp==80 and ui.run.maxHp==88,'Geo retains its default loadout plus the actual HP mini reward')
    else assert(ui.run.character==id and not ui.run.characterProfile.originalV4)end
    assert(ui.run.campaign and ui.run.act==1 and #sent==0)
end
print('PASS explicit development experimental character switch')
print('FORMAL_CAMPAIGN_ENTRY_PASS 4; controlled room completions; native/natural NOT_RUN')
