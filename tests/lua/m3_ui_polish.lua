local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=require('abyss_theme')
local Enemy=require('abyss_battle_enemy_view')
local function colour(actual,expected)
 assert(actual.r==expected.r and actual.g==expected.g and actual.b==expected.b
  and actual.a==expected.a,'reviewed native colour')
end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function find(nodes,name)
 for _,node in ipairs(nodes)do
  if node.name==name then return node end
  local child=find(node.children or {},name);if child then return child end
 end
end
local spec=find(find(H.F.Layout,'battlePanel').children,'card1')
local shifted,unchanged=0,0
local function carry(card,origin)
 local sx=Theme.canvas.base[1]/2-Theme.canvas.safe.x
 local sy=Theme.canvas.base[2]/2-Theme.canvas.safe.y
 local z=card.localScaleX
 local left,right=-Theme.layout.card.size[1]/2,Theme.layout.card.size[1]/2
 local function bounds(x,y,w,h)
  assert(card.x+(x-w/2)*z>=-sx-1e-6 and card.x+(x+w/2)*z<=sx+1e-6
   and card.y+(y-h/2)*z>=-sy-1e-6 and card.y+(y+h/2)*z<=sy+1e-6,'reading frame outside safe canvas')
 end
 bounds(0,0,Theme.layout.card.size[1],Theme.layout.card.size[2])
 for _,name in ipairs({'cost','costCore','name','type','label'})do
  local source=find(spec.children,name);local child=card:GetChild(name)
  local x,y=child.x or source.position[1],child.y or source.position[2]
  local w,h=child.sizeDeltaX or source.size[1],child.sizeDeltaY or source.size[2]
  bounds(x,y,w,h)
  -- The cost badge reading frame is square, covering its native line and core.
  if name=='cost' or name=='costCore' then w=math.max(w,h) end
  left,right=math.min(left,x-w/2),math.max(right,x+w/2)
 end
 local expected=math.max(-sx-left*z,math.min(sx-right*z,origin))
 assert(math.abs(card.x-expected)<1e-6,'carry must preserve original column except minimal safe translation')
 if math.abs(expected-origin)<1e-6 then unchanged=unchanged+1 else shifted=shifted+1 end
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
 local before=H.F.Combat.copy(host.run)
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
  before=H.F.Combat.copy(host.run)
  event('card1','drag',7,hitX,hitY)
  assert(same(host.run,before),'target preview changed run/RNG')
  assert(ui.gesture.drawnTarget==i,'target identity must switch before decorative interpolation')
  for _=1,20 do host:update(1/60) end -- settle approved endpoint transition before geometric comparison
  local layer=panel:GetChild('dragLayer')
  assert(layer.visible and math.abs(layer:GetChild('reticle').x-x)<1e-8,'actual target hitbox differs from visual slot count='..count..' slot='..i..' expected='..x..' actual='..tostring(layer:GetChild('reticle').x)..' moving='..tostring(ui.gesture and ui.gesture.moving))
  assert(ui.gesture.drawnTarget==i,'target identity was replaced by presentation position')
  carry(panel:GetChild('card1'),origin)
  assert(ui.gesture.uid==battle.hand[1].uid and math.abs(ui.gesture.x-hitX)<1e-6 and math.abs(ui.gesture.y-hitY)<1e-6,'display translation changed pointer/UID')
  colour(layer:GetChild('reticle').imageColor,Theme.color.danger)
  for dot=1,14 do
   local part=layer:GetChild('aim'..dot)
   -- STS star chain: upright square beads; locked tail (last 40%) turns red.
   assert(part.visible and part.sizeDeltaX==part.sizeDeltaY and part.sizeDeltaX<=24)
   if dot==14 then colour(part.imageColor,Theme.color.danger) end
  end
 end
 before=H.F.Combat.copy(host.run)
 event('dragLayer','drag',7,0,Theme.layout.hand.y)
 assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil,'return-to-hand cancellation lost')
 assert(battle.energy==3 and #battle.hand==2,'visual inspection or cancellation changed rules')
 assert(same(host.run,before),'cancellation changed run/RNG')
 -- A second, interior column must remain unmoved, not be centred unconditionally.
 host:update(1/60)
 before=H.F.Combat.copy(host.run)
 local card=panel:GetChild('card2');local interior=card.x
 local enemy=monsterControl(panel,'enemy1');local hit=enemy:GetChild('hit')
 local px,py=enemy.x+hit.x,enemy.y+hit.y
 event('card2','down',8);event('card2','drag',8,px,py)
 carry(card,interior)
 assert(ui.gesture.drawnTarget==1 and ui.gesture.uid==battle.hand[2].uid)
 assert(same(host.run,before),'interior preview changed run/RNG')
 if count==5 then
 local hp=battle.enemies[1].hp
 event('dragLayer','up',8,px,py);event('card2','endDrag',8,px,py)
 assert(battle.energy==2 and #battle.hand==1 and battle.enemies[1].hp==hp-6,'legal release must commit once')
 local committed=H.F.Combat.copy(host.run)
 event('card2','click',8,px,py);assert(same(host.run,committed),'duplicate release changed run/RNG')
 else
  event('dragLayer','drag',8,0,Theme.layout.hand.y)
  assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil and same(host.run,before),'interior cancellation changed run/RNG')
 end
end
assert(shifted>0 and unchanged>0,'both safe-edge and original-column witnesses required')
print('M3_UI_POLISH_PASS counts=1,2,3,4,5')
