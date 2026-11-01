package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local run=Run.new(Data,42);assert(Run.obtainPotion(run,'blessing_of_the_forge'));assert(Run.startCombat(run,'cultist_solo'))
local s=run.combat
s.hand={{cardId='strike',uid=1000},{cardId='bash',uid=1001},{cardId='defend',uid=1002,upgraded=true},{cardId='burn',uid=1003}}
local energy=s.energy;local nextUid=s.nextUid;local ids={}
for i,c in ipairs(s.hand) do ids[i]=c.uid end
assert(Run.usePotion(run,1));assert(run.potions[1]==nil and s.energy==energy and s.nextUid==nextUid)
assert(s.hand[1].upgraded and s.hand[2].upgraded and s.hand[3].upgraded and not s.hand[4].upgraded)
for i,c in ipairs(s.hand) do assert(c.uid==ids[i]) end
for _,c in ipairs(run.deck) do assert(not c.upgraded) end
assert(not s.pendingChoice)
local empty=Run.new(Data,43);assert(Run.obtainPotion(empty,'blessing_of_the_forge'));assert(Run.startCombat(empty,'cultist_solo'))
empty.combat.hand={};assert(Run.usePotion(empty,1));assert(empty.potions[1]==nil)
print('LUA_POTION_FORGE_PASS 2')
