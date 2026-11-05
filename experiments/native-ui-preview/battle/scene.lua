local S=require('semantic')
local Arrow=require('approved_arrow')
local GestureModule=require('abyss_battle_card_gestures')
local BindingModule=require('abyss_battle_card_bindings')
local InputState=require('abyss_battle_input_state')
local ActionBindings=require('abyss_battle_action_bindings')
local TargetBindings=require('abyss_battle_target_bindings')
local inputState,actionBindings,targetBindings
local geometry=setmetatable({},{__mode='k'})
-- Production CardView handValues pattern, adapted to the approved 150x210
-- fan. Keep the world hit rectangle stable across idle, hover (+32/1.12)
-- and selection (+54/1.13), including the actual candidate's larger lift.
local function handValues(p)
 local w,h=150,210
 local r=p.goal.restAngle*math.pi/180
 local c,s=math.abs(math.cos(r)),math.abs(math.sin(r))
 local restH,restW=(h*c+w*s)/2,(w*c+h*s)/2
 local hoverH,selectedH=h*1.12/2,h*1.13/2
 local low=math.min(p.goal.baseY-restH,p.goal.baseY+32-hoverH,p.goal.baseY+54-selectedH)
 local high=math.max(p.goal.baseY+restH,p.goal.baseY+32+hoverH,p.goal.baseY+54+selectedH)
 local dy,angle=(low+high)/2-p.y,p.r*math.pi/180
 return {p.x,p.y,p.s,p.r,math.sin(angle)*dy/p.s,math.cos(angle)*dy/p.s,
  math.max(restW*2,w*1.13)/p.s,(high-low)/p.s}
end
local function sameValues(a,b)
 for i=1,8 do if a[i]~=b[i]then return false end end;return true
end
local function applyPose(p)
 local box=p.box;local hit=box:GetChild('hit');local old=geometry[box]
 local values,uid=handValues(p),p.uid
 if old and old.values and old.uid==uid and old.hit[1]==hit and box.alive~=false
  and hit.alive~=false and sameValues(old.values,values) then return end
 local pending={};geometry[box]=pending
 local ok,accepted=pcall(function()
  local accepted=box:SetAnchoredPosition(values[1],values[2])~=false
  accepted=box:SetLocalScale(values[3],values[3],1)~=false and accepted
  box.localRotationZ=values[4]
  accepted=hit:SetAnchoredPosition(values[5],values[6])~=false and accepted
  accepted=hit:SetSizeDelta(values[7],values[8])~=false and accepted
  accepted=hit:SetLocalScale(1,1,1)~=false and accepted
  hit.localRotationZ=-values[4]
  return accepted
 end)
 local current=geometry[box]==pending;geometry[box]=nil
 if not ok then error(accepted,0)end
 if accepted and current and p.box==box and box:GetChild('hit')==hit and p.uid==uid
  and box.alive~=false and hit.alive~=false and sameValues(values,handValues(p))then
  geometry[box]={values=values,uid=uid,hit=setmetatable({hit},{__mode='v'})}
 end
end
local root,battle,hud,a,owner,gestures,bindings,host,ownership
local positions,poses,faces={},{},{}
local clock,stage,lastFrame=0,0,nil
local function cardNode(i)return battle:GetChild('hand'..(i-1))end
local function image(node,id)node:SetImage(Enum.ImageSource.StaticReference,id)end
local function setFace(box,instance)
 local id=instance.cardId;local def=a.run.combat.catalog.cards[id];local skill=def.type=='skill'
 image(box:GetChild('body'),skill and 100125 or 100124);image(box:GetChild('portrait'),skill and 100142 or 100141)
 image(box:GetChild('typeIcon'),skill and 100131 or 100130);image(box:GetChild('rarityFrame'),skill and 100127 or 100126)
 box:GetChild('cardName').text=def.name;box:GetChild('cardType').text=skill and '技能' or '攻击';box:GetChild('cost').text=tostring(def.cost)
 local line1,line2=id=='bash' and '对目标造成 8 点伤害，' or skill and '为自己增加' or '对目标造成',id=='bash' and '再施加 2 回合易伤。' or skill and '5 点格挡。' or '6 点伤害。'
 box:GetChild('description0').text=line1;box:GetChild('description1').text=line2
