-- Explicit chapter/queue and lethal-HP component setup; no natural route claim.
local Run,C,D,Q,R,A=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
 require('abyss_encounter_queue'),require('abyss_sts_random'),require('abyss_actor')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local seed
for i=1,50 do local raw=tostring(i);if Q.peek(Q.new(raw,3),'elite')=='Reptomancer'then seed=raw;break end end
assert(seed,'fixture needs real unmodified Reptomancer queue')
local function stage(character)
 local run=Run.new(D,seed,{experimental=true,campaign=true,character=character or 'ironclad'})
 run.act,run.floor,run.encounters=3,37,Q.new(seed,3)
 return run
end
local function strike(run)
 for _,c in ipairs(run.combat.hand)do local d=C.cardDefinition(run.combat,c)
  if d.type=='attack'and d.cost>=0 and d.cost<=run.combat.energy then return c.uid end
 end;error('source starter hand needs an attack')
end
test('all four real starter catalogs open unchanged source elite queue and draw correct streams',function()
 for _,character in ipairs({'ironclad','silent','defect','watcher'})do
  local run=stage(character);local old=run.encounters;local misc=R.snapshot(Run.roomStreams(run,run.floor).miscRng)
  eq(Q.peek(old,'elite'),'Reptomancer');assert(Run.startRoomCombat(run,'elite'))
  eq(run.encounterSource,'Reptomancer');eq(run.encounterTier,'elite');eq(run.encounterId,'act3_reptomancer')
  eq(#run.encounters.elite,#old.elite-1);eq(#old.elite,10);eq(run.combat.monsterHpRng.counter,4)
  eq(run.combat.aiRng.counter,3);eq(run.combat.enemies[2].sourceId,'Reptomancer')
  same(R.snapshot(run.miscRng),misc);eq(run.combat.player.maxHp,run.maxHp)
 end
end)
test('killing a Minion never completes room or creates rewards and leader gives one elite offer',function()
 local run=stage();assert(Run.startRoomCombat(run,'elite'));local s=run.combat
 s.enemies[1].hp=1;local original=s.enemies[1];assert(Run.play(run,strike(run),1))
 eq(original.hp,0);eq(run.phase,'combat');eq(run.victories,0);eq(run.rewards,nil)
 -- Component energy/HP staging only: the next command and reward path are real.
 s.energy=3;s.enemies[2].hp=1;assert(Run.play(run,strike(run),2))
 eq(run.phase,'reward');eq(run.victories,1);eq(run.lastResult.encounterId,'act3_reptomancer')
 eq(run.lastResult.allEnemiesEscaped,false);eq(#run.rewards.relics,1);eq(#run.rewards.cards,3)
 assert(run.rewards.gold>=25 and run.rewards.gold<=35);eq(run.rewards.goldClaimed,false)
 for _,e in ipairs(s.enemies)do eq(e.hp,0);eq(e.escaped,nil)end
 local before=C.copy(run);local ok,why=Run.finishCombat(run);eq(ok,false);eq(why,'not_in_combat');same(run,before)
 local gold=run.gold;local amount=run.rewards.gold;assert(Run.claimGoldReward(run));eq(run.gold,gold+amount)
 local again=Run.claimGoldReward(run);eq(again,false);eq(run.gold,gold+amount)
 assert(Run.leaveCombatRewards(run));eq(run.phase,'map');eq(run.victories,1)
 assert(Run.reopenCombatRewards(run));eq(run.phase,'reward');eq(run.rewards.goldClaimed,true);eq(run.victories,1)
end)
test('late source setup failure leaves queue stream and permanent owner identities unchanged',function()
 local run=stage();local before=C.copy(run);local queue,deck,misc=run.encounters,run.deck,run.miscRng
 local old=C.new;local fired=false;C.new=function(...)old(...);fired=true;error('LATE_REPTOMANCER_SETUP')end
 local called,ok,why=pcall(Run.startRoomCombat,run,'elite');C.new=old
 assert(called and fired);eq(ok,false);eq(why,'combat_unavailable');same(run,before)
 eq(run.encounters,queue);eq(run.deck,deck);eq(run.miscRng,misc)
end)
test('Run endTurn restores summon and permanent owners after later spawn failure',function()
 local run=stage();assert(Run.startRoomCombat(run,'elite'))
 local before=C.copy(run);local combat,leader,slots,queue=run.combat,run.combat.enemies[2],run.combat.enemies[2].reptomancerSlots,run.encounters
 local old=C.summonEnemies;local fired=false
 C.summonEnemies=function(...)old(...);fired=true;error('LATE_PUBLIC_REPTOMANCER_SUMMON')end
 local ok=pcall(Run.endTurn,run);C.summonEnemies=old
 assert(not ok and fired);same(run,before);eq(run.combat,combat);eq(run.combat.enemies[2],leader)
 eq(leader.reptomancerSlots,slots);eq(run.encounters,queue)
end)
test('leader death cleanup invokes normal death powers but never grants Minion fatal growth',function()
 local run=stage('silent');assert(Run.startRoomCombat(run,'elite'));local s=run.combat
 local leader=s.enemies[2];A.applyPower(s,s.enemies[1],'corpse_explosion',1,s.player)
 A.applyPower(s,s.enemies[3],'corpse_explosion',1,s.player)
 local Silent=require('abyss_silent_final_cards');local old=Silent.death;local visits,queued=0,0
 Silent.death=function(st,e,before,push)
  visits=visits+1
  return old(st,e,before,function(ss,effect,top)
   if effect.kind=='corpseDamage'then queued=queued+1 end
   return push(ss,effect,top)
  end)
 end
 leader.hp=1;local called,ok=pcall(Run.play,run,strike(run),2);Silent.death=old
 assert(called and ok);eq(visits,2);eq(queued,1);eq(run.phase,'reward');eq(run.victories,1)
 local suicides=0;for _,ev in ipairs(s.events)do if ev.kind=='enemy_suicide'then suicides=suicides+1 end end
 eq(suicides,2);eq(s.stolenGoldReward,0)
end)
print('REPTOMANCER_PUBLIC '..count..' groups; '..failed..' failed; source seed '..seed);assert(failed==0)
