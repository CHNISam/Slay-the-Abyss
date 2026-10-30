-- Controlled offline source/queue fixtures; no native or natural campaign claim.
local C,A,D,R,AI,B,Actions=require('abyss_combat'),require('abyss_actor'),require('abyss_data'),
 require('abyss_sts_random'),require('abyss_enemy_ai'),require('abyss_time_eater'),require('abyss_card_actions')
local Run,Q=require('abyss_run'),require('abyss_encounter_queue')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,'[TIME_EATER_ASSERT '..(label or 'value')..'] '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local function test(name,fn)
 if ABYSS_MUTATION_CASE and ABYSS_MUTATION_CASE~=name then return end
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function streams(seed)
 local out={seed=seed};for _,id in ipairs({'aiRng','monsterHpRng','cardRandomRng','shuffleRng'})do out[id]=R.fromSeed(seed)end;return out
end
local function battle(mode,deck,allies,seed,data)
 local s=C.new(data or D,{enemies=allies and {'time_eater','cultist'}or {'time_eater'},deck=deck or {},
  roomSeed=seed or '42',roomStreams=streams(seed or '42'),maxHp=1000,hp=1000,enableStances=mode=='advanced'})
 return s,s.enemies[1]
end
local function intent(e)return e.intents[e.intentIndex].id end
local function force(e,id)
 for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return end end;error(id)
