-- enemyN resolves a displayed native instance; suffixes traverse its real handle.
local Surfaces=require('abyss_monster_surfaces')
local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
return function(root,path)
 local control=root
 for name in path:gmatch('[^/]+')do
  if name:match('^enemy%d+$') and Surfaces.get(control)then
   control=assert(monsterControl(control,name),path)
  else control=assert(control:GetChild(name),path)end
 end
 return control
end
