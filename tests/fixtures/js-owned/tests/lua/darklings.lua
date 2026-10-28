-- Controlled source fixtures; not an original-PC run or natural campaign.
local C,A,D,B,AI,R,Run,Q=require('abyss_combat'),require('abyss_actor'),require('abyss_data'),
 require('abyss_darklings'),require('abyss_enemy_ai'),require('abyss_sts_random'),require('abyss_run'),require('abyss_encounter_queue')
local count,failed=0,0
local fixtureData=C.copy(D);fixtureData.statuses=require('abyss_silent_final_cards').withCardDefinitions(D).statuses
local function eq(a,b,label)assert(a==b,'[DARKLING_ASSERT '..(label or '')..'] '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function test(name,fn)
 if ABYSS_MUTATION_CASE and ABYSS_MUTATION_CASE~=name then return end
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function battle(mode,deck,seed)
 seed=seed or '42';local streams={}
 for _,id in ipairs({'monsterHpRng','aiRng','miscRng','cardRandomRng','shuffleRng'})do streams[id]=R.fromSeed(seed)end
 return C.new(fixtureData,{enemies={'darkling','darkling','darkling'},deck=deck or {},hp=1000,maxHp=1000,
  roomSeed=seed,roomStreams=streams,enableStances=mode=='advanced'})
end
local function intent(e)return e.intents[e.intentIndex].id end
local function force(e,id)for i,m in ipairs(e.intents)do if m.id==id then e.intentIndex=i;return end end;error(id)end
local function card(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('missing '..id)end
local function zero(s,e)A.loseHp(s,e,1000);assert(e.halfDead);eq(e.hp,0);require('abyss_card_actions').drain(C,s)end
local function stage()
 local r=Run.new(D,'1',{experimental=true,campaign=true});r.act,r.floor,r.encounters=3,35,Q.new('1',3)
 eq(Q.peek(r.encounters,'normal'),'3 Darklings');return r
end
local function open()local r=stage();assert(Run.startRoomCombat(r,'normal'));return r end
test('source formation resolves only normal and constructs in exact source order without misc draws',function()
 local resolver=require('abyss_act3_enemies');local e=assert(resolver.resolve('3 Darklings','normal'))
 eq(e.sourceEncounter,'3 Darklings');eq(e.tier,'normal');eq(resolver.resolve('3 Darklings','elite'),nil)
 local trace={};local rows=require('abyss_encounter_formation').assemble('3 Darklings',{misc={},construct=function(id,x,y)
  trace[#trace+1]={id,x,y};return {id=id}
 end})
 eq(#rows,3);same(trace,{{'darkling',-440,10},{'darkling',-140,30},{'darkling',180,-5}})
end)
test('public unchanged weak queue constructs real Darklings and commits once',function()
 local r=stage();local before,queue,data=C.copy(r.encounters),r.encounters,C.copy(r.data)
 assert(Run.startRoomCombat(r,'normal'));eq(r.phase,'combat');eq(#r.combat.enemies,3)
 eq(r.combat.roomSeed,'36');eq(r.combat.sourceEncounter,'3 Darklings');assert(r.encounters~=queue)
 local source,nextQueue=Q.consume(before,'normal');eq(source,'3 Darklings');same(r.encounters,nextQueue);same(r.data,data)
 local positions={{-440,10},{-140,30},{180,-5}}
 for i,e in ipairs(r.combat.enemies)do eq(e.sourceId,'Darkling');eq(e.definitionId,'darkling')
  eq(e.statuses.regrow,-1);eq(e.sourcePosition.x,positions[i][1]);eq(e.sourcePosition.y,positions[i][2]);eq(e.statuses.strength,nil)
 end
end)
test('constructors interleave HP and Nip per actor before every opening roll and Power',function()
 local prepare,initialize,preBattle=AI.prepare,AI.initialize,B.preBattle;local trace={}
 AI.prepare=function(s,e,random)
  trace[#trace+1]='before'..s.monsterHpRng.counter..'/'..s.aiRng.counter
  local result=prepare(s,e,random);trace[#trace+1]='after'..s.monsterHpRng.counter;return result
 end
 AI.initialize=function(s,e,random)trace[#trace+1]='init'..s.monsterHpRng.counter..'/'..s.aiRng.counter;return initialize(s,e,random)end
 B.preBattle=function(api,s,e)trace[#trace+1]='pre'..s.monsterHpRng.counter..'/'..s.aiRng.counter;return preBattle(api,s,e)end
 local ok,why=pcall(battle);AI.prepare,AI.initialize,B.preBattle=prepare,initialize,preBattle;assert(ok,why)
 same(trace,{'before1/0','after2','before3/0','after4','before5/0','after6','init6/0','init6/1','init6/2','pre6/3','pre6/3','pre6/3'})
end)
test('all one hundred opening thresholds consume exactly one roll and never select Chomp',function()
 local s=battle();for _,e in ipairs(s.enemies)do for n=0,99 do
  local calls=0;B.initialize(s,e,function(_,maximum)eq(maximum,100);calls=calls+1;return n+1 end)
  eq(intent(e),n<50 and 'harden'or 'nip');eq(calls,1);eq(e.darklingFirst,false)
 end end
end)
test('source decision thresholds and recursive reroll ranges honor actual center slot and histories',function()
 local s=battle()
 for slot,e in ipairs(s.enemies)do for _,history in ipairs({{'nip'},{'harden'},{'chomp'},{'nip','nip'}})do
  for n=0,99 do
   e.darklingFirst=false;e.darklingHistory=C.copy(history)
   local calls={};local needReroll=n<40 and (slot==2 or history[#history]=='chomp')or n>=70 and #history==2
   B.afterAction(s,e,function(_,maximum)
    calls[#calls+1]=maximum
    if #calls==1 then eq(maximum,100);return n+1 end
    eq(maximum,n<40 and 60 or 100);return n<40 and 11 or 51 -- fallback value50
   end)
   local roll=needReroll and 50 or n;local last=history[#history]
   local expected=roll<40 and 'chomp'or roll<70 and (last=='harden'and 'nip'or 'harden')or 'nip'
   eq(intent(e),expected);eq(#calls,needReroll and 2 or 1)
  end
 end end
end)
test('independent six-seed seven-round vectors match HP Nip moves block damage and complete RNG words',function()
 local vectors=dofile('tests/fixtures/darklings-vectors.lua');eq(#vectors,6)
 for _,v in ipairs(vectors)do
  local s=battle(nil,nil,v.seed)
  for i,e in ipairs(s.enemies)do eq(e.hp,v.initial.actors[i].maxHp);eq(e.darklingNip,v.initial.actors[i].nip)
   eq(intent(e),v.initial.moves[i]);eq(e.statuses.regrow,-1)
  end
  same(R.snapshot(s.aiRng),v.initial.ai);same(R.snapshot(s.monsterHpRng),v.monsterHp)
  for _,round in ipairs(v.rounds)do
   local start=#s.events;assert(C.endTurn(s));eq(s.player.hp,round.playerHp)
   for i,e in ipairs(s.enemies)do
    eq(intent(e),round.actors[i].next);eq(e.block,round.actors[i].block);eq(e.statuses.strength,nil)
    local hits,total=0,0
    for n=start+1,#s.events do local ev=s.events[n]
     if ev.kind=='damage'and ev.detail.source==e.id then hits=hits+1;total=total+ev.detail.amount end
    end
    eq(total,round.actors[i].damage);eq(hits,round.actors[i].move=='chomp'and 2 or round.actors[i].move=='nip'and 1 or 0)
   end
   same(R.snapshot(s.aiRng),round.ai);same(R.snapshot(s.monsterHpRng),v.monsterHp);same(R.snapshot(s.miscRng),v.misc)
  end
 end
end)
for _,mode in ipairs({'native','advanced'})do
 test(mode..' first death clears all powers and block but keeps combat nonterminal and untargetable',function()
  local s=battle(mode,{'strike','defend'});local e=s.enemies[1]
  A.applyPower(s,e,'strength',3,e);A.applyPower(s,e,'poison',9,s.player);A.applyPower(s,e,'barricade',1,e);e.block=17
  zero(s,e);eq(e.block,0);eq(next(e.statuses),nil);eq(#e.powerOrder,0);eq(intent(e),'regrow')
  eq(A.isActive(e),false);eq(A.isPresent(e),true);eq(C.outcome(s),nil);assert(s.darklingsCannotLose)
  local before=C.copy(s);local ok,why=C.play(s,card(s,'strike').uid,1);eq(ok,false);eq(why,'invalid_target');same(s,before)
  assert(C.play(s,card(s,'defend').uid));eq(s.player.block,5)
 end)
 test(mode..' Regrow consumes a turn before Reincarnate heals integer half and selects a fresh move',function()
  local s=battle(mode);local e=s.enemies[1];e.maxHp=55;zero(s,e);local hpRng=R.snapshot(s.monsterHpRng)
  local before=s.aiRng.counter;assert(C.endTurn(s));eq(e.hp,0);assert(e.halfDead);eq(intent(e),'reincarnate')
  assert(s.aiRng.counter>=before+3);eq(A.isActive(e),false)
  assert(C.endTurn(s));eq(e.hp,27);eq(e.halfDead,false);eq(e.statuses.regrow,-1);eq(A.isActive(e),true)
  assert(intent(e)~='regrow'and intent(e)~='reincarnate');eq(e.darklingFirst,false)
  same(R.snapshot(s.monsterHpRng),hpRng)
 end)
 test(mode..' one or two sleeping Darklings do not award victory and all three finally die',function()
  local s=battle(mode);zero(s,s.enemies[1]);zero(s,s.enemies[2]);eq(C.outcome(s),nil)
  A.loseHp(s,s.enemies[3],1000);eq(C.outcome(s),'victory');eq(s.darklingsCannotLose,nil)
  for i,e in ipairs(s.enemies)do eq(e.hp,0);eq(e.isDying,true);eq(A.isPresent(e),false);eq(A.isActive(e),false)
   eq(e.halfDead,i~=3)
  end
  local rng=R.snapshot(s.aiRng);C.endTurn(s);same(R.snapshot(s.aiRng),rng)
 end)
 test(mode..' lethal poison enters Regrow in the same enemy turn without reinserting the Power',function()
  local s=battle(mode);local e=s.enemies[1];A.applyPower(s,e,'poison',1000,s.player)
  assert(C.endTurn(s));eq(e.hp,0);assert(e.halfDead);eq(e.statuses.poison,nil);eq(intent(e),'reincarnate')
 end)
 test(mode..' Reincarnate queues Heal then REVIVE then Regrow before RollMove without a second manager',function()
  local s=battle(mode);local e=s.enemies[1];zero(s,e);assert(C.endTurn(s))
  local old=B.reincarnate;local trace={}
  B.reincarnate=function(api,state,actor,stage)
   if actor==e then
    trace[#trace+1]={stage,actor.hp,actor.halfDead,actor.statuses.regrow or 0};eq(state.actionQueue,nil)
    if stage=='darklingRevive'then eq(A.isActive(actor),false,'healed halfDead is not a target')end
   end
   return old(api,state,actor,stage)
  end
  local ok,why=pcall(C.endTurn,s);B.reincarnate=old;assert(ok,why)
  same(trace,{{'darklingHeal',0,true,0},{'darklingRevive',math.floor(e.maxHp/2),true,0},
   {'darklingRegrow',math.floor(e.maxHp/2),false,0}})
 end)
 test(mode..' late Reincarnate failure rolls back zeroHP actors queues powers and RNG in place',function()
  local s=battle(mode);local e=s.enemies[1];zero(s,e);assert(C.endTurn(s))
  local before=C.copy(s);local enemies,hand,events,rng,history=s.enemies,s.hand,s.events,s.aiRng,e.darklingHistory
  local old=B.reincarnate
  B.reincarnate=function(api,state,actor,stage)
   local value=old(api,state,actor,stage);if actor==e and stage=='darklingRegrow'then error('late Reincarnate')end;return value
  end
  local ok=pcall(C.endTurn,s);B.reincarnate=old;eq(ok,false);same(s,before)
  eq(s.enemies,enemies);eq(s.hand,hand);eq(s.events,events);eq(s.aiRng,rng);eq(e.darklingHistory,history)
  assert(C.endTurn(s));assert(A.isActive(e))
 end)
 test(mode..' lethal Thorns cancels second Chomp hit and bottom SetMove overrides its already queued RollMove',function()
  local s=battle(mode);local e=s.enemies[1];e.hp=1;force(e,'chomp');A.applyPower(s,s.player,'thorns',2,s.player)
  force(s.enemies[2],'harden');force(s.enemies[3],'harden');local hp=s.player.hp
  assert(C.endTurn(s));eq(s.player.hp,hp-8);eq(e.hp,0);eq(intent(e),'regrow');assert(e.halfDead)
  local h=e.darklingHistory;eq(h[#h-1],'reincarnate');eq(h[#h],'regrow')
 end)
 test(mode..' source linked death transition participates in existing play rollback',function()
  local s=battle(mode,{'strike'});local e=s.enemies[1];e.hp=1;local before=C.copy(s);local hand,order=s.hand,e.powerOrder
  local old=B.deathFinish
  B.deathFinish=function(...)old(...);error('late linked death')end
  local ok=pcall(C.play,s,card(s,'strike').uid,1);B.deathFinish=old;eq(ok,false);same(s,before)
  eq(s.enemies[1],e);eq(s.hand,hand);eq(e.powerOrder,order);assert(C.play(s,card(s,'strike').uid,1))
 end)
end
test('death Power visits see cleared block before total Power removal and final group die visits once per actor',function()
 local s=battle();local e=s.enemies[1];local P=require('abyss_act2_powers');local SF=require('abyss_silent_final_cards')
 A.applyPower(s,e,'corpse_explosion',1,s.player);e.block=17
 local died,death=P.died,SF.death;local visits,blocks={},{}
 P.died=function(state,actor,push)if state==s then visits[#visits+1]={actor.id,actor.halfDead,actor.isDying or false}end;return died(state,actor,push)end
 SF.death=function(state,actor,...)
  if state==s then blocks[#blocks+1]=actor.block end;return death(state,actor,...)
 end
 local ok,why=pcall(function()A.loseHp(s,e,1000);A.loseHp(s,s.enemies[2],1000);A.loseHp(s,s.enemies[3],1000)end)
 P.died,SF.death=died,death;assert(ok,why)
 eq(#visits,6);eq(blocks[1],0);eq(#blocks,1)
 same(visits,{{'darkling_1',true,false},{'darkling_2',true,false},{'darkling_3',true,false},
  {'darkling_1',true,true},{'darkling_2',true,true},{'darkling_3',false,true}})
end)
test('Corpse Explosion snapshots once while first linked death remains a real onDeath callback',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'corpse_explosion',1,s.player)
 local maximum=e.maxHp;zero(s,e);eq(e.statuses.corpse_explosion,nil)
 require('abyss_card_actions').drain(C,s)
 for i=2,3 do eq(s.enemies[i].hp,math.max(0,s.enemies[i].maxHp-maximum))end
end)
test('InstantKill uses halfDead not a fake HP1 and final death cannot revive the group',function()
 local s=battle();for i=1,3 do A.instantKill(s,s.enemies[i]);eq(s.enemies[i].hp,0)end
 eq(C.outcome(s),'victory');for _,e in ipairs(s.enemies)do eq(A.isPresent(e),false)end
end)
test('Feed gets no halfDead kill benefit but rewards only the actual last linked death',function()
 local s=battle(nil,{'feed'});local e=s.enemies[1];e.hp=1;local hp=s.player.maxHp
 assert(C.play(s,card(s,'feed').uid,1));eq(s.player.maxHp,hp);assert(e.halfDead)
 local t=battle(nil,{'feed'});zero(t,t.enemies[1]);zero(t,t.enemies[2]);t.enemies[3].hp=1
 assert(C.play(t,card(t,'feed').uid,3));eq(t.player.maxHp,1003);eq(C.outcome(t),'victory')
end)
test('last constructor error leaves public Run source queue and every permanent alias unchanged',function()
 local r=stage();local before=C.copy(r);local queue,deck,rng=r.encounters,r.deck,r.cardRng;local old=B.prepare;local reached=false
 B.prepare=function(s,e,random)
  local value=old(s,e,random);if s.monsterHpRng.counter==6 then reached=true;error('last constructor')end;return value
 end
 local ok,why=Run.startRoomCombat(r,'normal');B.prepare=old;eq(ok,false);eq(why,'combat_unavailable');assert(reached);same(r,before)
 eq(r.encounters,queue);eq(r.deck,deck);eq(r.cardRng,rng);assert(Run.startRoomCombat(r,'normal'))
end)
test('late second RollMove error restores public Run aliases and can retry normally',function()
 local r=open();local s=r.combat;local before=C.copy(r);local actor=s.enemies[2];local enemies,rng,hand=s.enemies,s.aiRng,s.hand
 local old=B.afterAction;local reached=false
 B.afterAction=function(state,e,random)
  local value=old(state,e,random);if e==actor then reached=true;error('late second RollMove')end;return value
 end
 local ok=pcall(Run.endTurn,r);B.afterAction=old;eq(ok,false);assert(reached);same(r,before)
 eq(r.combat,s);eq(s.enemies,enemies);eq(s.enemies[2],actor);eq(s.aiRng,rng);eq(s.hand,hand);assert(Run.endTurn(r))
end)
test('public Run first and second linked deaths stay combat and only final group death creates one reward',function()
 local r=open();local s=r.combat;local before=C.copy(r.encounters);local treasure=R.snapshot(r.treasureRng)
 zero(s,s.enemies[1]);zero(s,s.enemies[2]);eq(r.phase,'combat');eq(r.victories,0);eq(r.rewards,nil)
 same(R.snapshot(r.treasureRng),treasure);A.loseHp(s,s.enemies[3],1000)
 assert(Run.endTurn(r));eq(r.phase,'reward');eq(r.victories,1);assert(r.rewards.gold>=10 and r.rewards.gold<=20)
 local reward=r.rewards;eq(Run.endTurn(r),false);eq(r.victories,1);eq(r.rewards,reward);same(r.encounters,before)
end)
test('public Run.play keeps the three actual source actor targets and rewards only final linked death',function()
 local r=stage();r.deck={{uid=1,cardId='strike'},{uid=2,cardId='strike'},{uid=3,cardId='strike'}}
 assert(Run.startRoomCombat(r,'normal'));local s=r.combat
 for _,e in ipairs(s.enemies)do e.hp=1 end
 for i=1,3 do
  assert(Run.play(r,card(s,'strike').uid,i))
  eq(r.victories,i==3 and 1 or 0);eq(r.phase,i==3 and 'reward'or 'combat')
 end
 eq(C.outcome(s),'victory');eq(Run.play(r,1,3),false);eq(r.victories,1)
end)
test('late final reward error through Run.endTurn restores linked actors and all permanent streams in place',function()
 local r=open();local s=r.combat;zero(s,s.enemies[1]);zero(s,s.enemies[2]);s.enemies[3].hp=1
 A.applyPower(s,s.enemies[3],'poison',1,s.player)
 local before=C.copy(r);local actor,hand,enemies,rng,queue=s.enemies[3],s.hand,s.enemies,s.aiRng,r.encounters
 local P=require('abyss_potion_rewards');local old=P.commit;local reached=false
 P.commit=function(...)
  old(...);reached=true;error('late reward commit')
 end
 local ok=pcall(Run.endTurn,r);P.commit=old;eq(ok,false);assert(reached);same(r,before)
 eq(r.combat,s);eq(s.enemies,enemies);eq(s.enemies[3],actor);eq(s.hand,hand);eq(s.aiRng,rng);eq(r.encounters,queue)
 assert(Run.endTurn(r));eq(r.victories,1);eq(r.phase,'reward')
end)
print('DARKLINGS '..count..' groups; '..failed..' failed');assert(failed==0)
