local actorControl=dofile('tests/lua/support/game_ui_fixture.lua').actorControl
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Run=H.Run
local count=0
for _,valid in ipairs({false,true})do for _,anonymous in ipairs({false,true})do
 local h,u,p,event,tap,drain=H.setup({'defend','defend'},{'cultist','jaw_worm'})
 assert(Run.obtainPotion(h.run,'fire_potion'));local positions=require('abyss_monster_source_positions').positions('Cultist and Chosen');for i,a in ipairs(h.run.combat.enemies)do a.sourcePosition=positions[i]end;h:refresh()
 local touch=not anonymous and 7 or nil
 local enemy=actorControl(p,"enemy2");local hp=h.run.combat.enemies[2].hp
 event('potion1','down',touch);event('potion1','drag',touch,enemy.x,enemy.y)
 assert(u.potionAim and u.potionAim.moving)
 event('dragLayer','up',touch,valid and enemy.x or 0,valid and enemy.y or 0);drain()
 assert(not u.potionAim and not p:GetChild('dragLayer').visible)
 assert(h.run.combat.enemies[2].hp==hp-(valid and 20 or 0))
 assert((h.run.potions[1]==nil)==valid)
 if anonymous then
  p:GetChild('endTurn').click();assert(h.run.combat.turn==1,'first nil-origin potion release Click escaped')
 else
  event('endTurn','click',7);event('endTurn','click',7)
  assert(h.run.combat.turn==1,'repeated named potion release Click escaped')
 end
 p:GetChild('endTurn').click();assert(h.run.combat.turn==2,'independent action could not recover')
 drain()
 if not anonymous then
  event('endTurn','click',7);event('endTurn','click',7)
  assert(h.run.combat.turn==2,'independent action revived potion release origin')
  tap('endTurn',7);assert(h.run.combat.turn==3,'fresh Down failed to reclaim potion release origin')
 end
 count=count+1;print('POTION_DRAG_CLICK_COMPOSITION_CASE '..count)
end end
assert(count==4)
do
 local h,u,p,event,tap,drain=H.setup({'defend','defend'},{'cultist','jaw_worm'})
 assert(Run.obtainPotion(h.run,'fire_potion')and Run.obtainPotion(h.run,'poison_potion'));local positions=require('abyss_monster_source_positions').positions('Cultist and Chosen');for i,a in ipairs(h.run.combat.enemies)do a.sourcePosition=positions[i]end;h:refresh()
 local first,second=actorControl(p,"enemy1"),actorControl(p,"enemy2")
 local hp1,hp2=h.run.combat.enemies[1].hp,h.run.combat.enemies[2].hp
 local bottles=h.run.potions
 -- A foreign press already held before the active drag must not borrow its aim.
 event('potion2','down',8)
 event('potion1','down',7);event('potion1','drag',7,second.x,second.y)
 local aim=assert(u.potionAim);assert(aim.slot==1 and aim.touch==7 and aim.moving)
 local x,y=aim.x,aim.y
 event('potion2','drag',8,first.x,first.y)
 assert(u.potionAim==aim and aim.slot==1 and aim.touch==7 and aim.x==x and aim.y==y,
  'pre-held foreign potion touch stole or redirected the moving aim owner')
 event('dragLayer','up',8,first.x,first.y)
 event('potion2','up',8,first.x,first.y);event('potion2','click',8,first.x,first.y)
 assert(u.potionAim==aim and h.run.potions==bottles and bottles[1]=='fire_potion'and bottles[2]=='poison_potion')
 assert(h.run.combat.enemies[1].hp==hp1 and h.run.combat.enemies[2].hp==hp2)
 -- The actual owning pointer continues and submits once after all foreign events.
 event('potion1','drag',7,second.x,second.y);event('dragLayer','up',7,second.x,second.y);drain()
 assert(not u.potionAim and h.run.potions~=bottles and Run.potionCount(h.run)==1 and h.run.potions[1]==nil and h.run.potions[2]=='poison_potion')
 assert(h.run.combat.enemies[1].hp==hp1 and h.run.combat.enemies[2].hp==hp2-20)
 event('potion2','endDrag',8,first.x,first.y);event('potion2','click',8,first.x,first.y)
 assert(Run.potionCount(h.run)==1 and h.run.potions[1]==nil and h.run.potions[2]=='poison_potion'and h.run.combat.enemies[1].hp==hp1)
 count=count+1;print('POTION_DRAG_CLICK_COMPOSITION_CASE '..count)
end
assert(count==5)
for _,surface in ipairs({'potion2','dragLayer'})do for _,release in ipairs({'up','endDrag'})do
 local h,u,p,event,tap,drain=H.setup({'defend','defend'},{'cultist','jaw_worm'})
 assert(Run.obtainPotion(h.run,'fire_potion')and Run.obtainPotion(h.run,'poison_potion'));local positions=require('abyss_monster_source_positions').positions('Cultist and Chosen');for i,a in ipairs(h.run.combat.enemies)do a.sourcePosition=positions[i]end;h:refresh()
 local first,second=actorControl(p,"enemy1"),actorControl(p,"enemy2")
 local hp1,hp2=h.run.combat.enemies[1].hp,h.run.combat.enemies[2].hp
 local bottles=h.run.potions
 event('potion2','down',8)
 event('potion1','down',7);event('potion1','drag',7,second.x,second.y)
 local aim=assert(u.potionAim);local x,y=aim.x,aim.y
 event(surface,release,8,first.x,first.y)
 assert(u.potionAim==aim and aim.touch==7 and aim.slot==1 and aim.x==x and aim.y==y,
  'foreign terminal event disturbed the live owner')
 assert(h.run.potions==bottles and #bottles==2 and h.run.combat.enemies[1].hp==hp1 and h.run.combat.enemies[2].hp==hp2)
 event('dragLayer','up',7,0,0)
 assert(not u.potionAim and #bottles==2,'owning cancel must not consume a bottle')
 event('potion2','drag',8,first.x,first.y)
 assert(not u.potionAim,'ended foreign token revived a moving aim after '..surface..'/'..release)
 event('potion2','up',8,first.x,first.y);event('potion2','click',8,first.x,first.y)
 assert(not u.potionAim and #bottles==2 and h.run.combat.enemies[1].hp==hp1 and h.run.combat.enemies[2].hp==hp2)
 -- Retiring this ended token must not permanently reject a genuine new press.
 event('potion2','down',8);event('potion2','drag',8,first.x,first.y)
 assert(u.potionAim and u.potionAim.slot==2 and u.potionAim.touch==8)
 event('dragLayer','up',8,0,0)
 assert(not u.potionAim and #bottles==2 and h.run.combat.enemies[1].hp==hp1 and h.run.combat.enemies[2].hp==hp2)
 count=count+1;print('POTION_DRAG_CLICK_COMPOSITION_CASE '..count)
end end
assert(count==9)
print('POTION_DRAG_CLICK_COMPOSITION_PASS 9; controlled/offline only')
