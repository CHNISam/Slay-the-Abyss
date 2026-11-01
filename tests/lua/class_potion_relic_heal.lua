package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local D=C.copy(require('abyss_data'))
-- These passive definitions only supply already implemented healing hooks;
-- their natural relic acquisition is outside this potion regression.
for _,id in ipairs({'magic_flower','mark_of_bloom'})do
 D.relics.relics[#D.relics.relics+1]={id=id,name=id,rarity='rare',trigger='passive',effects={}}
end
for _,case in ipairs({{{'magic_flower'},8},{{'mark_of_bloom'},0},{{'magic_flower','mark_of_bloom'},0}})do
 local r=Run.new(D,42,{character='watcher',experimental=true});r.relics[#r.relics+1]='toy_ornithopter'
 for _,id in ipairs(case[1])do r.relics[#r.relics+1]=id end
 assert(Run.obtainPotion(r,'ambrosia'));assert(Run.startCombat(r,'cultist_solo'))
 local before=r.hp-20;r.hp=before;r.combat.player.hp=before
 assert(Run.usePotion(r,1));assert(r.hp==before+case[2],tostring(r.hp-before)..' ~= '..case[2])
 assert(r.combat.player.stance=='Divinity');assert(r.combat.energy==6)
 print('ok actual queued Toy healing '..case[2]..' with '..table.concat(case[1],'+'))
end
print('CLASS_POTION_RELIC_HEAL_PASS')
