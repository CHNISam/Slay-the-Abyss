local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local EnemyView=require('abyss_battle_enemy_view')
local host,ui,panel,event,tap,drain=H.setup({'strike'},{'automaton','bronze_orb','bronze_orb'})
local battle=host.run.combat
local function check()
 local rows=EnemyView.slots(battle)
 assert(rows[2].actor==battle.enemies[1] and rows[2].index==1 and rows[2].id==battle.enemies[1].id,
  'unique Boss occupies center screen slot without changing core identity')
 assert(rows[1].index==2 and rows[3].index==3,'adds retain relative core order')
 local x=panel:GetChild('enemy2').x
 assert(math.abs(x-(require('abyss_theme').layout.enemyRow.zoneLeft+require('abyss_theme').layout.enemyRow.zoneRight)/2)<1e-8)
 return rows
end
check()
local ids={};for index,enemy in ipairs(battle.enemies)do ids[index]=enemy.id end
for screen=1,3 do
 local rows=check();local target=rows[screen].index
 local hp=battle.enemies[target].hp
 host.run.potions[1]='fire_potion';host:refresh()
 assert(ui:usePotion(1));tap('enemy'..screen,100+screen);drain()
 assert(battle.enemies[target].hp==hp-20,'screen slot issues command to original core target')
 for index,id in ipairs(ids)do assert(battle.enemies[index].id==id,'presentation cannot reorder core actors')end
end
print('APPROVED_MAIN_BOSS_SLOTS_PASS center/index/id/targets')
