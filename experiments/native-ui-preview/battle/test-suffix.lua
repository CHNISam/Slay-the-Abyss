OnStart()
assert(#ownership.cardInputs==10 and #ownership.enemyInputs==2 and #ownership.actionInputs==1)
-- Semantic calls only. Registered native listeners are never invoked.
owner:playSlot(2);assert(owner.selected==a.run.combat.hand[2].uid and a.commandCount==0)
owner:playSlot(2);assert(owner.selected==nil and a.commandCount==0)
owner:playSlot(2)
for i=1,120 do OnUpdate(1/60)end
local uid=owner.selected
assert(owner.cardPositions[uid][2]==poses[uid].y and poses[uid].y==poses[uid].goal.y)
local before=writes;for i=1,120 do OnUpdate(1/60)end;assert(writes==before,'steady hand wrote geometry')
local token={name='playArea',run=owner.run,phase=owner.run.phase,battle=owner.run.combat,turn=owner.run.combat.turn,slot=2,uid=uid,selectionEpoch=owner.selectionEpoch}
assert(inputState.actionReady(token));owner:playSlot(2);assert(not inputState.actionReady(token))
local g=a:capture(1,false);assert(inputState.cardReady(g));g.turn=g.turn-1;assert(not inputState.cardReady(g))
g=a:capture(1,false);g.moving=true;owner.carry=g;owner.selected=g.uid;renderDrag()
assert(root:GetChild('dragLayer'):GetChild('hit').visible==false)
assert(root:GetChild('dragLayer').disableCursorEventPassthrough==false)
owner.gesture=g;owner.carry=nil;renderDrag()
assert(root:GetChild('dragLayer'):GetChild('hit').visible==true)
owner.gesture=nil;owner.selected=nil;owner:render()
for i=1,120 do OnUpdate(1/60)end
before=writes;OnUpdate(1/60);assert(writes==before)
local p=poses[a.run.combat.hand[1].uid];geometry[p.box]=nil;p.box.fail=true;applyPose(p);assert(geometry[p.box]==nil);p.box.fail=false;applyPose(p);assert(geometry[p.box]~=nil)
p.x=p.x+1;p.box.throw=true;assert(not pcall(applyPose,p));assert(geometry[p.box]==nil);p.box.throw=false;applyPose(p);assert(geometry[p.box])
p.x=p.x+1;p.box.nested=function()p.y=p.y+1;applyPose(p)end;applyPose(p);assert(geometry[p.box]==nil);applyPose(p);assert(geometry[p.box])
local oldHit=p.box:GetChild('hit')
p.box.children.hit=node('hit');local replacement=p.box:GetChild('hit');before=writes;applyPose(p)
assert(writes>before and geometry[p.box].hit[1]==replacement,'replacement hit must repaint')
replacement.fail=true;p.x=p.x+1;applyPose(p);assert(geometry[p.box]==nil);replacement.fail=false;applyPose(p)
replacement.throw=true;p.x=p.x+1;assert(not pcall(applyPose,p));assert(geometry[p.box]==nil);replacement.throw=false;applyPose(p)
replacement.nested=function()p.r=p.r+1;applyPose(p)end;p.x=p.x+1;applyPose(p);assert(geometry[p.box]==nil);applyPose(p)
-- Pure geometry only: reconstruct the resulting world axis-aligned hit rectangle.
local function worldRect(pose)
 local v=handValues(pose);local r=v[4]*math.pi/180
 return v[1]+v[3]*(math.cos(r)*v[5]-math.sin(r)*v[6]),
  v[2]+v[3]*(math.sin(r)*v[5]+math.cos(r)*v[6]),v[3]*v[7],v[3]*v[8]
end
local q={x=-248,y=-302,s=1,r=8,goal={baseY=-302,restAngle=8}}
local x,y,w,h=worldRect(q);assert(math.abs(-335-x)<=w/2 and math.abs(-209-y)<=h/2)
for _,pose in ipairs({{-270,1.12,0},{-248,1.13,0},{-286,1.065,4}})do
 q.y,q.s,q.r=table.unpack(pose)
 local a,b,c,d=worldRect(q)
 assert(math.abs(a-x)<1e-9 and math.abs(b-y)<1e-9 and math.abs(c-w)<1e-9 and math.abs(d-h)<1e-9)
 assert(math.abs(-335-a)<=c/2 and math.abs(-209-b)<=d/2,'hover edge must remain hittable')
end
print('PASS hover union counterexample, invariant world rectangle, replacement hit, hit false/throw/reentry')
owner:render();for i=1,120 do OnUpdate(1/60)end
-- Direct adapter method with a coordinate data object, never dispatch a native event.
local slot=1;local instance=a.run.combat.hand[slot];local origin=owner.cardPositions[instance.uid]
local sample={GetUIPos=function()return 640,70 end}
local drag=a:capture(slot,false);bindings.beginCardDrag(drag,instance,a.run.combat,sample)
assert(drag.origin==origin and drag.grabDx==origin[1] and drag.grabDy==origin[2]+290)
owner.gesture=nil;owner:render()
owner:playSlot(2);local commands=a.commandCount;owner:playSelected(nil);assert(a.commandCount==commands+1)
-- A stalled native frame must not abort feedback or execute the command again.
for _,dt in ipairs({.101,.25,1})do
 local beforeClock=clock;OnUpdate(dt)
 assert(math.abs(clock-beforeClock-.1)<1e-9,'long presentation frame must be bounded')
 assert(a.commandCount==commands+1,'long frame repeated a command')
end
local beforeClock=clock;OnUpdate(0);OnUpdate(-.1)
assert(clock==beforeClock,'nonpositive frame must not rewind presentation')
for i=1,180 do OnUpdate(1/60)end
assert(not a.busy)
print('PASS bounded long frames resume feedback without repeated commands')
print('PASS semantic selection/cancel; stale ownership; live geometry; steady idle zero setters; carry capture visibility; failed setter retry; explicit Run.play')
print('NO native callbacks, pointer events, mouse/key/focus/click/runCase dispatched')
