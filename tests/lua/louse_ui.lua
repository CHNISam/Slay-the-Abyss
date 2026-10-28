package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local host,ui,panel,emit,tap,drain=H.setup({'defend'},{'cultist'})
local old,n=C.random,0
C.random=function(s,max)local value=old(s,max);if max==100 then return 100 elseif max==3 then n=n+1;return n==1 and 1 or 3 end;return value end
local ok,s=pcall(C.new,H.F.Data,{deck={'defend'},enemies={'red_louse','green_louse'}})
C.random=old;assert(ok,s)
host.run.combat=s;host:refresh()
local first,second=panel:GetChild('enemy1'),panel:GetChild('enemy2')
assert(first:GetChild('intent').text=='5' and second:GetChild('intent').text=='7','sampled actor values displayed')
assert(first:GetChild('hp').text==s.enemies[1].hp..'/'..s.enemies[1].maxHp,'sampled HP displayed')
local function same(a,b)if type(a)~='table' then assert(a==b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
C.addStatus(s.enemies[1],'strength',3);C.addStatus(s.enemies[2],'weak',1);host:refresh()
assert(first:GetChild('intent').text=='8' and second:GetChild('intent').text=='5','core modifiers apply to sampled base')
local before=C.copy(s);host:refresh();tap('enemy1',1);same(s,before)
local detail=inspectDetails(ui,panel)
assert(detail:find('8',1,true),'read-only detail shows sampled modified Bite')
same(s,before)
tap('endTurn',2);drain()
assert(s.player.hp==67,'real controls execute 8 plus 5 damage')
assert(s.enemies[1].intents[1].effects[1].value==5 and s.enemies[2].intents[1].effects[1].value==7,'Bite bases never resample')
print('LOUSE_GENERATED_UI_PASS sampled-HP/Bite/core-modifiers/read-only/real-turn')
