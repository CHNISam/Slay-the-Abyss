local G=require('abyss_monster_source_geometry')
local I=require('abyss_monster_source_intents')
math.random=function()error('source metadata must not use RNG')end
local cases={
 {'bandit_pointy',-320,0,-5,-4,190,180,{pointy_special='ATTACK'}},
 {'bandit_leader',-75,-6,-10,-7,180,285,{mock='UNKNOWN',agonizing_slash='ATTACK_DEBUFF',cross_slash='ATTACK'}},
 {'bandit_bear',150,-6,-5,-4,180,280,{bear_hug='STRONG_DEBUFF',lunge='ATTACK_DEFEND',maul='ATTACK'}},
 {'lagavulin_awake',0,20,0,-25,320,220,{siphon='STRONG_DEBUFF',attack='ATTACK'}}}
for _,c in ipairs(cases)do
 local actor={definitionId=c[1],id=c[1]..'_1',hp=42,sourcePosition={x=c[2],y=c[3]}}
 local g=assert(G.resolve(actor));for i,k in ipairs({'x','y','hbX','hbY','width','height'})do assert(g[k]==c[i+1],c[1]..':'..k)end
 assert(I.hasDefinition(actor));for id,enum in pairs(c[8])do
  local intent={id=id};assert(I.enum(actor,intent)==enum)
  assert(I.isMulti(actor,intent)==(c[1]=='bandit_pointy'))
 end
 assert(not pcall(I.enum,actor,{id='foreign_move'}),'unknown move must fail closed')
 actor.hp=0;local dead=G.resolve(actor);assert(dead.x==g.x and dead.y==g.y,'death must not reflow')
 assert(actor.sourcePosition.x==c[2]and actor.sourcePosition.y==c[3])
end
local sleep=G.resolve({definitionId='lagavulin'});local awake=G.resolve({definitionId='lagavulin_awake'})
for k,v in pairs(sleep)do assert(awake[k]==v,'awake constructor has same geometry')end
assert(I.enum({definitionId='lagavulin'},{id='lagavulin_1'})=='SLEEP')
assert(I.visual('ATTACK',5,2)=='INTENT_ATK_3','Pointy total10 uses exact tier')
assert(I.visual('ATTACK_DEFEND',9,1)=='INTENT_ATK_2','Bear world uses attack not composite')
assert(I.visual('ATTACK_DEBUFF',10,1)=='INTENT_ATK_3')
local _,_,visible=I.visual('UNKNOWN');assert(not visible,'Romeo mock uses source particles, not base sprite')
assert(I.visual('STRONG_DEBUFF')=='INTENT_DEBUFF2_L')
print('EVENT_MONSTER_SOURCE_UI_PASS 4 definitions / 9 moves / exact geometry / multi / no RNG')
