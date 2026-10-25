-- Unknown-room routing fixture, not a source map-generation matrix.
-- Keep one real seed42 topology and clone all navigation state for every run.
-- Bind only the Run/Map ownership ABI to the actual routing seed. Source map
-- generation metadata remains seed42; this fixture is not a restorable map.
local C,Map=require('abyss_combat'),require('abyss_map')
local M={}
local template,templateData
function M.new(data,run)
    if templateData~=data then template,templateData=Map.generate(data,42),data end
    local map=C.copy(template)
    map.seed,map.runSeed=run.runSeed,run.runSeed
    map.nodes[1].type='event';map.nodes[1].eventId=nil
    return map,map.nodes[1].id
end
return M
