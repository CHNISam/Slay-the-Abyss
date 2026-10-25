package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,Data=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local run=Run.new(Data,42);assert(Run.obtainPotion(run,'explosive_potion'));assert(Run.startCombat(run,'cultist_solo'))
local s=run.combat;local e=s.enemies[1]
local second=C.copy(e);second.id='second';s.enemies[2]=second
A.applyPower(s,s.player,'strength',20);A.applyPower(s,s.player,'weak',2)
for _,v in ipairs(s.enemies) do
 A.applyPower(s,v,'vulnerable',3);A.applyPower(s,v,'thorns',5);A.applyPower(s,v,'angry',2);A.applyPower(s,v,'curl_up',9)
 v.block=3
end
local hp,hp2,player=e.hp,second.hp,s.player.hp
assert(Run.usePotion(run,1));assert(e~=s.enemies[1]);e=s.enemies[1];second=s.enemies[2]
assert(e.hp==hp-7 and second.hp==hp2-7)
assert(s.player.hp==player and not e.curlUpTriggered and not second.curlUpTriggered)
assert((e.statuses.strength or 0)==0 and (second.statuses.strength or 0)==0)
assert(run.potions[1]==nil)
print('LUA_POTION_EXPLOSIVE_PASS 1')
