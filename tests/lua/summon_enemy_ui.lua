local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local C,A=require('abyss_combat'),require('abyss_actor')
local Theme=require('abyss_theme')
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
end
local function indexOf(s,actor)for i,e in ipairs(s.enemies)do if e==actor then return i end end end
local function shown(panel,actor)
 for i=1,5 do local box=panel:GetChild('enemy'..i)
  if box.visible and box:GetChild('name').text==actor.name
   and box:GetChild('hp').text==tostring(actor.hp)..'/'..tostring(actor.maxHp)then return i,box end
 end
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
  assert(box:GetChild('intentIcon').visible,'every live actor retains its compact intent icon')
  assert(box:GetChild('intentIcon').imageId==Theme.icon.intent[require('abyss_battle_intent_view').intentView(s,indexOf(s,boss)).kind])
  local count,live=0,0;for i=1,5 do if p:GetChild('enemy'..i).visible then count=count+1 end end
  for _,e in ipairs(s.enemies)do if A.isActive(e)then live=live+1 end end
  assert(count==live,'a living actor was silently omitted')
  A.applyPower(s,boss,'strength',2,boss);h:refresh()
  box:GetChild('statusRow'):GetChild('hit').click({touchId=40})
  assert(u.info and u.info.index==indexOf(s,boss) and u.info.id==boss.id,'status help used the display slot as actor index')
  assert(u:showStatus(indexOf(s,boss)))
  local chip=box:GetChild('statusRow'):GetChild('hit1')
  part(chip,'down',41);part(chip,'up',41);part(chip,'click',41)
  assert(u.info and u.info.index==indexOf(s,boss) and u.info.statusId==C.statusView(boss)[1].id,'status chip used the display slot as actor index')
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
test('Collector replacement drag reticle and landing use compact live coordinates and true target index',function()
 local h,u,p,event,_,drain,s,boss=fixture('collector')
 local live={};for _,e in ipairs(s.enemies)do if e~=boss and A.isActive(e)then live[#live+1]=e end end
 C.damage(s,s.player,live[1],999,true);h:refresh()
 local victim=live[2];local slot,box=shown(p,victim);assert(slot,'surviving Torch not displayed')
 local row=Theme.layout.enemyRow;local liveCount=0;for _,e in ipairs(s.enemies)do if A.isActive(e)then liveCount=liveCount+1 end end
 assert(box.x==(liveCount<=row.fewCount and row.xFromFew or row.xFrom),'dead actors still consume live layout columns')
 local target=indexOf(s,victim);local hp=victim.hp
 event('card1','down',5);event('card1','drag',5,box.x,Theme.layout.enemyRow.y)
 local ring=p:GetChild('dragLayer'):GetChild('reticle')
 assert(ring.visible and ring.x==box.x,'reticle follows corpse-count coordinates')
 event('card1','up',5,box.x,Theme.layout.enemyRow.y)
 assert(u.target==target and victim.hp==hp-6,'drag committed the display slot')
 assert(u.feedback.flight and u.feedback.flight.tx==box.x,'card landed at raw array coordinates')
 drain();assert(not u.busy)
end)
test('old portrait and help presses cannot follow a reused display slot in the same turn',function()
 local h,u,p,event,tap,_,s,boss=fixture('leader')
 local living={};for _,e in ipairs(s.enemies)do if A.isActive(e)then living[#living+1]=e end end
 C.damage(s,s.player,living[2],1,true);h:refresh()
 local kept=living[2];local oldSlot,oldBox=shown(p,kept);assert(oldSlot)
 tap('enemy'..oldSlot,60);assert(u.target==indexOf(s,kept))
 event('enemy'..oldSlot,'down',61)
 local help=oldBox:GetChild('intentHit');part(help,'down',62)
 C.damage(s,s.player,living[1],999,true);h:refresh()
 event('enemy'..oldSlot,'up',61);event('enemy'..oldSlot,'click',61)
 assert(u.target==indexOf(s,kept),'old portrait touch targeted the replacement display occupant')
 part(help,'up',62);part(help,'click',62)
 assert(not u.info,'old help touch followed a remapped screen control')
 local bossSlot=shown(p,boss);tap('enemy'..bossSlot,63);assert(u.target==indexOf(s,boss),'fresh remapped touch failed')
 local intent=p:GetChild('enemy'..bossSlot):GetChild('intentHit')
 part(intent,'down',64);part(intent,'up',64);part(intent,'click',64)
 assert(u.info and u.info.index==indexOf(s,boss) and u.info.kind=='intent','fresh mapped intent help failed')
end)
test('completed death feedback cannot hide or tint the living actor that inherits its screen slot',function()
 local h,u,p,_,tap,drain,s,boss=fixture('leader')
 local victim;for _,e in ipairs(s.enemies)do if e~=boss and A.isActive(e)then victim=e;break end end
 s.hand[1].cardId='bludgeon';h:refresh()
 local slot=shown(p,victim);tap('card1',70);tap('enemy'..slot,71);drain()
 assert(victim.hp==0)
 for _=1,20 do h:update(.05)end
 local visible=0;for i=1,5 do local box=p:GetChild('enemy'..i)
  if box.visible then
   visible=visible+1
   assert(not box:GetChild('floating').visible,'old damage number moved onto a replacement actor')
   local portrait=box:GetChild('portrait')
   assert(portrait.localScaleX==1 and portrait.localScaleY==1 and portrait.x==0 and portrait.y==0,
    'old death pose moved onto a replacement actor')
  end
 end
 assert(visible==2,'old death animation hid a living actor after compaction')
 assert(shown(p,boss),'Leader lost its slot after feedback completion')
end)
print('SUMMON_ENEMY_UI '..passed..' passed; '..failed..' failed')
assert(failed==0,'summon visibility regressions')
