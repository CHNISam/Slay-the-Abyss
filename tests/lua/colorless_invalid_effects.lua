package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,R=require('abyss_combat'),require('abyss_sts_random')
local Data=require('abyss_data')
local count=0
for _,id in ipairs({'strike','mind_blast','ritual_dagger'})do
 for _,kind in ipairs({'nil','false','non_table_entry'})do
  local s=C.new(Data,{deck={id},enemies={'cultist'},seed=42,cardRandomSeed='17'})
  if kind=='nil' then s.catalog.cards[id].effects=nil
  elseif kind=='false' then s.catalog.cards[id].effects=false
  else s.catalog.cards[id].effects={false} end
  local hand,card,events,energy,hp=s.hand,s.hand[1],#s.events,s.energy,s.enemies[1].hp
  local random=R.snapshot(s.cardRandomRng)
  local called,ok,why=pcall(C.canPlay,s,card.uid,1)
  assert(called and not ok and why:find('unsupported_effect:',1,true),id..' '..kind..': '..tostring(why))
  local played,reason=C.play(s,card.uid,1)
  assert(not played and reason==why)
  assert(s.hand==hand and s.hand[1]==card and s.energy==energy and #s.events==events and s.enemies[1].hp==hp)
  local after=R.snapshot(s.cardRandomRng)
  assert(after.counter==random.counter and after.words[1]==random.words[1] and after.words[2]==random.words[2])
  count=count+1
 end
end
assert(count==9)
print('COLORLESS_INVALID_EFFECTS_PASS 9')
