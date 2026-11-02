if ABYSS_DECK_CONTROLLER_MUTANT then
    package.loaded.abyss_deck_ui=assert(load(ABYSS_DECK_CONTROLLER_MUTANT,'@deck_controller_mutant'))()
end
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Deck=require('abyss_deck_ui')
local Controller=require('abyss_controller')
local function preserveGraph(value)
    local saved={}
    local function remember(v)
        if type(v)~='table' or saved[v] then return end
        local copy={};saved[v]=copy
        for k,item in pairs(v)do copy[k]=item;remember(k);remember(item)end
    end
    remember(value)
    return function()
        for original,copy in pairs(saved)do
            for k,v in pairs(original)do assert(copy[k]==v,'run/RNG graph changed')end
            for k,v in pairs(copy)do assert(original[k]==v,'run/RNG graph entry removed')end
        end
    end
end
local function controller(using)
    local focus
    local api={events={Confirm='confirm',Cancel='cancel'},
        directions={Left='left',Right='right'},modes={Specified='specified'},
        using=using,getFocus=function()return focus end,
        setFocus=function(value)assert(value);focus=value end}
    api.isController=function()return api.using end
    return api
end
local function setup(amount,using,destroy)
    local spec
    local function find(entries)
        for _,entry in ipairs(entries)do
            if entry.name=='deckPanel' then spec=entry end
            find(entry.children or {})
        end
    end
    find(F.Layout)
    local panel=F.control(assert(spec))
    local api=controller(using)
    local manager=Controller.new(api,panel)
    local deck
    deck=Deck.new(panel,F.Presentation,'click',{controller=manager,controllerApi=api,
        imageSource='static',color=function(...)return {...}end},function()return deck:close()end)
    local grid=panel:GetChild('grid')
    grid.destroyOnRefresh=destroy
    local run={deck={},data=F.Data,relics={},rng={state=13579,counter=0}}
    for i=1,amount do run.deck[i]={uid=i,cardId=i%2==0 and 'defend' or 'bash',upgraded=false}end
    return deck,manager,grid,run,api
