package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,H,D=require('abyss_run'),require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function card(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('missing '..id)
end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function close(s)
 assert(C.play(s,card(s,'bludgeon').uid,1));eq(s.enemies[1].hp,208)
 assert(C.endTurn(s));eq(s.enemies[1].statuses.sharp_hide,3)
 return s
end
for _,row in ipairs({{2,true,false,'defeat',0},{2,true,true,'victory',24},{3,true,false,'victory',1},{3,false,false,'defeat',0}})do
 local s=close(C.new(D,{seed=42,hp=row[1],enemies={'guardian'},deck={'bludgeon',{cardId='searing_blow',upgraded=true,upgrades=20}},beforeFirstTurn=function(state)
  state.relics=row[2]and {'tungsten_rod'}or {}
  if row[3]then state.potionInventory={'fairy_in_a_bottle'}end
  return true
 end}))
 assert(C.play(s,card(s,'searing_blow').uid,1));eq(s.enemies[1].hp,0)
 eq(s.player.hp,row[5]);eq(s.phase,row[4]);eq(s.player.damagedThisCombat,1)
 if row[3]then eq(s.potionInventory[1],nil)end
 local win,loss=0,0
 for _,e in ipairs(s.events)do if e.kind=='victory'then win=win+1 elseif e.kind=='defeat'then loss=loss+1 end end
 eq(win,row[4]=='victory'and 1 or 0);eq(loss,row[4]=='defeat'and 1 or 0)
 print('PASS dead final Guardian: startHP='..row[1]..' Rod='..tostring(row[2])..' Fairy='..tostring(row[3])..' outcome='..row[4])
end
do
 local s=close(C.new(D,{seed=42,hp=2,enemies={'guardian'},deck={'bludgeon',{cardId='searing_blow',upgraded=true,upgrades=20}},beforeFirstTurn=function(state)
  state.relics={'tungsten_rod'};state.potionInventory={'fairy_in_a_bottle'};return true
 end}))
 local chosen=card(s,'searing_blow');local before=C.copy(s)
 local inventory,enemy,hand,rng=s.potionInventory,s.enemies[1],s.hand,s.cardRandomRng
 local fairy=require('abyss_potion_fairy');local fatal,observed=fairy.fatal,false
 fairy.fatal=function(state)
  local revived=fatal(state);assert(revived);eq(state.player.hp,24);eq(state.potionInventory[1],nil)
  observed=true;error('SHARP_HIDE_AFTER_FAIRY')
 end
 local ok,why=pcall(C.play,s,chosen.uid,1);fairy.fatal=fatal
 assert(not ok and observed and tostring(why):find('SHARP_HIDE_AFTER_FAIRY',1,true))
 same(s,before);eq(s.potionInventory,inventory);eq(s.enemies[1],enemy);eq(s.hand,hand);eq(s.cardRandomRng,rng)
 assert(C.play(s,chosen.uid,1));eq(s.phase,'victory');eq(s.player.hp,24);eq(inventory[1],nil)
 print('PASS late failure after actual Fairy consumption restores the original inventory and dead-owner queue')
end
do
 local r=R.new(D,42);local uids={}
 for _,c in ipairs(r.deck)do uids[#uids+1]=c.uid end
 for _,uid in ipairs(uids)do assert(R.removeCard(r,uid))end
 assert(R.obtainCard(r,'bludgeon'));assert(R.obtainRelic(r,'tungsten_rod'))
 r.floor=D.rules.map.bossFloor;assert(R.startCombat(r,'boss_guardian'))
 local s=r.combat;assert(R.play(r,card(s,'bludgeon').uid,1));assert(R.endTurn(r))
 eq(s.enemies[1].statuses.sharp_hide,3)
 local before=C.copy(r);local player,hand,enemy,ownerStatuses,rng,deck=s.player,s.hand,s.enemies[1],s.enemies[1].statuses,s.cardRandomRng,r.deck
 local chosen=card(s,'bludgeon');local hook,observed=H.hpChanged,false
 H.hpChanged=function(state,actor,hp)
  hook(state,actor,hp)
  if actor==player then eq(hp-actor.hp,2);observed=true;error('SHARP_HIDE_LATE_FAILURE')end
 end
 local ok,why=pcall(R.play,r,chosen.uid,1);H.hpChanged=hook
 assert(not ok and observed and tostring(why):find('SHARP_HIDE_LATE_FAILURE',1,true))
 same(r,before);eq(r.combat,s);eq(s.player,player);eq(s.hand,hand);eq(s.hand[1],chosen)
 eq(s.enemies[1],enemy);eq(enemy.statuses,ownerStatuses);eq(s.cardRandomRng,rng);eq(r.deck,deck)
 assert(R.play(r,chosen.uid,1));eq(s.player.hp,before.combat.player.hp-2)
 print('PASS public Run Sharp Hide late failure restores original Run graph and retries same UID')
end
do
 local s=close(C.new(D,{seed=42,enemies={'guardian'},deck={'bludgeon','anger','pommel_strike'},beforeFirstTurn=function(state)
  state.relics={'tungsten_rod'};return true
 end}))
 -- Actual Anger creates its additional physical card in discard. Pommel
 -- Strike then draws from those real cards before its queued Sharp Hide.
 assert(C.play(s,card(s,'anger').uid,1))
 local first=#s.events+1;local hp=s.player.hp
 assert(C.play(s,card(s,'pommel_strike').uid,1));eq(s.player.hp,hp-2)
 local reshuffle,hide
 for i=first,#s.events do local e=s.events[i]
  if e.kind=='reshuffle'then reshuffle=i elseif e.kind=='status_damage'and e.detail.status=='sharp_hide'then hide=i end
 end
 assert(reshuffle and hide and reshuffle<hide,'Pommel reshuffle must precede Sharp Hide')
 -- Draw has no separate event; its real new Anger UID must already be in
 -- hand in the detached Sharp Hide frame, before later disposal callbacks.
 local drawn=false
 for _,held in ipairs(s.events[hide].frame.hand)do if held.cardId=='anger'then drawn=true end end
 assert(drawn,'Pommel drawn Anger must already be in Sharp Hide frame')
 print('PASS actual queued Pommel draw remains before the captured Sharp Hide reaction')
end
print('GUARDIAN_SHARP_HIDE_DEATH_ROLLBACK_PASS 7')