end
local function setHp(box,hp,max)
 box:GetChild('number').text=tostring(hp)..'/'..tostring(max)
 box:GetChild('fill'):SetSizeDelta(152*hp/max,9)
 local x,y=box:GetChild('track'):GetAnchoredPosition();box:GetChild('fill'):SetAnchoredPosition(x-(152-152*hp/max)/2,y)
end
local function ready(g)return a:ready(g)end
local function target(g)
 if not ready(g)then return false end
 local b=g.battle;local ok,why=S.Combat.canPlay(b,g.uid,nil);if not ok and why~='invalid_target'then return false end
 local hovered
 for i,e in ipairs(b.enemies)do if e.hp>0 and math.abs(g.x-(245.5+(i-1)*220))<=95 and math.abs(g.y+53.5)<=100 then hovered=i;break end end
 S.input.sample(g,g.x,g.y,hovered,not ok)
 if g.cancelled then return false,nil,g.aiming end
 if ok then return g.dropZone,nil,false end
 return g.aiming and hovered~=nil and S.Combat.canPlay(b,g.uid,hovered) or false,hovered,g.aiming
end
local function renderDrag(valid,index,aiming,resolved)
 local g=owner.gesture or owner.carry
 local layer=root:GetChild('dragLayer');layer:SetVisible(g~=nil and g.moving==true)
 local capture=owner.gesture~=nil
 layer:GetChild('hit'):SetVisible(capture)
 layer.disableCursorEventPassthrough=capture
 if not g or not g.moving then Arrow.render(root:GetChild('aimLayer'),nil);return end
 if not resolved then valid,index,aiming=target(g)end
 local box=cardNode(g.slot);local x,y=g.x,g.y
 -- Continuous 80px pickup easing is preserved from production targeting.
 local dist=math.sqrt((g.x-g.sx)^2+(g.y-g.sy)^2);local t=math.max(0,math.min(1,dist/80));local k=t*t*(3-2*t)
 local lift=g.touchScreen and 180 or 0
 x=x+(g.grabDx or 0)*(1-k);y=y+(g.grabDy or 0)+(lift-(g.grabDy or 0))*k
 if aiming and not g.touchScreen then x,y=g.origin[1],g.origin[2]+54 end
 x,y=math.max(-545,math.min(545,x)),math.max(-235,math.min(215,y))
 geometry[box]=nil;box:SetAnchoredPosition(x,y);owner.cardPositions[g.uid]={x,y};box:SetLocalScale(1.13,1.13,1);box.localRotationZ=0;box:SetAsLastSibling()
 -- Approved SVG begins 25px below the top of the selected card.
 local sx,sy=x,y+210*1.13/2-25
 if aiming then Arrow.render(root:GetChild('aimLayer'),Arrow.geometry(sx,sy,g.x,g.y))else Arrow.render(root:GetChild('aimLayer'),nil)end
 g.drawn,g.drawnValid,g.drawnTarget,g.drawnAiming=true,valid,index,aiming
