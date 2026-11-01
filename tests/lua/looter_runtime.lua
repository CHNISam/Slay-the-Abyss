package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local r=R.new(D,42);r.floor=4 -- existing legal encounter prerequisite, otherwise untouched starter Run
assert(R.startCombat(r,'looter_solo'));local e=r.combat.enemies[1]
assert(R.endTurn(r));assert(r.gold==84,'real opening Mug must steal 15: got '..r.gold)
assert(r.hp==80,'run HP sync remains at combat-end');assert(r.combat.player.hp==70);assert(e.stolenGold==15)
assert(R.endTurn(r));assert(r.gold==69);assert(r.combat.player.hp==60)
for _=1,3 do if r.phase=='combat' then assert(R.endTurn(r)) end end
assert(r.phase=='reward');assert(e.escaped and e.hp>0);assert(r.rewards.gold==0);assert(not r.rewards.stolenGold);assert(#R.rewardOptions(r)==3);assert(r.victories==1)
assert(r.hp==r.combat.player.hp+6);print('LOOTER_REAL_RUNTIME_PASS')
