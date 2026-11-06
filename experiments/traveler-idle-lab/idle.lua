-- Isolated native-control sample. No battle commands or production state.
-- Motion constants reproduce the project's feedback keys at develop 87c944f3.
local actors, timer, demo, demoTime, attackAge, hitAge, attacker = {}, 0, false, 0, nil, nil, 1
local keys={{0,0},{.06,-8},{.20,16},{.55,0}}
local function clamp(x) return math.max(0,math.min(1,x)) end
local function pose(t)
 for i=2,#keys do
  local a,b=keys[i-1],keys[i]
  if t<b[1] then local p=clamp((t-a[1])/(b[1]-a[1]));p=p*p*(3-2*p);return a[2]+(b[2]-a[2])*p end
 end
 return 0
end
local function child(parent,name) return parent:GetChild(name) end
local function move(n,x,y) n:SetAnchoredPosition(x,y) end
local function reset()
 attackAge,hitAge=nil,nil
 for i,a in ipairs(actors)do move(a.root,a.x,0);a.impact:SetVisible(false) end
end
local function attack(index)
 -- Repeated click replaces the current presentation, never queues unbounded work.
 reset();attacker=index;attackAge=0
 print('idle-lab-attack:'..index)
end
local function idle(a,i)
 local wave=math.sin(timer*math.pi*2/2.8)
 if i==1 then
  move(a.head,0,111+2.4*wave)
  move(a.body,0,1.5*wave)
  a.body:SetLocalScale(1,1+.007*wave,1)
  child(a.root,'cape'):SetLocalRotation(0,0,1.1+1.1*math.sin(timer*math.pi*2/3.4+.4))
  child(a.head,'braid'):SetLocalRotation(0,0,1.4+1.4*math.sin(timer*math.pi*2/3.4+.9))
  child(a.root,'weapon'):SetLocalRotation(0,0,.65+.65*math.sin(timer*math.pi*2/2.8+.2))
  move(child(a.root,'offhand'),-60,31+1.2*wave)
 else
  local w=math.sin(timer*math.pi*2/3.2)
  move(a.body,0,-60+2*w);a.body:SetLocalScale(1+.005*w,1+.01*w,1)
  move(a.head,0,72+3*math.sin(timer*math.pi*2/3.2+.35))
  move(child(a.root,'left'),-106,-34+3*math.sin(timer*math.pi*2/3.2+.6))
  move(child(a.root,'right'),106,-34+3*math.sin(timer*math.pi*2/3.2+2.1))
 end
 local blink=timer%4.7
 local sy=1
 if blink>4.4 and blink<4.58 then sy=1-.9*math.sin((blink-4.4)/.18*math.pi) end
 child(a.head,'eyes'):SetLocalScale(1,sy,1)
end
function OnStart()
 timer,demo,demoTime=0,false,0;actors={}
 for i,name in ipairs({'traveler','monster'})do
  local r=child(script.object,name)
  actors[i]={root=r,x=i==1 and -350 or 350,head=child(r,'head'),body=child(r,'body'),impact=child(r,'impact')}
 end
 reset();script.object.showCursor=true
 child(script.object,'attack'):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()attack(1)end)
 child(script.object,'counter'):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()attack(2)end)
 child(script.object,'auto'):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()demo=not demo;demoTime=0;print('idle-lab-demo:'..tostring(demo))end)
 child(script.object,'reset'):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()demo=false;reset();print('idle-lab-reset')end)
 script:EnableUpdate(true)
 print('traveler-idle-lab-ready:original-primitives:87c944f3')
end
function OnUpdate(dt)
 -- Ignore negative/nonfinite input, cap stalls, preserve monotonic local idle phase.
 if dt~=dt or dt<0 or dt==math.huge then return end
 dt=math.min(dt,.1);timer=timer+dt
 for i,a in ipairs(actors)do idle(a,i) end
 if demo then
  demoTime=demoTime+dt
  if demoTime>=2 then demoTime=0;attack(3-attacker) end
 end
 if hitAge then hitAge=hitAge+dt end
 if attackAge then
  local previous=attackAge;attackAge=attackAge+dt
  local a=actors[attacker];move(a.root,a.x+(attacker==1 and 1 or -1)*pose(attackAge),0)
  if previous<.20 and attackAge>=.20 then hitAge=attackAge-.20 end
  if attackAge>=.55 then move(a.root,a.x,0);attackAge=nil end
 end
 if hitAge then
  local victim=actors[3-attacker]
  local after=math.max(0,hitAge-.05)
  local out=(1-clamp(after/.20))^2
  move(victim.root,victim.x+(attacker==1 and 1 or -1)*12*out,0)
  local flash=hitAge<.05 and 1 or math.max(0,1-after/.12)
  victim.impact:SetVisible(flash>0)
  for i=0,3 do child(victim.impact,'spark'..i).imageColor=math.floor(255*flash)*16777216+15981457 end
  victim.impact:SetLocalScale(.7+flash*.35,.7+flash*.35,1)
  if hitAge>=.25 then move(victim.root,victim.x,0);victim.impact:SetVisible(false);hitAge=nil end
 end
end
function OnDestroy()
 script:EnableUpdate(false);reset();actors={}
end
