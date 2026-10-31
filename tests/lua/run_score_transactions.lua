local Run,C,D,A=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_actor')
local F=dofile('tests/lua/support/event_combat_route_fixture.lua')
local r=F.event('42','colosseum')
assert(Run.obtainPotion(r,'smoke_bomb'));assert(require('abyss_nodes').chooseEvent(r,'continue'));assert(require('abyss_nodes').chooseEvent(r,'fight'))
local b,s=r.combat,r.scoreStats
b.scoreStats.goldGained=25;b.scoreStats.combo=true
local before=C.copy(r);local EC=require('abyss_event_combat');local old=EC.escape
EC.escape=function()return false,'injected_after_score_merge'end
local ok,why=Run.usePotion(r,1);EC.escape=old
assert(not ok and why=='potion_effect_failed');assert(r.scoreStats==s and r.combat==b)
F.same(r.scoreStats,before.scoreStats);F.same(b.scoreStats,before.combat.scoreStats)
assert(r.potions[1]=='smoke_bomb');assert(b.scoreStats.merged==nil)
assert(Run.usePotion(r,1));assert(r.scoreStats.goldGained==25 and r.scoreStats.combo)
assert(r.scoreStats.normalWins==0 and r.scoreStats.eliteWins[2]==0)
print('PASS independent event Smoke late rejection isolates stats; successful retry merges once')
r=Run.new(D,'42');assert(Run.startRoomCombat(r,'normal'));b=r.combat
local e=b.enemies[1];e.hp=1;e.block=0;e.statuses.poison=99
A.startTurn(b,e);assert(b.scoreStats.overkill)
print('PASS independent poison final damage before hp truncation')
