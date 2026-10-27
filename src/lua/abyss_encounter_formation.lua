-- Source-method boundary. Run supplies privately staged, floor-reseeded streams.
-- MonsterHelper @319009d5:403..428, 600..605, 700..729, 774..829.
-- misc owns color/index decisions. MathUtils offsets use visualFloat, never misc.
-- construct runs immediately, including candidates later discarded. Its caller
-- owns HP/Bite and cosmetic constructor draws and must supply staged streams.
local M={}
local f32=require('abyss_sts_random').float32
local sources={['Small Slimes']=true,['Gremlin Gang']=true,['2 Louse']=true,['3 Louse']=true,['Large Slime']=true,
 ['Lots of Slimes']=true,['Exordium Thugs']=true,['Exordium Wildlife']=true}
function M.supports(source)return sources[source]==true end
sources['Gremlin Leader']=true
function M.assemble(source,boundary)
 assert(M.supports(source),'unsupported source formation: '..tostring(source))
 assert(type(boundary)=='table' and type(boundary.misc)=='table'
  and type(boundary.construct)=='function','formation needs misc and constructor boundaries')
 local misc=boundary.misc
 local function boolean()
  assert(type(misc.boolean)=='function','missing misc Boolean boundary')
  local value=misc.boolean();assert(type(value)=='boolean','invalid misc Boolean');return value
 end
 local function integer(maximum)
  assert(type(misc.integer)=='function','missing misc integer boundary')
  local value=misc.integer(0,maximum)
  assert(type(value)=='number' and value%1==0 and value>=0 and value<=maximum,'invalid misc index')
  return value+1
 end
 local function make(id,x,y)
  local actor=boundary.construct(id,x,y);assert(type(actor)=='table','constructor must return an actor');return actor
 end
 local function louse(x,y)return make(boolean() and 'red_louse' or 'green_louse',x,y)end
 local function weak(x,y)
  local candidates={}
  candidates[1]=louse(x,y)
  candidates[2]=make('spike_slime_m',x,y)
  candidates[3]=make('acid_slime_m',x,y)
  return candidates[integer(2)]
 end
 local function humanoid(x,y)
  local candidates={}
  candidates[1]=make('cultist',x,y)
  candidates[2]=make(boolean() and 'red_slaver' or 'blue_slaver',x,y)
  candidates[3]=make('looter',x,y)
  return candidates[integer(2)]
 end
 local function strongWildlife(x,y)
  local candidates={}
  candidates[1]=make('fungi_beast',x,y)
  candidates[2]=make('jaw_worm',x,y)
  return candidates[integer(1)]
 end
 local function offset(base)
  assert(type(boundary.visualFloat)=='function','missing independent MathUtils offset boundary')
  local value=boundary.visualFloat(-20,20)
  assert(type(value)=='number' and value>=-20 and value<=20,'invalid MathUtils offset')
  return f32(base+f32(value))
 end
 local result={}
 if source=='Gremlin Leader'then
  local pool={'mad_gremlin','mad_gremlin','sneaky_gremlin','sneaky_gremlin','fat_gremlin','fat_gremlin','shield_gremlin','wizard_gremlin'}
  result[1]=make(pool[integer(7)],-366,-4)
  result[2]=make(pool[integer(7)],-170,6)
  result[3]=make('gremlin_leader',35,0)
 elseif source=='Small Slimes'then
  if boolean()then
   result[1]=make('spike_slime_s',-230,32);result[2]=make('acid_slime_m',35,8)
  else result[1]=make('acid_slime_s',-230,32);result[2]=make('spike_slime_m',35,8)end
 elseif source=='Gremlin Gang'then
  local pool={'mad_gremlin','mad_gremlin','sneaky_gremlin','sneaky_gremlin','fat_gremlin','fat_gremlin','shield_gremlin','wizard_gremlin'}
  local positions={{-320,25},{-160,-12},{25,-35},{205,40}}
  for i,p in ipairs(positions)do result[i]=make(table.remove(pool,integer(#pool-1)),p[1],p[2])end
 elseif source=='2 Louse' or source=='3 Louse'then
  local positions=source=='2 Louse' and {{-200,10},{80,30}} or {{-350,25},{-125,10},{80,30}}
  for i,p in ipairs(positions)do result[i]=louse(p[1],p[2])end
 elseif source=='Large Slime'then result[1]=make(boolean() and 'acid_slime_l' or 'spike_slime_l',0,0)
 elseif source=='Lots of Slimes'then
  local pool={'spike_slime_s','spike_slime_s','spike_slime_s','acid_slime_s','acid_slime_s'}
  local positions={{-480,30},{-320,2},{-160,32},{10,-12},{200,9}}
  for i,p in ipairs(positions)do result[i]=make(table.remove(pool,integer(#pool-1)),p[1],p[2])end
 elseif source=='Exordium Thugs'then
  local x,y=offset(-160),offset(20)
  result[1]=weak(x,y)
  x,y=offset(130),offset(20)
  result[2]=humanoid(x,y)
 else -- Source bottomWildlife fixes numMonster=2; its three-slot branch is unreachable.
  local x,y=offset(-150),offset(20)
  result[1]=strongWildlife(x,y)
  x,y=offset(150),offset(20)
  result[2]=weak(x,y)
 end
 return result
end
return M
