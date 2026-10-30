-- Original fixed MonsterHelper constructor arguments @319009d5:385-505.
-- These are NOT resolved draw positions: geometry applies class delta once.
local M={}
local positions={
 ['Cultist']={{0,-10}},['Jaw Worm']={{0,25}},['Blue Slaver']={{0,0}},['Red Slaver']={{0,0}},['Looter']={{0,0}},
 ['2 Fungi Beasts']={{-400,30},{-40,20}},['Gremlin Nob']={{0,0}},['Lagavulin']={{0,20}},['Lagavulin Event']={{0,20}},
 ['3 Sentries']={{-330,25},{-85,10},{140,30}},
 ['The Guardian']={{-50,-100}},['Hexaghost']={{0,0}},['Slime Boss']={{0,28}},
 ['2 Thieves']={{-200,15},{80,0}},['Chosen']={{0,0}},['Shell Parasite']={{-20,10}},['Spheric Guardian']={{0,0}},
 ['Cultist and Chosen']={{-230,15},{100,25}},['3 Cultists']={{-465,-20},{-130,15},{200,-5}},
 ['Sentry and Sphere']={{-305,30},{0,0}},['Snake Plant']={{-30,-30}},['Snecko']={{0,0}},
 ['Centurion and Healer']={{-200,15},{120,0}},['Shelled Parasite and Fungi']={{-260,15},{120,0}},
 ['Book of Stabbing']={{0,5}},['Slavers']={{-385,-15},{-133,0},{125,-30}},
 ['Champ']={{-90,0}},['Collector']={{60,135}},['Automaton']={{-50,20}},
}
local byrdGroups={['3 Byrds']={-360,-80,200},['4 Byrds']={-470,-210,50,310},['Chosen and Byrds']={-170}}
function M.positions(source,visualFloat)
 local input=positions[source]
 if input then
  local result={};for i,p in ipairs(input)do result[i]={x=p[1],y=p[2]}end;return result
 end
 local xs=byrdGroups[source]
 if not xs then return nil end
 assert(type(visualFloat)=='function','original Byrd height requires cosmetic visualFloat')
 local result={}
 for i,x in ipairs(xs)do
  local y=visualFloat(25,70)
  assert(type(y)=='number' and y>=25 and y<=70,'invalid original Byrd height')
  result[i]={x=x,y=y}
 end
 if source=='Chosen and Byrds'then result[2]={x=80,y=0}end
 return result
end
return M
