-- Visual beats only. Transactions commit through Nodes before this timeline starts.
local Theme=require('abyss_theme')
local L=Theme.layout.nativeNode
local T=L.roomMotion
local M={}
local integer=require('abyss_numbers').integer
local function clamp(n)return math.max(0,math.min(1,n))end
local durations={openTreasure=T.shakeDuration+T.burstDuration+T.revealDuration+3*T.rowStagger,rest=T.restDuration,upgrade=T.forgeDuration}
function M.new(owner,child,options)
 local state={}
 local panel,effect=child('treasureView'),child('roomEffect')
 local function sound(cue)if options.sound then pcall(options.sound,cue)end end
 local function tint(box,c,alpha)
  if options.color then box.imageColor=options.color(c.r,c.g,c.b,math.floor((c.a or 255)*clamp(alpha)))end
 end
 function state:cancel()
  if not self.active and not owner.presentationBusy then return end
  self.active=nil;owner.presentationBusy=nil;effect:SetVisible(false)
  panel:GetChild('burst'):SetVisible(false)
  for _,key in ipairs({'closed','open','glow'})do panel:GetChild(key):SetLocalScale(1,1,1)end
 end
 local function chestPose(a)
  local t=a.time
  local burst=clamp((t-T.shakeDuration)/T.burstDuration)
  local base,target=L.treasure.chest,L.rewardList.chest
  local x=base[1]+(target[1]-base[1])*burst
  local y=base[2]+(target[2]-base[2])*burst
  local shake=t<T.shakeDuration and math.sin(t/T.shakeDuration*math.pi*4)*T.shakeAmplitude or 0
  local squash=t<T.shakeDuration and math.abs(math.sin(t/T.shakeDuration*math.pi*2))*.08 or 0
  panel:GetChild('closed'):SetAnchoredPosition(x+shake,y)
  panel:GetChild('closed'):SetLocalScale(1+squash,1-squash,1)
  local pop=1+(T.popScale-1)*math.sin(burst*math.pi)
  panel:GetChild('open'):SetAnchoredPosition(x,y+math.sin(burst*math.pi)*20)
  panel:GetChild('open'):SetLocalScale(pop,pop,1)
  panel:GetChild('glow'):SetAnchoredPosition(x,y)
  panel:GetChild('glow'):SetLocalScale(1+math.sin(burst*math.pi),1+math.sin(burst*math.pi),1)
  local flash=panel:GetChild('burst')
  flash:SetAnchoredPosition(x,y);flash:SetVisible(t>=T.shakeDuration and burst<1)
  flash:SetLocalScale(.6+burst*1.4,.6+burst*1.4,1)
  tint(flash,Theme.color.goldBright,1-burst)
  panel:GetChild('closed'):SetVisible(t<T.shakeDuration)
  panel:GetChild('open'):SetVisible(t>=T.shakeDuration)
 end
 local function chestRewards(a)
  for i,y in ipairs(L.rewardList.rows)do
   local box=panel:GetChild('rewardItem'..i)
   local p=clamp((a.time-T.shakeDuration-T.burstDuration-(i-1)*T.rowStagger)/T.revealDuration)
   box:SetVisible(a.rows[i] and p>0)
   box:SetLocalScale(.9+.1*p,.9+.1*p,1)
   box:SetAnchoredPosition(L.rewardList.x,y-(1-p)*20)
  end
  for _,key in ipairs({'page','bossDescription'})do panel:GetChild(key):SetVisible(a.time>=T.shakeDuration+T.burstDuration)end
 end
 local function sparks(a,p)
  local burst=clamp((p-.2)/.4)
  for i=1,T.sparkCount do
   local box=effect:GetChild('spark'..i)
   local angle=i/T.sparkCount*math.pi*2
   box:SetVisible(a.kind=='upgrade' and burst>0 and burst<1)
   box:SetAnchoredPosition(math.cos(angle)*burst*T.sparkRadius,40+math.sin(angle)*burst*T.sparkRadius)
   tint(box,Theme.color.goldBright,1-burst)
  end
 end
 local function campPose(a)
  local p=clamp(a.time/a.duration)
  local fade=math.min(1,p*5,(1-p)*5)
  effect:SetVisible(true)
  tint(effect:GetChild('shade'),Theme.color.backdrop,fade*.92)
  effect:GetChild('icon'):SetLocalScale(.9+.15*math.sin(p*math.pi),.9+.15*math.sin(p*math.pi),1)
  effect:GetChild('glow'):SetLocalScale(.8+.4*p,.8+.4*p,1)
  effect:GetChild('title'):SetVisible(p>.2)
  effect:GetChild('description'):SetVisible(p>.35)
  sparks(a,p)
 end
 local function configureEffect(command,before)
  effect:GetChild('title').text=command=='rest' and '休息完成' or '锻造完成'
  effect:GetChild('description').text=command=='rest' and ('生命 +'..integer(owner.run.hp-before.hp)..'  ·  '..integer(owner.run.hp)..' / '..integer(owner.run.maxHp)) or owner.notice
  local icon=effect:GetChild('icon')
  if options.imageSource then icon:SetImage(options.imageSource,command=='rest' and Theme.icon.hp or Theme.icon.upgrade)end
  tint(icon,command=='rest' and Theme.color.positive or Theme.color.goldBright,1)
 end
 function state:paint()
  local a=self.active;if not a then return end
  if owner.run~=a.run or owner.map~=a.map or owner.run.nodeFlow~=a.flow then self:cancel();return end
  if a.kind=='openTreasure' then chestPose(a);chestRewards(a)else campPose(a)end
 end
 function state:start(command,before)
  if not options.enhancedRooms or not durations[command] then return end
  local flow=owner.run.nodeFlow
  if command~='openTreasure' and flow.type~='camp' then return end
  local a={kind=command,time=0,duration=durations[command],run=owner.run,map=owner.map,flow=flow,rows={}}
  for i=1,4 do a.rows[i]=panel:GetChild('rewardItem'..i).visible end
  self.active=a;owner.presentationBusy=true
  configureEffect(command,before)
  self:paint()
 end
 function state:update(dt)
  local a=self.active;if not a then return end
  if not owner.visible or owner.run~=a.run or owner.map~=a.map or owner.run.nodeFlow~=a.flow then self:cancel();return end
  a.time=a.time+math.max(0,dt)
  local cueTime=a.kind=='openTreasure' and T.shakeDuration or a.duration*.3
  if not a.sounded and a.time>=cueTime then
   a.sounded=true;sound(a.kind=='openTreasure' and 'treasure_open' or a.kind=='rest' and 'rest' or 'forge')
  end
  if a.time>=a.duration then self:cancel();owner:render();return end
  self:paint()
 end
 return state
end
return M
