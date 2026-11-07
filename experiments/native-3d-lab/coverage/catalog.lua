-- Read the same full-source registration boundary used by Combat.new.
-- This audit constructs no combat, actors, RNG streams or game state.
package.path='build/lua/?.lua;src/lua/?.lua;'..package.path
local data=require('abyss_data')
local Catalog=require('abyss_combat_catalog')
local _,catalog=Catalog.prepare(data)
catalog.enemies=Catalog.enemies(data)
require('abyss_combat_enemy_setup').register(catalog)
local ids={};for id in pairs(catalog.enemies)do ids[#ids+1]=id end;table.sort(ids)
for _,id in ipairs(ids)do
 local d=catalog.enemies[id]
 local ai=d.ai or {}
 print(table.concat({id,d.name or '',d.tier or '',ai.kind or '',ai.policy or '',d.sourceId or '',tostring(d.hp or '')},'\t'))
end
