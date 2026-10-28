package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,D=require('abyss_run'),require('abyss_data')
local r=Run.new(D,42)
for _,c in ipairs(r.data.cards.cards)do
 if ({red=true,green=true,blue=true,purple=true})[c.color]and c.rarity~='special'and c.type~='status'and c.type~='curse'then
  print(table.concat({'CATALOG',c.id,c.sourceId or '',c.type,c.color,c.rarity,tostring(c.healing==true),tostring(c.cost)},'\t'))
 end
end
