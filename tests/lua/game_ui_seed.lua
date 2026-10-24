local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Map = require("abyss_map")
local count = 0
local function test(name, fn) fn(); count=count+1; print("ok fresh run "..count.." - "..name) end
local function host(seed, newSeed)
    local canvas=F.control({children=F.Layout})
    local root=F.Viewport.apply(canvas,1280,720)
    local ui=F.GameUI.new(root,F.Data,F.Presentation,"click",{
        seed=seed,newSeed=newSeed,prologue=false,imageSource="static",
        color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
    root.ui=ui
    return ui,root
end

test("real Host samples normal new-run source on accepted starts only",function()
    local calls=0
    local ui=host(nil,function()calls=calls+1;return 42100+calls end)
    assert(calls==0,"menu preview consumed a new-run seed")
    assert(ui:start())
    assert(calls==1 and ui.run.seed==42101 and ui.map.runSeed=='42101' and ui.run.runSeed=='42101',
        "normal Host ignored its new-run source (historically fixed seed=1)")
    assert(ui.run.eventSeed=="42101")
    local original=ui.run
    assert(not ui:start() and calls==1 and ui.run==original)
    ui.run.phase="defeat";ui:refresh()
    assert(ui:start() and calls==2 and ui.run.seed==42102 and ui.map.runSeed=='42102')
    ui.mode="victory"
    assert(ui:start() and calls==3 and ui.run.seed==42103)
end)

test("fresh Hosts use their source and explicit ui.seed replays the real map",function()
    local a=host(nil,function()return 32410 end)
    local b=host(nil,function()return 54692 end)
    assert(a:start() and b:start())
    assert(a.run.seed==32410 and b.run.seed==54692)
    local replay=host(nil,function()error("explicit seed must bypass entropy")end)
    replay.seed=32410 -- The M2/native test driver already uses this interface.
    assert(replay:start())
    assert(replay.run.eventSeed==a.run.eventSeed)
    local map=Map.generate(F.Data,32410)
    for i,node in ipairs(a.map.nodes)do
        assert(node.type==replay.map.nodes[i].type and node.encounterId==replay.map.nodes[i].encounterId)
        assert(node.type==map.nodes[i].type and node.encounterId==map.nodes[i].encounterId)
    end
    assert(F.Nodes.enter(a.run,a.map,a.map.nodes[1].id))
    assert(F.Nodes.enter(replay.run,replay.map,replay.map.nodes[1].id))
    assert(a.run.encounterId==replay.run.encounterId)
    for i,enemy in ipairs(a.run.combat.enemies)do
        assert(enemy.hp==replay.run.combat.enemies[i].hp)
    end
end)

test("explicit seed zero and rollover keep the established deterministic restart path",function()
    local ui=host(65535,function()error("explicit seed requested entropy")end)
    assert(ui:start() and ui.run.seed==65535 and ui.map.runSeed=='65535')
    ui.run.phase="defeat";ui:refresh()
    assert(ui:start() and ui.run.seed==0 and ui.map.runSeed=='0')
end)

test("raw signed64 Host identity survives mutable combat seed and string restart increment",function()
    local ui=host('2780424839485660359',function()error('explicit raw seed requested entropy')end)
    assert(ui:start())
    assert(ui.runSeed=='2780424839485660359' and ui.run.runSeed==ui.runSeed and ui.map.runSeed==ui.runSeed)
    assert(ui.run.eventSeed==ui.runSeed and ui.map.mapSeed=='2780424839485660360')
    local snapshot=Map.snapshot(ui.map)
    ui.run.seed=17 -- The mutable legacy combat stream must never become map identity.
    assert(ui.map.runSeed==snapshot.runSeed and Map.restore(F.Data,snapshot))
    ui.run.phase='defeat';ui:refresh();assert(ui:start())
    assert(ui.runSeed=='2780424839485660360' and ui.map.runSeed==ui.runSeed)
    local wrapped=host('9223372036854775807')
    assert(wrapped:start());wrapped.run.phase='defeat';wrapped:refresh();assert(wrapped:start())
    assert(wrapped.runSeed=='-9223372036854775808' and wrapped.map.mapSeed=='-9223372036854775807')
end)

test("rejected seed samples cannot replace a run and rendering cannot consume them",function()
    local calls=0
    local ui=host(nil,function()calls=calls+1;if calls==1 then return 28000 end;return 0/0 end)
    ui:refresh();ui:update(0.1)
    assert(calls==0 and ui:start())
    local run,map=ui.run,ui.map
    ui.run.phase="defeat";ui:refresh()
    assert(not pcall(function()ui:start()end))
    assert(calls==2 and ui.run==run and ui.map==map and ui.runSeed=='28000')
end)

test("native OnStart rereads wall and CPU time after script and module recreation",function()
    local saved={script=script,Enum=Enum,OnStart=OnStart,OnUpdate=OnUpdate,game=game,Color=Color,
        wall=os.time,cpu=os.clock,new=F.GameUI.new}
    local seen={}
    F.GameUI.new=function(...)local ui=saved.new(...);seen[#seen+1]=ui;return ui end
    os.time=function()return 1792843200 end -- Same wall-clock second, like a fast retry.
    Enum={CursorEventType={CursorClick="click"},ImageSource={StaticReference="static"}}
    Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
    game={GetUICanvasSize=function()return 1280,720 end}
    for i=1,2 do
        os.clock=function()return 120.123456+i*0.03125 end
        package.loaded.abyss_new_run_seed=nil -- Rechallenge may recreate the Lua module world.
        local canvas=F.control({children=F.Layout})
        script={object=canvas,EnableUpdate=function(self,v)self.updating=v end}
        dofile("src/lua/abyss_ui.lua");OnStart();OnStart()
        assert(#seen==i and script.updating)
        assert(seen[i]:start())
    end
    assert(seen[1].run.seed~=seen[2].run.seed,
        "same-second platform reconstruction systematically replayed the fixed seed")
    script,Enum,OnStart,OnUpdate,game,Color=saved.script,saved.Enum,saved.OnStart,saved.OnUpdate,saved.game,saved.Color
    os.time,os.clock,F.GameUI.new=saved.wall,saved.cpu,saved.new
end)

test("clock seed stays in the production range and preserves private rule RNG states",function()
    local Fresh=require("abyss_new_run_seed")
    local Random=require("abyss_random")
    local state=Random.new(42)
    local run=require("abyss_run").new(F.Data,42)
    local eventCounter,miscCounter=run.eventRng.counter,run.miscRng.counter
    local seen={}
    for i=0,255 do
        local seed=Fresh.fromTime(1792843200+i,120.123456+i/256,1)
        assert(seed>=0 and seed<65536 and seed%1==0)
        seen[seed]=true
    end
    local n=0;for _ in pairs(seen)do n=n+1 end
    assert(n>240,"time samples collapsed to a fixed or very small seed set")
    assert(state.seed==42 and run.seed==42)
    assert(run.eventRng.counter==eventCounter and run.miscRng.counter==miscCounter)
    assert(Fresh.fromTime(1792843200,120.123456,1)==Fresh.fromTime(1792843200,120.123456,1))
    for _,bad in ipairs({-1,math.huge,0/0,"bad"})do
        assert(not pcall(Fresh.fromTime,1792843200,bad,1))
    end
end)

print("LUA_GAME_UI_SEED_PASS "..count)
