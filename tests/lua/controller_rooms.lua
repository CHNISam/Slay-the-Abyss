local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map=require('abyss_run'),require('abyss_map')
local Random,Pool=require('abyss_sts_random'),require('abyss_relic_pool')
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for key,value in pairs(a)do if not same(value,b[key])then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end
local focus
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
    modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(c)focus=c end,
    isController=function()return true end}
local function setup(kind)
    focus=nil
    local source=F.Combat.copy(F.Data)
    if kind=='event'then source.rules.events.encounterId='cleric'end
    local ui,root=F.fixture(source,nil,nil,nil,false,nil,nil,api)
    assert(ui:start())
    local run,map=Run.new(source,42),Map.generate(source,42)
    while true do
        local choices=Map.available(map);assert(#choices>0,'room not found')
        local found
        for _,node in ipairs(choices)do if node.type==kind then found=node;break end end
        if found then assert(F.Nodes.enter(run,map,found.id));break end
        assert(Map.choose(map,choices[1].id))
    end
    run.gold,run.hp=999,30
    ui.run,ui.map=run,map;ui.battleUI.run=run;ui.mapUI.map=map;ui.nodeUI.run,ui.nodeUI.map=run,map
    ui:refresh()
    local function hit(path,panel)
        local c=root:GetChild(panel or 'nodePanel')
        for name in path:gmatch('[^/]+')do c=assert(c:GetChild(name),path)end
        return c:GetChild('hit') or c
    end
    local function press(path,panel,event)
        ui:update(.01);ui:syncController()
        local c=hit(path,panel);assert(c.canControllerFocus,'unavailable '..path)
        focus=c;return c.navigationListeners[event or 'confirm']()
    end
    return ui,root,press,hit
end
local ui,root,press,hit=setup('camp')
assert(ui.mode=='node')
press('campView/forge');assert(ui.nodeUI.mode=='picker')
press('pickerView/forgeGrid/card1');press('back');press('back');assert(ui.nodeUI.mode=='main')
press('campView/rest');assert(ui.run.hp>30)
ui:update(require('abyss_theme').layout.nativeNode.roomMotion.restDuration+.01)
press('confirm');assert(ui.mode=='map');ui:disable()
print('controller rooms: camp, upgrade picker cancel and continue passed')
ui,root,press,hit=setup('shop')
local before=#ui.run.deck
press('shopView/card1');assert(#ui.run.deck==before+1 and ui.run.gold<999)
assert(not hit('shopView/card1').canControllerFocus,'sold item cannot keep gamepad focus')
press('shopView/removal');press('pickerView/card1');press('confirm')
assert(#ui.run.deck==before,'remove must commit through the existing room command')
press('confirm');press('confirm');assert(ui.mode=='map');ui:disable()
print('controller rooms: shop buy, sold item, remove and leave passed')
ui,root,press,hit=setup('treasure')
assert(press('treasureView/chest'))
ui:update(2)
local treasureRandom,relicPool=Random.snapshot(ui.run.treasureRng),Pool.snapshot(ui.run.relicPool)
local sourceOffers={}
for _,item in ipairs(ui.run.nodeFlow.reward.items)do sourceOffers[item.slot]=F.Combat.copy(item)end
while ui.run.phase=='node' do
    local items=ui.run.nodeFlow.reward.items
    assert(#items>0,'completed reward list must return to the map')
    local choice
    for index,item in ipairs(items)do
        assert(same(item,sourceOffers[item.slot]),'controller readback replaced a prepared source identity')
        if not choice and (item.kind~='relic' or item.available==true)then choice=index end
    end
    if not choice then
        for _,item in ipairs(items)do assert(item.kind=='relic' and item.available==false)end
        local gold,relics=ui.run.gold,F.Combat.copy(ui.run.relics)
        assert(press('back'),'controller must explicitly leave unsupported source identities')
        assert(ui.run.gold==gold and same(ui.run.relics,relics),'leaving granted a substitute reward')
        break
    end
    local pending=#items
    assert(press('treasureView/rewardItem'..choice))
    assert(#ui.run.nodeFlow.reward.items<pending,'each controller claim must consume a displayed source item')
    assert(same(Random.snapshot(ui.run.treasureRng),treasureRandom),'claim consumed another treasure roll')
    assert(same(Pool.snapshot(ui.run.relicPool),relicPool),'claim consumed the shared relic queue again')
end
assert(same(Random.snapshot(ui.run.treasureRng),treasureRandom))
assert(same(Pool.snapshot(ui.run.relicPool),relicPool))
assert(ui.mode=='map');ui:disable()
print('controller rooms: treasure claim returns to the map passed')
ui,root,press,hit=setup('event')
local slot
for i=1,3 do
    local box=root:GetChild('nodePanel'):GetChild('eventView'):GetChild('option'..i)
    if box.visible and box:GetChild('title').text=='［离开］'then slot=i end
end
assert(slot);press('eventView/option'..slot);press('confirm');assert(ui.mode=='map')
-- More than two rows must remain reachable without a mouse wheel or dragging.
for i=1,20 do local card=F.Combat.copy(ui.run.deck[1]);card.uid=100+i;ui.run.deck[#ui.run.deck+1]=card end
assert(Run.obtainPotion(ui.run,'fire_potion'))
press('open','potionEntry');press('slot1','potionPanel')
press('slot1','potionPanel','cancel');assert(not ui.potionUI.visible and #ui.run.potions==1)
press('open','deckEntry');ui:update(.01)
local grid=root:GetChild('deckPanel'):GetChild('grid')
assert(grid.itemCount==12 and ui.deckUI.controllerPage==1)
local uid=grid.items[0]:GetChild('uid').text
press('next','deckPanel');assert(ui.deckUI.controllerPage==2 and grid.items[0]:GetChild('uid').text~=uid)
press('next','deckPanel');assert(ui.deckUI.controllerPage==3 and grid.itemCount==6)
assert(not grid.items[11]:GetChild('hit').canControllerFocus,'unused recycled items cannot retain focus on a short page')
press('previous','deckPanel')
press('previous','deckPanel');assert(ui.deckUI.controllerPage==1 and grid.items[0]:GetChild('uid').text==uid)
grid.deferRefresh=true
press('next','deckPanel');local oldPage=grid.refreshCallback
press('previous','deckPanel')
oldPage(grid.items[0],0)
assert(grid.items[0]:GetChild('uid').text==uid,'an old page callback must not rebind the current grid')
grid:flush();grid.deferRefresh=false
press('close','deckPanel');assert(not ui.deckUI.visible)
ui:disable()
print('controller rooms: event, potion cancel and paged permanent deck passed')
