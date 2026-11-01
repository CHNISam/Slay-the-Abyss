-- M4: view-only category filters and sorting must never touch game state.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Combat=F.Combat
local passed=0
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function test(name,fn)fn();passed=passed+1;print('ok deck browse '..passed..' - '..name)end
local function ids(cards)
    local t={}
    for _,card in ipairs(cards)do t[#t+1]=card.uid end
    return table.concat(t,',')
end
local function click(panel,name)
    return panel:GetChild(name):GetChild('hit').click()
end

test('permanent card views filter and sort copies, retaining stable UIDs and run state',function()
    local controller=false
    local host,root=F.fixture(nil,nil,nil,nil,nil,nil,nil,{isController=function()return controller end})
    assert(F.start(host))
    host.run.deck={{uid=11,cardId='defend',upgraded=false},
        {uid=12,cardId='bash',upgraded=false},{uid=13,cardId='barricade',upgraded=false},
        {uid=14,cardId='anger',upgraded=false},{uid=15,cardId='bash',upgraded=true}}
    local before=Combat.copy(host.run)
    assert(host:openDeck());host:update(0)
    local panel=root:GetChild('deckPanel')
    local grid=panel:GetChild('grid')
    assert(grid.itemCount==5)
    assert(panel:GetChild('browseTitle').visible)
    assert(panel:GetChild('sort'):GetChild('hit'):GetChild('normal'):GetChild('label').text=='初始')
    assert(not panel:GetChild('pageHint').visible,'browse rule footer must not obscure battle')
    assert(click(panel,'filterAttack'));host:update(0)
    assert(ids(host.deckUI.cards)=='12,14,15')
    assert(grid.itemCount==3 and panel:GetChild('filterAttack'):GetChild('selected').visible)
    assert(not click(panel,'filterAttack'),'same filter is a no-op')
    assert(click(panel,'sort'));host:update(0)
    assert(host.deckUI.sortMode=='name')
    assert(panel:GetChild('sort'):GetChild('hit'):GetChild('normal'):GetChild('label').text=='名称')
    assert(click(panel,'sort'));host:update(0)
    assert(host.deckUI.sortMode=='rarity')
    assert(panel:GetChild('sort'):GetChild('hit'):GetChild('normal'):GetChild('label').text=='稀有度')
    assert(click(panel,'sort'));host:update(0)
    assert(host.deckUI.sortMode=='cost')
    assert(panel:GetChild('sort'):GetChild('hit'):GetChild('normal'):GetChild('label').text=='费用')
    assert(not panel:GetChild('pageHint').visible)
    assert(ids(host.deckUI.cards)=='14,12,15','cost must use the actual printed definitions')
    assert(click(panel,'filterAll'));host:update(0)
    assert(ids(host.deckUI.cards)=='14,11,12,15,13')
    assert(click(panel,'sort'));host:update(0)
    assert(ids(host.deckUI.cards)=='12,14,15,11,13','type order preserves initial order within each type')
    assert(panel:GetChild('sort'):GetChild('hit'):GetChild('normal'):GetChild('label').text=='类型')
    assert(not panel:GetChild('pageHint').visible)
    assert(same(before,host.run),'browse mutated the run or random state')
    assert(host:closeDeck())
    assert(host:openDeck());host:update(0)
    assert(ids(host.deckUI.cards)=='11,12,13,14,15','reopen restores acquisition order')
    assert(host.deckUI.typeFilter=='all' and host.deckUI.sortMode=='original')
    controller=true;host:update(0)
    assert(panel:GetChild('pageHint').text=='摇杆导航 · 确认选择 · 返回关闭 · 1/1')
    assert(not panel:GetChild('pageHint').visible,'single controller page keeps the original hidden hint')
    assert(host:closeDeck());assert(same(before,host.run))
end)

test('empty categories, stale callbacks and text detail pages cannot leak interactions',function()
    local host,root=F.fixture();assert(F.start(host))
    assert(host:openDeck());host:update(0)
    local panel,grid=root:GetChild('deckPanel'),root:GetChild('deckPanel'):GetChild('grid')
    local old=grid.refreshCallback
    assert(click(panel,'filterCurse'));host:update(0)
    assert(grid.itemCount==0)
    assert(panel:GetChild('browseTitle').text:find('0/',1,true))
    assert(click(panel,'filterAll'));host:update(0)
    local first,uid=grid.items[0],host.deckUI.cards[1].uid
    old(first,0)
    assert(host.deckUI.cards[1].uid==uid,'stale callback changed projected cards')
    assert(host.deckUI:showText('说明','只读页面'))
    assert(not panel:GetChild('filterAttack').visible)
    assert(not host.deckUI:setFilter('attack'),'detail page rejects browse changes')
    assert(host.deckUI:back() and panel:GetChild('filterAttack').visible)
    host:update(0)
    assert(not panel:GetChild('pageHint').visible,'browse rule footer must not obscure battle')
    assert(host:closeDeck())
end)

test('combat pile filters preserve the existing hidden-order semantics and never re-order the actual pile',function()
    local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
    local host,_,_,_,_,_,_,root=H.setup()
    host.run.combat.draw={{uid=101,cardId='bash',upgraded=false},
        {uid=102,cardId='defend',upgraded=false},{uid=103,cardId='burn',upgraded=false}}
    local before=Combat.copy(host.run)
    assert(host.deckUI:openPile(host.run,'draw'));host.deckUI:update(0)
    local panel=root:GetChild('deckPanel')
    assert(not panel:GetChild('pageHint').visible)
    assert(click(panel,'filterSkill'));host.deckUI:update(0)
    assert(ids(host.deckUI.cards)=='102')
    assert(click(panel,'filterAll'));host.deckUI:update(0)
    assert(same(before,host.run))
    host.deckUI:close();assert(same(before,host.run))
end)

test('character preview lists the starter deck by type without filters and never starts a run',function()
    local host,root=F.fixture()
    assert(host:start());assert(host:selectCharacter('traveler'))
    local detail=root:GetChild('characterPanel'):GetChild('details')
    local info=host.characterSelection.info
    assert(info.deckSize>0 and #info.deck>0 and not host.run)
    -- TASK-59.3.1：选角页不再堆筛选按钮，牌组一次性按类型排好。
    for _,name in ipairs({'All','Attack','Skill','Power','Status','Curse'})do assert(detail:GetChild('deckFilter'..name)==nil)end
    assert(host.characterSelection.setDeckFilter==nil and host.filterCharacterDeck==nil)
    assert(detail:GetChild('deckTitle').text=='初始牌组 · '..info.deckSize..' 张')
    local rank={attack=1,skill=2,power=3,status=4,curse=5}
    local byName={}
    for _,card in ipairs(info.deck)do
        byName[card.name]=card
        assert(detail:GetChild('deckSummary').text:find(card.name..'×'..card.count,1,true),
            'starter summary omitted '..card.name)
    end
    assert(detail:GetChild('deckOpen'):GetChild('hit').click())
    local view=root:GetChild('characterPanel'):GetChild('deckView')
    assert(view.visible and host.characterSelection.deckOpen and not host.run)
    local last,listed=0,0
    local counts={}
    local i=1
    while view:GetChild('deckCard'..i)do
        local slot=view:GetChild('deckCard'..i)
        if slot.visible then
            local face=slot:GetChild('face')
            local text=face:GetChild('name').text
            local card=assert(byName[text],'unexpected starter card '..text)
            assert((rank[card.type] or 9)>=last,'deck rows are not grouped by type');last=rank[card.type] or 9
            assert(face:GetChild('cost').text~='' and face:GetChild('label').text~='',
                'starter card must show its cost and rules')
            counts[text]=(counts[text] or 0)+1;listed=listed+1
        end
        i=i+1
    end
    assert(listed==info.deckSize and view:GetChild('overflow').text=='','every starter card is visible')
    for name,card in pairs(byName)do assert(counts[name]==card.count,'wrong starter count for '..name)end
    assert(view:GetChild('close'):GetChild('hit').click())
    assert(not view.visible and not host.characterSelection.deckOpen and host.characterOpen)
    assert(detail:GetChild('stats').text:find(tostring(info.maxHp),1,true))
    assert(detail:GetChild('gold').text:find(tostring(info.gold),1,true))
    assert(detail:GetChild('relic').text==info.relics[1].name and detail:GetChild('relicText').text~='')
    assert(not host.run,'previewing cannot start the run')
    assert(host:closeCharacters())
end)
print('DECK_BROWSE_FILTER_PASS '..passed)
