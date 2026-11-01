if ABYSS_DECK_LIFECYCLE_MUTANT then
 package.loaded.abyss_deck_ui=assert(load(ABYSS_DECK_LIFECYCLE_MUTANT,'@deck_lifetime_mutant'))()
end
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function setup()
 local host,root=F.fixture();assert(F.start(host))
 local grid=root:GetChild('deckPanel'):GetChild('grid');grid.destroyOnRefresh=true
 return host,root,grid
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS local deck lifetime '..name)end
test('destroyed calibration item survives consecutive updates',function()
 local host,_,grid=setup();assert(host:openDeck());local first=grid.items[0]
 host:update(.01);assert(not first.alive,'calibration fixture must retire actual item')
 host:update(.01);host:update(.01)
end)
test('scroll destruction and close/reopen never dereference retired controls',function()
 local host,_,grid=setup();assert(host:openDeck());host:update(.01)
 grid.destroyOnRecycle=true;grid:recycle(0,0);host:update(.01)
 assert(host:closeDeck());assert(host:openDeck());host:update(.01);host:update(.01);assert(host:closeDeck())
end)
test('delayed callbacks from destroyed controls cannot mutate deck view',function()
 local host,_,grid=setup();assert(host:openDeck())
 local old=grid.items[0];local click=old:GetChild('hit').click
 host:update(.01);host:update(.01);local generation=host.deckUI.generation
 assert(not old.alive);assert(not click());assert(host.deckUI.generation==generation)
end)
print('PR323_DECK_LIFECYCLE_PASS '..count)
