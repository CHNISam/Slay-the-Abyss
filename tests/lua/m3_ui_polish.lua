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
 -- Main.dc.html: zoneL=1010, zoneR=1850; front=min(190,round(slot*1.1)).
 -- Keep this live gesture test on the approved source geometry, not the retired row.
 local sourceStep=(1850-1010)/count
 local front=math.min(190,math.floor(sourceStep*1.1+.5))
 local origin=panel:GetChild('card1').x
 event('card1','down',7)
 for i=1,count do
  local box=panel:GetChild('enemy'..i)
  local portrait=i%2==1 and front or math.floor(front*.86+.5)
  local x=(1010+sourceStep*(i-.5))/1.5-640
  local y=360-((i%2==1 and 300 or 180)+58+16+portrait/2)/1.5
  assert(box.visible and math.abs(box.x-x)<1e-8 and math.abs(box.y-y)<1e-8,'visible enemy row changed')
  local renderedX=Enemy.position(count,i,battle.enemies[i])
  assert(math.abs(renderedX-x)<1e-8,'feedback position differs from visible enemy')
  event('card1','drag',7,x,y)
  local layer=panel:GetChild('dragLayer')
  assert(layer.visible and math.abs(layer:GetChild('reticle').x-x)<1e-8,'actual target hitbox differs from visual slot')
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
