-- Pinned319009 method-chain regressions on real PR234 actors/cards/queues.
-- Staged powers/HP isolate ordering; this is not natural campaign or PC evidence.
local C,A,Q,D=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions'),require('abyss_data')
local P,AP,AI=require('abyss_plated_armor'),require('abyss_act2_powers'),require('abyss_enemy_ai')
local Schedule=require('abyss_power_schedule')
local modes={'native','advanced','v4'}
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or '')..' expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'ok ' or 'not ok ')..count..' - '..name..(ok and '' or ': '..tostring(why)))
end
local function battle(mode,ids)
 -- Import real source Power definitions without adding target-less Watcher
 -- cards, which would silently enable experimental mechanics in native/V4.
 local data=C.copy(D);data.statuses=require('abyss_watcher_flow_cards').withCards(D).statuses
 if mode=='v4'then data=require('abyss_original_v4_profiles').prepare(data,'hutao')end
 local state=C.new(data,{enemies=ids or {'shelled_parasite','cultist'},deck={},seed=42,hp=500,maxHp=500,enableStances=mode=='advanced'})
 if mode=='advanced'then assert(state.experimentalMechanics and state.player.stance)
 else assert(not state.experimentalMechanics,'native/V4 registry must not enable experimental mechanics')end
 eq(state.originalV4~=nil,mode=='v4','real V4 state routing')
 return state
end
local function card(s,id)
 local c={cardId=id,uid=s.nextUid,upgraded=false};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=c;return c
end
local function intent(e,id)
 for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error('missing intent '..id)
end
local function selected(e)return e.intents[e.intentIndex].id end
local function contains(pile,c)for _,v in ipairs(pile)do if v==c then return true end end end
local function withHooks(hooks,fn)
 local saved={}
 for i,h in ipairs(hooks)do saved[i]=h[1][h[2]];h[1][h[2]]=h[3](saved[i])end
 local ok,why=pcall(fn)
 for i,h in ipairs(hooks)do h[1][h[2]]=saved[i]end
 assert(ok,why)
end

