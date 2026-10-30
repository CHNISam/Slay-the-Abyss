local Combat=require('abyss_combat')
local Data=require('abyss_data')
local Actors=require('abyss_actor')
local Controller=require('abyss_controller')
local Target=require('abyss_battle_target_bindings')
local Detail=require('abyss_battle_detail_bindings')
local Native=dofile('tests/lua/support/native_ui_contract.lua')
local Theme=require('abyss_theme')
-- Throw after native registration: exercise callbacks installed before a failed bind.
local failAt,registrations=nil,0
local reentrantRetire
local function registered()
 if failAt then registrations=registrations+1;if registrations==failAt then if reentrantRetire then reentrantRetire() else error('injected native registration failure') end end end
end
local function control(name,parent)
 local c={name=name,parent=parent,children={},listeners={},navigation={},visible=true,alive=true,raycastTarget=true}
 function c:GetChild(n)return assert(self.children[n],self.name..' missing '..n)end
 function c:GetChildren()local a={};for _,v in pairs(self.children)do a[#a+1]=v end;return a end
 function c:AddCursorEventListener(e,f)Native.listener(e,f);assert(not self.listeners[e],self.name..' duplicate '..e);self.listeners[e]=f;registered() end
 function c:AddNavigationEventListener(e,f)Native.listener(e,f);assert(not self.navigation[e]);self.navigation[e]=f;registered() end
 function c:SetControllerNavigation(d,m,t)self['link'..d]=t end
 if parent then parent.children[name]=c end
 return c
end
local function unit(name)
 local c=control(name);control('hit',c);control('intentHit',c);local row=control('statusRow',c);control('hit',row)
 for i=1,Theme.layout.statusIcon.perRow*Theme.layout.statusIcon.rows do control('hit'..i,row)end
 return c
end
local focus,usingController=nil,false
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},modes={Specified='specified'},
 getFocus=function()return focus end,setFocus=function(c)assert(c);focus=c end,isController=function()return usingController end}
local ctl=Controller.new(api)
local battle=Combat.new(Data,{deck={'strike','defend'},enemies={'acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m'},seed=42})
local owner={run={phase='combat',combat=battle},active=true,busy=false,dragEnabled=true,selectionEpoch=0}
local calls={status=0,help=0,down=0,swallowed=0,drag=0,render=0,potion=0,card=0,queue=0,close=0}
function owner:showStatus(index)calls.status=calls.status+1;calls.index=index end
function owner:openHelp(spec)calls.help=calls.help+1;calls.spec=spec end
function owner:queueHelp(spec,source,held,touch)calls.queue=calls.queue+1;self.help={spec=spec,source=source,touch=touch,held=held}end
function owner:render()calls.render=calls.render+1 end
function owner:setHover(value)self.hover=value end
function owner:cardHelpSpec()end
function owner:potionHelpSpec()end
function owner:commitPotion(slot,index)calls.potion=calls.potion+1;calls.index=index end
function owner:playSelected(index)calls.card=calls.card+1;calls.index=index end
local surfaces={entries={},boxes={}}
function surfaces:entry(slot)return self.entries[slot]end
function surfaces:control(slot)return self.boxes[slot]end
function surfaces:slotFor(box)for i,b in pairs(self.boxes)do if b==box then return i end end end
local host={monsterSurfaces=surfaces,controller=ctl,clickEvent='click',cursor={CursorDown='down',CursorUp='up',CursorEndDrag='endDrag',CursorEnter='enter',CursorExit='exit'}}
local ownership={enemyInputs={},enemyPointerObserved=false}
local static={hero=unit('hero'),statusInfo=control('statusInfo')};control('hit',static.statusInfo);control('page',static.statusInfo)
for i=1,10 do static['card'..i]=unit('card'..i)end
for i=1,Theme.layout.battlePotions.count do static['potion'..i]=control('potion'..i);static['potionHelp'..i]=control('potionHelp'..i)end
local deps={}
function deps.child(name)return assert(static[name],'dynamic init must not request '..name)end
function deps.enemyAt(slot)return surfaces:entry(slot)end
function deps.sameEnemySlot(slot,actor)local e=surfaces:entry(slot);return e and e.actor==actor and e.id==actor.id end
function deps.controllerReady()return owner.active and not owner.busy end
function deps.swallowed()calls.swallowed=calls.swallowed+1;return false end
function deps.down()calls.down=calls.down+1;return false end
function deps.consumeReleasedDragClick()calls.drag=calls.drag+1;return false end
function deps.cancelPotionAim()return false end
function deps.discardEnemyPointer(input)input.held=nil;input.released=nil end
-- Deliberately permissive dependency: stale surface fencing must live in bindings themselves.
function deps.enemyReady()return true end
function deps.closeInfo()owner.info=nil;calls.close=calls.close+1;return true end
function deps.listen(c,fn)c:AddCursorEventListener('click',fn);Controller.bind(ctl,c,'battle',fn)end
local target=Target.install(owner,ownership,host,deps);deps.helpActorReady=target.helpActorReady
local detail=Detail.install(owner,ownership,host,deps)
target.bindEnemyControls();detail.bindDetailControls()
local staticRecords=#ctl.records
local function bind(slot,actor,index,box)
 box=box or unit('dynamic'..slot)
 surfaces.boxes[slot]=box;surfaces.entries[slot]={index=index,id=actor.id,actor=actor,controlSlot=slot}
 target.bindEnemyControl(slot,box);detail.bindEnemyDetailControls(slot,box)
 return box