end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('missing '..id)end
local function play(s,id,target)local c=held(s,id);local ok,why=C.play(s,c.uid,target);assert(ok,why);return c end
local function add(s,id)
 local c=Actions.fresh(C,s,id);s.hand[#s.hand+1]=c;return c
end
local function bare(last,previous)
 local e=C.copy(B.enemy);e.hp,e.maxHp=456,456;e.intentIndex=1;e.timeEaterLast,e.timeEaterPrevious=last,previous;return e
end
local function sequence(values,limits)
 local n=0
 return function(_,maximum)n=n+1;eq(maximum,limits[n],'RNG bound');assert(values[n]~=nil,'extra RNG');return values[n]+1 end,
  function()eq(n,#values,'draw count')end
end

test('A0 source registration and opening streams are exact',function()
 local resolved=assert(require('abyss_act3_bosses').resolve('Time Eater','boss'));eq(resolved.enemies[1],'time_eater')
 eq(require('abyss_act3_bosses').resolve('Time Eater','elite'),nil)
 for _,seed in ipairs({'1','42','77'})do local s,e=battle(nil,nil,nil,seed)
  eq(e.hp,456);eq(e.maxHp,456);eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1)
  eq(e.statuses.time_warp,0);eq(e.statuses.strength,nil);eq(e.sourcePosition.x,-50)
  eq(e.timeEaterUsedHaste,false);eq(s.cardRandomRng.counter,0)
 end
end)
test('independent three-seed twelve-turn vectors preserve recursive RNG states and source damage',function()
 local vectors=dofile('tests/fixtures/time-eater-vectors.lua');eq(#vectors,3)
 for _,v in ipairs(vectors)do
  local s,e=battle(nil,nil,nil,v.seed)
  for turn,step in ipairs(v.steps)do
   if turn==5 then e.hp=227 end
   eq(intent(e),step.intent);eq(s.aiRng.counter,step.aiBeforeRoll)
   assert(C.endTurn(s));eq(s.player.hp,step.playerHp);eq(e.hp,step.monsterHp)
  end
  eq(intent(e),v.nextIntent);same(R.snapshot(s.aiRng),v.ai);same(R.snapshot(s.monsterHpRng),v.hp)
 end
end)
test('all primary probability boundaries match independent decision table',function()
 for _,history in ipairs({{}, {'reverberate'}, {'reverberate','ripple'}})do
  for roll=0,99 do
   local e=bare(history[1],history[2]);local rng,done=sequence({roll},{100});B.advance({},e,rng);done()
   local expected=roll<45 and 'reverberate'or roll<80 and 'head_slam'or 'ripple'
   eq(intent(e),expected,'0/45/80 threshold')
  end
 end
end)
test('repeat avoidance consumes inclusive secondary integer draws not primary rerolls',function()
 for _,roll in ipairs({0,44})do for _,secondary in ipairs({0,29,30,49})do
  local e=bare('reverberate','reverberate');local rng,done=sequence({roll,secondary},{100,50})
  B.advance({},e,rng);done();eq(intent(e),secondary<30 and 'head_slam'or 'ripple')
 end end
 for _,secondary in ipairs({0,44,45,74})do
  local e=bare('ripple');local rng,done=sequence({99,secondary},{100,75})
  B.advance({},e,rng);done();eq(intent(e),secondary<45 and 'reverberate'or 'head_slam')
 end
end)
test('Head Slam repeat uses exact Java 0.66f float draw and both branches',function()
 local old= require('abyss_enemy_random').float
 for _,value in ipairs({0,0.6600000262260437-2^-24,0.6600000262260437,1-2^-24})do
  local calls=0;require('abyss_enemy_random').float=function()calls=calls+1;return value end
  local e=bare('head_slam');local rng,done=sequence({45},{100});B.advance({},e,rng);done();eq(calls,1)
  eq(intent(e),value<0.6600000262260437 and 'reverberate'or 'ripple')
 end
 require('abyss_enemy_random').float=old
end)
test('Haste selects strictly below half HP once at next roll and still consumes primary',function()
 local e=bare('ripple');e.hp=228
 local rng,done=sequence({0},{100});B.advance({},e,rng);done();eq(intent(e),'reverberate');eq(e.timeEaterUsedHaste,nil)
 e.hp=227;rng,done=sequence({99},{100});B.advance({},e,rng);done();eq(intent(e),'haste');eq(e.timeEaterUsedHaste,true)
 e.hp=1;rng,done=sequence({45},{100});B.advance({},e,rng);done();eq(intent(e),'head_slam')
 local s,actor=battle();force(actor,'ripple');C.damage(s,s.player,actor,230,true)
 eq(intent(actor),'ripple','damage must not interrupt');assert(C.endTurn(s));eq(intent(actor),'haste')
end)
for _,mode in ipairs({'native','advanced'})do
 test(mode..' exact Reverberate and Head Slam damage with only Head Slam reducing draw',function()
  local s,e=battle(mode,{'strike','defend','anger','bash','battle_trance','cleave','shrug_it_off','inflame','pommel_strike','true_grit'})
  force(e,'reverberate');local before=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,before-21);eq(#s.hand,5)
  force(e,'head_slam');before=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,before-26);eq(#s.hand,4)
  eq(s.player.statuses.draw_reduction,1);eq(#s.discard+#s.draw+#s.hand,10,'no A19 Slimed')
  force(e,'reverberate');assert(C.endTurn(s));eq(s.player.statuses.draw_reduction,0);eq(#s.hand,5)
 end)
 test(mode..' Ripple gives fixed block then Vulnerable then Weak and no A19 Frail',function()
  local s,e=battle(mode);force(e,'ripple');local start=#s.events+1
  A.applyPower(s,e,'dexterity',4,e);A.applyPower(s,e,'frail',1,s.player)
  A.applyPower(s,s.player,'artifact',1,s.player);assert(C.endTurn(s));eq(e.block,20)
  eq(s.player.statuses.vulnerable,nil);eq(s.player.statuses.weak,1);eq(s.player.statuses.frail,nil)
  local found={};for i=start,#s.events do local ev=s.events[i]
   if ev.kind=='status'and ev.detail.blockedStatus then found[#found+1]=ev.detail.blockedStatus end
  end;eq(found[1],'vulnerable')
 end)
 test(mode..' Draw Reduction Artifact and stacked duration do not multiply draw penalty',function()
  local s,e=battle(mode);A.applyPower(s,s.player,'artifact',1,s.player)
  eq(A.applyPower(s,s.player,'draw_reduction',1,e),false);eq(B.drawCount(s,5),5)
  assert(A.applyPower(s,s.player,'draw_reduction',1,e));assert(A.applyPower(s,s.player,'draw_reduction',2,e))
  eq(B.drawCount(s,5),4);eq(B.drawCount(s,0),0);eq(s.player.statuses.draw_reduction,3)
  A.endRound(s,s.player);eq(s.player.statuses.draw_reduction,3);A.endRound(s,s.player);eq(s.player.statuses.draw_reduction,2)
 end)
 test(mode..' Haste clears debuffs and negative Strength before captured heal, preserves positive Strength',function()
  for _,strength in ipairs({-8,6})do
   local s,e=battle(mode);e.hp=100;force(e,'haste');e.timeEaterUsedHaste=true
   A.applyPower(s,e,'strength',strength,s.player);A.applyPower(s,e,'weak',2,s.player)
   A.applyPower(s,e,'shackled',8,s.player);A.applyPower(s,e,'poison',3,s.player)
   local start=#s.events+1;assert(C.endTurn(s));eq(e.hp,228)
   if strength<0 then eq(e.statuses.strength,nil)else eq(e.statuses.strength,strength)end;eq(e.statuses.weak,nil);eq(e.statuses.poison,nil);eq(e.statuses.shackled,nil)
   eq(e.statuses.time_warp,0);local heal
   for i=start,#s.events do local ev=s.events[i];if ev.kind=='heal'and ev.detail.target==e.id then heal=i end end
   assert(heal);for i=heal+1,#s.events do local ev=s.events[i];assert(not(ev.kind=='status'and ev.detail.target==e.id and ev.detail.amount<0),'cleanup after heal')end
  end
 end)
 test(mode..' twelfth card completes effects before count reset Strength and forced end',function()
  local s,e=battle(mode,{'anger'});e.statuses.time_warp=11;force(e,'reverberate')
  local start=#s.events+1;local hp=s.player.hp;local c=play(s,'anger',1)
  eq(e.hp,450);eq(e.statuses.time_warp,0);eq(e.statuses.strength,2);eq(s.turn,2);eq(s.player.hp,hp-27)
  eq(s.endTurnAfterCard,nil);eq(s.cardInUse,nil);eq(s.actionQueue,nil);eq(s.cardActions,nil)
  local hit,reset,strength
  for i=start,#s.events do local ev=s.events[i]
   if ev.kind=='damage'and ev.detail.target==e.id then hit=i end
   if ev.kind=='status'and ev.detail.status=='time_warp'then reset=i end
   if ev.kind=='status'and ev.detail.status=='strength'and ev.detail.target==e.id then strength=i end
  end
  assert(hit<reset and reset<strength);assert(c.uid)
 end)
 test(mode..' count persists across turns and real card types all count',function()
  local s,e=battle(mode,{'anger','defend','inflame'});force(e,'ripple')
  play(s,'anger',1);play(s,'defend');play(s,'inflame');eq(e.statuses.time_warp,3)
  assert(C.endTurn(s));eq(e.statuses.time_warp,3);play(s,'anger',1);eq(e.statuses.time_warp,4)
 end)
 test(mode..' duplication counts real uses and threshold cancels pending purge copies',function()
  local s,e=battle(mode,{'anger'});A.applyPower(s,s.player,'double_tap',2,s.player)
  play(s,'anger',1);eq(e.statuses.time_warp,2);eq(e.hp,444)
  local attack=add(s,'anger');e.statuses.time_warp=11;A.applyPower(s,s.player,'double_tap',1,s.player);force(e,'ripple')
  assert(C.play(s,attack.uid,1));eq(e.hp,438);eq(e.statuses.time_warp,0);eq(e.statuses.strength,2);eq(s.turn,2)
  eq(s.queuedCards,nil)
 end)
 test(mode..' physical dontTrigger flag suppresses after-use and stat copies start fresh',function()
  local s,e=battle(mode,{'anger'});local c=held(s,'anger');c.dontTriggerOnUseCard=true
  local clone=Actions.sameInstance(C,s,c);eq(clone.dontTriggerOnUseCard,nil)
  A.applyPower(s,s.player,'double_tap',1,s.player)
  play(s,'anger',1);eq(e.statuses.time_warp,0);eq(e.hp,450);eq(s.player.statuses.double_tap,1)
  -- The Giant Head leaf owns the common ordinary-use flag reset; source
  -- TimeWarp reads the actual pre-reset object, not a definition-only flag.
  local purge=Actions.sameInstance(C,s,c);purge.dontTriggerOnUseCard=true
  C.queueCard(s,purge,{targetIndex=1,purge=true,exhaustCards=false});Actions.drain(C,s);eq(e.statuses.time_warp,0)
 end)
 test(mode..' real autoplay uses count; threshold cancellation disposes without use or count',function()
  local s,e=battle(mode,{'anger'});local first=held(s,'anger');local cancelled=Actions.fresh(C,s,'strike')
  C.queueCard(s,cancelled,{targetIndex=1,exhaustCards=true,append=true});e.statuses.time_warp=11;force(e,'ripple')
  assert(C.play(s,first.uid,1));eq(e.hp,450);eq(e.statuses.time_warp,0);eq(cancelled.dontTriggerOnUseCard,false)
  local found=false;for _,c in ipairs(s.exhaust)do if c==cancelled then found=true end end;assert(found)
  local nextCard=Actions.fresh(C,s,'anger');C.queueCard(s,nextCard,{targetIndex=1,exhaustCards=false});Actions.drain(C,s)
  eq(e.statuses.time_warp,1);eq(e.hp,450);eq(e.block,16)
 end)
 test(mode..' cancelled Sentinel TOP energy precedes Strength and Dark Embrace BOT draw follows',function()
  local s,e=battle(mode,{'anger'});e.statuses.time_warp=11;force(e,'ripple')
  local sentinel=Actions.fresh(C,s,'sentinel');local drawn=Actions.fresh(C,s,'defend');s.draw[#s.draw+1]=drawn
  A.applyPower(s,s.player,'dark_embrace',1,s.player);require('abyss_exhaust').rememberPower(s,'dark_embrace')
  C.queueCard(s,sentinel,{targetIndex=1,exhaustCards=true,append=true})
  local start=#s.events+1;play(s,'anger',1);local strength
  for i=start,#s.events do local ev=s.events[i]
   if ev.kind=='status'and ev.detail.target==e.id and ev.detail.status=='strength'then strength=ev;break end
  end
  assert(strength);eq(strength.frame.energy,5,'Sentinel TOP before Strength');eq(#strength.frame.hand,0,'Dark Embrace BOT after Strength')
  eq(#strength.frame.draw,1);eq(strength.frame.draw[1].uid,drawn.uid);eq(strength.frame.exhaust[1].uid,sentinel.uid)
 end)
 test(mode..' paused real Burning Pact reaches twelfth-card hook only after valid choice resume',function()
  local data
  if mode=='advanced'then data=require('abyss_warrior_exhaust_cards').withCards(require('abyss_warrior_cards').withFoundationCards(D))end
  local s,e=battle(mode,{'burning_pact','strike','defend'},nil,nil,data);e.statuses.time_warp=11;force(e,'ripple')
  local chosen=held(s,'defend');play(s,'burning_pact')
  local p=s.pendingHandChoice or s.pendingChoice;assert(p);eq(e.statuses.time_warp,11);eq(s.turn,1)
  local choose=s.pendingHandChoice and function(token)return C.chooseHand(s,{chosen.uid},token)end
   or function(token)return C.chooseCard(s,token,chosen.uid)end
  local before=C.copy(s);eq(choose(p.token+1),false);same(s,before)
  assert(choose(p.token));eq(e.statuses.time_warp,0);eq(s.turn,2);eq(e.statuses.strength,2)
  eq(s.pendingHandChoice,nil);eq(s.pendingChoice,nil);eq(s.cardInUse,nil);eq(choose(p.token),false);eq(s.turn,2)
 end)
 test(mode..' all enemies receive captured Strength but a lethal twelfth card creates no extra turn',function()
  local s,e=battle(mode,{'anger'},true);local ally=s.enemies[2];e.statuses.time_warp=11
  force(e,'ripple');play(s,'anger',1);eq(e.statuses.strength,2);eq(ally.statuses.strength,2)
  s,e=battle(mode,{'anger'});e.hp=6;e.statuses.time_warp=11;play(s,'anger',1)
  eq(C.outcome(s),'victory');eq(s.turn,1);eq(e.statuses.strength,nil);eq(s.endTurnAfterCard,nil)
 end)
 test(mode..' failures after after-use restore physical identity count RNG and queues',function()
  local s,e=battle(mode,{'anger'});e.statuses.time_warp=11;local c=held(s,'anger')
  local before=C.copy(s);local player,hand=s.player,s.hand;local old=B.execute
  B.execute=function(api,state,effect,...)
   local result=old(api,state,effect,...)
   if effect.kind=='strength'then error('TIME_EATER_INJECTED_FAILURE')end
   return result
  end
  local ok,why=pcall(C.play,s,c.uid,1);B.execute=old;eq(ok,false);assert(tostring(why):find('TIME_EATER_INJECTED_FAILURE',1,true))
  same(s,before);eq(s.player,player);eq(s.hand,hand);eq(held(s,'anger'),c)
 end)
end

test('Haste RemoveDebuffs reverses priority-sorted source Powers before explicit Shackled and heal',function()
 local s,e=battle();A.applyPower(s,e,'weak',2,s.player);A.applyPower(s,e,'strength',-3,s.player)
 A.applyPower(s,e,'poison',2,s.player);A.applyPower(s,e,'shackled',3,s.player);A.applyPower(s,e,'artifact',1,e)
 -- ApplyPowerAction stably sorts by AbstractPower.priority (default 5; Weak 99).
 -- RemoveDebuffsAction iterates that list and addToTop reverses its removals.
 eq(require('abyss_power_order').sourceFacts.weak.priority,99)
 eq(table.concat(e.powerOrder,','),'time_warp,strength,poison,shackled,artifact,weak')
 local start=#s.events+1;B.execute(C,s,{op='timeEater',kind='cleanse'},e,Actions)
 local removed={};for i=start,#s.events do local ev=s.events[i]
  if ev.kind=='status'and ev.detail.target==e.id then removed[#removed+1]=ev.detail.status end
 end
 eq(table.concat(removed,','),'weak,shackled,poison,strength');eq(e.statuses.artifact,1);eq(e.statuses.time_warp,0)
 local n=#s.events;B.execute(C,s,{op='timeEater',kind='removeShackled'},e,Actions);eq(#s.events,n)
end)
test('Haste HealAction captures signed amount at takeTurn rather than forcing half HP at resolution',function()
 local s,e=battle();e.hp=300;force(e,'haste');B.beforeAction(s,e,e.intents[e.intentIndex])
 eq(e.timeEaterHealAmount,-72);e.hp=290
 B.execute(C,s,{op='timeEater',kind='heal'},e,Actions);eq(e.hp,218)
end)
test('source public Run boss entry RNG rewards and no-repeat settlement',function()
 local run=Run.new(D,'42',{experimental=true,campaign=true});run.act,run.floor,run.encounters=3,50,Q.new('42',3)
 run.bossInitialization,run.encounters=Q.initializeBoss(run.encounters,{CROW=true,DONUT=true})
 eq(run.bossInitialization.bossList[1],'Time Eater');local misc=run.miscRng.counter;assert(Run.startRoomCombat(run,'boss'))
 local s,e=run.combat,run.combat.enemies[1];eq(run.encounterSource,'Time Eater');eq(#s.enemies,1)
 eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1);eq(run.miscRng.counter,misc)
 C.damage(s,s.player,e,1000,true);assert(Run.endTurn(run));eq(run.phase,'reward');eq(run.victories,1)
 local gold=run.gold;eq(Run.endTurn(run),false);eq(run.gold,gold);eq(run.victories,1)
end)
test('native Chinese metadata exposes zero countdown Head Slam draw and complete Haste intent',function()
 local s,e=battle();local found
 for _,entry in ipairs(C.statusView(e))do if entry.id=='time_warp'then found=entry;break end end
 assert(found);eq(found.amount,0);eq(found.name,'时间扭曲')
 local text=require('abyss_battle_status_view').statusDetail(found,s.rules,e);assert(text:find('0/12',1,true))
 local view=require('abyss_battle_intent_view');force(e,'head_slam');local v=view.intentView(s,1)
 assert(v.text:find('26',1,true));assert(v.text:find('抽牌减少',1,true))
 force(e,'haste');v=view.intentView(s,1);eq(#v.rows,3);assert(v.text:find('228',1,true));assert(not v.text:find('未知',1,true))
 local theme=require('abyss_theme');assert(theme.icon.status.time_warp);assert(theme.icon.status.draw_reduction)
end)
print('TIME_EATER '..count..' groups; '..failed..' failed')
assert(count>0 and failed==0,'Time Eater source contract regression')