for _,mode in ipairs(modes)do
 test(mode..' real Twin Strike queues two reductions after original hits and disposal',function()
  local s=battle(mode);local e=s.enemies[1];e.hp=1000;e.block=0;local c=card(s,'twin_strike');local frames={};local reductions=0
  withHooks({{P,'apply',function(old)return function(combat,state,effect,...)
   if effect.op=='platedReduce'then
    if mode=='advanced'then assert(state.actionQueue and not state.drainingCardActions,'advanced must own the ID-only queue')
    else assert(state.drainingCardActions and not state.actionQueue,'native/V4 must own CardActions, not legacy resolution')end
    reductions=reductions+1;eq(state.cardInUse,nil);assert(contains(state.discard,c),'card identity must be disposed first')
   end
   return old(combat,state,effect,...)
  end end}},function()assert(C.play(s,c.uid,1))end)
  for _,ev in ipairs(s.events)do if ev.kind=='damage' and ev.detail.target==e.id then frames[#frames+1]=ev.frame.enemies[1].statuses.plated_armor end end
  eq(#frames,2);eq(frames[1],14);eq(frames[2],14);eq(e.statuses.plated_armor,12);eq(reductions,2)
  eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil)
 end)
 test(mode..' real multihit Plated/BlockReturn/Juggernaut share causal BOTTOM order',function()
  for _,blocked in ipairs({0,5})do
   local s=battle(mode);local e=s.enemies[1];e.hp=1000;e.block=blocked
   A.applyPower(s,e,'block_return',2,s.player);A.applyPower(s,s.player,'juggernaut',1,s.player)
   local c=card(s,'twin_strike');local trace={}
   withHooks({{P,'apply',function(old)return function(combat,state,effect,...)
    if effect.op=='platedReduce'then trace[#trace+1]='R';eq(state.cardInUse,nil)end;return old(combat,state,effect,...)
   end end},{C,'damage',function(old)return function(state,source,target,n,fixed,...)
    if state==s and fixed and source==s.player then trace[#trace+1]='J';eq(state.cardInUse,nil)end
    return old(state,source,target,n,fixed,...)
   end end}},function()assert(C.play(s,c.uid,1))end)
   eq(table.concat(trace,','),blocked==0 and 'R,J,R,J' or 'J,R,J')
   eq(e.statuses.plated_armor,blocked==0 and 12 or 13);eq(s.cardActions,nil);eq(s.actionQueue,nil)
  end
 end)
 test(mode..' qualified hits remove an existing zero-valued Plated Power but never act on absence',function()
  for _,present in ipairs({false,true})do
   local s=battle(mode);local e=s.enemies[1];e.hp=1000;e.block=0
   Q.enqueue(s,{op='platedRemove',targetId=e.id});Q.drain(C,s);intent(e,'life_suck')
   if present then A.applyPower(s,e,'plated_armor',0,s.player);eq(Schedule.list(e,{plated_armor=true})[1].amount,0)end
   local c=card(s,'twin_strike');local reductions,changes=0,0
   withHooks({{Q,'enqueueReaction',function(old)return function(state,effect,top)
    if state==s and effect.op=='platedReduce'then reductions=reductions+1 end;return old(state,effect,top)
   end end},{C,'changeMonsterState',function(old)return function(state,target,name)
    if state==s and target==e then changes=changes+1 end;return old(state,target,name)
   end end}},function()assert(C.play(s,c.uid,1))end)
   eq(reductions,present and 2 or 0);eq(changes,present and 1 or 0);eq(e.statuses.plated_armor,nil)
   eq(selected(e),present and 'stunned' or 'life_suck')
  end
 end)
 test(mode..' original Taskmaster Wound and Roll precede appended Reduce',function()
  local s=battle(mode,{'taskmaster','cultist'});local e=s.enemies[1];local trace={}
  A.applyPower(s,s.player,'plated_armor',4,s.player)
  local V=require('abyss_original_v4')
  withHooks({{C,'damage',function(old)return function(state,source,target,n,...)
   if state==s and source==e then eq(state.actionQueue,nil,'enemy must not activate advanced routing');trace[#trace+1]='H'end
   return old(state,source,target,n,...)
  end end},{Q,'apply',function(old)return function(combat,state,item)
   if state==s and item.effect.op=='enemyAction' and item.effect.payload and item.effect.payload.op=='makeTempCardInDiscard'then trace[#trace+1]='W'end
   return old(combat,state,item)
  end end},{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s and owner==e then trace[#trace+1]='Roll'end;return old(state,owner,...)
  end end},{P,'apply',function(old)return function(combat,state,effect,...)
   if state==s and effect.op=='platedReduce'then trace[#trace+1]='R'end;return old(combat,state,effect,...)
  end end},{V,'endEnemyAction',function(old)return function(combat,state)
   if state==s and state.originalV4.enemyAction.enemy==e then trace[#trace+1]='V'end;return old(combat,state)
  end end}},function()assert(C.endTurn(s))end)
  eq(table.concat(trace,','),mode=='v4' and 'H,W,V,Roll,R' or 'H,W,Roll,R');eq(s.player.statuses.plated_armor,3)
 end)
 test(mode..' real Book callbacks append Reduce then Wound per hit after its original Roll',function()
  local s=battle(mode,{'book_of_stabbing'});local e=s.enemies[1];intent(e,'multi_stab');local trace={}
  A.applyPower(s,s.player,'plated_armor',4,s.player)
  withHooks({{C,'damage',function(old)return function(state,source,target,n,...)
   if state==s and source==e then trace[#trace+1]='H';eq(state.actionQueue,nil)end;return old(state,source,target,n,...)
  end end},{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s and owner==e then trace[#trace+1]='Roll'end;return old(state,owner,...)
  end end},{P,'apply',function(old)return function(combat,state,effect,...)
   if state==s and effect.op=='platedReduce'then trace[#trace+1]='R'end;return old(combat,state,effect,...)
  end end},{AP,'apply',function(old)return function(api,state,effect)
   if state==s and effect.op=='painfulWound'then trace[#trace+1]='W'end;return old(api,state,effect)
  end end}},function()assert(C.endTurn(s))end)
  eq(table.concat(trace,','),'H,H,Roll,R,W,R,W');eq(s.player.statuses.plated_armor,2)
 end)
 test(mode..' blocked first enemy hit cannot let Juggernaut overtake original Roll before later Reduce',function()
  local s=battle(mode,{'book_of_stabbing'});local e=s.enemies[1];intent(e,'multi_stab');local trace={}
  A.applyPower(s,s.player,'plated_armor',6,s.player);A.applyPower(s,s.player,'block_return',2,s.player)
  A.applyPower(s,s.player,'juggernaut',1,s.player)
  withHooks({{C,'damage',function(old)return function(state,source,target,n,fixed,...)
   if state==s and state.phase=='enemy'then trace[#trace+1]=source==e and 'H' or 'J'end
   return old(state,source,target,n,fixed,...)
  end end},{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s and owner==e then trace[#trace+1]='Roll'end;return old(state,owner,...)
  end end},{P,'apply',function(old)return function(combat,state,effect,...)
   if state==s and effect.op=='platedReduce'then trace[#trace+1]='R'end;return old(combat,state,effect,...)
  end end}},function()assert(C.endTurn(s))end)
  eq(table.concat(trace,','),'H,H,Roll,J,R,J');eq(s.player.statuses.plated_armor,5)
 end)
 test(mode..' both pre-card hooks snapshot fixed amounts before any block action',function()
  for _,platedFirst in ipairs({false,true})do
  local s=battle(mode,{'cultist'});A.applyPower(s,s.player,'metallicize',3,s.player);A.applyPower(s,s.player,'plated_armor',4,s.player)
  if platedFirst then
   -- Recreate legal reverse acquisition order through source application.
   s=battle(mode,{'cultist'});A.applyPower(s,s.player,'plated_armor',4,s.player);A.applyPower(s,s.player,'metallicize',3,s.player)
  end
  A.applyPower(s,s.player,'dexterity',20,s.player);A.applyPower(s,s.player,'frail',2,s.player);card(s,'burn')
  local seen={};local hp=s.player.hp
  withHooks({{C,'block',function(old)return function(state,owner,n,fixed)
   if state==s and owner==s.player then
    seen[#seen+1]=n;eq(fixed,true);if #seen==1 then A.applyPower(s,s.player,platedFirst and 'metallicize' or 'plated_armor',90,s.player)end
   end
   return old(state,owner,n,fixed)
  end end}},function()assert(C.endTurn(s))end)
  eq(#seen,2);eq(seen[1],platedFirst and 4 or 3);eq(seen[2],platedFirst and 3 or 4);eq(s.player.hp,hp)
  end
 end)
 test(mode..' group-end fixed block snapshots follow every teammate and precede round-end',function()
  local s=battle(mode);local e,ally=s.enemies[1],s.enemies[2];intent(e,'double_strike');A.applyPower(s,ally,'metallicize',5,ally)
  A.applyPower(s,e,'metallicize',3,e)
  local seen={};local acted={}
  withHooks({{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s then acted[owner.id]=true end;return old(state,owner,...)
  end end},{C,'block',function(old)return function(state,owner,n,fixed)
   if state==s and owner~=s.player then
    assert(acted[e.id] and acted[ally.id],'all original turns and tails must finish first');seen[#seen+1]=n;eq(fixed,true)
    if owner==e then ally.statuses.metallicize=99 end
   end
   return old(state,owner,n,fixed)
  end end}},function()assert(C.endTurn(s))end)
  eq(#seen,3);eq(seen[1],14);eq(seen[2],3);eq(seen[3],5);eq(e.block,17);eq(ally.block,5)
 end)
 test(mode..' queued Remove/ChangeState failure rolls card, actors, membership and RNG back in place',function()
  local s=battle(mode);local e=s.enemies[1];e.hp=1000;e.block=0;e.statuses.plated_armor=1;local c=card(s,'twin_strike')
  local actor,statuses,hand,events,order,schedule,rng=e,e.statuses,s.hand,s.events,e.powerOrder,e.powerScheduleOrder,s.cardRandomRng
  local before=C.copy(s)
  withHooks({{C,'changeMonsterState',function(old)return function(state,target,name)
   old(state,target,name);error('injected after ARMOR_BREAK')
  end end}},function()
   local ok,why=pcall(C.play,s,c.uid,1);eq(ok,false);assert(tostring(why):find('injected after ARMOR_BREAK',1,true))
  end)
  eq(s.enemies[1],actor);eq(e.statuses,statuses);eq(s.hand,hand);eq(s.hand[1],c);eq(s.events,events)
  eq(e.powerOrder,order);eq(e.powerScheduleOrder,schedule);eq(s.cardRandomRng,rng)
  eq(e.statuses.plated_armor,1);eq(e.hp,before.enemies[1].hp);eq(s.energy,before.energy);eq(#events,#before.events)
  eq(rng.counter,before.cardRandomRng.counter);eq(s.seed,before.seed);eq(s.cardActions,nil);eq(s.actionQueue,nil)
 end)
end

test('low-level qualified hit appends without mutation; exclusions never append',function()
 local s=battle('native');local e=s.enemies[1];e.block=0;local chosen=selected(e)
 C.damage(s,e,e,1);C.damage(s,nil,e,1,false,nil,1);C.damage(s,s.player,e,1,true);C.retaliate(s,s.player,e,1)
 eq(e.statuses.plated_armor,14);eq(s.cardActions,nil);eq(selected(e),chosen)
 A.damage(s,s.player,e,1);eq(e.statuses.plated_armor,14);eq(s.cardActions[1].effect.op,'platedReduce')
 Q.drain(C,s);eq(e.statuses.plated_armor,13)
end)
test('public standalone damage settles tails and applyEffects settles only after the whole batch',function()
 local s=battle('native');local e=s.enemies[1];e.block=0
 C.damage(s,s.player,e,1);eq(e.statuses.plated_armor,13);eq(s.cardActions,nil)
 s.events={};C.applyEffects(s,{{op='damage',value=1,times=2}},s.player,e)
 local frames={};for _,ev in ipairs(s.events)do if ev.kind=='damage'then frames[#frames+1]=ev.frame.enemies[1].statuses.plated_armor end end
 eq(#frames,2);eq(frames[1],13);eq(frames[2],13);eq(e.statuses.plated_armor,11);eq(s.cardActions,nil)
end)
test('preexisting native queue shared area batch and active owners prevent standalone draining',function()
 local s=battle('native');local e=s.enemies[1];e.block=0;local energy=s.energy
 Q.enqueue(s,{op='energy',value=1});C.damage(s,s.player,e,1)
 eq(e.statuses.plated_armor,14);eq(s.energy,energy);Q.drain(C,s);eq(e.statuses.plated_armor,13);eq(s.energy,energy+1)
 s=battle('native',{'shelled_parasite','shelled_parasite'});local reactions={}
 for _,target in ipairs(s.enemies)do target.block=0;C.damage(s,s.player,target,1,false,reactions)end
 for _,target in ipairs(s.enemies)do eq(target.statuses.plated_armor,14)end
 A.resolveDamageReactions(s,reactions);Q.drain(C,s)
 for _,target in ipairs(s.enemies)do eq(target.statuses.plated_armor,13)end
 for _,field in ipairs({'resolvingEffects','resolvingCard','drainingCardActions'})do
  s=battle('native');e=s.enemies[1];e.block=0;s[field]=true;C.damage(s,s.player,e,1)
  eq(e.statuses.plated_armor,14);s[field]=nil;Q.drain(C,s);eq(e.statuses.plated_armor,13)
 end
end)
test('dead target distinguishes reducing stacks from guarded last-stack removal and final clear',function()
 for _,stacks in ipairs({1,2})do for _,teammate in ipairs({false,true})do
  local s=battle('native',teammate and {'shelled_parasite','cultist'} or {'shelled_parasite'});local e=s.enemies[1]
  e.block=0;e.hp=1;e.statuses.plated_armor=stacks;local chosen=selected(e)
  A.damage(s,s.player,e,1);eq(e.statuses.plated_armor,stacks);Q.drain(C,s)
  eq(e.statuses.plated_armor,teammate and math.max(1,stacks-1) or stacks);eq(selected(e),chosen)
 end end
end)
test('escaped target has Reduce without life guard but Remove refuses final-stack deletion',function()
 for _,stacks in ipairs({1,2})do
  local s=battle('native');local e=s.enemies[1];e.block=0;e.statuses.plated_armor=stacks
  A.damage(s,s.player,e,1);e.escaped=true;Q.drain(C,s);eq(e.statuses.plated_armor,math.max(1,stacks-1))
 end
end)
test('TOP Remove calls onRemove before membership deletion; BOTTOM ChangeState has no life guard',function()
 local s=battle('native');local e=s.enemies[1];e.block=0;e.hp=6;e.statuses.plated_armor=1;local seen={}
 withHooks({{Q,'enqueueReaction',function(old)return function(state,effect,top)
  if effect.op=='monsterChangeState'then eq(e.statuses.plated_armor,1,'onRemove still owns Power');seen[#seen+1]='onRemove'end
  return old(state,effect,top)
 end end},{C,'changeMonsterState',function(old)return function(state,target,name)
  eq(target.statuses.plated_armor,nil);eq(target.hp,0);seen[#seen+1]='Change';return old(state,target,name)
 end end}},function()
  A.damage(s,s.player,e,1);Q.enqueue(s,{op='damage',value=99,fixed=true},s.player,e);Q.drain(C,s)
 end)
 eq(table.concat(seen,','),'onRemove,Change');eq(selected(e),'stunned')
 for _,entry in ipairs(Schedule.list(e,{plated_armor=true}))do error('removed acquisition remains '..entry.id)end
 e.hp=20;A.applyPower(s,e,'plated_armor',3,s.player);eq(e.statuses.plated_armor,3)
 eq(Schedule.list(e,{plated_armor=true})[1].amount,3)
end)
test('generic non-Parasite removal uses source default no-op and player never queues ChangeState',function()
 for _,player in ipairs({false,true})do
  local s=battle('native',{'cultist','cultist'});local e=player and s.player or s.enemies[1]
  A.applyPower(s,e,'plated_armor',1,s.player);local chosen=not player and selected(e)
  C.damage(s,player and s.enemies[1] or s.player,e,1);Q.drain(C,s);eq(e.statuses.plated_armor,nil)
  if not player then eq(selected(e),chosen)end
 end
end)
test('Plated initial amount and stack cap remain distinct; fixed block caps final block999',function()
 local s=battle('native',{'cultist'});A.applyPower(s,s.player,'plated_armor',1001,s.player);eq(s.player.statuses.plated_armor,1001)
 A.applyPower(s,s.player,'plated_armor',1,s.player);eq(s.player.statuses.plated_armor,999)
 s.player.block=998;P.preEndCards(s,s.player,Q.enqueueReaction);Q.drain(C,s);eq(s.player.block,999)
end)
test('advanced real Cut Through Fate keeps ID-only Reduce behind scry, disposal and resume',function()
 local data=require('abyss_character_profiles').prepare(D,'watcher')
 local s=C.new(data,{enemies={'shelled_parasite','cultist'},deck={},seed=42,hp=500,maxHp=500,enableStances=true})
 local e=s.enemies[1];e.block=0;local c=card(s,'cut_through_fate')
 for i=1,4 do s.draw[i]={cardId='strike_purple',uid=5000+i}end
 assert(C.play(s,c.uid,1));assert(s.pendingScry and s.actionQueue);eq(e.statuses.plated_armor,14)
 local token=s.pendingScry.token;assert(C.chooseScry(s,{},token));eq(e.statuses.plated_armor,13)
 assert(contains(s.discard,c));eq(s.cardInUse,nil);eq(s.actionQueue,nil);eq(s.cardActions,nil)
end)
for _,mode in ipairs(modes)do
 test(mode..' TOP Puzzle draw runs between original enemy hits without advanced routing',function()
  local s=battle(mode,{'book_of_stabbing'});local e=s.enemies[1];intent(e,'multi_stab');require('abyss_relic_hooks').bindBattle(s,{'centennial_puzzle'})
  for i=1,4 do s.draw[i]={cardId='strike',uid=7000+i}end
  local trace={}
  withHooks({{C,'damage',function(old)return function(state,source,target,n,...)
   if state==s and source==e then trace[#trace+1]='H';eq(state.actionQueue,nil)end;return old(state,source,target,n,...)
  end end},{C,'draw',function(old)return function(state,n,...)
   if state==s then trace[#trace+1]='D'..n end;return old(state,n,...)
  end end}},function()assert(C.endTurn(s))end)
  eq(trace[1],'H');eq(trace[2],'D3');eq(trace[3],'H');eq(s.relicCombat.centennialUsed,true)
 end)
 test(mode..' dead-owner Wound/Roll survive with teammate; final death clears Reduce and later turns',function()
  for _,teammate in ipairs({false,true})do
   local s=battle(mode,teammate and {'taskmaster','cultist'} or {'taskmaster'});local e=s.enemies[1];e.hp=1
   A.applyPower(s,s.player,'plated_armor',4,s.player);A.applyPower(s,s.player,'thorns',1,s.player)
   local rolls=0
   withHooks({{AI,'afterAction',function(old)return function(state,owner,...)
    if state==s and owner==e then rolls=rolls+1 end;return old(state,owner,...)
   end end}},function()assert(C.endTurn(s))end)
   eq(e.hp,0);eq(rolls,teammate and 1 or 0);eq(s.player.statuses.plated_armor,teammate and 3 or 4)
   local wounds=0;for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,v in ipairs(pile)do if v.cardId=='wound'then wounds=wounds+1 end end end
   eq(wounds,teammate and 1 or 0);eq(s.phase,teammate and 'player' or 'victory')
  end
 end)
 test(mode..' fatal player hit stops Wound Roll Reduce and later teammate actions',function()
  local s=battle(mode,{'taskmaster','cultist'});local e=s.enemies[1];s.player.hp=1
  A.applyPower(s,s.player,'plated_armor',1,s.player);local rolls=0
  withHooks({{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s then rolls=rolls+1 end;return old(state,owner,...)
  end end}},function()assert(C.endTurn(s))end)
  eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.player.statuses.plated_armor,1);eq(rolls,0);eq(s.nextUid,1)
  eq(s.cardActions,nil);eq(s.actionQueue,nil);if s.originalV4 then eq(s.originalV4.enemyAction,nil)end
  eq(selected(e),'whip')
 end)
end
test('V4 counter completion precedes Roll and appended Reduce; final counter kill clears both',function()
 for _,teammate in ipairs({false,true})do
  local s=battle('v4',teammate and {'taskmaster','cultist'} or {'taskmaster'});local e=s.enemies[1];e.hp=1
  A.applyPower(s,s.player,'plated_armor',4,s.player);s.originalV4.counter=1
  local rolls=0
  withHooks({{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s and owner==e then eq(e.hp,0);eq(state.originalV4.counter,0);rolls=rolls+1 end;return old(state,owner,...)
  end end}},function()assert(C.endTurn(s))end)
  eq(e.hp,0);eq(rolls,teammate and 1 or 0);eq(s.player.statuses.plated_armor,teammate and 3 or 4);eq(s.originalV4.enemyAction,nil)
 end
end)
test('TOP boss suicide resolves before retained Thorns and clears queued Stasis return custody',function()
 local s=battle('native',{'automaton'});assert(C.endTurn(s));local orb,boss=s.enemies[1],s.enemies[2]
 local held={cardId='impervious',uid=9000};s.draw={held};C.applyEffects(s,{{op='enemyStasis',value=1}},orb,s.player)
 A.applyPower(s,boss,'thorns',1,boss);boss.hp=1;s.events={};C.damage(s,s.player,boss,1);Q.drain(C,s)
 local suicide,retaliation
 for i,ev in ipairs(s.events)do if ev.kind=='enemy_suicide'then suicide=suicide or i elseif ev.kind=='status_damage'then retaliation=i end end
 assert(suicide and retaliation and suicide<retaliation);eq(s.act2StasisCards,nil);eq(C.outcome(s),'victory')
end)
for _,mode in ipairs({'advanced','v4'})do
 test(mode..' failed enemy Reduce restores end-turn state and original table/RNG identities',function()
  local s=battle(mode,{'taskmaster','cultist'});A.applyPower(s,s.player,'plated_armor',4,s.player)
  local player,statuses,events,hand,rng=s.player,s.player.statuses,s.events,s.hand,s.cardRandomRng;local before=C.copy(s)
  withHooks({{P,'apply',function(old)return function(combat,state,effect,...)
   local result=old(combat,state,effect,...);if state==s and effect.op=='platedReduce'then error('injected enemy Reduce')end;return result
  end end}},function()local ok,why=pcall(C.endTurn,s);eq(ok,false);assert(tostring(why):find('injected enemy Reduce',1,true))end)
  eq(s.player,player);eq(s.player.statuses,statuses);eq(s.events,events);eq(s.hand,hand);eq(s.cardRandomRng,rng)
  eq(s.phase,'player');eq(player.hp,before.player.hp);eq(statuses.plated_armor,4);eq(#events,#before.events);eq(s.seed,before.seed)
  eq(rng.counter,before.cardRandomRng.counter);eq(s.cardActions,nil);eq(s.actionQueue,nil)
 end)
end
print('PLATED_ARMOR_QUEUE '..count..' checked; '..failed..' failed')
assert(failed==0,'Plated queue failures: '..failed)
print('LUA_PLATED_ARMOR_QUEUE_PASS '..count)
