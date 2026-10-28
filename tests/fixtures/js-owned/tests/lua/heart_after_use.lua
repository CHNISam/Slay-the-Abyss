package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
-- Controlled hands/lethal HP isolate real use-card queue boundaries.
local C,D,Cards=require('abyss_combat'),require('abyss_data'),require('abyss_card_actions')
local function fresh(advanced,id)
 local data=C.copy(D);data.rules.player.drawPerTurn=0
 local s=assert(C.new(data,{seed=42,enemies={'corrupt_heart'},deck={},enableStances=advanced}))
 local card=Cards.fresh(C,s,id or 'strike');s.hand={card};return s,s.enemies[1],card
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Heart afterUse '..count..' '..name)end
for _,advanced in ipairs({false,true})do
 test((advanced and 'advanced'or 'native')..' card effects precede fixed Beat and physical disposal remains valid',function()
  local s,e,card=fresh(advanced);local hp=s.player.hp
  assert(C.play(s,card.uid,1));assert(e.hp==744 and s.player.hp==hp-1)
  assert(#s.discard==1 and s.discard[1]==card and not s.cardInUse)
  local dealt,beat
  for i,event in ipairs(s.events)do
   if event.kind=='damage'and event.detail.target==e.id then dealt=i end
   if event.kind=='status_damage'and event.detail.target==s.player.id then beat=i end
  end
  assert(dealt and beat and dealt<beat)
 end)
 test((advanced and 'advanced'or 'native')..' Beat uses block and ignores attack modifiers',function()
  local s,e,card=fresh(advanced,'defend');local hp=s.player.hp
  e.statuses.strength=99;e.statuses.weak=1;s.player.statuses.vulnerable=1
  assert(C.play(s,card.uid));assert(s.player.hp==hp and s.player.block==4)
 end)
 test((advanced and 'advanced'or 'native')..' a dead final Heart still owns its queued damage',function()
  local s,e,card=fresh(advanced);e.hp=6;s.player.hp=1
  assert(C.play(s,card.uid,1));assert(e.hp==0 and s.player.hp==0)
  assert(C.outcome(s)=='defeat'and s.discard[1]==card)
 end)
end
test('physical dontTrigger suppresses Beat while a normal duplication triggers twice',function()
 local s,e,card=fresh(false);card.dontTriggerOnUseCard=true;local hp=s.player.hp
 assert(C.play(s,card.uid,1));assert(e.hp==744 and s.player.hp==hp)
 local t,b,used=fresh(false);t.player.statuses.duplication=1;hp=t.player.hp
 assert(C.play(t,used.uid,1));assert(b.hp==738 and t.player.hp==hp-2 and #t.discard==1)
end)
test('late Beat failure restores HP, damage budget, physical hand and queues for retry',function()
 assert(type(C.heartBeat)=='function','missing real Beat dispatcher')
 local s,e,card=fresh(true);local hp=s.player.hp;local old=C.heartBeat
 C.heartBeat=function(...)old(...);error('late beat failure')end
 local called,ok=pcall(C.play,s,card.uid,1);C.heartBeat=old
 assert(not called or not ok);assert(s.player.hp==hp and e.hp==750 and e.statuses.invincible==300)
 assert(s.hand[1]==card and #s.discard==0 and not s.actionQueue and not s.cardActions)
 assert(C.play(s,card.uid,1));assert(s.player.hp==hp-1 and e.hp==744)
end)
print('HEART_AFTER_USE_PASS '..count..' real card/cleanup boundaries; controlled offline, not natural/live evidence')
