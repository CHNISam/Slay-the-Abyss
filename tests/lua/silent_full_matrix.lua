-- Constructed exhaustive command matrix. Specific values/order remain asserted
-- in Silent foundation/attack/discard/tactics/final regression fixtures.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local R=require('abyss_sts_random');local D=require('abyss_discard')
local data=require('abyss_character_profiles').prepare(require('abyss_data'),'silent')
local definitions={};for _,d in ipairs(data.cards.cards)do if d.color=='green'and d.rarity~='special'and d.type~='status'and d.type~='curse'then definitions[#definitions+1]=d end end
assert(#definitions==75)
local n=0
for _,up in ipairs({false,true})do for _,def in ipairs(definitions)do
 local s=C.new(data,{deck={def.id,'defend_green','strike_green','defend_green'},enemies={'jaw_worm','jaw_worm'},seed=42,experimental=true,enableStances=true})
 local all,seen={},{};for _,name in ipairs({'hand','draw','discard','exhaust'})do for _,c in ipairs(s[name])do if not seen[c.uid]then all[#all+1]=c;seen[c.uid]=true end end;s[name]={}end
 s.hand=all;s.energy=30;s.potionRng=R.fromSeed('42');s.potionCharacter='silent';s.potionInventory={};s.potionCapacity=3
 for _,e in ipairs(s.enemies)do e.hp,e.maxHp=1000,1000;e.statuses.poison=1 end
 local selected;for _,c in ipairs(s.hand)do if c.cardId==def.id then selected=c;break end end;assert(selected,def.id)
 if up then assert(C.upgrade(s,selected),def.id..' has no real upgrade')end
 if def.id=='tactician'or def.id=='reflex'then
  local ok,why=C.canPlay(s,selected.uid,1);assert(not ok and why)
  local energy=s.energy;assert(D.discardSpecific(s,selected.uid,true,C));local discarded=false
  for _,event in ipairs(s.events)do if event.kind=='manual_discard'and event.detail.uid==selected.uid then discarded=true end end;assert(discarded)
  if def.id=='tactician'then assert(s.energy==energy+(up and 2 or 1))end
 else
  local before=#s.events;local ok,why=C.play(s,selected.uid,1);assert(ok,def.id..': '..tostring(why))
  local steps=0
  while s.pendingChoice or s.pendingDiscard or s.pendingScry or s.pendingHandChoice do
   steps=steps+1;assert(steps<=20,'choice loop '..def.id)
   if s.pendingChoice then local p=s.pendingChoice;assert(C.chooseCard(s,p.token,p.multiple and 0 or p.uids[1]))
   elseif s.pendingDiscard then local p=s.pendingDiscard;local ids={};for i=1,p.count do ids[i]=assert(s.hand[i]).uid end;assert(C.chooseDiscard(s,ids,p.token))
   elseif s.pendingScry then assert(C.chooseScry(s,{},s.pendingScry.token))
   else local p=s.pendingHandChoice;assert(C.chooseHand(s,{s.hand[1].uid},p.token))end
  end
  assert(not s.pendingPlay and not s.actionQueue and not s.cardActions,'unfinished real play '..def.id)
  assert(#s.events>before,'no actual play event '..def.id)
 end
 n=n+1;print('ok Silent matrix '..n..' '..def.id..(up and '+'or ''))
end end
assert(n==150);print('SILENT_FULL_REAL_MATRIX 75x2')
