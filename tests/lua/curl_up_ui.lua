package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'red_louse','green_louse'})
local C=H.F.Combat;local s=host.run.combat;local first,second=panel:GetChild('enemy1'),panel:GetChild('enemy2')
local definition=assert(s.catalog.statuses.curl_up,'Curl power must be described');local amount,other=s.enemies[1].statuses.curl_up,s.enemies[2].statuses.curl_up
assert(first:GetChild('statuses').text:find(definition.name..' '..string.format('%.0f',amount),1,true),'first Curl amount visible')
assert(second:GetChild('statuses').text:find(definition.name..' '..string.format('%.0f',other),1,true),'independent second Curl amount visible')
local function same(a,b)if type(a)~='table'then assert(a==b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local before=C.copy(s);host:refresh();tap('enemy1',2);same(s,before)
tap('card1',3);tap('enemy1',3);drain()
assert(s.enemies[1].block==amount and s.enemies[1].statuses.curl_up==0,'real controls grant once and remove')
assert(not first:GetChild('statuses').text:find(definition.name,1,true),'spent passive hidden')
assert(second:GetChild('statuses').text:find(definition.name..' '..string.format('%.0f',other),1,true),'other passive retained')
assert(first:GetChild('block').text==string.format('%.0f',amount),'granted Block visible')
print('CURL_UP_GENERATED_UI_PASS passive/amount/read-only/real-card/block/removal')
