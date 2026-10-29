if ABYSS_DECK_LIFECYCLE_MUTANT then
 package.loaded.abyss_deck_ui=assert(load(ABYSS_DECK_LIFECYCLE_MUTANT,'@deck_lifecycle_mutant'))()
end
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function setup()
 local host,root=F.fixture();assert(F.start(host))
 local grid=root:GetChild('deckPanel'):GetChild('grid')
 grid.destroyOnRefresh=true
 return host,root,grid
end
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
test('first open survives calibration item destruction on the next updates',function()
 local host,_,grid=setup();assert(host:openDeck())
 local first=grid.items[0];host:update(0.01)
 assert(first.alive==false,'fixture must actually destroy calibration item')
 host:update(0.01);host:update(0.01)
end)
test('scroll recycling and close never inspect retired grid items',function()
 local host,_,grid=setup();assert(host:openDeck());host:update(0.01)
 grid:RefreshItems(grid.itemCount,grid.refreshCallback);host:update(0.01)
 assert(host:closeDeck());assert(host:openDeck());host:update(0.01);host:update(0.01)
end)
test('relic text view survives the grid items retired by its entry path',function()
 local host=setup();assert(host:openRelics());host:update(0.01);host:update(0.01)
 assert(host:closeDeck());assert(host:openRelics());host:update(0.01)
end)
test('delayed item click cannot act after item destruction',function()
 local host,_,grid=setup();assert(host:openDeck())
 local oldClick=grid.items[0]:GetChild('hit').click
 host:update(0.01);host:update(0.01)
 local generation=host.deckUI.generation
 assert(not oldClick());assert(host.deckUI.generation==generation)
end)
print('DECK_ITEM_LIFECYCLE_PASS '..passed)
