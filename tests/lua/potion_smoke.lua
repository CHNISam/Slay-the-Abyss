package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Nodes,Map,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_nodes'),require('abyss_map'),require('abyss_sts_random'),require('abyss_data')
local run=Run.new(Data,42);local map=Map.generate(Data,42)
assert(Run.obtainPotion(run,'smoke_bomb'));assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id))
local gold,hp,wins=run.gold,run.hp,run.victories
local card=R.snapshot(run.cardRng);local potion=C.copy(run.shopRng)
assert(Run.usePotion(run,1));assert(run.phase=='map' and run.lastResult.outcome=='escaped')
assert(run.gold==gold and run.hp==hp and run.victories==wins and run.rewards==nil and not run.potions[1])
assert(R.snapshot(run.cardRng).counter==card.counter)
assert(Nodes.completeCombat(run,map));assert(run.nodeFlow.complete and run.nodeFlow.result=='escaped')
assert(#Nodes.available(run,map)>0)
local back=Run.new(Data,42);assert(Run.obtainPotion(back,'smoke_bomb'));assert(Run.startCombat(back,'cultist_solo'))
back.combat.enemies[1].statuses.back_attack=1
local ok,why=Run.usePotion(back,1);assert(not ok and why=='smoke_not_allowed' and back.potions[1]=='smoke_bomb')
local boss=Run.new(Data,42);boss.floor=16;assert(Run.obtainPotion(boss,'smoke_bomb'));assert(Run.startCombat(boss,'boss_guardian'))
local ok,why=Run.usePotion(boss,1);assert(not ok and why=='smoke_not_allowed' and boss.potions[1]=='smoke_bomb')
print('LUA_POTION_SMOKE_PASS 3')
