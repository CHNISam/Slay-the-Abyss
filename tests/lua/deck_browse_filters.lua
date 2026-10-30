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
    local host,root=F.fixture()
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
    assert(click(panel,'filterAttack'));host:update(0)
    assert(ids(host.deckUI.cards)=='12,14,15')
    assert(grid.itemCount==3 and panel:GetChild('filterAttack'):GetChild('selected').visible)
    assert(not click(panel,'filterAttack'),'same filter is a no-op')
    assert(click(panel,'sort'));host:update(0)
    assert(host.deckUI.sortMode=='name')
    assert(click(panel,'sort'));host:update(0)
    assert(host.deckUI.sortMode=='rarity')
    assert(click(panel,'sort'));host:update(0)
    assert(host.deckUI.sortMode=='cost')
    assert(ids(host.deckUI.cards)=='14,12,15','cost must use the actual printed definitions')
    assert(click(panel,'filterAll'));host:update(0)
    assert(ids(host.deckUI.cards)=='14,11,12,15,13')
    assert(same(before,host.run),'browse mutated the run or random state')
    assert(host:closeDeck())
    assert(host:openDeck());host:update(0)
    assert(ids(host.deckUI.cards)=='11,12,13,14,15','reopen restores acquisition order')
    assert(host.deckUI.typeFilter=='all' and host.deckUI.sortMode=='original')
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
    assert(click(panel,'filterSkill'));host.deckUI:update(0)
    assert(ids(host.deckUI.cards)=='102')
    assert(click(panel,'filterAll'));host.deckUI:update(0)
    assert(same(before,host.run))
    host.deckUI:close();assert(same(before,host.run))
end)

test('character preview type filter is detached from run creation and resets on role changes',function()
    local host,root=F.fixture()
    assert(host:start());assert(host:selectCharacter('traveler'))
    local panel,detail=root:GetChild('characterPanel'),root:GetChild('characterPanel'):GetChild('details')
    local info=host.characterSelection.info
    assert(info.deckSize>0 and #info.deck>0 and not host.run)
    local attack=0
    for _,card in ipairs(info.deck)do
        assert(type(card.type)=='string')
        if card.type=='attack' then attack=attack+card.count end
    end
    assert(click(detail,'deckFilterAttack'))
    assert(host.characterSelection.deckFilter=='attack')
    assert(detail:GetChild('deckTitle').text:find(tostring(attack)..'/'..info.deckSize,1,true))
    assert(detail:GetChild('deckFilterAttack'):GetChild('selected').visible)
    assert(click(detail,'deckFilterCurse'))
    assert(detail:GetChild('deckTitle').text:find('0/'..info.deckSize,1,true))
    assert(not host.run,'card browsing cannot start the run')
    assert(host:selectCharacter('traveler'))
    assert(host.characterSelection.deckFilter=='all')
    assert(detail:GetChild('deckFilterAll'):GetChild('selected').visible)
    assert(host:closeCharacters())
end)
print('DECK_BROWSE_FILTER_PASS '..passed)
