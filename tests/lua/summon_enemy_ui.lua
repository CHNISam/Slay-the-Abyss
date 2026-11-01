local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local C,A=require('abyss_combat'),require('abyss_actor')
local Theme=require('abyss_theme')
local Surfaces=require('abyss_monster_surfaces')
local Powers=require('abyss_monster_power_surfaces')
local function idleBounds(portrait)
 local idle=Theme.motion.actorIdle
 return math.abs(portrait.x)<=idle.sway and math.abs(portrait.y)<=idle.lift
  and math.abs(portrait.localScaleX-1)<=idle.scale+1e-9
  and math.abs(portrait.localScaleY-1)<=idle.scale+1e-9
end
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
end
local function indexOf(s,actor)for i,e in ipairs(s.enemies)do if e==actor then return i end end end
local function shown(panel,actor)
 local box,slot=assert(Surfaces.get(panel)):find(actor.id)
 if box and box.visible then return slot,box end
end
local function fixture(kind)
 local h,u,p,event,tap,drain=H.setup({'strike','strike','strike','strike','strike'},{'cultist'})
 local members=kind=='leader' and {'mad_gremlin','sneaky_gremlin','gremlin_leader'} or {'collector'}
 local s=C.new(H.F.Data,{deck={'strike','strike','strike','strike','strike'},enemies=members,seed=42,hp=1000,maxHp=1000})
 local boss=s.enemies[#s.enemies]
 h.run.combat,h.run.hp,h.run.maxHp=s,1000,1000
 -- Real turn AI creates replacements. Dead actors remain in the authoritative array.
 for _=1,30 do
  for _,e in ipairs(s.enemies)do if e~=boss and A.isActive(e)then C.damage(s,s.player,e,999,true)end end
  assert(C.endTurn(s))
  if #s.enemies>=7 then break end
 end
 assert(#s.enemies>=7 and indexOf(s,boss)>5,'source summons did not retain enough corpses')
 h:refresh()
 return h,u,p,event,tap,drain,s,boss
end
local function part(box,kind,touch)
 local callback=box.listeners and box.listeners[kind]
 if callback then return callback({touchId=touch}) end
end
test('Leader and Collector keep every live HP intent and status panel after repeated source summons',function()
 for _,kind in ipairs({'leader','collector'})do
  local h,u,p,_,_,_,s,boss=fixture(kind)
  local slot,box=shown(p,boss);assert(slot,'living '..kind..' disappeared after retained corpses')
  assert(box:GetChild('hp').text==tostring(boss.hp)..'/'..tostring(boss.maxHp))
  dofile('tests/lua/support/intent_face_assertion.lua')(box,require('abyss_battle_intent_view').intentView(s,indexOf(s,boss)))
  local count,live=0,0
  Surfaces.get(p):each(function(box)if box.visible then count=count+1 end end)
  for _,e in ipairs(s.enemies)do if A.isActive(e)then live=live+1 end end
  assert(count==live,'a living actor was silently omitted')
  A.applyPower(s,boss,'strength',2,boss);h:refresh()
  assert(u:showStatus(indexOf(s,boss)))
  assert(u.info and u.info.index==indexOf(s,boss) and u.info.id==boss.id,'status help used the display slot as actor index')
  p:GetChild('statusInfo'):GetChild('hit').click({touchId=40});assert(not u.info)
  local chip=assert(Powers.get(box:GetChild('statusRow')):find('strength')):GetChild('hit')
  part(chip,'down',41);part(chip,'up',41);part(chip,'click',41)
  assert(u.info and u.info.index==indexOf(s,boss) and u.info.statusId=='strength','status chip used the display slot as actor index')
 end
end)
test('click targets true Leader index and damage feedback paints its displayed actor',function()
 local h,u,p,_,tap,drain,s,boss=fixture('leader')
 local slot,box=shown(p,boss);assert(slot,'Leader not displayed')
 local hp=boss.hp;tap('card1',1);tap('enemy'..slot,2)
 assert(u.target==indexOf(s,boss) and boss.hp==hp-6,'click damaged a corpse or another actor')
 local seen=false
 for _=1,200 do
  local current=u.feedback.current
  if current and current.kind=='damage' and current.detail.target==boss.id then
   local displayed,painted=shown(p,boss);assert(displayed and painted:GetChild('floating').text:find('6',1,true))
   assert(painted:GetChild('floating').visible,'feedback painted an unrelated raw index')
   seen=true;break
  end
  h:update(.05)
 end
 assert(seen,'real damage feedback was not reached');drain()
 assert(not u.busy and #s.enemies>=7)
end)
test('Collector replacement drag reticle and landing use original fixed coordinates and true target index',function()
 local h,u,p,event,_,drain,s,boss=fixture('collector')
 local live={};for _,e in ipairs(s.enemies)do if e~=boss and A.isActive(e)then live[#live+1]=e end end
 local victim=live[2];local _,beforeBox=shown(p,victim)
 local beforeX,beforeY=beforeBox.x,beforeBox.y
 C.damage(s,s.player,live[1],999,true);h:refresh()
 local slot,box=shown(p,victim);assert(slot,'surviving Torch not displayed')
 assert(box==beforeBox and box.x==beforeX and box.y==beforeY,'death must not reallocate or reflow a surviving actor')
 local expectedX=(1440+victim.sourcePosition.x)/1.5-640
 assert(math.abs(box.x-expectedX)<1e-8,'survivor moved away from original constructor drawX')
 local target=indexOf(s,victim);local hp=victim.hp
 event('card1','down',5);event('card1','drag',5,box.x,box.y)
 local ring=p:GetChild('dragLayer'):GetChild('reticle')
 assert(ring.visible and ring.x==box.x,'reticle follows corpse-count coordinates')
 event('card1','up',5,box.x,box.y)
 assert(u.target==target and victim.hp==hp-6,'drag committed the display slot')
 assert(u.feedback.flight and u.feedback.flight.tx==box.x,'card landed at raw array coordinates')
 drain();assert(not u.busy)
end)
test('retired portrait and help presses cannot follow a reused slot in the same turn',function()
 local h,u,p,event,tap,_,s,boss=fixture('leader')
 local living={};for _,e in ipairs(s.enemies)do if A.isActive(e)then living[#living+1]=e end end
 C.damage(s,s.player,living[2],1,true);h:refresh()
 local kept=living[2];local oldSlot,oldBox=shown(p,kept);assert(oldSlot)
 tap('enemy'..oldSlot,60);assert(u.target==indexOf(s,kept))
 p:GetChild('statusInfo'):GetChild('hit').click({touchId=60});assert(not u.info)
 event('enemy'..oldSlot,'down',61)
 local help=oldBox:GetChild('intentHit');part(help,'down',62)
 local oldX,oldY=oldBox.x,oldBox.y
 C.damage(s,s.player,living[1],999,true);h:refresh()
 local stableSlot,stableBox=shown(p,kept)
 assert(stableSlot==oldSlot and stableBox==oldBox and oldBox.x==oldX and oldBox.y==oldY,
  'another actor dying must not reflow or replace the held survivor')
 event('enemy'..oldSlot,'up',61);event('enemy'..oldSlot,'click',61)
 assert(u.target==indexOf(s,kept),'surviving portrait press lost its actor')
 assert(u.info and u.info.id==kept.id,'surviving portrait details lost ownership')
 p:GetChild('statusInfo'):GetChild('hit').click({touchId=61})
 part(help,'up',62);part(help,'click',62)
 assert(u.info and u.info.id==kept.id and u.info.kind=='intent','surviving intent press lost ownership')
 p:GetChild('statusInfo'):GetChild('hit').click({touchId=62});assert(not u.info)
 event('enemy'..oldSlot,'down',65);part(help,'down',66)
 -- Keep queued native callbacks, even after native unbind removes listeners.
 local hit=oldBox.listeners and oldBox or oldBox:GetChild('hit')
 local oldUp,oldClick=hit.listeners.up,hit.listeners.click
 local helpUp,helpClick=help.listeners.up,help.listeners.click
 C.damage(s,s.player,kept,999,true);h:refresh()
 assert(not shown(p,kept),'dead actor surface was not retired')
 local created=C.summonEnemies(s,{{id='mad_gremlin',x=-200,y=0},{id='sneaky_gremlin',x=-100,y=0}})
 assert(#created==2,'source summon did not create a replacement')
 h:refresh()
 local reused=false
 for _,actor in ipairs(created)do if shown(p,actor)==oldSlot then reused=true end end
 assert(reused,'fixture must exercise actual stable-slot reuse')
 local target=u.target
 if oldUp then oldUp({touchId=65})end;oldClick({touchId=65})
 assert(u.target==target,'old portrait touch targeted another actor after retirement')
 if helpUp then helpUp({touchId=66})end;helpClick({touchId=66})
 assert(not u.info,'old help touch followed a remapped screen control')
 local bossSlot=shown(p,boss);tap('enemy'..bossSlot,63);assert(u.target==indexOf(s,boss),'fresh remapped touch failed')
 -- An ordinary fresh portrait now opens that actor's approved details. Close it
 -- through the real surface before the next independent intent-help gesture.
 assert(u.info and u.info.index==indexOf(s,boss) and u.info.id==boss.id,'fresh remapped details used a different actor')
 p:GetChild('statusInfo'):GetChild('hit').click({touchId=63});assert(not u.info)
 local _,bossBox=shown(p,boss)
 local intent=bossBox:GetChild('intentHit')
 part(intent,'down',64);part(intent,'up',64);part(intent,'click',64)
 assert(u.info and u.info.index==indexOf(s,boss) and u.info.kind=='intent','fresh mapped intent help failed')
end)
test('completed death feedback cannot hide or tint other identity-owned actor surfaces',function()
 local h,u,p,_,tap,drain,s,boss=fixture('leader')
 local victim;for _,e in ipairs(s.enemies)do if e~=boss and A.isActive(e)then victim=e;break end end
 s.hand[1].cardId='bludgeon';h:refresh()
 local slot=shown(p,victim);tap('card1',70);tap('enemy'..slot,71);drain()
 assert(victim.hp==0)
 -- Death is independently clocked (1.8 seconds), not bounded by action busy.
 for _=1,40 do h:update(.05)end
 assert(not shown(p,victim),'completed original death must retire only its actor')
 local visible=0;Surfaces.get(p):each(function(box,_,entry)
  if box.visible then
   visible=visible+1
   assert(A.isActive(entry.actor),'expired corpse surface remained visible')
   assert(not box:GetChild('floating').visible,'old damage number moved onto a replacement actor')
   local portrait=box:GetChild('portrait')
   -- Continuous idle may move within theme bounds; a transferred death pose may not.
   assert(idleBounds(portrait),
    'old death pose moved onto a replacement actor')
   local colour=portrait.imageColor
   assert(colour.a==255 and colour.r==Theme.color.text.r and colour.g==Theme.color.text.g and colour.b==Theme.color.text.b,
    'old death fade or tint moved onto a replacement actor')
  end
 end)
 assert(visible==2,'old death animation hid a living actor after display-control reuse')
 assert(shown(p,boss),'Leader lost its slot after feedback completion')
 -- Negative controls retain the old regression's ability to reject collapse and knockback.
 local oldDeath={x=0,y=-Theme.space.m/2,localScaleX=1.1,localScaleY=0.7}
 assert(not idleBounds(oldDeath),'idle allowance accepted a transferred death collapse')
 local oldHit={x=Theme.space.m,y=0,localScaleX=1,localScaleY=1}
 assert(not idleBounds(oldHit),'idle allowance accepted old victim knockback')
end)
print('SUMMON_ENEMY_UI '..passed..' passed; '..failed..' failed')
assert(failed==0,'summon visibility regressions')
