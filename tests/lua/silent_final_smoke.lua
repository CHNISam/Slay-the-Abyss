package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Profiles=require('abyss_character_profiles')
local data=Profiles.prepare(require('abyss_data'),'silent')
local ids={};local n=0
for _,d in ipairs(data.cards.cards)do ids[d.id]=d;if d.color=='green'and d.rarity~='special'and d.type~='status'and d.type~='curse'then n=n+1 end end
for _,id in ipairs({'distraction','endless_agony','masterful_stab','setup','well_laid_plans','bullet_time','burst','corpse_explosion','doppelganger','nightmare','phantasmal_killer','tools_of_the_trade','alchemize','wraith_form'})do assert(ids[id],'missing actual production definition '..id)end
assert(n==75,tostring(n)..' ~=75')
print('SILENT_FINAL_DEFINITIONS 75')