end
local function event(c,kind,touch)if c.listeners[kind]then return c.listeners[kind]({touchId=touch})end end
local function click(c,touch)event(c,'down',touch);event(c,'up',touch);event(c,'click',touch)end

-- No enemy statusRow or fixed chips: dynamic actor binding must only use intent.
local actorBox=control('actor');control('hit',actorBox);control('intentHit',actorBox)
bind(1,battle.enemies[1],1,actorBox)
assert(#ctl.records==staticRecords+2,'enemy should bind only portrait and intent')
local actor=battle.enemies[1];Actors.applyPower(battle,actor,'strength',3,actor);Actors.applyPower(battle,actor,'weak',2,battle.player)
local pool={entries={},boxes={}}
function pool:entry(slot)return self.entries[slot]end
function pool:control(slot)return self.boxes[slot]end
local function chip(id,slot)
 local box=control('power-'..id);control('hit',box)
 pool.entries[slot]={id=id,status={id=id}};pool.boxes[slot]=box
 return box
end
local function bindPower(box,slot)detail.bindEnemyPowerControl(1,slot,box,pool)end
local function retire(box,slot)
 pool.entries[slot]=nil;pool.boxes[slot]=nil
 detail.unbindEnemyPowerControl(box)
end
local strength=chip('strength',1);bindPower(strength,1)
local hit=strength:GetChild('hit');click(hit,101)
assert(calls.spec.statusId=='strength' and calls.spec.index==1 and calls.spec.controlBox==actorBox)
local count=#ctl.records;bindPower(strength,1);assert(#ctl.records==count,'power bind idempotence')
-- Source index moves, actor lifetime and power id stay constant.
battle.enemies[1],battle.enemies[2]=battle.enemies[2],battle.enemies[1]
surfaces.entries[1].index=2
click(hit,102);assert(calls.spec.index==2)
local helpCount=calls.help
require('abyss_power_schedule').remove(battle,actor,'strength');actor.statuses.strength=nil
click(hit,103);assert(calls.help==helpCount,'removed power must reject retained input')
Actors.applyPower(battle,actor,'strength',3,actor)
local callbacks={}
local function retain(box)
 for _,fn in pairs(box:GetChild('hit').listeners)do callbacks[#callbacks+1]=function()fn({touchId=104})end end
 for _,fn in pairs(box:GetChild('hit').navigation)do callbacks[#callbacks+1]=fn end
end
retain(strength);event(hit,'down',104);retire(strength,1)
local weak=chip('weak',1);bindPower(weak,1)
owner.help={source=static.card1:GetChild('hit')};owner.info={source=static.card1:GetChild('hit'),transient=true}
local function total()local n=0;for k,v in pairs(calls)do if type(v)=='number' and k~='index' then n=n+v end end;return n end
local baseline=total();usingController=true;focus=hit
for _,fn in ipairs(callbacks)do ctl:tick();fn()end
assert(total()==baseline and owner.help and owner.info,'retired power callbacks changed unrelated UI')
usingController=false;ctl:tick();click(weak:GetChild('hit'),105);assert(calls.spec.statusId=='weak')
retire(weak,1)
local preserved={};for c,r in pairs(ctl.byControl)do preserved[c]=r end
local preservedCount=#ctl.records
local function unchanged()
 assert(#ctl.records==preservedCount,'power binding leaked records')
 for c,r in pairs(ctl.byControl)do assert(preserved[c]==r,'power binding leaked byControl')end
 for c,r in pairs(preserved)do assert(ctl.byControl[c]==r,'power cleanup removed actor/hero/card record')end
end
failAt=100000;registrations=0
local probe=chip('strength',1);bindPower(probe,1);local sites=registrations
failAt=nil;retire(probe,1);unchanged();assert(sites>=8)
for mode=1,2 do
 for n=1,sites do
  local box=chip('strength',1);registrations=0;failAt=n
  if mode==2 then reentrantRetire=function()retire(box,1)end end
  local ok,err=pcall(function()bindPower(box,1)end)
  failAt=nil;reentrantRetire=nil
  if mode==1 then assert(not ok and tostring(err):find('injected native registration failure',1,true))
  else assert(ok,tostring(err));assert(registrations==n,'continued registering after power retirement');unchanged()end
  callbacks={};retain(box);retire(box,1);unchanged()
  local replacement=chip('weak',1);bindPower(replacement,1)
  owner.help={source=static.card1:GetChild('hit')};owner.info={source=static.card1:GetChild('hit'),transient=true}
  baseline=total();usingController=true;focus=box:GetChild('hit')
  for _,fn in ipairs(callbacks)do ctl:tick();fn()end
  assert(total()==baseline and owner.help and owner.info,'failed/retired power callback affected replacement or card')
  usingController=false;ctl:tick();retire(replacement,1);unchanged()
 end
end
local last=chip('strength',1);bindPower(last,1);baseline=total()
surfaces.boxes[1]=control('replacement-actor');click(last:GetChild('hit'),106)
assert(total()==baseline,'old actor box activated power')
surfaces.boxes[1]=actorBox
local priorBattle=owner.run.combat;owner.run.combat=Combat.new(Data,{deck={'strike'},enemies={'acid_slime_m'},seed=42})
click(last:GetChild('hit'),107);assert(total()==baseline,'old combat activated power')
owner.run.combat=priorBattle;retire(last,1);unchanged()
print('DYNAMIC_POWER_INPUT_PASS throw_sites='..sites..' retire_sites='..sites)
