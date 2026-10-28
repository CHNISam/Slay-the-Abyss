package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Combat=require('abyss_combat')
local Data=require('abyss_data')
local View=require('abyss_battle_damage_view')
local function equal(a,b,seen)
 if type(a)~='table' then assert(a==b);return end
 seen=seen or {};if seen[a]then assert(seen[a]==b);return end;seen[a]=b
 for k,v in pairs(a)do equal(v,b[k],seen)end
 for k in pairs(b)do assert(a[k]~=nil)end
end
for _,id in ipairs({'strike','twin_strike','cleave','iron_wave','body_slam'})do
 local battle=Combat.new(Data,{deck={id,id,id},enemies={'cultist','cultist'}})
 battle.player.statuses.strength=3;battle.player.statuses.weak=1
 battle.enemies[1].block=5;battle.enemies[2].statuses.vulnerable=1
 local before=Combat.copy(battle)
 local uid=battle.hand[1].uid
 local result=assert(View.preview(battle,uid,2))
 equal(battle,before)
 assert(Combat.play(battle,uid,2))
 for i,enemy in ipairs(battle.enemies)do assert(result[i].hp==enemy.hp)end
end
local battle=Combat.new(Data,{deck={'strike'},enemies={'cultist'}})
assert(View.preview(battle,battle.hand[1].uid,nil)==nil)
assert(View.preview(battle,'stale',1)==nil)
print('LUA_BATTLE_DAMAGE_VIEW_PASS 7')
local Run=require('abyss_run')
local run=Run.new(Data,42)
assert(Run.startCombat(run,'cultist_solo'))
for _,card in ipairs(run.combat.hand)do
 if Combat.canPlay(run.combat,card.uid,1)then
  assert(View.preview(run.combat,card.uid,1),'formal Run preview missing')
 end
end
