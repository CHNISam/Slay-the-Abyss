-- Real chapter maps and generated native controls; no chapter combat is faked.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map=require('abyss_map')
local MapUI=require('abyss_map_ui')
local count=0
local function test(name,fn)fn();count=count+1;print('ok chapter map '..count..' - '..name)end
local function fixture(act,map)
    local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
    local panel=root:GetChild('mapPanel')
    map=map or Map.generate(F.Data,'42',act)
    local ui=MapUI.new(panel,map,function(node)return Map.choose(map,node.id)end,'click',{
        embedded=true,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
    return ui,panel,map
end
local function box(panel,map,id)
    for i,node in ipairs(map.nodes)do
        if node.id==id then return F.mapControl(panel,'node'..i)end
    end
    error('missing real node')
end
test('later chapters expose legal first nodes at local row one',function()
    for _,act in ipairs({2,3,4})do
        local ui,panel,map=fixture(act)
        assert(ui.navigationEnabled,'chapter start incorrectly locked')
        assert(ui.scroll==0,'chapter start incorrectly scrolled to global floor')
        for _,node in ipairs(Map.available(map))do
            local control=box(panel,map,node.id)
            assert(control.visible and control:GetChild('hit').visible,'first node is offscreen or inert')
            assert(control.y==require('abyss_map_layout').firstY,'global floor leaked into local geometry')
        end
        assert(F.mapControl(panel,'title').text:find(require('abyss_acts').get(act).name,1,true))
    end
end)
test('each complete chapter route remains reachable within the same viewport',function()
    for _,act in ipairs({2,3,4})do
        local ui,panel,map=fixture(act)
        local rooms=0
        while #Map.available(map)>0 do
            ui:setNavigationEnabled(true)
            local node=Map.available(map)[1]
            ui:focusCurrent()
            local control=box(panel,map,node.id)
            assert(control.visible and control:GetChild('hit').visible,'next chapter room is offscreen')
            assert(control:GetChild('hit').click())
            assert(map.floor==node.floor)
            rooms=rooms+1
        end
        assert(rooms==(act==4 and 4 or 17))
        local notice=F.mapControl(panel,'notice').text
        if act==2 then assert(notice:find('宝箱',1,true))
        else assert(not notice:find('宝箱',1,true),'ending falsely described as Boss treasure')end
    end
end)
test('restored later chapters focus local progress and wait for the host grant',function()
    local map=Map.generate(F.Data,'42',3)
    for _=1,8 do assert(Map.choose(map,Map.available(map)[1].id))end
    local restored=assert(Map.restore(F.Data,Map.snapshot(map)))
    local ui,panel=fixture(3,restored)
    assert(not ui.navigationEnabled)
    assert(box(panel,restored,restored.currentNodeId).visible,'restored current room is offscreen')
    ui:setNavigationEnabled(true)
    local node=Map.available(restored)[1]
    assert(box(panel,restored,node.id):GetChild('hit').click())
    assert(restored.floor==node.floor)
end)
print('CHAPTER_MAP_PASS '..count)
