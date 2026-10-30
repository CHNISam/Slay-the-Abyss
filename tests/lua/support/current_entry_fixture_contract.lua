local fresh=dofile('tests/lua/support/current_entry_fixture.lua')
local Surfaces=require('abyss_monster_surfaces')
for cycle=1,8 do
    local F=fresh();assert(F.worldCount()==0)
    local host,root=F.fixture()
    local panel=root:GetChild('battlePanel')
    assert(Surfaces.get(panel) and F.worldCount()==1)
    assert(F.start(host))
    assert(require('abyss_run').startCombat(host.run,'louse_pair'))
    host:refresh()
    local actor=assert(Surfaces.get(panel):control(1),'actual dynamic actor must be allocated')
    F.close()
    assert(F.worldCount()==0 and Surfaces.get(panel)==nil,'real teardown must unregister its own actor manager')
    assert(root.alive==false and panel.alive==false and actor.alive==false)
    for _,write in ipairs({function()root:SetVisible(true)end,function()root:SetSizeDelta(1,1)end,
        function()root:GetChild('menuPanel')end,function()root.visible=true end,function()actor:SetVisible(true)end,function()actor:GetChild('portrait')end})do
        local ok,why=pcall(write);assert(not ok and tostring(why):find('native control is destroyed',1,true))
    end
    F.close();assert(F.worldCount()==0)
end
print('CURRENT_ENTRY_FIXTURE_LIFETIME_PASS 8')
