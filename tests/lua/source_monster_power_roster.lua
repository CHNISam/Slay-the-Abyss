-- Current 42 enemy roster; normal constructor and three actual turn boundaries.
local C,A,D=require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local ids={'cultist','jaw_worm','red_louse','green_louse','acid_slime_s','acid_slime_m','acid_slime_l','spike_slime_s','spike_slime_m','spike_slime_l','red_slaver','blue_slaver','looter','fungi_beast','mad_gremlin','fat_gremlin','sneaky_gremlin','shield_gremlin','wizard_gremlin','gremlin_nob','sentry','lagavulin','guardian','slime_boss','hexaghost','centurion','mystic','spheric_guardian','taskmaster','book_of_stabbing','snake_plant','chosen','shelled_parasite','byrd','snecko','mugger','gremlin_leader','torch_head','collector','automaton','bronze_orb','champ'}
local function check(e)
 local rows=A.statusView(e)
 for _,row in ipairs(rows)do
  assert(type(row.canGoNegative)=='boolean','unverified negative flag '..row.id)
  assert(type(row.isTurnBased)=='boolean','unverified turn flag '..row.id)
 end
end
for _,id in ipairs(ids)do
 local enemies=id=='gremlin_leader'and {'mad_gremlin','sneaky_gremlin',id}or {id}
 local s=C.new(D,{enemies=enemies,deck={},seed=42,hp=500,maxHp=500})
 for _=1,3 do
  for _,e in ipairs(s.enemies)do check(e)end
  if C.outcome(s)then break end
  assert(C.endTurn(s))
 end
 for _,event in ipairs(s.events)do for _,e in ipairs(event.frame.enemies)do check(e)end end
 print('PASS source list frames '..id)
end
print('SOURCE_MONSTER_POWER_ROSTER 42 actors passed')
