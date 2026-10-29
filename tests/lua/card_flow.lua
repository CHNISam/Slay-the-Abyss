package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Flow=require('abyss_card_flow')
local Theme=require('abyss_theme')
local function control()
 local c={visible=false,children={}}
 function c:GetChild(name)self.children[name]=self.children[name]or control();return self.children[name]end
 function c:SetVisible(v)self.visible=v end
 function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
 function c:SetLocalScale(x,y)self.sx,self.sy=x,y end
 function c:SetImage()end
 return c
end
local root=control()
local flow=Flow.new(root,{color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,imageSource='static'})
local catalog={cards={strike={type='attack',name='打击'},inflame={type='power',name='燃烧'}}}
local function frame(hand,draw,discard,exhaust)return{hand=hand or{},draw=draw or{},discard=discard or{},exhaust=exhaust or{},catalog=catalog}end
local a={uid=1,cardId='strike'}
flow:playing(a,{tx=200,ty=50})
flow:sync(frame(),frame(nil,nil,{a}),nil,true)
assert(flow.waiting[1].uid==1 and flow.waiting[1].to=='discard')
assert(flow.waiting[1].start[1]==200)
flow:update(Theme.motion.slow,catalog,{})
local trail=root:GetChild('feedback'):GetChild('cardTrail1')
assert(trail.visible and trail.x==Theme.layout.discardPile.position[1])
assert(trail.y==Theme.layout.discardPile.position[2])
flow:update(0.01,catalog,{})
assert(not trail.visible and not flow:busy())
flow:sync(frame({a}),frame(nil,nil,nil,{a}))
assert(flow.waiting[1].to=='exhaust')
flow:update(Theme.motion.slow,catalog,{})
assert(trail.x==Theme.layout.topBar.exhaustIcon[1] and trail.y==Theme.layout.topBar.y)
flow:reset()
flow:sync(frame(nil,nil,{a}),frame(nil,{a}), 'reshuffle')
assert(flow.waiting[1].from=='discard'and flow.waiting[1].to=='draw')
flow:reset()
flow:sync(frame({a}),frame({a}),'enemy_turn')
assert(flow.waiting[1].to=='retain')
flow:reset()
local power={uid=2,cardId='inflame'}
flow:playing(power,{tx=-300,ty=40})
flow:sync(frame(),frame(),nil,true)
assert(flow.waiting[1].to=='power'and flow.waiting[1].uid==2)
flow:reset()
local batch={};for i=1,25 do batch[i]={uid=i,cardId='strike'}end
flow:sync(frame(batch),frame(nil,nil,batch))
flow:update(0,catalog,{})
local count=0;for _ in pairs(flow.active)do count=count+1 end
assert(count==10 and #flow.waiting==15)
flow:reset();assert(not flow:busy()and next(flow.inPlay)==nil)
for slot=1,10 do assert(not root:GetChild('feedback'):GetChild('cardTrail'..slot).visible)end
print('ok card_flow - UID destinations, endpoints, retain, power, shuffle and bounded pool')
