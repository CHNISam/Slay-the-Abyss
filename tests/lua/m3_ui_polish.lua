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
 host:refresh()
 local battle=host.run.combat
 -- Explicit constructor inputs for a synthetic 1..5-member group. Production
 -- positions remain source-authored and never depend on live actor count.
 for i,actor in ipairs(battle.enemies)do actor.sourcePosition={x=-840+(i-1)*240,y=-10}end
 host:refresh()
 local origin=panel:GetChild('card1').x
 event('card1','down',7)
 for i=1,count do
  local box=H.F.actorControl(panel,'enemy'..i)
  local g=Enemy.geometry(battle.enemies[i])
  local x,y=g.hitX,g.hitY
  assert(box.visible and math.abs(box.x-g.x)<1e-8 and math.abs(box.y-g.y)<1e-8,'source constructor position changed')
  local renderedX=Enemy.position(count,i,battle.enemies[i])
  assert(math.abs(renderedX-g.x)<1e-8,'feedback position differs from source actor')
  event('card1','drag',7,x,y)
  assert(ui.gesture.drawnTarget==i,'target identity must switch before decorative interpolation')
  for _=1,20 do host:update(1/60) end -- settle approved endpoint transition before geometric comparison
  local layer=panel:GetChild('dragLayer')
  assert(layer.visible and math.abs(layer:GetChild('reticle').x-g.x)<1e-8,'source aim endpoint differs from actor drawX count='..count..' slot='..i..' expected='..g.x..' actual='..tostring(layer:GetChild('reticle').x)..' moving='..tostring(ui.gesture and ui.gesture.moving))
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
