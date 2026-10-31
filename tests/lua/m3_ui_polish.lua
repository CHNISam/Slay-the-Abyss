local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=require('abyss_theme')
local Enemy=require('abyss_battle_enemy_view')
local function colour(actual,expected)
 assert(actual.r==expected.r and actual.g==expected.g and actual.b==expected.b
  and actual.a==expected.a,'reviewed native colour')
end
local host,ui,panel,event=H.setup({'strike','strike'},{'cultist'})
for count=1,5 do
 local enemies={};for i=1,count do enemies[i]='cultist' end
 host.run.combat=H.F.Combat.new(H.F.Data,{deck={'strike','strike'},enemies=enemies,seed=11})
 -- Explicit separated source offsets isolate targeting for repeated test actors;
 -- raw C.new IDs do not invoke a MonsterHelper encounter formation.
 for i,actor in ipairs(host.run.combat.enemies)do actor.sourcePosition={x=-795+(i-1)*240,y=(i%2==1 and -10 or 140)}end
 host:refresh()
 local battle=host.run.combat
 -- Cultist constructor: hitbox230x240, hb(-8,10), source canvas1920x1080.
 local origin=panel:GetChild('card1').x
 event('card1','down',7)
 for i=1,count do
  local box=monsterControl(panel,'enemy'..i)
  local actor=battle.enemies[i]
  local x=(1440+actor.sourcePosition.x)/1.5-640
  local y=(require('abyss_battle_enemy_view').floorY+actor.sourcePosition.y)/1.5-360+240/3
  assert(box.visible and math.abs(box.x-x)<1e-8 and math.abs(box.y-y)<1e-8,'visible enemy row changed')
  local renderedX=Enemy.position(count,i,battle.enemies[i])
  assert(math.abs(renderedX-x)<1e-8,'feedback position differs from visible enemy')
  local hit=box:GetChild('hit')
  assert(math.abs(hit.sizeDeltaX-230/1.5)<1e-8 and math.abs(hit.sizeDeltaY-240/1.5)<1e-8,'source hitbox changed')
  local hitX,hitY=x-8/1.5,(require('abyss_battle_enemy_view').floorY+actor.sourcePosition.y+10+240/2)/1.5-360
  assert(math.abs(x+hit.x-hitX)<1e-8 and math.abs(y+hit.y-hitY)<1e-8,'native hitbox differs from source constructor')
  event('card1','drag',7,hitX,hitY)
  assert(ui.gesture.drawnTarget==i,'target identity must switch before decorative interpolation')
  for _=1,20 do host:update(1/60) end -- settle approved endpoint transition before geometric comparison
  local layer=panel:GetChild('dragLayer')
  assert(layer.visible and math.abs(layer:GetChild('reticle').x-x)<1e-8,'actual target hitbox differs from visual slot count='..count..' slot='..i..' expected='..x..' actual='..tostring(layer:GetChild('reticle').x)..' moving='..tostring(ui.gesture and ui.gesture.moving))
  assert(ui.gesture.drawnTarget==i,'target identity was replaced by presentation position')
  assert(panel:GetChild('card1').x==origin,'first UI batch broke original-column carry')
  colour(layer:GetChild('reticle').imageColor,Theme.color.danger)
  for dot=1,14 do
   local part=layer:GetChild('aim'..dot)
   -- STS arrow: a locked target turns the whole shaft and head red.
   assert(part.visible and part.sizeDeltaY<=30)
   colour(part.imageColor,Theme.color.danger)
  end
 end
 event('dragLayer','drag',7,0,Theme.layout.hand.y)
 assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil,'return-to-hand cancellation lost')
 assert(battle.energy==3 and #battle.hand==2,'visual inspection or cancellation changed rules')
end
print('M3_UI_POLISH_PASS counts=1,2,3,4,5')
