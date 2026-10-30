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
 if not box then box=control('dynamic'..slot);control('hit',box);control('intentHit',box) end
 surfaces.boxes[slot]=box;surfaces.entries[slot]={index=index,id=actor.id,actor=actor,controlSlot=slot}
 target.bindEnemyControl(slot,box);detail.bindEnemyDetailControls(slot,box)
 return box
end
local function event(c,kind,touch)if c.listeners[kind]then return c.listeners[kind]({touchId=touch})end end
local function click(c,touch)event(c,'down',touch);event(c,'up',touch);event(c,'click',touch)end
local boxes={};for i,actor in ipairs(battle.enemies)do boxes[i]=bind(i,actor,i)end
local perActor=2 -- Portrait targeting and intent only; powers have their own lifetime fixture.
assert(#ctl.records==staticRecords+7*perActor,'all seven actors bind, no five limit')
for i=1,7 do click(boxes[i]:GetChild('hit'),i);assert(calls.index==i)end
-- A surface created from a feedback snapshot must remain usable after actual actor replaces it.
local shadowInitial={};for k,v in pairs(battle.enemies[2])do shadowInitial[k]=v end
surfaces.entries[2].actor=shadowInitial
local extra=bind(8,shadowInitial,2)
surfaces.entries[8].actor=battle.enemies[2]
click(extra:GetChild('hit'),82);assert(calls.index==2)
surfaces.entries[8]=nil;surfaces.boxes[8]=nil;target.unbindEnemyControl(8,extra);detail.unbindEnemyDetailControls(8,extra)
local before=#ctl.records;target.bindEnemyControl(7,boxes[7]);detail.bindEnemyDetailControls(7,boxes[7]);assert(#ctl.records==before,'idempotent one handle binding')
-- Existing static controls remain active, cards and potions preserve hover/help initialization.
event(static.hero:GetChild('hit'),'click',1);assert(calls.index==0)
event(static.card1:GetChild('hit'),'enter',1);assert(owner.hover==1);event(static.card1:GetChild('hit'),'exit',1);assert(owner.hover==nil)
-- A feedback snapshot changes actor object identity but not stable actor identity.
local original=battle.enemies[3];local shadow={};for k,v in pairs(original)do shadow[k]=v end
surfaces.entries[3].actor=shadow;owner.busy=true;owner.busy=false;surfaces.entries[3].actor=original
click(boxes[3]:GetChild('hit'),33);assert(calls.index==3,'snapshot replacement must not permanently disable a surface')
-- Manager entry/core insertion index changes; stable actor surface must target current core index.
table.insert(battle.enemies,1,table.remove(battle.enemies,7))
local staleCount=calls.status
click(boxes[7]:GetChild('hit'),70)
assert(calls.status==staleCount,'stale list index must not retarget a different core actor')
for slot,e in pairs(surfaces.entries)do for i,a in ipairs(battle.enemies)do if a.id==e.id then e.index=i;e.actor=a end end end
click(boxes[7]:GetChild('hit'),71);assert(calls.index==1,'target current original list index, not slot')
local intent=boxes[7]:GetChild('intentHit');click(intent,73);assert(calls.spec.index==1 and calls.spec.controlBox==boxes[7])
-- Controller cleanup must leave unrelated static card/hero state and callback identity intact.
local kept=static.hero:GetChild('hit');ctl.memory.battle=kept
usingController=true;ctl:sync('battle');ctl:tick();focus=boxes[7]:GetChild('hit');focus.navigation.confirm();assert(calls.index==1)
usingController=false;ctl:tick()
local old=boxes[7];local oldHit=old:GetChild('hit');event(oldHit,'down',74);event(intent,'down',75)
local captured={};local function save(c)
 for kind,fn in pairs(c.listeners)do captured[#captured+1]=function()fn({touchId=74})end end
 for kind,fn in pairs(c.navigation)do captured[#captured+1]=fn end
 for _,child in pairs(c.children)do save(child)end
end;save(old)
-- Retire entries BEFORE cleanup, matching the manager contract.
surfaces.boxes[7]=nil;surfaces.entries[7]=nil
owner.info={source=static.card1:GetChild('hit'),transient=true};owner.help={source=static.card1:GetChild('hit')}
target.unbindEnemyControl(7,old);detail.unbindEnemyDetailControls(7,old)
assert(#ctl.records==staticRecords+6*perActor and ctl.byControl[kept] and ctl.memory.battle==kept,'precise subtree controller removal')
assert(owner.info and owner.help,'unrelated card help must survive actor cleanup')
local replacement=bind(7,battle.enemies[2],2)
local function total()local n=0;for k,v in pairs(calls)do if type(v)=='number'and k~='index'then n=n+v end end;return n end
local baseline=total();usingController=true;focus=oldHit
for _,fn in ipairs(captured)do ctl:tick();fn()end
assert(total()==baseline,'destroyed callbacks changed new UI or targeted reused slot')
assert(ownership.enemyInputs[7],'retired surface cleanup erased replacement input')
usingController=false;ctl:tick();click(replacement:GetChild('hit'),76);assert(calls.index==2)
-- Partial-bind retirement owns every controller record before any fallible native
-- registration. Exercise every target/intent registration site; powers are tested separately.
local preserved={};for c,r in pairs(ctl.byControl)do preserved[c]=r end
local preservedCount=#ctl.records
local cardHit=static.card1:GetChild('hit');local cardEnter=cardHit.listeners.enter
local function retireProbe(box)
 surfaces.boxes[9]=nil;surfaces.entries[9]=nil
 target.unbindEnemyControl(9,box);detail.unbindEnemyDetailControls(9,box)
end
failAt=100000;registrations=0
local probe=bind(9,battle.enemies[2],2);local registrationCount=registrations
failAt=nil;retireProbe(probe)
assert(registrationCount==15,'expected seven target and eight intent registration sites')
for fail=1,registrationCount do
 local box=control('failed'..fail);control('hit',box);control('intentHit',box)
 registrations=0;failAt=fail
 local ok,err=pcall(function()bind(9,battle.enemies[2],2,box)end)
 failAt=nil
 assert(not ok and tostring(err):find('injected native registration failure',1,true),'missing injected failure '..fail)
 local oldCallbacks={}
 local function retain(c)
  for _,fn in pairs(c.listeners)do oldCallbacks[#oldCallbacks+1]={control=c,fn=function()fn({touchId=901})end}end
  for _,fn in pairs(c.navigation)do oldCallbacks[#oldCallbacks+1]={control=c,fn=fn}end
  for _,child in pairs(c.children)do retain(child)end
 end
 retain(box)
 owner.help={source=cardHit};owner.info={source=cardHit,transient=true};ctl.memory.battle=kept
 retireProbe(box)
 assert(#ctl.records==preservedCount,'partial bind leaked controller records at registration '..fail)
 for c,r in pairs(ctl.byControl)do assert(preserved[c]==r,'partial bind leaked byControl entry at registration '..fail)end
 for c,r in pairs(preserved)do assert(ctl.byControl[c]==r,'partial bind removed unrelated controller entry')end
 assert(ownership.enemyInputs[9]==nil and ctl.memory.battle==kept,'partial bind retained input or removed shared focus')
 assert(owner.help.source==cardHit and owner.info.source==cardHit and cardHit.listeners.enter==cardEnter,'partial bind changed card controls/help')
 local fresh=bind(9,battle.enemies[2],2)
 local count=total();usingController=true
 for _,callback in ipairs(oldCallbacks)do focus=callback.control;ctl:tick();callback.fn()end
 assert(total()==count,'partial bind retained active stale callback at registration '..fail)
 assert(owner.help.source==cardHit and owner.info.source==cardHit,'stale callback cleared unrelated help')
 usingController=false;ctl:tick();retireProbe(fresh)
end
for fail=1,registrationCount do
 local box=control('retired'..fail);control('hit',box);control('intentHit',box)
 registrations=0;failAt=fail
 owner.help={source=cardHit};owner.info={source=cardHit,transient=true};ctl.memory.battle=kept
 reentrantRetire=function()retireProbe(box)end
 local ok,err=pcall(function()bind(9,battle.enemies[2],2,box)end)
 failAt=nil;reentrantRetire=nil
 assert(ok,'reentrant retirement failed '..fail..': '..tostring(err))
 assert(registrations==fail,'registration continued after retirement at '..fail)
 assert(#ctl.records==preservedCount,'reentrant retirement leaked controller records at '..fail)
 local oldCallbacks={}
 local function retain(c)
  for _,fn in pairs(c.listeners)do oldCallbacks[#oldCallbacks+1]={control=c,fn=function()fn({touchId=901})end}end
  for _,fn in pairs(c.navigation)do oldCallbacks[#oldCallbacks+1]={control=c,fn=fn}end
  for _,child in pairs(c.children)do retain(child)end
 end
 retain(box)
 owner.help={source=cardHit};owner.info={source=cardHit,transient=true};ctl.memory.battle=kept
 retireProbe(box)
 assert(#ctl.records==preservedCount,'partial bind leaked controller records at registration '..fail)
 for c,r in pairs(ctl.byControl)do assert(preserved[c]==r,'partial bind leaked byControl entry at registration '..fail)end
 for c,r in pairs(preserved)do assert(ctl.byControl[c]==r,'partial bind removed unrelated controller entry')end
 assert(ownership.enemyInputs[9]==nil and ctl.memory.battle==kept,'partial bind retained input or removed shared focus')
 assert(owner.help.source==cardHit and owner.info.source==cardHit and cardHit.listeners.enter==cardEnter,'partial bind changed card controls/help')
 local fresh=bind(9,battle.enemies[2],2)
 local count=total();usingController=true
 for _,callback in ipairs(oldCallbacks)do focus=callback.control;ctl:tick();callback.fn()end
 assert(total()==count,'partial bind retained active stale callback at registration '..fail)
 assert(owner.help.source==cardHit and owner.info.source==cardHit,'stale callback cleared unrelated help')
 usingController=false;ctl:tick();retireProbe(fresh)
end
print('REENTRANT_RETIRE_SITES='..registrationCount)
print('PARTIAL_BIND_FAILURE_SITES='..registrationCount)
-- Cross-battle same IDs cannot activate an old surface before lifecycle cleanup runs.
local newer=Combat.new(Data,{deck={'strike'},enemies={'acid_slime_m','acid_slime_m'},seed=42})
owner.run.combat=newer;baseline=total();click(replacement:GetChild('hit'),77);event(replacement:GetChild('intentHit'),'enter',78)
assert(total()==baseline,'old battle identity remained usable')
-- Standalone controller record generation guard rejects retained callback after unbind/rebind.
local c=control('rebind');local n=0;Controller.bind(ctl,c,'battle',function()n=n+1 end);local oldConfirm=c.navigation.confirm
Controller.unbind(ctl,c);c.navigation={};Controller.bind(ctl,c,'battle',function()n=n+100 end)
usingController=true;focus=c;ctl.scope='battle';ctl:tick();oldConfirm();assert(n==0,'old controller closure used replacement record')
ctl:tick();c.navigation.confirm();assert(n==100)
print('DYNAMIC_MONSTER_INPUT_BINDINGS_PASS')
