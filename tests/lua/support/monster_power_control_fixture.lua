-- Read the native chip for a power identity, including count-less powers.
local Powers=require('abyss_monster_power_surfaces')
return function(box,id)
    local manager=assert(Powers.get(box:GetChild('statusRow')),'missing native power manager')
    return assert(manager:find(id),'missing native power '..id)
end
