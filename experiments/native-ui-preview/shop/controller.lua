-- Private approved genshin-rooms.js/css shop fixture. No production deck/economy.
-- CSS .13s defaults to ease = cubic-bezier(.25,.1,.25,1).
local order={'cleave','iron_wave','shrug_it_off','shockwave','inflame','impervious','barricade'}
local prices={cleave=50,iron_wave=50,shrug_it_off=50,shockwave=50,inflame=75,impervious=99,barricade=174}
local function ease(x)
 if x<=0 then return 0 end;if x>=1 then return 1 end
 local low,high=0,1
 for i=1,45 do local t=(low+high)/2;local q=1-t;local bx=3*q*q*t*.25+3*q*t*t*.25+t*t*t;if bx<x then low=t else high=t end end
 local t=(low+high)/2;local q=1-t;return 3*q*q*t*.1+3*q*t*t+t*t*t
end
local function begin(b,field,target,immediate)
 local old=b.motion;local value=b[field]
 if old and old.to==target then return end
 if immediate or math.abs(value-target)<.00000001 then b[field]=target;b.motion=nil;return end
 local factor,reverseStart=1,value
 if old and target==old.reverseStart then
  factor=math.min(1,math.abs(ease(math.min(1,old.elapsed/old.duration))*old.factor+(1-old.factor)))
  reverseStart=old.to
 end
 b.motion={field=field,from=value,to=target,elapsed=0,duration=.13*factor,factor=factor,reverseStart=reverseStart}
end
local function advance(b,dt)
 local m=b.motion;if not m then return end
 m.elapsed=math.min(m.duration,m.elapsed+dt)
 b[m.field]=m.from+(m.to-m.from)*ease(m.duration==0 and 1 or m.elapsed/m.duration)
 if m.elapsed>=m.duration then b[m.field]=m.to;b.motion=nil end