end
local function paint()
 local f=a.display;local b=a.run.combat
 hud:GetChild('hp').text=f.player.hp..'/'..f.player.maxHp;hud:GetChild('gold').text=tostring(f.player.gold)
 battle:GetChild('energy').text=f.energy..'/3'
 setHp(battle:GetChild('heroHp'),f.player.hp,f.player.maxHp)
 battle:GetChild('draw'):GetChild('count').text=tostring(#f.draw);battle:GetChild('discard'):GetChild('count').text=tostring(#f.discard)
 for i,e in ipairs(f.enemies)do setHp(battle:GetChild('enemyHp'..(i-1)),e.hp,e.maxHp)end
 owner.cardPositions={}
 local seen={}
 for i=1,10 do
  local box=cardNode(i);local instance=f.hand[i];box:SetVisible(instance~=nil)
  if instance then
   seen[instance.uid]=true
   if faces[i]~=instance.uid then setFace(box,instance);faces[i]=instance.uid end
   local n=#f.hand;local x=(i-(n+1)/2)*124;local y=-290-math.abs(i-(n+1)/2)*6;local hot=owner.selected==instance.uid or owner.hover==i
   local goal={baseY=y,restAngle=-(i-(n+1)/2)*4,x=x,y=y+(hot and (owner.selected==instance.uid and 54 or 32) or 0),s=hot and (owner.selected==instance.uid and 1.13 or 1.12) or 1,r=hot and 0 or -(i-(n+1)/2)*4}
   local p=poses[instance.uid]or{x=x,y=y,s=1,r=goal.r};poses[instance.uid]=p;p.goal=goal;p.uid=instance.uid;if p.box~=box then geometry[box]=nil end;p.box=box
   owner.cardPositions[instance.uid]={p.x,p.y};positions[instance.uid]={x,y}
   if not ((owner.gesture or owner.carry)and(owner.gesture or owner.carry).uid==instance.uid)then
    applyPose(p)
   end
  end
 end
 for uid in pairs(poses)do if not seen[uid]then poses[uid]=nil end end
 renderDrag()
end
local function beginSemantic(slot)
 local g=a:capture(slot,false);if not g then return end
 g.input=ownership.cardInputs[slot];g.input.held=g;g.touch='semantic-not-pointer';g.moving=true
 owner.gesture,owner.selected=g,g.uid;return g
end
local function aimSemantic(index)
 local g=owner.gesture;if not g then return end
 g.x,g.y=245.5+(index-1)*220,-53.5
 target(g);paint()
end
local function status(text)root:GetChild('status'):GetChild('label').text=text end
local function cancelSemantic()
 a:cancel(owner.gesture);owner.gesture,owner.carry,owner.selected,owner.hover=nil,nil,nil,nil;paint()
end
function OnStart()
 root=script.object;battle=root:GetChild('battle');hud=root:GetChild('hud')
 local w,h=game.GetUICanvasSize();local scale=math.min(w/1280,h/720);root:SetLocalScale(scale,scale,1)
 local started=os.clock();a=S.new();print('RULES_READY init_ms='..((os.clock()-started)*1000))
 owner={run=a.run,active=true,busy=false,canvasWidth=w,canvasHeight=h,cardPositions={},dragEnabled=true}
 ownership={cardInputs={},actionInputs={},potionInputs={},enemyInputs={}}
 host={platform={touchScreen=function()return false end,cursorPosition=game.GetCursorUIPos},cursor=Enum.CursorEventType,
 clickEvent=Enum.CursorEventType.CursorClick,options={},stage=battle,cardView={renderDrag=renderDrag}}
 -- These two approved native surfaces stay at fixed core indices, including
 -- a defeated actor; do not compact EnemyView slots onto a different picture.
 host.monsterSurfaces={
  control=function(_,slot)return slot<=2 and battle:GetChild('enemyWrapper'..slot) or nil end,
  entry=function(_,slot)local actor=owner.run.combat.enemies[slot];if actor then return {index=slot,id=actor.id,actor=actor}end end}
 inputState=InputState.install(owner,ownership,host,{})
 function owner:render()
 owner.busy=a.busy
 if owner.carry and (not inputState.cardReady(owner.carry) or owner.selected~=owner.carry.uid) then owner.carry=nil end
 paint()
 end
 function owner:showStatus(index)self.target=index end
 function owner:setHover(i)if not self.gesture and not self.busy then self.hover=i;paint()end end
 function owner:queueHelp()end
 function owner:cardHelpSpec()return{}end
 function owner:playSelected(index)
  local slot
  for i,c in ipairs(a.run.combat.hand)do if c.uid==self.selected then slot=i;break end end
  if not slot then return false end
  local g=self.gesture or self.carry or a:capture(slot,true)
  local flight=root:GetChild('playedCard');setFace(flight,a.run.combat.hand[slot])
  local ok,why=a:submit(g,index,'candidate_'..(a.commandCount+1))
  if ok then
   flight:SetVisible(true);self.gesture,self.carry,self.selected,self.hover=nil,nil,nil,nil
   print('RUN_PLAY accepted command_ms='..a.lastCommandMs..' count='..a.commandCount)
  else print('RUN_PLAY rejected reason='..tostring(why))end
  self:render();return ok,why
 end
 function owner:playSlot(slot)
  if not self.active or self.busy or self.gesture or self.suppressClick or self.run.phase~='combat' then return end
  local c=a.run.combat.hand[slot];if not c then return end
  self.selectionEpoch=(self.selectionEpoch or 0)+1
  if self.selected==c.uid then self.selected=nil;self:render();return end
  if not S.Combat.canPlay(a.run.combat,c.uid,self.target or 1)then self:render();return end
  self.selected=c.uid;self:render()
 end
 local deps={closeInfo=function()return false end,cardReady=inputState.cardReady,dragTarget=target,notice=function()end,
  cancelCardInputs=inputState.cancelCardInputs,cancelActionInputs=inputState.cancelActionInputs,
  cancelPotionInputs=inputState.cancelPotionInputs,cancelPotionAim=inputState.cancelPotionAim,
  refresh=function()owner:render()end,rewardScreen=inputState.rewardScreen}
 gestures=GestureModule.install(owner,ownership,host,deps)
 local function child(name)
  if name=='dragLayer' or name=='playArea' then return root:GetChild(name)end
  return cardNode(tonumber(name:match('%d+')))
 end
 local ad={child=child,point=gestures.point,swallowed=gestures.swallowed,down=gestures.down,
  cardReady=inputState.cardReady,actionReady=inputState.actionReady,
  consumeReleasedDragClick=inputState.consumeReleasedDragClick,controllerReady=gestures.controllerReady,
  inPlayArea=function(x,y)return math.abs(x)<610 and y>-170 and y<230 end}
 actionBindings=ActionBindings.install(owner,ownership,host,ad)
 local bd={child=child,point=gestures.point,controllerReady=gestures.controllerReady,
  retireInterruptedPress=gestures.retireInterruptedPress,down=gestures.down,move=gestures.move,
  release=gestures.release,cancelPotionAim=inputState.cancelPotionAim,listen=actionBindings.listen}
 bindings=BindingModule.install(owner,ownership,host,bd);bindings.bindCardControls()
 for i=1,10 do local slot=i;local hit=cardNode(i):GetChild('hit')
  hit:AddCursorEventListener(Enum.CursorEventType.CursorEnter,function()owner:setHover(slot)end)
  hit:AddCursorEventListener(Enum.CursorEventType.CursorExit,function()if owner.hover==slot then owner:setHover(nil)end end)
 end
 targetBindings=TargetBindings.install(owner,ownership,host,{
  enemyAt=inputState.enemyAt,enemyReady=inputState.enemyReady,discardEnemyPointer=inputState.discardEnemyPointer,
  consumeReleasedDragClick=inputState.consumeReleasedDragClick,controllerReady=gestures.controllerReady,
  swallowed=gestures.swallowed,down=gestures.down,cancelPotionAim=inputState.cancelPotionAim})
 for i=1,2 do targetBindings.bindEnemyControl(i,battle:GetChild('enemyWrapper'..i))end
 actionBindings.bind('playArea',function()owner:playSelected(nil)end)
 owner:render();script:EnableUpdate(true)
 print('INTERACTIVE_READY real_Run=true real_Combat=true mature_gestures_bound=true approved_dashed_arrow=true pointer_events=0 official_game_verified=false partial_feedback=true')
end
function OnUpdate(dt)
 -- Presentation-only time: a stalled frame must not violate the adapter bound.
 -- Run/Combat commands have already committed; never replay them to catch up.
 dt=math.min(.1,math.max(0,dt))
 clock=clock+dt
 if owner.gesture then owner.gesture.elapsed=(owner.gesture.elapsed or 0)+dt end
 gestures.updateCarry()
 local prior=a.current;a:update(dt);owner.busy=a.busy
 if prior~=a.current then paint()end
 for uid,p in pairs(poses)do
  if not ((owner.gesture or owner.carry)and(owner.gesture or owner.carry).uid==uid)then
   local k=math.min(1,dt*14);for _,f in ipairs({'x','y','s','r'})do local delta=p.goal[f]-p[f];p[f]=math.abs(delta)<.001 and p.goal[f] or p[f]+delta*k end
   applyPose(p);owner.cardPositions[uid]={p.x,p.y}
  end
 end
 local flight=root:GetChild('playedCard');local entry=a.current
 if a.busy and entry and entry.kind=='play'then
  local p=math.min(1,a.age/.2);local q=p*p;local origin=a.origin or{0,-230};local tx,ty=245.5,-53.5
  local target=entry.detail.target;if target and type(target)=='number'then tx=245.5+(target-1)*220 end
  flight:SetVisible(true);flight:SetAnchoredPosition(origin[1]+(tx-origin[1])*q,origin[2]+(ty-origin[2])*q+50*math.sin(p*math.pi));local s=1.13-.6*q;flight:SetLocalScale(s,s,1);flight.localRotationZ=-14*p
 else flight:SetVisible(false)end
 local fx=root:GetChild('effects');for i=1,2 do fx:GetChild('float'..i):SetVisible(false)end;fx:GetChild('block'):SetVisible(false)
 for _,e in ipairs(a.effects)do
  if e.kind=='damage'then for i,enemy in ipairs(a.run.combat.enemies)do if e.target==enemy.id then local f=fx:GetChild('float'..i);f:SetVisible(true);f.text='−'..tostring(e.amount);f:SetAnchoredPosition(245.5+(i-1)*220,-18+e.age*55);f.fontColor=math.floor(255*(1-e.age/.6))*16777216+0xffce72;local actor=battle:GetChild('fungi'..(i-1));actor:SetAnchoredPosition(245.5+(i-1)*220+math.sin(e.age*70)*5*math.max(0,1-e.age/.15),-53.5)end end
  elseif e.kind=='block'then local f=fx:GetChild('block');f:SetVisible(true);f.text='格挡 +'..tostring(e.amount or a.run.combat.player.block);f:SetAnchoredPosition(-324,-90+e.age*45)end
 end
 if AUTO_SEMANTIC_DEMO then
  if stage==2 and owner.gesture then
   local g=owner.gesture;local t=math.max(0,math.min(1,(clock-1)/.6));local k=t*t*(3-2*t)
   g.x=-185+(245.5+185)*k;g.y=-180+126.5*k;target(g);renderDrag()
  elseif stage==3 and owner.gesture and clock>=2 then
   local g=owner.gesture;local t=math.min(1,(clock-2)/.4);g.x=245.5+220*t;g.y=-53.5;target(g);renderDrag()
  end
  if stage==0 and clock>=.4 then owner:setHover(1);status('无输入程序验帧：原生抬牌');stage=1;print('DEMO hover')
  elseif stage==1 and clock>=1 then local g=beginSemantic(1);g.x,g.y=-185,-180;target(g);paint();status('无输入程序验帧：提牌与定稿红色虚线');stage=2;print('DEMO lifted')
  elseif stage==2 and clock>=1.6 then aimSemantic(1);status('无输入程序验帧：瞄准敌人一');stage=3;print('DEMO aimed_one')
  elseif stage==3 and clock>=2.4 then aimSemantic(2);status('无输入程序验帧：切换目标');stage=4;print('DEMO aimed_two')
  elseif stage==4 and clock>=3.1 then owner:playSelected(2);status('真实 Run.play：出牌与结算帧');stage=5;print('DEMO play')
  elseif stage==5 and clock>=3.7 and not a.busy then local slot=a:find('strike');beginSemantic(slot);aimSemantic(1);stage=6;status('第二张牌：上次飘字尾部独立保留');print('DEMO second_aim')
  elseif stage==6 and clock>=4.2 then cancelSemantic();status('取消后回手，不花费能量');stage=7;print('DEMO cancelled')
  elseif stage==7 and clock>=4.9 then local slot=a:find('defend');owner.selected=a.run.combat.hand[slot].uid;owner:playSelected(nil);status('真实 Run.play：防御与格挡');stage=8;print('DEMO defend')
  elseif stage==8 and clock>=5.7 and not a.busy then status('候选局部验证结束 · 未做触屏命中或官方实机验收');stage=9;print('DEMO_COMPLETE no_pointer=true commands='..a.commandCount..' energy='..a.run.combat.energy..' block='..a.run.combat.player.block)end
 end
end
