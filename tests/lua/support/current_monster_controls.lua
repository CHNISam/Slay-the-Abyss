-- Current native actor/power controls, resolved by identity rather than static slots.
local Surfaces=require('abyss_monster_surfaces')
local Powers=require('abyss_monster_power_surfaces')
local M={}
function M.actor(panel,actor)
 local box,slot,entry=assert(Surfaces.get(panel),'missing native actor manager'):find(assert(actor.id))
 assert(box and entry and entry.id==actor.id,'missing native actor '..actor.id)
 assert(box.alive~=false,'retired native actor '..actor.id)
 return box,slot,entry
end
function M.power(box,id)
 local chip=assert(Powers.get(box:GetChild('statusRow')),'missing native power manager'):find(id)
 return assert(chip,'missing native power '..id)
end
function M.count(panel,expected)
 local count=0
 assert(Surfaces.get(panel)):each(function(box,slot,entry)
  assert(box.alive~=false and entry.id and entry.actor.id==entry.id,'invalid native actor ownership')
  count=count+1
 end)
 assert(count==expected,'native actor count '..count..' ~= '..expected)
end
return M