end
function NewShopController(root,options)
 options=options or {}
 local input=options.state or {};local state={gold=input.gold or 150,hp=input.hp or 42,maxHp=input.maxHp or 80,sold={}}
 for key,value in pairs(input.sold or {})do if type(key)=='number' then state.sold[value]=true elseif value then state.sold[key]=true end end
 local c={root=root,options=options,state=state,generation=0,active=false,products={},leave={hovered=false,brightness=1},handlers={},reducedMotion=options.reducedMotion==true}
 for _,id in ipairs(order)do c.products[id]={id=id,hovered=false,scale=1}end
 if root then
  c.shop=root:GetChild('shop');c.baseOrder={}
  for _,node in ipairs(c.shop:GetChildren())do c.baseOrder[#c.baseOrder+1]={node=node,index=node:GetSiblingIndex()}end
 end
 function c:hoveredId()for _,id in ipairs(order)do if self.products[id].hovered then return id end end;return self.leave.hovered and 'leave' or nil end
 function c:snapshot()
  local sold={};for _,id in ipairs(order)do if self.state.sold[id]then sold[#sold+1]=id end end
  return {gold=self.state.gold,hp=self.state.hp,maxHp=self.state.maxHp,sold=sold,sourcePage='shop',generation=self.generation,fixtureOnly=true}
 end
 function c:available(id)return self.active and prices[id]~=nil and not self.state.sold[id] and self.state.gold>=prices[id]end
 function c:restoreOrder()
  if self.baseOrder then for _,item in ipairs(self.baseOrder)do item.node:SetSiblingIndex(item.index)end end
 end
 function c:paint()
  if not self.root then return end
  self.shop:SetVisible(self.active)
  self.root:GetChild('hud'):GetChild('gold').text=tostring(self.state.gold)
  self.root:GetChild('hud'):GetChild('hp').text=tostring(self.state.hp)..'/'..tostring(self.state.maxHp)
  self:restoreOrder()
  for _,id in ipairs(order)do
   local p=self.products[id];local node=self.shop:GetChild('product_'..id)
   node:SetLocalScale(p.scale,p.scale,1);node:SetVisible(not self.state.sold[id])
   node:GetChild('hit').raycastTarget=self:available(id)
   node:GetChild('price_'..id):GetChild('amount').fontColor=self.state.gold<prices[id] and 4292705905 or 4294110946
   if p.hovered then node:SetSiblingIndex(#self.baseOrder-1-3)end -- below the three z-index:6 leave controls, above regular stock
  end
  local b=self.leave.brightness;local background=self.shop:GetChild('leaveBackground')
  if b<=1 then background:SetImage(Enum.ImageSource.StaticReference,100192);background.imageColor=4294967295
  else local tint=math.floor(255*b/1.2+.5);background:SetImage(Enum.ImageSource.StaticReference,103146);background.imageColor=4278190080+tint*65793 end
  local function channel(n)return math.min(255,math.floor(n*b+.5))end
  self.shop:GetChild('leaveLabel').fontColor=4278190080+channel(244)*65536+channel(222)*256+channel(142)
  self.shop:GetChild('leaveHit').raycastTarget=self.active
 end
 function c:clearTransient()
  for _,id in ipairs(order)do local p=self.products[id];p.hovered=false;p.scale=1;p.motion=nil end
  self.leave.hovered=false;self.leave.brightness=1;self.leave.motion=nil
  self:paint()
 end
 function c:bind()
  self.handlers={};if not self.root then return end
  local token=self.generation
  local function bind(id,hit)
   hit:RemoveAllCursorEventListeners()
   local function callback(phase)return function()return self:signal(token,id,phase)end end
   self.handlers[id]={enter=callback('enter'),leave=callback('leave'),activate=callback('activate')}
   local e=Enum.CursorEventType
   hit:AddCursorEventListener(e.CursorEnter,self.handlers[id].enter)
   hit:AddCursorEventListener(e.CursorExit,self.handlers[id].leave)
   hit:AddCursorEventListener(e.CursorClick,self.handlers[id].activate)
  end
  for _,id in ipairs(order)do bind(id,self.shop:GetChild('product_'..id):GetChild('hit'))end
  bind('leave',self.shop:GetChild('leaveHit'))
 end
 function c:enter()
  self.generation=self.generation+1;self.active=true;self:clearTransient();self:bind();return self.generation
 end
 function c:signal(token,id,phase)
  if token~=self.generation or not self.active then return false,'stale' end
  if id~='leave' and not self:available(id)then return false,self.state.sold[id] and 'sold' or (prices[id] and 'insufficient-gold' or 'invalid-item')end
  if phase=='enter' or phase=='leave' then
   local on=phase=='enter'
   if on then
    for _,other in ipairs(order)do if other~=id then local p=self.products[other];p.hovered=false;begin(p,'scale',1,self.reducedMotion)end end
    if id~='leave' then self.leave.hovered=false;begin(self.leave,'brightness',1,self.reducedMotion)end
   end
   if id=='leave' then self.leave.hovered=on;begin(self.leave,'brightness',on and 1.2 or 1,self.reducedMotion)
   else local p=self.products[id];p.hovered=on;begin(p,'scale',on and 1.14 or 1,self.reducedMotion)end
   self:paint();return true
  elseif phase=='activate' then
   if id=='leave' then
    self.active=false;self.generation=self.generation+1;self:clearTransient();self:bind()
    local data=self:snapshot();self.navigationRequest={target='map',data=data}
    if self.options.onNavigate then self.options.onNavigate('map',data)end
    return true,'navigated'
   end
   self.state.gold=self.state.gold-prices[id];self.state.sold[id]=true;self:clearTransient();self:bind();return true,'purchased'
  elseif phase=='cancel' then self:clearTransient();return true end
  return false,'unknown-phase'
 end
 function c:tick(dt)
  if not self.active then return end
  dt=math.max(0,dt or 0)
  for _,id in ipairs(order)do advance(self.products[id],dt)end;advance(self.leave,dt);self:paint()
 end
 function c:destroy()self.generation=self.generation+1;self.active=false;self:clearTransient();self:bind()end
 c:enter();return c
end
