-- Controlled arithmetic/cards isolate source timing; Run cases use real room
-- queues, starter decks and reward APIs, not natural full-campaign evidence.
local C,D,R,Run,Q,A,G,Actions=require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),
 require('abyss_run'),require('abyss_encounter_queue'),require('abyss_actor'),require('abyss_giant_head'),require('abyss_card_actions')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b));if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end;for k in pairs(b)do assert(a[k]~=nil,path..'.'..tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function battle(deck,ids,data)
 local streams={seed='1'}
 for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[key]=R.fromSeed('1')end
 return C.new(data or D,{enemies=ids or {'giant_head'},deck=deck or {},roomSeed='1',roomStreams=streams})
end
local function uid(s,id,exclude)
 for _,c in ipairs(s.hand)do if c.cardId==id and c.uid~=exclude then return c.uid end end;error('missing '..id)
end
local function stage(seed)
 local r=Run.new(D,seed or '0',{experimental=true,campaign=true})
 r.act,r.floor,r.encounters=3,40,Q.new(seed or '0',3);return r
end
local function nearLethal(r)
 assert(Run.startRoomCombat(r,'elite'));local s,e=r.combat,r.combat.enemies[1]
 C.damage(s,s.player,e,494,true);eq(e.hp,6)
 return s,e,uid(s,'strike')
end
test('the first card uses Slow zero, later cards use the prior completed-card count',function()
 local s=battle({'strike','strike'});local e=s.enemies[1];A.applyPower(s,s.player,'strength',4,s.player)
 local first=uid(s,'strike');assert(C.play(s,first,1));eq(e.hp,490);eq(e.statuses.slow,1)
 assert(C.play(s,uid(s,'strike'),1));eq(e.hp,479);eq(e.statuses.slow,2)
 eq(#s.discard,2);eq(e.powerScheduleSerial,1);eq(e.powerOrder[1],'slow')
end)
test('skills Powers and cards aimed elsewhere count once for every Slow owner',function()
 local s=battle({'defend','inflame','strike'},{'giant_head','giant_head','cultist'})
 local one,two=s.enemies[1],s.enemies[2]
 assert(C.play(s,uid(s,'defend')));eq(one.statuses.slow,1);eq(two.statuses.slow,1)
 assert(C.play(s,uid(s,'inflame')));eq(one.statuses.slow,2);eq(two.statuses.slow,2)
 local hp=s.enemies[3].hp;assert(C.play(s,uid(s,'strike'),3));eq(s.enemies[3].hp,hp-8)
 eq(one.hp,500);eq(two.hp,500);eq(one.statuses.slow,3);eq(two.statuses.slow,3)
end)
test('all hits from one card use one old Slow snapshot, not one stack per hit',function()
 local s=battle({'twin_strike'});local e=s.enemies[1];A.applyPower(s,s.player,'strength',5,s.player)
 assert(C.play(s,uid(s,'twin_strike'),1));eq(e.hp,480);eq(e.statuses.slow,1)
 local amounts={};for _,ev in ipairs(s.events)do if ev.kind=='damage'and ev.detail.target==e.id then amounts[#amounts+1]=ev.detail.amount end end
 eq(#amounts,2);eq(amounts[1],10);eq(amounts[2],10)
end)
test('purged automatic copies trigger separately after their own complete use',function()
 local s=battle({'strike'});local e=s.enemies[1];A.applyPower(s,s.player,'strength',4,s.player)
 local original=s.hand[1];s.hand={}
 C.queueCard(s,Actions.sameInstance(C,s,original),{targetIndex=1,purge=true,append=true})
 C.queueCard(s,Actions.sameInstance(C,s,original),{targetIndex=1,purge=true,append=true})
 Actions.drain(C,s);eq(e.hp,479);eq(e.statuses.slow,2);eq(#s.discard,0);eq(#s.exhaust,0)
end)
test('dontTriggerOnUseCard and rejected plays never increment Slow',function()
 local s=battle({'strike','strike'});local e=s.enemies[1]
 s.catalog.cards.strike.dontTriggerOnUseCard=true
 assert(C.play(s,uid(s,'strike'),1));eq(e.statuses.slow,0);eq(e.hp,494)
 local before=C.copy(s);local ok,why=C.play(s,uid(s,'strike'),99)
 eq(ok,false);eq(why,'invalid_target');same(s,before)
end)
for _,experimental in ipairs({false,true})do
 test('per-instance suppression resets after ordinary use and does not suppress a later copy '..tostring(experimental),function()
  local data=experimental and require('abyss_warrior_exhaust_cards').withCards(D)or D
  local s=battle({'strike','strike'},nil,data);local e=s.enemies[1];local physical=s.hand[1]
  physical.dontTriggerOnUseCard=true
  assert(C.play(s,physical.uid,1));eq(e.hp,494);eq(e.statuses.slow,0)
  eq(physical.dontTriggerOnUseCard,false);eq(s.catalog.cards.strike.dontTriggerOnUseCard,nil)
  C.queueCard(s,Actions.sameInstance(C,s,physical),{targetIndex=1,purge=true});Actions.drain(C,s)
  eq(e.hp,488);eq(e.statuses.slow,1)
 end)
 test('per-instance suppression on an actual automatic purge card '..tostring(experimental),function()
  local data=experimental and require('abyss_warrior_exhaust_cards').withCards(D)or D
  local s=battle({'strike'},nil,data);local e=s.enemies[1];local physical=s.hand[1]
  physical.dontTriggerOnUseCard=true
  eq(C.cardDefinition(s,physical).dontTriggerOnUseCard,true)
  local duplicate=Actions.sameInstance(C,s,physical)
  duplicate.dontTriggerOnUseCard=true -- Explicit queued-instance flag, not a copy-inheritance claim.
  C.queueCard(s,duplicate,{targetIndex=1,purge=true});Actions.drain(C,s)
  eq(e.hp,494);eq(e.statuses.slow,0);eq(duplicate.dontTriggerOnUseCard,true)
 end)
end
test('a live false instance flag overrides captured and definition true flags',function()
 local s=battle({'strike'});local physical=s.hand[1]
 s.catalog.cards.strike.dontTriggerOnUseCard=true;physical.dontTriggerOnUseCard=false
 eq(C.cardDefinition(s,physical).dontTriggerOnUseCard,false)
 local effects={};G.afterUse(s,{dontTriggerOnUseCard=true},function(_,effect)effects[#effects+1]=effect end,physical)
 eq(#effects,1);eq(effects[1].op,'giantHeadSlow')
end)
test('a playable status card counts once before its normal exhaust callbacks',function()
 local s=battle({'slimed','strike'});local e=s.enemies[1]
 assert(C.play(s,uid(s,'slimed')));eq(e.statuses.slow,1);eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'slimed')
end)
test('only NORMAL damage receives Slow; fixed damage Thorns and Poison do not',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'slow',7,e)
 eq(C.damage(s,s.player,e,10,false),17);eq(C.damage(s,s.player,e,10,true),10)
 eq(C.retaliate(s,s.player,e,10),10);A.applyPower(s,e,'poison',5,s.player)
 local hp=e.hp;A.startTurnEffects(s,e);eq(e.hp,hp-5)
 A.applyPower(s,e,'intangible',1,e);eq(A.attackAmount(s,s.player,e,100),1)
end)
test('independent binary32 vectors cover flooring stance and stable Slow/Vulnerable order',function()
 local s=battle();local e=s.enemies[1];local vectors=dofile('tests/fixtures/giant-head-vectors.lua')
 for _,v in ipairs(vectors.damage)do
  e.statuses,e.powerOrder,e.powerScheduleOrder,e.powerScheduleSerial={},{},nil,nil
  if v.vulnerable and v.vulnerableFirst then A.applyPower(s,e,'vulnerable',1,s.player)end
  A.applyPower(s,e,'slow',v.slow,e)
  if v.vulnerable and not v.vulnerableFirst then A.applyPower(s,e,'vulnerable',1,s.player)end
  s.player.stance=v.stance==3 and 'Divinity'or nil
  s.player.statuses.strength=v.strength;s.player.statuses.double_damage=v.doubleDamage
  s.player.statuses.weak=v.weak and 1 or nil
  eq(A.attackAmount(s,s.player,e,v.base),v.expected)
 end
end)
test('non-Slow arithmetic remains the existing unrounded modifier pipeline',function()
 local s=battle({}, {'cultist'});local e=s.enemies[1]
 s.player.statuses.strength=3;s.player.statuses.weak=1;s.player.statuses.double_damage=1
 s.player.stance='Divinity';e.statuses.vulnerable=1
 for _,base in ipairs({6,31,16777217})do
  eq(A.attackAmount(s,s.player,e,base),math.floor((base+3.0)*2*.75*1.5*3))
 end
end)
test('Slow resets at round end only and preserves its zero-value acquisition slot',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'slow',7,e)
 A.applyPower(s,e,'vulnerable',2,s.player);local serial=e.powerScheduleSerial
 A.endTurn(s,e);eq(e.statuses.slow,7);eq(e.powerOrder[1],'slow')
 A.endRound(s,e);eq(e.statuses.slow,0);eq(e.powerOrder[1],'slow');eq(e.powerScheduleSerial,serial)
 A.applyPower(s,e,'slow',1,e);eq(e.statuses.slow,1);eq(e.powerOrder[1],'slow');eq(e.powerScheduleSerial,serial)
end)
test('the queued Slow application respects Artifact and dead-owner cancellation',function()
 local s=battle({'defend'});local e=s.enemies[1];A.applyPower(s,e,'artifact',1,e)
 assert(C.play(s,uid(s,'defend')));eq(e.statuses.artifact,0);eq(e.statuses.slow,0)
 local effects={};G.afterUse(s,{},function(_,effect)effects[#effects+1]=effect end);eq(#effects,1)
 C.damage(s,s.player,e,500,true);eq(G.applySlow(A,s,effects[1]),false);eq(e.statuses.slow,0)
end)
test('a real paused exhaust selection increments only after the card finishes',function()
 local s=battle({'burning_pact','strike','defend'});local e=s.enemies[1]
 assert(C.play(s,uid(s,'burning_pact')));assert(s.pendingChoice);eq(e.statuses.slow,0)
 local choice=s.pendingChoice;assert(C.chooseCard(s,choice.token,choice.uids[1]))
 eq(e.statuses.slow,1);eq(s.pendingChoice,nil)
end)
test('the experimental queue keeps multi-hit damage at the old stack until UseCard disposal',function()
 local data=require('abyss_warrior_exhaust_cards').withCards(D)
 local s=battle({'twin_strike','strike'},nil,data);local e=s.enemies[1]
 assert(s.experimentalMechanics);A.applyPower(s,s.player,'strength',5,s.player)
 assert(C.play(s,uid(s,'twin_strike'),1));eq(e.hp,480);eq(e.statuses.slow,1)
 assert(C.play(s,uid(s,'strike'),1));eq(e.hp,468);eq(e.statuses.slow,2);eq(s.pendingPlay,nil)
end)
test('the experimental hand-choice continuation delays Slow and rejects stale resumes',function()
 local data=require('abyss_warrior_exhaust_cards').withCards(D)
 local s=battle({'burning_pact','strike','defend'},nil,data);local e=s.enemies[1]
 assert(C.play(s,uid(s,'burning_pact')));local choice=assert(s.pendingHandChoice)
 eq(e.statuses.slow,0);local selected=uid(s,'strike')
 eq(C.chooseHand(s,{},choice.token),false);eq(e.statuses.slow,0)
 assert(C.chooseHand(s,{selected},choice.token));eq(e.statuses.slow,1);eq(s.pendingPlay,nil)
 local before=C.copy(s);eq(C.chooseHand(s,{selected},choice.token),false);same(s,before)
end)
test('late queued ApplyPower failure restores the exact play graph and permits retry',function()
 local s=battle({'strike'});local e=s.enemies[1];local hand,events,statuses=s.hand,s.events,e.statuses
 local before=C.copy(s);local old=G.applySlow;local reached=false
 G.applySlow=function(...)old(...);reached=true;error('late Slow failure')end
 local ok=pcall(C.play,s,uid(s,'strike'),1);G.applySlow=old
 assert(not ok and reached);same(s,before);eq(s.hand,hand);eq(s.events,events);eq(e.statuses,statuses)
 assert(C.play(s,uid(s,'strike'),1));eq(e.hp,494);eq(e.statuses.slow,1)
end)
test('late end-round failure restores ramp history Slow and RNG object identities',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'slow',3,e)
 local before=C.copy(s);local rng,words,events=s.aiRng,s.aiRng.primitive,s.events
 local old=G.endRound;local reached=false
 G.endRound=function(state,actor)old(state,actor);if actor==e then reached=true;error('late Slow reset')end end
 local ok=pcall(C.endTurn,s);G.endRound=old
 assert(not ok and reached);same(s,before);eq(s.enemies[1],e);eq(s.aiRng,rng);eq(rng.primitive,words);eq(s.events,events)
 assert(C.endTurn(s));eq(e.statuses.slow,0);eq(s.aiRng.counter,2)
end)
test('real unchanged Act3 elite queue opens Giant Head and leaves unavailable elites atomic',function()
 local r=stage();eq(Q.peek(r.encounters,'elite'),'Giant Head');local queue=r.encounters
 assert(Run.startRoomCombat(r,'elite'));eq(r.encounterSource,'Giant Head');eq(r.encounterTier,'elite')
 eq(r.combat.enemies[1].definitionId,'giant_head');eq(#r.combat.enemies,1)
 eq(r.combat.monsterHpRng.counter,1);eq(r.combat.aiRng.counter,1);eq(#r.encounters.elite,#queue.elite-1)
 for _,seed in ipairs({'1','3'})do
  local unavailable=stage(seed);local before=C.copy(unavailable)
  local ok,why=Run.startRoomCombat(unavailable,'elite');eq(ok,false);eq(why,'act_content_unavailable');same(unavailable,before)
 end
 eq(require('abyss_act3_enemies').resolve('Giant Head','normal'),nil)
end)
test('real elite victory creates one source gold card potion and relic reward transaction',function()
 local r=stage();local s,e,strike=nearLethal(r)
 local goldRng=R.cloneState(r.treasureRng);local gold=R.randomIntBetween(goldRng,25,35)
 assert(Run.play(r,strike,1));eq(e.hp,0);eq(r.phase,'reward');eq(r.victories,1)
 eq(r.lastResult.outcome,'victory');eq(r.lastResult.allEnemiesEscaped,false)
 eq(r.rewards.gold,gold);eq(#r.rewards.cards,3);eq(#r.rewards.relics,1)
 same(R.snapshot(r.treasureRng),R.snapshot(goldRng));eq(s.enemies[1],e)
 assert(Run.claimGoldReward(r));local before=C.copy(r);eq(Run.claimGoldReward(r),false);same(r,before)
end)
test('late public constructor and reward rejection restore resources queues and actor references',function()
 do
  local r=stage();local before=C.copy(r);local queue,deck=r.encounters,r.deck
  local old=C.new;C.new=function(...)local s=old(...);eq(s.enemies[1].definitionId,'giant_head');error('late constructor')end
  local ok,why=Run.startRoomCombat(r,'elite');C.new=old
  eq(ok,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,queue);eq(r.deck,deck)
 end
 for _,mode in ipairs({'throw','reject'})do
  local r=stage();local s,e,strike=nearLethal(r);local before=C.copy(r)
  local queue,deck,hand,events,statuses,rng=r.encounters,r.deck,s.hand,s.events,e.statuses,r.cardRng
  local old=Run.finishCombat;local reached=false
  Run.finishCombat=function(...)local ok,why=old(...);assert(ok,why);reached=true
   if mode=='throw'then error('late reward failure')end;return false,'late_reward_rejection'end
  local called,ok,why=pcall(Run.play,r,strike,1);Run.finishCombat=old
  assert(reached);if mode=='reject'then assert(called);eq(ok,false);eq(why,'late_reward_rejection')else assert(not called)end
  same(r,before);eq(r.combat,s);eq(s.enemies[1],e);eq(r.encounters,queue);eq(r.deck,deck)
  eq(s.hand,hand);eq(s.events,events);eq(e.statuses,statuses);eq(r.cardRng,rng)
  assert(Run.play(r,strike,1));eq(r.phase,'reward');eq(r.victories,1)
 end
end)
print('GIANT_HEAD_SLOW '..count..' groups; '..failed..' failed');assert(failed==0)
