-- Application smoke: experimental restricted uniform rewards, not PC drops.
-- Room-entry harness advances floor only after real rewards; no Map/UI claim.
-- Frozen historical pools used seed11 (pre-Accuracy), seed1 (Accuracy), seed65
-- (24 regular green cards), seed56 (41). Current61 changes seed56's rewards.
-- Bounded1..64 Fumes-only search failed; a read-only poison-card policy found
-- seed9 within1..9. Stats, deck, RNG and reward algorithms were never injected.
-- Poisoned Stab into Bane is actually used; Finisher/Storm are only obtained.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Run,Combat,Actors=require('abyss_run'),require('abyss_combat'),require('abyss_actor')
local data=require('abyss_data')
local function target(s)
 local best
 for i,e in ipairs(s.enemies)do
  if Actors.isActive(e) and (not best or e.hp+e.block<s.enemies[best].hp+s.enemies[best].block)then best=i end
 end
 return best
end
local function incoming(s)
 local total=0
 for i,e in ipairs(s.enemies)do
  if Actors.isActive(e) and e.hp>(e.statuses.poison or 0)then
   local intent=Combat.intent(s,i)
   for _,effect in ipairs(intent.effects or {})do
    if effect.op=='damage'then total=total+Combat.attackAmount(s,e,s.player,effect.value)*(effect.times or 1)end
   end
  end
 end
 return total
end
local function score(s,card,t)
 local id=card.cardId
 if id=='neutralize'then return 100 end
 if id=='noxious_fumes'then return 90 end
 if id=='bane'then return (s.enemies[t].statuses.poison or 0)>0 and 95 or 50 end
 if id=='poisoned_stab'then return 80 end
 if id=='catalyst'then return (s.enemies[t].statuses.poison or 0)>0 and 95 or -1 end
 if id=='bouncing_flask'or id=='deadly_poison'or id=='crippling_poison'then return 85 end
 if id=='defend_green'or id=='survivor'then
  return s.player.block<incoming(s) and (id=='survivor'and 75 or 60)or -1
 end
 if id=='strike_green'then
  local enemy=s.enemies[t];local amount=Combat.attackAmount(s,s.player,enemy,6)
  return amount>=enemy.hp+enemy.block and 80 or 50
 end
 return -1
