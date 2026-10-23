package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'fungi_beast','fungi_beast'})
local C=H.F.Combat
local function same(a,b) if type(a)~='table' then assert(a==b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local s=host.run.combat;local definition=assert(s.catalog.statuses.spore_cloud,'death passive must be described')
local first,second=panel:GetChild('enemy1'),panel:GetChild('enemy2')
assert(first:GetChild('statuses').text:find(definition.name..' 2',1,true),'first Fungi passive visible')
assert(second:GetChild('statuses').text:find(definition.name..' 2',1,true),'second Fungi passive visible')
local before=C.copy(s);host:refresh();tap('enemy1',3);same(s,before)
s.enemies[1].hp=6;host:refresh();tap('card1',4);tap('enemy1',4);drain()
assert(s.enemies[1].hp==0 and s.player.statuses.vulnerable==2,'real controls commit death power')
assert(panel:GetChild('hero'):GetChild('statuses').text:find('易伤 2',1,true),'player receives visible Vulnerable')
assert(second:GetChild('statuses').text:find(definition.name..' 2',1,true),'living teammate retains own passive')
print('SPORE_CLOUD_GENERATED_UI_PASS passive/read-only/real-card/target-status')
