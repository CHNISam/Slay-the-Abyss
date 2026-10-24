package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'fungi_beast','fungi_beast'})
local C=H.F.Combat
local function same(a,b) if type(a)~='table' then assert(a==b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local s=host.run.combat;local definition=assert(s.catalog.statuses.spore_cloud,'death passive must be described')
local first,second=panel:GetChild('enemy1'),panel:GetChild('enemy2')
local function details(box)
    box:GetChild('statusRow'):GetChild('hit').click()
    local info,lines=panel:GetChild('statusInfo'),{}
    assert(info.visible,'status details open')
    for i=1,H.F.Theme.layout.statusInfo.rows do
        local name=info:GetChild('name'..i)
        if name.visible then lines[#lines+1]=name.text end
    end
    info:GetChild('hit').click();assert(not info.visible,'status details close')
    return table.concat(lines,' | ')
end
assert(details(first):find(definition.name..' 2',1,true),'first Fungi passive visible')
assert(details(second):find(definition.name..' 2',1,true),'second Fungi passive visible')
local before=C.copy(s);host:refresh();tap('enemy1',3);same(s,before)
s.enemies[1].hp=6;host:refresh();tap('card1',4);tap('enemy1',4);drain()
assert(s.enemies[1].hp==0 and s.player.statuses.vulnerable==2,'real controls commit death power')
assert(details(panel:GetChild('hero')):find('易伤 2',1,true),'player receives visible Vulnerable')
assert(details(second):find(definition.name..' 2',1,true),'living teammate retains own passive')
print('SPORE_CLOUD_GENERATED_UI_PASS passive/read-only/real-card/target-status')
