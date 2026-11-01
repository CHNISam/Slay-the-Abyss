local G=require('abyss_monster_source_geometry')
local P=require('abyss_monster_source_positions')
local function eq(got,want,label)assert(got==want,label..': '..tostring(got)..' ~= '..tostring(want))end
local cases={
 {'cultist',0,-10,230,240,-8,10}, {'guardian',-50,-100,440,350,0,95},
 {'slime_boss',0,28,400,350,0,-30}, {'hexaghost',0,0,450,450,20,0},
 {'collector',60,135,300,390,15,-40}, {'automaton',-50,20,270,400,0,-30},
 {'champ',-90,0,400,410,0,-15}, {'book_of_stabbing',0,5,320,420,0,-10},
 {'chosen',0,-20,200,280,5,-10}, {'snake_plant',-30,20,350,360,0,-44},
 {'wizard_gremlin',-35,0,130,180,40,-5}, {'bronze_orb',0,0,160,160,0,0}}
math.random=function()error('geometry must not consume RNG')end
for _,c in ipairs(cases)do
 local actor={definitionId=c[1],hp=55,id=c[1]..'_1'}
 local g=assert(G.resolve(actor));for i,k in ipairs({'x','y','width','height','hbX','hbY'})do eq(g[k],c[i+1],c[1]..'.'..k)end
 eq(actor.hp,55,'no hp mutation');assert(actor.sourcePosition==nil)
end
for _,c in ipairs({{'chosen',100,25,100,5},{'snake_plant',-30,-30,-30,20},{'wizard_gremlin',205,40,170,40}})do
 local a={definitionId=c[1],sourcePosition={x=c[2],y=c[3]}};local g=G.resolve(a)
 eq(g.x,c[4],'resolved x');eq(g.y,c[5],'resolved y');eq(a.sourcePosition.x,c[2],'input x unchanged');eq(a.sourcePosition.y,c[3],'input y unchanged')
end
assert(G.resolve({definitionId='future_monster'})==nil)
local sentries=P.positions('3 Sentries');eq(#sentries,3,'three sentries')
local expected={{-330,25},{-85,10},{140,30}}
for i,p in ipairs(sentries)do eq(p.x,expected[i][1],'sentry x');eq(p.y,expected[i][2],'sentry y')end
sentries[1].x=999;eq(P.positions('3 Sentries')[1].x,-330,'fresh immutable facts')
local count=0;local birds=P.positions('3 Byrds',function(lo,hi)eq(lo,25,'byrd low');eq(hi,70,'byrd high');count=count+1;return 25+count end)
eq(count,3,'one cosmetic call each');eq(birds[3].x,200,'third byrdx');eq(birds[3].y,28,'third byrdy')
assert(not pcall(P.positions,'3 Byrds'));assert(not pcall(P.positions,'3 Byrds',function()return 71 end))
local mixed=P.positions('Cultist and Chosen');eq(G.resolve({definitionId='chosen',sourcePosition=mixed[2]}).y,5,'chosen delta applied once')
-- Actor location never depends on count, slot, HP or other actors.
local a={definitionId='sentry',id='sentry_2',sourcePosition={x=-85,y=10}};local before=G.resolve(a);a.hp=0;local after=G.resolve(a)
eq(after.x,before.x,'death does not reflow');eq(after.y,before.y,'death does not reflow y')
print('SOURCE_MONSTER_GEOMETRY passed12 default+3 delta+formation+RNG/no mutation contracts')

local C,Data=require('abyss_combat'),require('abyss_data')
local state=C.new(Data,{enemies={'acid_slime_m','wizard_gremlin','cultist'},deck={},seed=42})
for i,x in ipairs({-100,200,-300})do state.enemies[i].sourcePosition={x=x,y=0}end
local prior={state.enemies[1],state.enemies[2],state.enemies[3]}
prior[1].hp=0 -- Dead objects still participate in source SpawnMonsterAction drawX counting.
local child=C.summonEnemies(state,{{id='mad_gremlin',x=180,y=0}})[1]
assert(state.enemies[4]==child,'source spawn counts entire unsorted list using resolved Wizard x=165')
for i,old in ipairs(prior)do assert(state.enemies[i]==old,'spawn must not reorder old MonsterGroup instances')end
print('SOURCE_MONSTER_SPAWN full-list/delta/dead count PASS')

local group=C.new(Data,{enemies={'sentry','sentry','sentry'},encounterSource='3 Sentries',deck={},seed=42})
for i,p in ipairs(expected)do eq(group.enemies[i].sourcePosition.x,p[1],'actual constructor sentry x');eq(group.enemies[i].sourcePosition.y,p[2],'actual constructor sentry y')end
assert(not pcall(C.new,Data,{enemies={'sentry'},encounterSource='3 Sentries',deck={},seed=42}))
print('SOURCE_MONSTER_CONSTRUCTION actual encounter offsets PASS')

do
 local geometry=require('abyss_monster_source_geometry')
 local actor={definitionId='guardian',aiPhase='defense'}
 local closed=geometry.resolve(actor);assert(closed.height==250 and closed.width==440 and closed.hbY==95)
 actor.aiPhase='offense';local open=geometry.resolve(actor)
 assert(open.height==350 and open.x==closed.x and open.y==closed.y,'Guardian hitbox changes must not move original draw coordinates')
end
