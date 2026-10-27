-- Offline presentation boundaries only. Later combat content remains gated.
local F = dofile('tests/lua/support/game_ui_fixture.lua')
local Map, MapUI, Acts = require('abyss_map'), require('abyss_map_ui'), require('abyss_acts')
local Run, Nodes = require('abyss_run'), require('abyss_nodes')
local Q, Pool = require('abyss_encounter_queue'), require('abyss_event_pool')
local Layout, Theme = require('abyss_map_layout'), require('abyss_theme')
local passed = 0
local function test(name, fn) fn(); passed=passed+1; print('PASS '..name) end
local function same(a,b,path)
    path=path or 'state'; assert(type(a)==type(b),path)
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b)); return end
    for k,v in pairs(a) do same(v,b[k],path..'.'..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,path..' missing '..tostring(k)) end
end
local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorExit='exit',CursorEndDrag='endDrag'}
local function pointer(id,y) return {touchId=id,GetUIPos=function()return 640,y or 200 end} end
local function setup(map,onChoose)
    local root=F.control({children=require('abyss_map_controls').controls})
    local panel=root:GetChild('stage'):GetChild('mapPanel')
    local calls={}
    local ui=MapUI.new(root,map,function(node)
        calls[#calls+1]=node.id
        if onChoose then return onChoose(node,map) end
        return Map.choose(map,node.id)
    end,'click',{imageSource='static',cursor=cursor,color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
    local function box(name) return F.mapControl(panel,type(name)=='number' and 'node'..name or name) end
    local function emit(slot,event,id,y)
        local hit=slot=='dragArea' and box(slot) or box(slot):GetChild('hit')
        return hit.listeners[event](pointer(id,y))
    end
    return ui,box,emit,calls
end
local function focused(map,ui,box)
    local chapter=Acts.get(map.act or 1)
    local row=math.max(1,map.floor-chapter.first+1)
    local expected=math.max(0,math.min(Layout.maxScroll,Layout.firstY+(row-1)*Theme.layout.map.floorGap-Layout.focusY))
    assert(ui.scroll==expected,'focus used a global floor as a map row')
    assert(box('title').text==chapter.name..' · 第 '..map.floor..' 层')
    if map.currentNodeId then
        for i,node in ipairs(map.nodes) do
            if node.id==map.currentNodeId then assert(box(i).visible and box(i):GetChild('current').visible) end
        end
    end
end

for act=1,4 do
    test('canonical Act '..act..' projects every global floor into unchanged chapter geometry',function()
        local chapter=Acts.get(act)
        local map=Map.generate(F.Data,'42',act)
        local before=Map.snapshot(map)
        local ui,box=setup(map)
        assert(ui.scroll==0 and ui.navigationEnabled)
        focused(map,ui,box)
        if act==4 then for i=1,4 do assert(box(i).visible,'fixed ending room outside initial viewport') end end
        local seen={}
        for scroll=0,Layout.maxScroll+60,60 do
            ui:setScroll(scroll)
            for i,node in ipairs(map.nodes) do
                local b=box(i)
                local row=node.localFloor or node.floor-chapter.first+1
                assert(b.x==(node.lane-(Layout.lanes+1)/2)*Theme.layout.map.columnGap)
                assert(b.y==Layout.firstY+(row-1)*Theme.layout.map.floorGap-ui.scroll)
                assert(b:GetChild('icon').imageId==Theme.icon.node[node.type])
                if b.visible then
                    seen[node.id]=true
                    local radius=(b.sizeDeltaX+Layout.glowPadding)*Layout.breathScale/2
                    assert(b.y-radius>=Layout.viewport.bottom and b.y+radius<=Layout.viewport.top)
                    assert(b:GetChild('hit').visible==(node.floor==chapter.first))
                end
            end
            for i=1,Layout.maxEdges do
                local e=box('edge'..i)
                if e.visible then
                    local angle=e.localRotationZ*math.pi/180
                    local half=(math.abs(e.sizeDeltaX*math.sin(angle))+math.abs(e.sizeDeltaY*math.cos(angle)))/2
                    assert(e.y-half>=Layout.viewport.bottom-.0001 and e.y+half<=Layout.viewport.top+.0001)
                end
            end
        end
        for _,node in ipairs(map.nodes) do assert(seen[node.id],node.id..' never enters viewport') end
        same(map,before,'presentation changed map/RNG')
        ui:focusCurrent()
        while #Map.available(map)>0 do
            assert(Map.choose(map,Map.available(map)[1].id))
            ui:render(); assert(not ui.navigationEnabled)
            ui:focusCurrent(); focused(map,ui,box)
            if map.floor==chapter.boss then
                assert(box('notice').text==(act==4 and '已抵达终幕首领 · 请完成最终战斗与结算'
                    or '已抵达首领 · 请完成首领战斗与奖励'))
                ui:setNavigationEnabled(true)
                if chapter.terminal=='boss_treasure' then
                    assert(box('notice').text=='首领奖励已处理 · 请选择首领宝箱')
                elseif act==4 then
                    assert(box('notice').text=='已抵达终幕首领 · 请完成最终战斗与结算')
                else assert(box('notice').text=='首领奖励已处理 · 请前往终点') end
            end
        end
        if chapter.terminal=='boss_treasure' then
            assert(box('notice').text=='已抵达首领宝箱 · 请完成当前房间')
        elseif act==4 then
            assert(box('notice').text=='已抵达终幕首领 · 请完成最终战斗与结算')
        else assert(box('notice').text=='已抵达终点 · 请完成当前房间') end
        assert(not ui:choose(map.currentNodeId))
        assert(map.floor==chapter.last and #map.path==chapter.last-chapter.first+1)
    end)
end

local function advance(run,map,act)
    local chapter=Acts.get(act)
    if act<3 then
        while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id)) end
        run.act,run.floor,run.phase=act,chapter.last,'node'
        if act~=1 then run.encounters=Q.new(run.runSeed,act);run.unknown.pools=Pool.new('full',false,act) end
        run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='treasure',roomKind='boss_treasure',
            mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
        assert(Nodes.claimBossTreasure(run,0))
    else
        while map.floor<chapter.boss do assert(Map.choose(map,Map.available(map)[1].id)) end
        run.act,run.floor,run.phase=3,chapter.boss,'map'
        run.encounters=Q.new(run.runSeed,3)
        run.endingUnlocked=true;run.keys={ruby=true,emerald=true,sapphire=true}
        run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='boss',result='boss_victory',complete=true,
            mapSeed=map.seed,mapSignature=map.sourceSignature}
        assert(Nodes.enter(run,map,'f51_l4'))
    end
    assert(run.phase=='act_transition' and Nodes.advanceAct(run,map))
end
for act=1,3 do
    for _,event in ipairs({'render','update','drag','up'}) do
        test('real Nodes same-table Act '..act..' advance retires old Down via '..event,function()
            local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
            local map=Map.generate(F.Data,'42',act)
            local identity=map
            local ui,box,emit,calls=setup(map)
            emit(1,'down',11,200)
            advance(run,map,act)
            assert(map==identity and map.act==act+1)
            local before,runBefore=Map.snapshot(map),F.Combat.copy(run)
            if event=='render' then ui:render()
            elseif event=='update' then ui:update(.04)
            else emit(1,event,11,100) end
            emit(1,'up',11,100)
            assert(not emit(1,'click',11),'old chapter gesture selected a new slot')
            same(map,before);same(run,runBefore);assert(#calls==0)
            -- A stale Up need not redraw; the next fresh Down must synchronize.
            emit(1,'down',22,200)
            focused(map,ui,box);assert(ui.navigationEnabled and box(1):GetChild('hit').visible)
            emit(1,'up',22,200);assert(emit(1,'click',22))
            assert(map.floor==Acts.get(act+1).first and #calls==1)
            same(run,runBefore,'MapUI changed Run/resource owners')
        end)
    end
end

for _,prior in ipairs({'down','released'}) do
    test('old '..prior..' cannot consume a newer chapter pointer or release grant',function()
        local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
        local map=Map.generate(F.Data,'42')
        local ui,_,emit,calls=setup(map)
        emit(1,'down',11)
        if prior=='released' then emit(1,'up',11) end
        advance(run,map,1)
        local before,runBefore=Map.snapshot(map),F.Combat.copy(run)
        emit(1,'down',22)
        emit(1,'up',11)
        assert(not emit(1,'click',11))
        same(map,before);same(run,runBefore);assert(#calls==0)
        emit(1,'up',22)
        assert(not emit(1,'click',11),'old touch consumed the newer release grant')
        assert(emit(1,'click',22) and map.floor==18 and #calls==1)
        assert(not ui.navigationEnabled);same(run,runBefore)
    end)
end

test('same-table chapter advance terminates old animation and resets error gate and focus',function()
    local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
    local map=Map.generate(F.Data,'42')
    local ui,box=setup(map)
    assert(box('next'):GetChild('hit').click());ui:update(.04);assert(ui.scroll>0)
    ui.entryError='old chapter error'
    advance(run,map,1)
    local before=Map.snapshot(map)
    ui:update(.04)
    focused(map,ui,box);assert(ui.navigationEnabled and ui.entryError==nil and ui.time==0)
    ui:update(1);assert(ui.scroll==0)
    same(map,before)
end)

test('source/context changes without identity floor or node changes retire completed taps',function()
    for _,field in ipairs({'sourceSignature','seed','runSeed','mapSeed'}) do
        local map=Map.generate(F.Data,'42',2)
        local ui,_,emit,calls=setup(map)
        emit(1,'down',11);emit(1,'up',11)
        map[field]=map[field]..':changed'
        local before=Map.snapshot(map)
        assert(not emit(1,'click',11));same(map,before);assert(#calls==0)
    end
end)

local corruptions={
    function(m)m.act=5 end,
    function(m)m.act=nil end,
    function(m)m.firstFloor=nil end,
    function(m)m.firstFloor=35 end,
    function(m)m.terminalFloor=nil end,
    function(m)m.sourceSignature=nil end,
    function(m)m.sourceSignature='map-v4:sts-a0-319009d5:TheBeyond:forged' end,
    function(m)m.nodes[1].localFloor=18 end,
    function(m)m.nodes[1].floor=35 end,
}
for i,corrupt in ipairs(corruptions) do
    test('forged/incomplete chapter context '..i..' fails closed without touching owners',function()
        local map=Map.generate(F.Data,'42',2)
        local ui,box,emit,calls=setup(map)
        emit(1,'down',11);emit(1,'up',11)
        corrupt(map)
        local before=Map.snapshot(map)
        ui:render();assert(not ui.navigationEnabled and next(ui.slots)==nil)
        assert(not box(1).visible and not box('focus'):GetChild('hit').visible)
        assert(not ui:setNavigationEnabled(true));assert(not ui:focusCurrent())
        local ok,reason=ui:choose(map.nodes[1].id)
        assert(not ok and reason=='invalid_map_context')
        assert(not emit(1,'click',11));same(map,before);assert(#calls==0)
        assert(not pcall(setup,map),'constructor accepted invalid chapter context')
    end)
end

test('presentation does not enable production campaign or enter later combat without the coordinator',function()
    local ordinary=Run.new(F.Data,'42')
    assert(ordinary.campaign~=true and not Run.advanceAct(ordinary))
    local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
    local map=Map.generate(F.Data,'42')
    advance(run,map,1)
    local before,mapBefore=F.Combat.copy(run),Map.snapshot(map)
    local ui=setup(map);ui:render();ui:focusCurrent();ui:update(.04)
    assert(run.phase=='map' and run.act==2 and map.floor==17)
    same(run,before);same(map,mapBefore)
    -- Current M3 already supplies Act 2 content; only an explicit core command
    -- enters it. The older PR's unavailable-content expectation is obsolete.
    assert(Nodes.enter(run,map,Map.available(map)[1].id))
    assert(run.phase=='combat' and run.act==2 and run.floor==18 and map.floor==18)
end)
test('later-act missing localFloor falls back from global18/34 to rows1/17 with fresh input and pure state',function()
    local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
    local map=Map.generate(F.Data,'42')
    advance(run,map,1)
    assert(map.act==2 and map.floor==17)
    -- Optional presentation coordinates may be absent; the core global floors
    -- remain authoritative and no graph/RNG data is rebuilt or inferred.
    for _,node in ipairs(map.nodes) do node.localFloor=nil end
    local before,runBefore=Map.snapshot(map),F.Combat.copy(run)
    local ui,box,emit,calls=setup(map)
    assert(ui.navigationEnabled and ui.scroll==0)
    local first=map.nodes[1]
    assert(first.floor==18 and first.localFloor==nil)
    assert(box(1).y==Layout.firstY and box(1):GetChild('hit').visible)
    ui:render();ui:focusCurrent();ui:update(.04)
    same(map,before);same(run,runBefore)
    local expected=Map.snapshot(map)
    assert(Map.choose(expected,first.id))
    emit(1,'down',22);emit(1,'up',22);assert(emit(1,'click',22))
    same(map,expected);same(run,runBefore)
    assert(#calls==1 and map.floor==18 and ui.scroll==0)
    while map.floor<33 do assert(Map.choose(map,Map.available(map)[1].id)) end
    ui:render();ui:focusCurrent();ui:setNavigationEnabled(true)
    local terminal=map.nodes[#map.nodes]
    assert(terminal.floor==34 and terminal.localFloor==nil)
    local slot=#map.nodes
    assert(box(slot).y==Layout.firstY+16*Theme.layout.map.floorGap-ui.scroll)
    assert(box(slot).visible and box(slot):GetChild('hit').visible)
    local terminalBefore=Map.snapshot(map)
    ui:setScroll(0);ui:focusCurrent();ui:render()
    same(map,terminalBefore);same(run,runBefore)
    expected=Map.snapshot(map);assert(Map.choose(expected,terminal.id))
    emit(slot,'down',33);emit(slot,'up',33);assert(emit(slot,'click',33))
    assert(map.floor==34 and ui.scroll==Layout.maxScroll and #calls==2)
    assert(box(slot).y==Layout.firstY+16*Theme.layout.map.floorGap-Layout.maxScroll)
    same(map,expected);same(run,runBefore)
end)

test('title-screen unbound controller remains hidden and refuses ownerless input',function()
    for _,invalid in ipairs({false,0,'not-a-map'}) do assert(not pcall(setup,invalid)) end
    local ui,_,emit,calls=setup(nil)
    assert(ui.map==nil and not ui.visible and not ui.root.visible and not ui.navigationEnabled)
    for _,method in ipairs({'render','focusCurrent','setNavigationEnabled','choose'}) do
        local ok,reason=ui[method](ui,true)
        assert(ok==false and reason=='map_unbound',method)
    end
    local ok,reason=ui:setVisible(true);assert(ok==false and reason=='map_unbound')
    ui:resize(1280,720);assert(ui:update(.05))
    emit(1,'down',11);emit(1,'up',11);assert(not emit(1,'click',11))
    assert(#calls==0 and ui.map==nil and not ui.visible and not ui.root.visible)
end)
test('unbound title controller accepts the later real owner without replacing it',function()
    local ui,box=setup(nil)
    local map=Map.generate(F.Data,'42',2)
    local before=Map.snapshot(map)
    ui.map=map;ui:setVisible(true)
    assert(ui.map==map and ui.visible and ui.root.visible and ui.navigationEnabled)
    focused(map,ui,box);assert(box(1):GetChild('hit').visible)
    same(map,before,'binding changed real owner')
    ui:setVisible(false);ui:setVisible(true);ui:update(.05)
    focused(map,ui,box);same(map,before)
end)
test('callback context substitution cannot commit a selection from an earlier source owner',function()
    local map=Map.generate(F.Data,'42',2)
    local ui,_,emit,calls=setup(map,function(node,owner)
        assert(Map.choose(owner,node.id));owner.seed=owner.seed..':replaced';return true
    end)
    emit(1,'down',11);emit(1,'up',11)
    local ok,reason=emit(1,'click',11)
    assert(ok==false and reason=='selection_not_committed' and #calls==1)
    assert(not ui.navigationEnabled)
    local before=Map.snapshot(map)
    assert(not emit(1,'click',11));same(map,before)
end)
test('invalid context arriving during an animation shuts down all stale navigation',function()
    local map=Map.generate(F.Data,'42',2)
    local ui,box,emit,calls=setup(map)
    assert(box('next'):GetChild('hit').click());ui:update(.04)
    map.version=3
    local before=Map.snapshot(map)
    assert(ui:update(.04));assert(not ui.navigationEnabled and next(ui.slots)==nil)
    assert(not box(1).visible and not box('focus'):GetChild('hit').visible)
    emit(1,'down',11);emit(1,'up',11);assert(not emit(1,'click',11))
    assert(not box('next'):GetChild('hit').click())
    assert(ui:update(1));same(map,before);assert(#calls==0)
end)

test('unavailable Act 3 and malformed Act 2 encounter context reject without touching any owner',function()
    for _,act in ipairs({2,3}) do
        local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
        local map=Map.generate(F.Data,'42')
        advance(run,map,1)
        if act==3 then advance(run,map,2) else run.encounters.rawSeed='malformed-encounter-context' end
        local before,mapBefore=F.Combat.copy(run),Map.snapshot(map)
        local ui,_,emit,calls=setup(map,function(node)return Nodes.enter(run,map,node.id)end)
        emit(1,'down',11);emit(1,'up',11)
        local ok,reason=emit(1,'click',11)
        assert(ok==false and reason==(act==3 and 'act_content_unavailable' or 'run_seed_mismatch'))
        assert(#calls==1 and ui.entryError~=nil)
        same(run,before,'rejected encounter changed Run');same(map,mapBefore,'rejected encounter changed Map')
        assert(not emit(1,'click',11));same(run,before);same(map,mapBefore)
    end
end)

test('non-table map nodes fail closed without rendering or mutating owners',function()
    for _,invalid in ipairs({false,42,'not-a-node'}) do
        local map=Map.generate(F.Data,'42',2)
        local ui,box,emit,calls=setup(map)
        emit(1,'down',11);emit(1,'up',11)
        map.nodes[1]=invalid
        local before=Map.snapshot(map)
        ui:render();assert(not ui.navigationEnabled and next(ui.slots)==nil)
        assert(not box(1).visible and not box('focus'):GetChild('hit').visible)
        assert(ui:update(.05));assert(not ui:setNavigationEnabled(true));assert(not ui:focusCurrent())
        local ok,reason=ui:choose('f18_l1');assert(ok==false and reason=='invalid_map_context')
        assert(not emit(1,'click',11));assert(not pcall(setup,map))
        same(map,before);assert(#calls==0)
    end
end)

print('LUA_MAP_CHAPTERS_PASS '..passed)