end
local function discard(run)
 local s=run.combat;local p=s.pendingDiscard;local candidates={}
 for _,c in ipairs(s.hand)do candidates[#candidates+1]=c end
 local t=target(s)
 table.sort(candidates,function(a,b)
  local sa,sb=score(s,a,t),score(s,b,t)
  if sa==sb then return a.uid<b.uid end
  return sa<sb
 end)
 local chosen={};for i=1,p.count do chosen[i]=candidates[i].uid end
 assert(Run.chooseDiscard(run,chosen,p.token,run.combatGeneration))
end
local function fight(run,evidence,quiet)
 local steps=0
 while run.phase=='combat'do
  steps=steps+1;if steps>400 then return false,'steps' end
  local s=run.combat
  if s.turn>40 then return false,'turns' end
  if s.pendingDiscard then discard(run)
  else
   local t=target(s);local best,bestscore
   for _,c in ipairs(s.hand)do
    if Combat.canPlay(s,c.uid,t)then
     local value=score(s,c,t)
     if value>=0 and (not bestscore or value>bestscore)then best,bestscore=c,value end
    end
   end
   if best then
    local id=best.cardId;local before=s.enemies[t].statuses.poison or 0
    local randomBefore=s.cardRandomRng and s.cardRandomRng.counter
    local eventsBefore,legacyBefore,energyBefore=#s.events,s.seed,s.energy
    local totalPoisonBefore=0;for _,enemy in ipairs(s.enemies)do totalPoisonBefore=totalPoisonBefore+(enemy.statuses.poison or 0)end
    assert(Run.play(run,best.uid,t))
    if id=='bane'then
     local hits,amount=0,0
     for i=eventsBefore+1,#s.events do local e=s.events[i]
      if e.kind=='damage'and e.detail.source==s.player.id then hits=hits+1;amount=amount+e.detail.amount end
     end
     if before>0 and hits==2 then
      evidence.bane=(evidence.bane or 0)+1;evidence.baneDamage=(evidence.baneDamage or 0)+amount
      if not quiet then print('NATURAL_BANE_COMBO',run.floor,s.turn,before,hits,amount)end
     end
    elseif id=='poisoned_stab'then
     evidence.stab=(evidence.stab or 0)+1;local applications=0
     for i=eventsBefore+1,#s.events do local e=s.events[i]
      if e.kind=='status'and e.detail.status=='poison'and e.detail.source==s.player.id and e.detail.amount==3 then applications=applications+1 end
     end
     if applications>0 then assert(applications==1 and s.enemies[t].statuses.poison==before+3,'Poisoned Stab actual three-poison application');evidence.stabPoison=(evidence.stabPoison or 0)+1 end
     if not quiet then print('NATURAL_POISONED_STAB',run.floor,s.turn,before,s.enemies[t].statuses.poison or 0,applications)end
    elseif id=='crippling_poison'then
     local applications=0;for i=eventsBefore+1,#s.events do local e=s.events[i];if e.kind=='status'and e.detail.status=='poison'and e.detail.source==s.player.id and e.detail.amount==4 then applications=applications+1 end end
     assert(applications>0,'Crippling Poison actual poison');evidence.cripple=(evidence.cripple or 0)+1
    elseif id=='catalyst'then
     if before>0 then evidence.catalyst=(evidence.catalyst or 0)+1 end
    elseif id=='noxious_fumes'then evidence.fumes=(evidence.fumes or 0)+1
    elseif id=='bouncing_flask'then
     assert(s.cardRandomRng.counter==randomBefore+3,'Flask must consume three independent target draws')
     assert(s.seed==legacyBefore and s.energy==energyBefore-2,'Flask RNG and energy separation')
     local applications=0
     for i=eventsBefore+1,#s.events do
      local event=s.events[i]
      if event.kind=='status'and event.detail.status=='poison'and event.detail.source==s.player.id
       and event.detail.amount==3 then applications=applications+1 end
     end
     assert(applications==3,'three distinct poison applications must execute')
     local totalPoisonAfter=0;for _,enemy in ipairs(s.enemies)do totalPoisonAfter=totalPoisonAfter+(enemy.statuses.poison or 0)end
     assert(totalPoisonAfter==totalPoisonBefore+9,'all three independent bounces apply across the current enemies')
     evidence.flask=(evidence.flask or 0)+1
     if not quiet then print('NATURAL_FLASK_CAST',run.floor,s.turn,randomBefore,s.cardRandomRng.counter,applications,totalPoisonBefore,totalPoisonAfter) end
    elseif id=='deadly_poison'then
     assert(s.enemies[t].statuses.poison==before+5,'naturally obtained Deadly Poison must apply five')
     evidence.poison=(evidence.poison or 0)+1
     if not quiet then print('NATURAL_DEADLY_POISON',run.floor,s.turn,before,s.enemies[t].statuses.poison) end
    end
   else
    local fumes=s.player.statuses.noxious_fumes or 0;local turn=s.turn;local eventCount=#s.events
    assert(Run.endTurn(run))
    if fumes>0 and run.phase=='combat'and s.turn>turn then
     local observed=0
     for i=eventCount+1,#s.events do
      local e=s.events[i]
      if e.kind=='status'and e.detail.status=='poison'and e.detail.source==s.player.id
       and e.detail.amount==fumes and e.frame.phase=='player'and e.frame.turn==turn+1 then
       observed=observed+1
       if not quiet then print('NATURAL_FUMES_POSTDRAW',run.floor,e.frame.turn,e.detail.target,e.detail.amount) end
      end
     end
     assert(observed>0,'Fumes must emit real poison application after next player turn draw')
     evidence.postdraw=(evidence.postdraw or 0)+1
    end
   end
  end
 end
 return run.phase=='reward',run.phase
end
local function canonical(value)
 local kind=type(value)
 if kind=='string'then return string.format('%q',value)end
 if kind=='number'or kind=='boolean'then return tostring(value)end
 assert(kind=='table'and getmetatable(value)==nil,'replay manifest must remain plain data')
 local keys={};for key in pairs(value)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
 local fields={};for _,key in ipairs(keys)do fields[#fields+1]='['..canonical(key)..']='..canonical(value[key])end
 return '{'..table.concat(fields,',')..'}'
end
local function stateSignature(run,rooms,evidence)
 local Random=require('abyss_sts_random')
 local s=assert(run.pendingCombatRewards).combat
 local last={phase=s.phase,turn=s.turn,energy=s.energy,seed=s.seed,nextUid=s.nextUid,
  player={hp=s.player.hp,maxHp=s.player.maxHp,block=s.player.block,statuses=Combat.copy(s.player.statuses)},enemies={},
  actionQueue=Combat.copy(s.actionQueue),pendingPlay=Combat.copy(s.pendingPlay),
  pendingDiscard=Combat.copy(s.pendingDiscard),pendingScry=Combat.copy(s.pendingScry),pendingHandChoice=Combat.copy(s.pendingHandChoice)}
 for _,pile in ipairs({'hand','draw','discard','exhaust'})do last[pile]=Combat.copy(s[pile])end
 for i,e in ipairs(s.enemies)do last.enemies[i]={id=e.id,hp=e.hp,maxHp=e.maxHp,block=e.block,
  statuses=Combat.copy(e.statuses),escaped=e.escaped,intentIndex=e.intentIndex}end
 for _,key in ipairs({'nextSourceUid','cardsPlayedThisTurn','cardsPlayedThisCombat','autoCardQueue','pendingRetainChoice','pendingFinalHand','nightmareTemplate','pendingDiscardDraws','retainedCards'})do last[key]=Combat.copy(s[key])end
 local snapshot={phase=run.phase,hp=run.hp,maxHp=run.maxHp,gold=run.gold,floor=run.floor,
  seed=run.seed,runSeed=run.runSeed,victories=run.victories,roomGeneration=run.roomGeneration,
  nextDeckUid=run.nextDeckUid,combatGeneration=run.combatGeneration,deck=Combat.copy(run.deck),
  relics=Combat.copy(run.relics),potions=Combat.copy(run.potions),rooms=rooms,evidence=evidence,
  encounters=Run.snapshotEncounters(run),lastCombat=last,runRng={},combatRng={}}
 for name,value in pairs(run)do
  if type(value)=='table'and value.counter~=nil and value.primitive then snapshot.runRng[name]=Random.snapshot(value)end
 end
 for name,value in pairs(s)do
  if type(value)=='table'and value.counter~=nil and value.primitive then snapshot.combatRng[name]=Random.snapshot(value)end
 end
 return canonical(snapshot)
end
local function attempt(seed,quiet)
 local run=Run.new(data,tostring(seed),{character='silent',experimental=true});local ev={};local got={};local rooms={}
 assert(run.character=='silent'and run.hp==70 and run.maxHp==70 and #run.deck==12,'real Silent starter state')
 assert(#run.relics==1 and run.relics[1]=='ring_of_the_snake','no extra starting relic or heal')
 assert(#run.potions==0,'no injected starting potion')
 local starter={};for _,c in ipairs(run.deck)do assert(not c.upgraded);starter[c.cardId]=(starter[c.cardId]or 0)+1 end
 assert(starter.strike_green==5 and starter.defend_green==5 and starter.neutralize==1 and starter.survivor==1,'unmodified12-card Silent starter')
 local green,basic=0,0;for _,c in ipairs(run.data.cards.cards)do if c.color=='green'and c.rarity~='special'and c.type~='status'and c.type~='curse'then green=green+1;if c.rarity=='basic'then basic=basic+1 end end end
 assert(green==61 and basic==4,'fixed61-green Profile includes57 nonbasic rewards and4 basics')
 for floor=1,4 do
  local hp=run.hp;assert(Run.startRoomCombat(run,'normal'))
  assert(run.combat.player.hp==hp,'HP continuity')
  local encounter=run.encounterId
  local ok,why=fight(run,ev,quiet);assert(ok,why)
  assert(run.combat.actionQueue==nil and run.combat.pendingPlay==nil and run.combat.pendingDiscard==nil,'battle must finish without unresolved card continuation')
  assert(run.hp==run.combat.player.hp,'Silent must carry actual battle HP without a heal fixture')
  assert(run.hp>0 and run.hp<=70,'natural health budget')
  local options=Run.rewardOptions(run);local choice
  local poisonChoices={'noxious_fumes','bouncing_flask','deadly_poison','crippling_poison','poisoned_stab','bane','catalyst'}
  for _,desired in ipairs(poisonChoices)do
   local acquired=false;for _,id in ipairs(got)do if id==desired then acquired=true end end
   if not acquired and not(desired=='catalyst'and #got==0)then
    for i,id in ipairs(options)do if id==desired then choice=i;break end end
   end
   if choice then break end
  end
  if not choice and floor>1 then choice=1 end
  assert(choice,'fixed seed must retain recorded natural reward')
  local picked=choice>0 and options[choice]or 'skip'
  got[#got+1]=picked;rooms[#rooms+1]={encounter=encounter,hpBefore=hp,hpAfter=run.hp,turns=run.lastResult.turn,options=options,picked=picked}
  local oldDeckSize=#run.deck;assert(Run.claimCardReward(run,choice))
  assert(#run.deck==oldDeckSize+1 and run.deck[#run.deck].cardId==picked,'reward must enter permanent deck by command')
  if not run.rewards.goldClaimed then assert(Run.claimGoldReward(run))end
  assert(Run.leaveCombatRewards(run));run.floor=run.floor+1
 end
 assert(ev.stab==4 and ev.stabPoison==4 and ev.bane==1 and ev.baneDamage==10,'recorded Poisoned Stab into poison-conditional Bane')
 assert(run.victories==4 and #run.deck==16 and run.hp==62,'recorded four-room state')
 assert(table.concat(got,',')=='poisoned_stab,finisher,bane,storm_of_steel','natural acquisition record')
 local expected={{'jaw_solo',70,69,8},{'small_slimes',69,69,3},{'cultist_solo',69,69,3},{'blue_slaver_solo',69,62,4}}
 for i,r in ipairs(rooms)do local ex=expected[i];assert(r.encounter==ex[1]and r.hpBefore==ex[2]and r.hpAfter==ex[3]and r.turns==ex[4],'exact room/HP/turn record')end
 local offers={{'sucker_punch','leg_sweep','poisoned_stab'},{'finisher','prepared','flying_knee'},
  {'reflex','skewer','bane'},{'storm_of_steel','escape_plan','accuracy'}}
 for i,room in ipairs(rooms)do assert(table.concat(room.options,',')==table.concat(offers[i],','),'actual natural reward offers')end
 if not quiet then print('NATURAL_BUILD_RESULT',seed,table.concat(got,','),'hp',run.hp,'stab',ev.stab,'stabPoison',ev.stabPoison,'bane',ev.bane,'baneDamage',ev.baneDamage)end
 for i,room in ipairs(rooms)do if not quiet then print('ROOM',i,room.encounter,room.hpBefore,room.hpAfter,room.turns,table.concat(room.options,','),room.picked)end end
 return stateSignature(run,rooms,ev)
end
local first=attempt('9')
local rebuilt=attempt('9',true)
assert(first==rebuilt,'same source seed and commands must reconstruct the recorded state')
print('SILENT_NATURAL_BUILD_PASS 1')
