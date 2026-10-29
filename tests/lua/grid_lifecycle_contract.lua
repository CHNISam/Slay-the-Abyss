local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function rejects(fn,why)
    local ok,err=pcall(fn)
    assert(not ok and tostring(err):find(why,1,true),tostring(err))
end
local function setup()
    local host,root=F.fixture()
    assert(F.start(host))
    local grid=root:GetChild('deckPanel'):GetChild('grid')
    grid.destroyOnRefresh=true
    return host,root,grid
end
do
    local _,_,grid=setup()
    local first
    grid:RefreshItems(1,function(item)first=item end)
    local face=first:GetChild('face')
    assert(first.alive and face.alive)
    rejects(function()first.alive=false end,'read-only')
    grid:RefreshItems(1,function(item)assert(item~=first and item.alive)end)
    assert(not first.alive and not face.alive)
    rejects(function()first:GetChild('face')end,'invalid object')
    rejects(function()face:GetChild('cost')end,'invalid object')
    local current=grid.items[0]
    grid.destroyOnRecycle=true
    grid:recycle(0,1)
    assert(not current.alive and grid.items[0].alive)
    current=grid.items[0]
    grid:RefreshItems(0,function()error('empty refresh must not fill')end)
    assert(not current.alive and next(grid.items)==nil)
end
do
    local host,_,grid=setup()
    assert(host:openDeck())
    local old=grid.items[0]
    host:update(0.01) -- calibration refresh destroys first control
    assert(not old.alive)
    host:update(0.01) -- stale animated-card handles must not be dereferenced
    grid.destroyOnRecycle=true
    grid:recycle(0,0)
    host:update(0.01)
    assert(host:closeDeck())
    assert(host:openDeck())
    host:update(0.01);host:update(0.01)
    assert(host:closeDeck())
end
do
    local host=setup()
    assert(host:openRelics())
    host:update(0.01);host:update(0.01)
    assert(host:closeDeck())
end
print('GRID_LIFECYCLE_CONTRACT_PASS 3')
