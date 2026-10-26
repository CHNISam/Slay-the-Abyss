-- Source summon constructors precede every spawned opening roll and leader roll.
local A=require('abyss_actor')
local ER=require('abyss_enemy_random')
local M={}
local pool={'mad_gremlin','mad_gremlin','sneaky_gremlin','sneaky_gremlin','fat_gremlin','fat_gremlin','shield_gremlin','wizard_gremlin'}
local positions={{-366,-4},{-170,6},{-532,0}}
function M.rally(combat,s,leader)
 local descriptors={};local slots=assert(leader.act2GremlinSlots,'missing Leader slots')
 for i=1,3 do
  local present
  for _,e in ipairs(s.enemies)do if e.id==slots[i]then present=e end end
  if not A.isActive(present) and #descriptors<2 then
   descriptors[#descriptors+1]={id=pool[ER.integer(s,8,combat.random)],x=positions[i][1],y=positions[i][2],slot=i}
  end
 end
 local created=combat.summonEnemies(s,descriptors)
 for i,e in ipairs(created)do slots[descriptors[i].slot]=e.id end
end
function M.torches(combat,s,collector,revive)
 local slots=collector.act2TorchSlots or {};collector.act2TorchSlots=slots
 local descriptors={}
 for i=1,2 do
  local dead=not revive
  for _,e in ipairs(s.enemies)do if e.id==slots[i] and e.hp<=0 then dead=true end end
  if dead then descriptors[#descriptors+1]={id='torch_head',x=-100-185*i,y=0,slot=i} end
 end
 local created=combat.summonEnemies(s,descriptors)
 for i,e in ipairs(created)do slots[descriptors[i].slot]=e.id end
end
return M
