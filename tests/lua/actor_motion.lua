package.path = 'src/lua/?.lua;' .. package.path
local Motion = require('abyss_actor_motion')
local config = {period=3.6, scale=0.012, lift=1.2, sway=0.8, maxDelta=0.1}
local tests = 0
local function test(name, fn)
    fn(); tests=tests+1; print('ok actor_motion '..tests..' - '..name)
end
local function near(a,b) return math.abs(a-b)<1e-9 end
local actor={hp=40,definitionId='jaw_worm',statuses={},events={},rng=1234}
test('idle clock is independent, finite, bounded after a background stall',function()
    assert(near(Motion.advance(0,0.05,config),0.05))
    assert(near(Motion.advance(0,60,config),0.1))
    assert(near(Motion.advance(config.period-0.01,0.02,config),0.01))
    for _,dt in ipairs({-1,math.huge,0/0})do assert(not pcall(Motion.advance,0,dt,config))end
end)
test('death and escape cannot be overwritten by hit or attack or idle',function()
    local damage={kind='damage',detail={amount=3}}
    assert(Motion.state(actor,{},damage,{},true)=='death')
    assert(Motion.state(actor,{},damage,nil,true)=='escape')
    assert(Motion.state(actor,{},damage,nil,nil)=='hit')
    assert(Motion.state(actor,{},nil,nil,nil)=='action')
    assert(Motion.state(actor,nil,nil,nil,nil)=='idle')
    assert(Motion.state({hp=0},nil,nil,nil,nil)=='death')
    assert(Motion.state({hp=10,halfDead=true},nil,nil,nil,nil)=='death')
    assert(Motion.state(nil,nil,nil,nil,nil)=='inactive')
end)
test('traveler, cultist and jaw worm have different bounded living motion',function()
    local seen={}
    for _,id in ipairs({'player','cultist','jaw_worm','book_of_stabbing'})do
        local unit={hp=20,definitionId=id}
        local moved=false
        for i=0,360 do
            local x,y,sx,sy=Motion.idle(unit,id,i/100,'idle',config)
            assert(math.abs(x)<=config.sway+1e-9 and math.abs(y)<=config.lift+1e-9)
            assert(math.abs(sx-1)<=config.scale+1e-9 and math.abs(sy-1)<=config.scale+1e-9)
            moved=moved or not near(x,0)or not near(y,0)or not near(sy,1)
            if i==100 then seen[id]=table.concat({x,y,sx,sy},',')end
        end
        assert(moved,id..' should breathe')
    end
    assert(seen.player~=seen.cultist and seen.cultist~=seen.jaw_worm)
end)
test('active poses, hits, death and escape return neutral transforms',function()
    for _,state in ipairs({'action','hit','death','escape','inactive'})do
        local x,y,sx,sy=Motion.idle(actor,'jaw_worm',0.25,state,config)
        assert(x==0 and y==0 and sx==1 and sy==1)
    end
end)
test('stable identity phase ignores slot and calls no RNG or rule mutation',function()
    local random=math.random
    math.random=function()error('presentation consumed RNG')end
    local x,y,sx,sy=Motion.idle(actor,'enemy-42',0.4,'idle',config)
    for _=1,100 do
        local a,b,c,d=Motion.idle(actor,'enemy-42',0.4,'idle',config)
        assert(a==x and b==y and c==sx and d==sy)
    end
    math.random=random
    assert(actor.hp==40 and actor.rng==1234 and next(actor.statuses)==nil and next(actor.events)==nil)
    local a,b=Motion.idle(actor,'enemy-43',0.4,'idle',config)
    assert(a~=x or b~=y,'distinct actor IDs must avoid synchronized breathing')
end)
test('large repeated updates remain bounded without accumulating objects',function()
    local clock=0
    for _=1,20000 do clock=Motion.advance(clock,1/60,config)end
    assert(clock>=0 and clock<config.period)
    local x,y,sx,sy=Motion.idle(actor,'enemy-42',clock,'idle',config)
    assert(x==x and y==y and sx==sx and sy==sy)
end)
print('LUA_ACTOR_MOTION_PASS '..tests)
