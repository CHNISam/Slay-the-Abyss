-- Actual generated GameUI, native input callbacks and complete run/RNG snapshots.
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local T=H.F.Theme
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function find(list,name)
 for _,c in ipairs(list)do
  if c.name==name then return c end
  local child=find(c.children or {},name);if child then return child end
 end
end
local spec=find(find(H.F.Layout,'battlePanel').children,'card1')
local function readable(card)
 local sx,sy=T.canvas.base[1]/2-T.canvas.safe.x,T.canvas.base[2]/2-T.canvas.safe.y
 local z=card.localScaleX
 assert(card.localRotationZ==0,'moving read frame must stay upright')
 local function inside(x,y,w,h,name)
  assert(card.x+(x-w/2)*z>=-sx-1e-6 and card.x+(x+w/2)*z<=sx+1e-6
   and card.y+(y-h/2)*z>=-sy-1e-6 and card.y+(y+h/2)*z<=sy+1e-6,
   'readable frame outside safe canvas: '..name..' card='..card.x..','..card.y..' scale='..z)
 end
 inside(0,0,T.layout.card.size[1],T.layout.card.size[2],'body')
 for _,name in ipairs({'cost','costCore','name','type','label'})do
  local c,source=card:GetChild(name),find(spec.children,name)
  inside(c.x or source.position[1],c.y or source.position[2],c.sizeDeltaX or source.size[1],c.sizeDeltaY or source.size[2],name)
 end
end
local cases=0
for _,size in ipairs({{1280,720},{2048,1150},{2048,1171},{2048,1152}})do
 for _,touch in ipairs({true,false})do
  local host,ui,panel,event=H.setup({'strike','defend','strike'},nil,{touchScreen=function()return touch end})
  host:resize(size[1],size[2]);host:update(10)
  local card=panel:GetChild('card1');local uid=host.run.combat.hand[1].uid
  local before=H.F.Combat.copy(host.run)
  -- Resting fan may intentionally cross the bottom; do not change its pose.
  assert(card.y-T.layout.card.size[2]/2 < -T.canvas.base[2]/2)
  event('card1','down',7,card.x,card.y)
  for _,pt in ipairs({{-285,100},{-620,330},{620,330},{620,0},{-620,0}})do
   event('dragLayer','drag',7,pt[1],pt[2])
   local g=assert(ui.gesture);assert(g.uid==uid and g.touchScreen==touch)
   assert(math.abs(g.x-pt[1])<1e-6 and math.abs(g.y-pt[2])<1e-6,'display clamp changed pointer')
   readable(card);assert(same(host.run,before),'preview changed run/RNG')
  end
  local enemy=H.F.actorControl(panel,'enemy1')
  event('dragLayer','drag',7,enemy.x,enemy.y)
  assert(ui.gesture.drawnTarget==1 and ui.gesture.uid==uid,'display clamp changed actual target')
  readable(card);assert(same(host.run,before))
  event('dragLayer','drag',7,0,-330);readable(card)
  event('card1','endDrag',7);event('card2','click',7)
  assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil)
  assert(same(host.run,before),'cancel changed run/RNG')
  -- Cancellation suppresses stale same-frame clicks; a real next frame admits a fresh gesture.
  host:update(1/60)
  local hp=host.run.combat.enemies[1].hp
  event('card1','down',8,card.x,card.y);event('card1','drag',8,enemy.x,enemy.y)
  readable(card)
  event('dragLayer','up',8,enemy.x,enemy.y);event('card1','endDrag',8,enemy.x,enemy.y)
  local b=host.run.combat
  assert(b.energy==2 and #b.hand==2 and b.enemies[1].hp==hp-6,'fresh legal release must commit once')
  local committed=H.F.Combat.copy(host.run)
  event('card1','click',8,enemy.x,enemy.y);assert(same(host.run,committed),'duplicate release changed run')
  host:disable();cases=cases+1
 end
end
print('TOUCH_CARD_READING_BOUNDS_PASS '..cases)
