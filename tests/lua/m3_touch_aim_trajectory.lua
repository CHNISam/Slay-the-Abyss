local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local Target=require('abyss_battle_targeting')
local h,u,p,e=H.setup({'strike'}, {'cultist','jaw_worm'}, {touchScreen=function()return true end})
h.run.combat.enemies[1].sourcePosition={x=-250,y=0}
h.run.combat.enemies[2].sourcePosition={x=100,y=0}
h:refresh()
local card=p:GetChild('card1')
local targeting=Target.install(u,{}, {},{dragReady=function()return true end})
e('card1','down',7)
local g=u.gesture
local y=g.dropStart-1
e('card1','drag',7,-285,y)
local beforeX,beforeY=card.x,card.y
e('card1','drag',7,-285,y+2)
assert(u.gesture.aiming,'trajectory must cross the real aiming boundary')
assert(math.abs(card.x-beforeX)<1 and math.abs(card.y-beforeY)<5,'mobile aim boundary teleported the held card')
local px,py=targeting.dragPose(g)
assert(math.abs(card.x-px)<0.001 and math.abs(card.y-py)<0.001,'mobile held pose disagrees with dragPose')
local layer=p:GetChild('dragLayer');local reticle=layer:GetChild('reticle')
assert(reticle.x==g.x and reticle.y==g.y,'untargeted reticle must identify the authoritative pointer')
assert(not card:GetChild('glow').visible,'empty ground must not guess the nearest enemy')
local enemy=monsterControl(p,'enemy2')
local entry=require('abyss_battle_enemy_view').slots(h.run.combat)[2]
local actor=entry.actor;local hp=actor.hp
local rx,_,_,_,ry=targeting.enemyPosition(h.run.combat,entry.index)
e('dragLayer','drag',7,enemy.x,enemy.y)
assert(card:GetChild('glow').visible and reticle.x==rx and reticle.y==ry and g.drawnTarget==entry.index,'preview must use the pointer hit target')
px,py=targeting.dragPose(g)
assert(card.x==px and card.y==py,'target acquisition parked the held mobile card')
e('dragLayer','up',7,enemy.x,enemy.y)
assert(actor.hp==hp-6 and h.run.combat.energy==2,'release disagrees with preview')
e('card1','endDrag',7,enemy.x,enemy.y);e('card1','click',7,enemy.x,enemy.y)
assert(actor.hp==hp-6 and h.run.combat.energy==2,'old pointer submitted twice')
print('M3_TOUCH_AIM_TRAJECTORY_PASS')
