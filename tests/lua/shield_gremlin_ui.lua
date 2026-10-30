local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local host,ui,panel,emit,tap,drain=H.setup({'defend'},{'shield_gremlin','sneaky_gremlin'})
local C=H.F.Combat
local function same(a,b) if type(a)~='table' then assert(a==b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local box=monsterControl(panel,'enemy1');assert(box:GetChild('intent').text=='')
C.addStatus(host.run.combat.enemies[1],'dexterity',20);C.addStatus(host.run.combat.enemies[1],'frail',2);host:refresh()
assert(box:GetChild('intent').text=='','defend intent uses an icon without a block number')
local before=C.copy(host.run.combat);tap('enemy1',1);local detail=inspectDetails(ui,panel)
assert(detail:find('随机队友',1,true),'Protect detail must name random teammate')
assert(detail:find('没有队友时给自己',1,true),'Protect detail must name solo fallback')
assert(detail:find('获得 7 点格挡',1,true),'Protect detail stays fixed7')
same(host.run.combat,before)
tap('endTurn',2);drain();assert(host.run.combat.enemies[2].block==7);assert(host.run.combat.enemies[1].block==0);assert(box:GetChild('intent').text=='')
host.run.combat.enemies[2].hp=0;host:refresh();tap('endTurn',3);drain();assert(box:GetChild('intent').text=='6');assert(host.run.combat.enemies[1].block==7)
print('SHIELD_GREMLIN_GENERATED_UI_PASS values/detail/readonly/ally-block/solo-transition')
