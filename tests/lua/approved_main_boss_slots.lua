local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local EnemyView=require('abyss_battle_enemy_view')
local host,ui,panel,event,tap,drain=H.setup({'strike'},{'automaton','bronze_orb','bronze_orb'})
local battle=host.run.combat
local surfaces=assert(require('abyss_monster_surfaces').get(panel))
-- This synthetic group uses the original Automaton summon constructor positions.
battle.enemies[2].sourcePosition={x=-300,y=200}
battle.enemies[3].sourcePosition={x=200,y=130}
host:refresh()
local function check()
 local rows=EnemyView.slots(battle)
 for i,entry in ipairs(rows)do
  assert(entry.actor==battle.enemies[i] and entry.index==i and entry.id==battle.enemies[i].id,
   'MonsterGroup render order is core order; no visual boss recentering')
 end
 local x=assert(surfaces:find(battle.enemies[1].id)).x
 assert(math.abs(x-((1440-50)/1.5-640))<1e-8,'Automaton retains constructor drawX')
 return rows
end
check()
local ids={};for index,enemy in ipairs(battle.enemies)do ids[index]=enemy.id end
for screen=1,3 do
 local rows=check();local target=rows[screen].index
 local hp=battle.enemies[target].hp
 host.run.potions[1]='fire_potion';host:refresh()
 assert(ui:usePotion(1))
 local _,slot=surfaces:find(battle.enemies[target].id)
 assert(slot,'target actor lost its native surface');tap('enemy'..slot,100+screen);drain()
 assert(battle.enemies[target].hp==hp-20,'screen slot issues command to original core target')
 for index,id in ipairs(ids)do assert(battle.enemies[index].id==id,'presentation cannot reorder core actors')end
end
print('APPROVED_MAIN_BOSS_SLOTS_PASS original-positions/index/id/targets')
