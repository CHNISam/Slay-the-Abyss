-- Facts from sts@319009d5 constructors/MonsterHelper; no RNG or render state.
-- x/y are original constructor offsets AFTER class-specific displacement.
-- width/height/hbX/hbY are hitbox facts, not original sprite/Spine bounds.
local M={}
local definitions={
 ['cultist']={0,-10,0,0,-8,10,230,240},
 ['jaw_worm']={0,25,0,0,0,-25,260,170},
 ['red_louse']={0,0,0,0,0,-5,180,140},
 ['green_louse']={0,0,0,0,0,-5,180,140},
 ['acid_slime_s']={0,0,0,0,0,-4,130,100},
 ['acid_slime_m']={0,0,0,0,0,0,170,130},
 ['acid_slime_l']={0,0,0,0,0,0,300,180},
 ['spike_slime_s']={0,0,0,0,0,-24,130,100},
 ['spike_slime_m']={0,0,0,0,0,-25,170,130},
 ['spike_slime_l']={0,0,0,0,0,-30,300,180},
 ['red_slaver']={0,0,0,0,0,0,170,230},
 ['blue_slaver']={0,0,0,0,0,0,170,230},
 ['looter']={0,0,0,0,0,0,200,220},
 ['fungi_beast']={0,0,0,0,0,-16,260,170},
 ['mad_gremlin']={0,0,0,0,-4,12,130,194},
 ['fat_gremlin']={0,0,0,0,0,0,110,220},
 ['sneaky_gremlin']={0,0,0,0,0,0,120,160},
 ['shield_gremlin']={0,0,0,0,0,0,120,200},
 ['wizard_gremlin']={0,0,-35,0,40,-5,130,180},
 ['gremlin_nob']={0,0,0,0,-70,-10,270,380},
 ['sentry']={0,0,0,0,0,-5,180,310},
 ['lagavulin']={0,20,0,0,0,-25,320,220},
 -- Event constructors use supplied sourcePosition; defaults are their MonsterHelper formation.
 ['lagavulin_awake']={0,20,0,0,0,-25,320,220},
 ['bandit_pointy']={-320,0,0,0,-5,-4,190,180},
 ['bandit_leader']={-75,-6,0,0,-10,-7,180,285},
 ['bandit_bear']={150,-6,0,0,-5,-4,180,280},
 ['guardian']={-50,-100,0,0,0,95,440,350},
 ['slime_boss']={0,28,0,0,0,-30,400,350},
 ['hexaghost']={0,0,0,0,20,0,450,450},
 ['centurion']={0,0,0,0,-14,-20,250,330},
 ['mystic']={0,0,0,0,0,-20,230,250},
 ['spheric_guardian']={0,0,0,0,0,10,280,280},
 ['taskmaster']={0,0,0,0,-10,-8,200,280},
 ['book_of_stabbing']={0,5,0,0,0,-10,320,420},
 ['snake_plant']={-30,-30,0,50,0,-44,350,360},
 ['chosen']={0,0,0,-20,5,-10,200,280},
 ['shelled_parasite']={-20,10,0,0,20,-6,350,260},
 ['byrd']={0,0,0,0,0,50,240,180},
 ['snecko']={0,0,0,0,-30,-20,310,305},
 ['mugger']={0,0,0,0,0,0,200,220},
 ['gremlin_leader']={35,0,0,0,0,-15,200,310},
 ['torch_head']={0,0,0,0,-5,-20,145,240},
 ['collector']={60,135,0,0,15,-40,300,390},
 ['automaton']={-50,20,0,0,0,-30,270,400},
 ['bronze_orb']={0,0,0,0,0,0,160,160},
 ['champ']={-90,0,0,0,0,-15,400,410},
 ['orb_walker']={-30,20,0,0,-20,-14,280,250},
 ['repulsor']={0,0,0,10,-8,-10,150,150},
 ['spiker']={0,0,0,10,-8,-10,150,150},
 ['exploder']={0,0,0,10,-8,-10,150,150},
 ['maw']={-70,20,0,0,0,-40,430,360},
 ['spire_growth']={0,10,0,0,-10,-35,480,430},
 ['transient']={0,20,0,0,0,-15,370,340},
 ['giant_head']={-70,40,0,0,0,-40,460,300},
 ['nemesis']={0,0,0,0,5,-10,350,440},
 ['reptomancer']={-20,10,0,0,0,-30,220,320},
 ['snake_dagger']={0,0,0,0,0,-50,140,130},
 ['darkling']={0,0,0,20,0,-20,260,200},
 ['awakened_one']={100,15,0,0,40,-30,460,250},
 ['time_eater']={-50,30,0,0,-10,-30,476,410},
 ['deca']={-350,30,0,0,0,-26,390,390},
 ['donu']={100,20,0,0,0,-20,390,390},
 ['writhing_mass']={0,15,0,0,5,-26,450,310},
 ['corrupt_heart']={-50,30,0,0,30,-30,476,410},
 ['spire_shield']={-1000,15,0,0,0,-20,380,290},
 ['spire_spear']={70,10,0,0,0,-15,380,290},
 ['jaw_worm_hard']={0,0,0,0,0,-25,260,170},
}
function M.resolve(actor)
 local definition=definitions[actor.definitionId]
 if not definition then return nil end
 local p=actor.sourcePosition
 local x,y=definition[1],definition[2]
 if p then assert(type(p.x)=='number' and type(p.y)=='number','invalid source position');x,y=p.x,p.y end
 -- TheGuardian.changeState changes only the source hitbox height, not draw position.
 local height=actor.definitionId=='guardian' and actor.aiPhase=='defense' and 250 or definition[8]
 return {x=x+definition[3],y=y+definition[4],hbX=definition[5],hbY=definition[6],width=definition[7],height=height}
end
return M
