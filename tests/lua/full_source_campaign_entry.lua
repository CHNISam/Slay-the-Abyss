-- Full-source future/test scenario retained alongside the formal two-act fixture.
-- Run the actual native entry and real Host/Nodes/Run with capability-guarded
-- engine doubles. Only combat completion and prior Boss progress are staged;
-- no keys or historical wins are granted. This is not a natural playthrough.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,Run=require('abyss_map'),require('abyss_run')
local function fixture(experimental,bgm)
    local canvas=F.control({children=F.Layout})
    local host,signals
    signals={}
    local new=F.GameUI.new
    F.GameUI.new=function(...)
        local args={...}
        assert(args[5].campaignProfile=='competition-two-act')
        args[5].campaignProfile='full-source' -- explicit future/test host
        args[5].characterProfile='dev' -- future/test hosts retain all eight loadouts
        host=new(table.unpack(args))
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
    game={GetUICanvasSize=function()return 1280,720 end,
        ServerSignal=function(name)return{SendSignal=function()signals[#signals+1]=name end}end}
    local ok,why=pcall(function()dofile('src/lua/abyss_ui.lua');OnStart();OnStart()end)
    F.GameUI.new=new
    assert(ok,why);assert(host and script.updating,'formal startup failed')
    host.seed='42'
    return host,canvas:GetChild('stage'),signals
end
local function start(host,root,button,element)
    F.click(root,'menuPanel','start')
    assert(host.characterOpen and not host.run)
    F.click(root,'characterPanel',button)
    if element then F.click(root,'characterPanel','elements/element'..element)end
    assert(not host.run,'selection must not create a Run')
    F.click(root,'characterPanel','confirm')
    assert(host.prologue:covering() and not host.mapUI.navigationEnabled,
        'the future/test entry also uses the real approved first-start opening')
    assert(host.prologue:skip());OnUpdate(1);OnUpdate(1)
    assert(not host.prologue:covering() and host.mode=='map' and host.map.floor==0)
    assert(host.mapUI.navigationEnabled)
    -- Unlike the bounded competition's fresh-start mini, the explicit full-
    -- source host still needs a real provider/session record for Neow. This
    -- fixture supplies neither, so it must not invent or skip a blessing.
    assert(host.run.neowStatus=='unavailable' and host.run.neowUnavailableReason=='neow_history_unavailable')
    assert(host.run.neowHistorySource==nil and host.run.nodeFlow==nil)
    -- The real entry has no history provider. Never synthesize qualification
    -- or mistake a seeded controlled route for a persisted natural victory.
    local history=host.run.endingHistory
    assert(history.known==false and history.unlocked==false and history.source=='unknown')
    assert(history.readStatus=='unavailable' and history.persistence=='unavailable')
    assert(next(history.wins)==nil and host.run.endingUnlocked==false)
    for _,key in ipairs({'ruby','emerald','sapphire'})do assert(host.run.keys[key]==false)end
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
    while Map.available(map)[1].floor<=bossFloor do
        assert(Map.choose(map,Map.available(map)[1].id))
    end
    run.floor,run.phase=bossFloor,'map'
    run.nodeFlow={id=map.currentNodeId,floor=bossFloor,type='boss',complete=true,result='boss_victory',
        mapSeed=map.seed,mapSignature=map.sourceSignature}
    host:refresh()
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
start(host,root,'traveler')
assert(not host.run.characterProfile and host.run.maxHp==80)
assert(#signals==2 and signals[1]=='ABYSS_BGM_STOP' and signals[2]=='ABYSS_BGM_MAP')
fight(host,root,1)
chest(host,16,2)
fight(host,root,18)
chest(host,33,3)
fight(host,root,35)
assert(host.run.endingUnlocked==false and host.run.endingHistory.known==false)
for _,key in ipairs({'ruby','emerald','sapphire'})do assert(host.run.keys[key]==false)end
bossComplete(host,50)
assert(host.mapUI:choose(Map.available(host.map)[1].id))
assert(host.run.floor==51 and host.run.phase=='victory' and host.mode=='victory')
assert(host.run.nodeFlow.result=='normal_victory' and not host.run.pendingAct)
assert(host.run.act==3 and host.map.act==3 and not host.run.endingHistoryResult)
assert(not host:advanceAct(),'missing real history/keys must keep Act4 locked')
assert(host:settle())
assert(signals[#signals-1]=='ABYSS_WIN' and signals[#signals]=='ABYSS_BGM_STOP')
local submitted=#signals;assert(not host:settle() and #signals==submitted)
print('PASS formal campaign three-act route and unqualified ending')

local originals={'hutao','arlecchino','furina','raiden'}
for index,id in ipairs(originals)do
    local ui,panel,sent=fixture(false,false)
    start(ui,panel,'character'..index)
    assert(ui.run.character==id and ui.run.characterProfile.originalV4)
    assert(ui.run.campaign and ui.run.act==1 and #sent==0)
end
print('PASS formal original character switch')
for index,id in ipairs({'ironclad','silent','defect','watcher'})do
    local ui,panel,sent=fixture(true,false)
    start(ui,panel,'traveler',index)
    if id=='ironclad' then
        assert(not ui.run.characterProfile and ui.run.maxHp==80,'Geo retains the production default loadout')
    else assert(ui.run.character==id and not ui.run.characterProfile.originalV4)end
    assert(ui.run.campaign and ui.run.act==1 and #sent==0)
end
print('PASS formal experimental character switch')
print('FULL_SOURCE_CAMPAIGN_ENTRY_PASS 3; controlled room completions; native/natural NOT_RUN')
