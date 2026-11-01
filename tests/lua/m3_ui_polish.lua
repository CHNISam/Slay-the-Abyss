local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=require('abyss_theme')
local Enemy=require('abyss_battle_enemy_view')
local function colour(actual,expected)
 assert(actual.r==expected.r and actual.g==expected.g and actual.b==expected.b
  and actual.a==expected.a,'reviewed native colour')
end
local function find(list,name)
 for _,item in ipairs(list)do
  if item.name==name then return item end
  local child=find(item.children or {},name);if child then return child end
 end
end
local cardSpec=find(find(H.F.Layout,'battlePanel').children,'card1')
local corrected,unchanged=0,0
local function readableColumn(card,origin)
 -- Independent native-control oracle for #450's approved reading envelope.
 -- Cost text/ring uses a square with max(width,height), intentionally reserving
 -- 3.5 extra logical half-width for the current 40px native line. This is not
 -- the tightest rectangle union and does not license any further translation.
 local left,right,bottom,top=-Theme.layout.card.size[1]/2,Theme.layout.card.size[1]/2,
  -Theme.layout.card.size[2]/2,Theme.layout.card.size[2]/2
 for _,name in ipairs({'cost','costCore','name','type','label'})do
  local c,source=card:GetChild(name),find(cardSpec.children,name)
  local x,y=c.x or source.position[1],c.y or source.position[2]
  local w,h=c.sizeDeltaX or source.size[1],c.sizeDeltaY or source.size[2]
  if name=='cost' or name=='costCore' then w=math.max(w,h);h=w end
  left,right=math.min(left,x-w/2),math.max(right,x+w/2)
  bottom,top=math.min(bottom,y-h/2),math.max(top,y+h/2)
 end
 local scale=card.localScaleX
 local sx,sy=Theme.canvas.base[1]/2-Theme.canvas.safe.x,Theme.canvas.base[2]/2-Theme.canvas.safe.y
 local lo,hi=-sx-left*scale,sx-right*scale
 local expected=origin
 if origin<lo then expected=lo elseif origin>hi then expected=hi end
 assert(math.abs(card.x-expected)<1e-8,'carry must keep its original column or apply only the minimum reading-frame correction: actual='..card.x..' expected='..expected..' left='..left..' right='..right..' scale='..scale)
 assert(card.y+bottom*scale>=-sy-1e-8 and card.y+top*scale<=sy+1e-8,'full reading frame leaves vertical safe area')
 if expected==origin then unchanged=unchanged+1 else corrected=corrected+1 end
end
for _,settled in ipairs({false,true})do
local host,ui,panel,event=H.setup({'strike','strike'},{'cultist'})
for count=1,5 do
 local enemies={};for i=1,count do enemies[i]='cultist' end
 host.run.combat=H.F.Combat.new(H.F.Data,{deck={'strike','strike'},enemies=enemies,seed=11})
 -- Explicit separated source offsets isolate targeting for repeated test actors;
 -- raw C.new IDs do not invoke a MonsterHelper encounter formation.
 for i,actor in ipairs(host.run.combat.enemies)do actor.sourcePosition={x=-795+(i-1)*240,y=(i%2==1 and -10 or 140)}end
 host:refresh()
 if settled then host:update(10)end -- Also cover a safe, fully dealt original column.
 local battle=host.run.combat
 -- Cultist constructor: hitbox230x240, hb(-8,10), source canvas1920x1080.
 local origin=panel:GetChild('card1').x
 local uid=battle.hand[1].uid
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
  assert(ui.gesture.uid==uid,'reading correction changed held card identity')
  readableColumn(panel:GetChild('card1'),origin)
  assert(math.abs(ui.gesture.x-hitX)<1e-8 and math.abs(ui.gesture.y-hitY)<1e-8,'reading correction changed authoritative pointer')
  colour(layer:GetChild('reticle').imageColor,Theme.color.danger)
  for dot=1,14 do
   local part=layer:GetChild('aim'..dot)
   -- STS star chain: upright square beads; locked tail (last 40%) turns red.
   assert(part.visible and part.sizeDeltaX==part.sizeDeltaY and part.sizeDeltaX<=24)
   if dot==14 then colour(part.imageColor,Theme.color.danger) end
  end
 end
 event('dragLayer','drag',7,0,Theme.layout.hand.y)
 assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil,'return-to-hand cancellation lost')
 assert(battle.energy==3 and #battle.hand==2,'visual inspection or cancellation changed rules')
end
end
assert(corrected>0 and unchanged>0,'both edge correction and safe original-column paths must execute')
print('M3_UI_POLISH_PASS counts=1,2,3,4,5 corrected='..corrected..' unchanged='..unchanged)