end
local function registry(manager,expected)
    assert(#manager.records==expected,'DECK_CONTROLLER_RETENTION: expected '..expected..' records, got '..#manager.records)
    local count=0
    for control,record in pairs(manager.byControl)do
        count=count+1
        assert(control==record.control and control.alive~=false,'dead or mismatched indexed control')
    end
    assert(count==expected,'byControl and records differ')
    for _,record in ipairs(manager.records)do assert(manager.byControl[record.control]==record)end
end
local function sync(deck,manager)
    manager:tick();manager:sync(deck.visible and 'deck' or 'map',function()return deck:back()end)
end
local function stale(deck,manager,api,hit)
    local generation=deck.generation
    manager:tick();api.setFocus(hit)
    assert(not hit.navigationListeners.confirm(),'retired confirm executed')
    assert(not hit.navigationListeners.cancel(),'retired cancel executed')
    assert(not hit.click(),'retired tap executed')
    assert(deck.generation==generation,'retired input changed current generation')
end
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end

test('20 pointer-mode open/close cycles release all destroyed registrations immediately',function()
    local deck,manager,grid,run,api=setup(12,false,true)
    local unchanged=preserveGraph(run)
    local baseline=#manager.records
    local persistent={};for _,record in ipairs(manager.records)do persistent[record.control]=record end
    for cycle=1,20 do
        assert(deck:open(run));deck:update(0)
        local hit=grid.items[0]:GetChild('hit')
        manager.memory.deck=hit
        manager.records[1].links={Right=hit}
        assert(deck:close())
        if cycle==1 or cycle==10 or cycle==20 then print('CLOSED_CYCLE '..cycle..' RECORDS '..#manager.records..' BASELINE '..baseline)end
        registry(manager,baseline) -- No subsequent update/open is needed to release.
        assert(manager.memory.deck==nil and manager.records[1].links.Right==nil)
        for control,record in pairs(persistent)do assert(manager.byControl[control]==record,'unrelated binding removed')end
        stale(deck,manager,api,hit)
        sync(deck,manager);unchanged()
    end
    local visits,eligible=0,manager.eligible
    manager.eligible=function(self,record)visits=visits+1;return eligible(self,record)end
    for _=1,300 do manager:sync('map')end
    assert(visits==baseline*300,'pointer sync retains retired scan work')
    print('POINTER_SYNC_300_VISITS '..visits)
end)

test('controller pages, filters, sorting, empty results and reentry keep only live handles',function()
    local deck,manager,grid,run,api=setup(30,true,true)
    local baseline=#manager.records
    local unchanged=preserveGraph(run)
    assert(deck:open(run));deck:update(0);sync(deck,manager)
    registry(manager,baseline+12)
    local old=grid.items[0]:GetChild('hit')
    assert(deck:controllerStep(1));sync(deck,manager)
    registry(manager,baseline+12);assert(not old.alive)
    stale(deck,manager,api,old)
    assert(deck:controllerStep(1));registry(manager,baseline+6)
    assert(deck:setFilter('attack'));registry(manager,baseline+1)
    deck:update(0);registry(manager,baseline+12)
    assert(deck:setSort('cost'));deck:update(0);registry(manager,baseline+12)
    assert(deck:setFilter('curse'));deck:update(0);registry(manager,baseline)
    assert(deck:setFilter('all'));deck:update(0);sync(deck,manager)
    local fresh=grid.items[0]:GetChild('hit')
    api.setFocus(fresh);assert(fresh.navigationListeners.confirm())
    assert(deck.cardDetail.instance.uid==deck.cards[1].uid and deck.detailPages)
    sync(deck,manager);assert(api.getFocus().navigationListeners.cancel())
    deck:update(0);sync(deck,manager);registry(manager,baseline+12)
    api.using=false;deck:update(0);registry(manager,baseline+12)
    api.using=true;deck:update(0);sync(deck,manager);registry(manager,baseline+12)
    assert(deck:close());registry(manager,baseline)
    assert(deck:open(run));deck:update(0);sync(deck,manager)
    stale(deck,manager,api,fresh)
    assert(deck:close());registry(manager,baseline);unchanged()
end)

test('native recycle, deferred fill and stale refresh cannot retain or resurrect dead records',function()
    local deck,manager,grid,run,api=setup(12,true,true)
    local baseline=#manager.records
    assert(deck:open(run));deck:update(0)
    local old=grid.items[0]:GetChild('hit')
    grid.destroyOnRecycle=true;grid:recycle(0,0);deck:update(0)
    registry(manager,baseline+12);stale(deck,manager,api,old)
    assert(deck:close());registry(manager,baseline)
    grid.deferRefresh=true
    assert(deck:open(run));registry(manager,baseline)
    grid:flush();registry(manager,baseline+1)
    local calibration=grid.items[0]
    local late=grid.refreshCallback
    deck:update(0);registry(manager,baseline)
    assert(not calibration.alive)
    late(calibration,0);registry(manager,baseline)
    grid:flush();registry(manager,baseline+12)
    local previous=grid.refreshCallback
    old=grid.items[0]
    assert(deck:close());registry(manager,baseline)
    previous(old,0);registry(manager,baseline)
    assert(deck:open(run));grid:flush();deck:update(0);grid:flush()
    registry(manager,baseline+12)
    assert(deck:close());registry(manager,baseline)
end)

test('live native reuse preserves listeners and current card activation across close/reopen',function()
    local deck,manager,grid,run,api=setup(12,true,false)
    local baseline=#manager.records
    assert(deck:open(run));deck:update(0);sync(deck,manager)
    local item=grid.items[0]
    local hit=item:GetChild('hit')
    local record,confirm,click=manager.byControl[hit],hit.navigationListeners.confirm,hit.click
    for _=1,10 do
        assert(deck:close());registry(manager,baseline+12)
        assert(item.alive);stale(deck,manager,api,hit)
        assert(deck:open(run));deck:update(0);sync(deck,manager)
        assert(grid.items[0]==item and manager.byControl[hit]==record)
        assert(hit.navigationListeners.confirm==confirm and hit.click==click)
        grid:recycle(0,1);sync(deck,manager);api.setFocus(hit)
        assert(confirm());assert(deck.cardDetail.instance.uid==2,'reused listener must use current instance')
        assert(deck:back());deck:update(0);sync(deck,manager)
        registry(manager,baseline+12)
    end
    assert(deck:close());grid.destroyOnRefresh=true
    grid:RefreshItems(0,function()error('empty grid filled')end)
    deck:update(0);registry(manager,baseline)
end)

test('external native destruction while hidden or showing details is collected on update',function()
    local deck,manager,grid,run=setup(12,false,false)
    local baseline=#manager.records
    assert(deck:open(run));deck:update(0)
    assert(deck:showText('说明','只读详情'))
    grid.destroyOnRefresh=true
    grid:RefreshItems(0,function()error('empty grid filled')end)
    deck:update(0);registry(manager,baseline)
    assert(deck:back());deck:update(0);registry(manager,baseline+12)
    grid.destroyOnRefresh=false
    assert(deck:close());registry(manager,baseline+12)
    grid.destroyOnRefresh=true
    grid:RefreshItems(0,function()error('empty grid filled')end)
    deck:update(0);registry(manager,baseline)
end)

test('destroyed choice callbacks cannot select or cancel a reopened choice',function()
    local deck,manager,grid,run,api=setup(12,true,true)
    local baseline=#manager.records
    grid.indexBase=1
    run.combat=F.Combat.new(F.Data,{deck={'bash','defend'},enemies={'cultist'}})
    local card=run.combat.hand[1]
    local choice={token='first-choice',op='upgradeHand',cards={card}}
    run.combat.pendingChoice=choice
    local picked={}
    local function pick(token,uid)picked[#picked+1]={token,uid};return true end
    assert(deck:open(run,choice,pick));deck:update(0);sync(deck,manager)
    local old=grid.items[0]:GetChild('hit')
    assert(deck:close());registry(manager,baseline)
    choice={token='second-choice',op='upgradeHand',cards={card}}
    run.combat.pendingChoice=choice
    local unchanged=preserveGraph(run)
    assert(deck:open(run,choice,pick));deck:update(0);sync(deck,manager)
    stale(deck,manager,api,old);assert(#picked==0 and deck.visible)
    local fresh=grid.items[0]:GetChild('hit')
    manager:tick();api.setFocus(fresh)
    assert(not fresh.navigationListeners.cancel(),'forced choice cannot be cancelled')
    assert(deck.visible and #picked==0)
    manager:tick();assert(fresh.navigationListeners.confirm()==nil)
    assert(#picked==1 and picked[1][1]=='second-choice' and picked[1][2]==card.uid)
    assert(not deck.visible);registry(manager,baseline);unchanged()
    stale(deck,manager,api,fresh);assert(#picked==1)
end)

test('real Host with controller manager releases deck handles without touching run/RNG',function()
    local api=controller(true)
    local host,root=F.fixture(nil,nil,nil,nil,nil,nil,nil,api)
    assert(F.start(host))
    local manager=assert(host.controller)
    local baseline=#manager.records
    local grid=root:GetChild('deckPanel'):GetChild('grid')
    grid.destroyOnRefresh=true;grid.destroyOnRecycle=true
    local unchanged=preserveGraph(host.run)
    for _=1,3 do
        assert(host:openDeck());host:update(0)
        grid:recycle(0,0);host:update(0)
        assert(host:closeDeck());registry(manager,baseline);unchanged()
    end
    host:disable()
end)
print('DECK_CONTROLLER_LIFECYCLE_PASS '..passed)
