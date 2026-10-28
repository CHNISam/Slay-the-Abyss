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
 local row=Theme.layout.enemyRow
 local xFrom=row.xFromFew
 local step=count>1 and (row.xTo-xFrom)/(count-1) or 0
 local origin=panel:GetChild('card1').x
 event('card1','down',7)
 for i=1,count do
  local box=panel:GetChild('enemy'..i)
  local x=count==1 and (xFrom+row.xTo)/2 or xFrom+(i-1)*step
  local y=row.y+(count>3 and (i%2==0 and row.frontOffset or row.backOffset) or 0)
  assert(box.visible and box.x==x and box.y==y,'accepted two-row enemy geometry changed')
  local renderedX,_,_,_,renderedY=Enemy.position(count,i,battle.enemies[i])
  assert(renderedX==x and renderedY==y,'feedback position differs from visible enemy')
  event('card1','drag',7,x,y)
  local layer=panel:GetChild('dragLayer')
  assert(layer.visible and layer:GetChild('reticle').x==x and layer:GetChild('reticle').y==y,'actual target hitbox differs from visual slot')
  assert(ui.gesture.drawnTarget==i,'target identity was replaced by presentation position')
  assert(panel:GetChild('card1').x==origin,'first UI batch broke original-column carry')
  colour(layer:GetChild('reticle').imageColor,Theme.color.danger)
  for dot=1,14 do
   local part=layer:GetChild('aim'..dot)
   assert(part.visible and math.abs(part.sizeDeltaX-(8+16*dot/14))<1e-9)
   colour(part.imageColor,dot/14>0.6 and Theme.color.danger or Theme.color.goldBright)
  end
 end
 event('dragLayer','drag',7,0,Theme.layout.hand.y)
 assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil,'return-to-hand cancellation lost')
 assert(battle.energy==3 and #battle.hand==2,'visual inspection or cancellation changed rules')
end
print('M3_UI_POLISH_PASS counts=1,2,3,4,5')
