local Native=dofile('tests/lua/support/current_monster_controls.lua')
local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local first,last=...
first,last=first or 1,last or 10
assert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=19 and first<=last,'invalid original fixture slice')
local registered=0
-- Controlled source/queue/transaction fixtures, not natural campaign play.
local Run,D,Q,C,A,R=require('abyss_run'),require('abyss_data'),require('abyss_encounter_queue'),
 require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random')
local Powers=require('abyss_act3_powers')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)registered=registered+1;if registered<first or registered>last then return end;local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function stage()
 local r=Run.new(D,'4',{experimental=true,campaign=true})
 r.act,r.floor,r.encounters=3,35,Q.new('4',3)
 for _=1,2 do local _,n=Q.consume(r.encounters,'normal');r.encounters=n;r.floor=r.floor+1 end
 return r
end
local function battle(ids,seed,data)
 local streams={seed=seed or '1'}
 for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[key]=R.fromSeed(seed or '1')end
 -- 1000 HP isolates arithmetic through all five turns; not Run/Host HP or natural play.
 return C.new(data or D,{enemies=ids or {'transient'},deck={},roomSeed=streams.seed,roomStreams=streams,hp=1000,maxHp=1000})
end
test('public source queue constructs constant HP and consumes only its opening AI roll',function()
 local r=stage();eq(Q.peek(r.encounters,'normal'),'Transient');local old=r.encounters
 local ok,why=Run.startRoomCombat(r,'normal');assert(ok,why)
 local s,e=r.combat,r.combat.enemies[1];eq(e.definitionId,'transient');eq(e.hp,999);eq(e.maxHp,999)
 eq(s.monsterHpRng.counter,0);eq(s.aiRng.counter,1);eq(r.miscRng.counter,0)
 eq(e.statuses.fading,5);eq(e.statuses.shifting,1);eq(e.powerOrder[1],'fading');eq(e.powerOrder[2],'shifting')
 eq(#old.normal,#r.encounters.normal+1);eq(r.player,nil);eq(s.player.hp,80)
end)
test('five real attacks grow 30 to 70 without RollMove and fade only after the fifth hit',function()
 local s=battle();local e=s.enemies[1];local ai=R.snapshot(s.aiRng);local health=1000
 for turn=1,5 do
  eq(e.intents[e.intentIndex].effects[1].value,20+turn*10)
  local before=#s.events;assert(C.endTurn(s));health=health-(20+turn*10);eq(s.player.hp,health)
  eq(e.transientCount,turn);same(R.snapshot(s.aiRng),ai)
  local hits=0;for i=before+1,#s.events do local ev=s.events[i]
   if ev.kind=='damage'and ev.detail.source==e.id then hits=hits+1;eq(ev.detail.amount,20+turn*10)end
  end;eq(hits,1)
  if turn<5 then eq(e.hp,999);eq(e.statuses.fading,5-turn);eq(C.outcome(s),nil)end
 end
 eq(e.hp,0);assert(not e.escaped);eq(C.outcome(s),'victory');eq(s.turn,5)
 local suicides=0;for _,ev in ipairs(s.events)do if ev.kind=='enemy_suicide'then suicides=suicides+1 end end;eq(suicides,1)
end)
test('Shifting uses post-block damage for normal fixed Thorns HP_LOSS and poison',function()
 for _,kind in ipairs({'normal','fixed','thorns','hp_loss','poison'})do
  local s=battle();local e=s.enemies[1];e.block=4
  if kind=='normal'then C.damage(s,s.player,e,10)
  elseif kind=='fixed'then C.damage(s,s.player,e,10,true)
  elseif kind=='thorns'then C.retaliate(s,s.player,e,10)
  elseif kind=='hp_loss'then A.loseHp(s,e,6)
  else A.applyPower(s,e,'poison',6,s.player);A.startTurnEffects(s,e)end
  eq(e.hp,993);eq(e.statuses.strength,-6);eq(e.statuses.shackled,6)
  eq(e.block,(kind=='hp_loss'or kind=='poison')and 4 or 0)
 end
end)
test('fully blocked and zero damage never create Shifting debt',function()
 local s=battle();local e=s.enemies[1];e.block=20
 C.damage(s,s.player,e,10);C.retaliate(s,s.player,e,5);A.loseHp(s,e,0)
 eq(e.hp,999);eq(e.statuses.strength,nil);eq(e.statuses.shackled,nil);eq(e.block,5)
end)
test('Artifact present at onAttacked prevents debt and absorbs only the negative Strength action',function()
 for _,n in ipairs({1,2})do
  local s=battle();local e=s.enemies[1];A.applyPower(s,e,'artifact',n,e);C.damage(s,s.player,e,7)
  eq(e.hp,992);eq(e.statuses.artifact or 0,n-1);eq(e.statuses.strength,nil);eq(e.statuses.shackled,nil)
 end
end)
test('Intangible caps Shifting and multiple hits stack until real owner-end restoration',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'intangible',2,e)
 C.damage(s,s.player,e,10);C.retaliate(s,s.player,e,9);eq(e.hp,997)
 eq(e.statuses.strength,-2);eq(e.statuses.shackled,2);local hp=s.player.hp
 assert(C.endTurn(s));eq(s.player.hp,hp-28);eq(e.statuses.strength,0);eq(e.statuses.shackled,nil)
 eq(e.intents[1].effects[1].value,40)
end)
test('onAttacked captures unbounded-to-current-HP amount before lethal cancellation',function()
 local s=battle();local e=s.enemies[1];e.hp=3
 local original=Powers.attacked;local amount
 Powers.attacked=function(state,target,n,reactions)if target==e then amount=n end;return original(state,target,n,reactions)end
 local ok,why=pcall(C.damage,s,s.player,e,20);Powers.attacked=original;assert(ok,why)
 eq(amount,20);eq(e.hp,0);eq(e.statuses.strength,nil);eq(e.statuses.shackled,nil)
end)
test('Shifting TOP order is GainStrength before Strength loss and old frames remain detached',function()
 local s=battle();local e=s.enemies[1];local first=#s.events;C.damage(s,s.player,e,8)
 local order={};for i=first+1,#s.events do local ev=s.events[i]
  if ev.kind=='status'and ev.detail.target==e.id then order[#order+1]=ev.detail.status end
 end;eq(order[1],'shackled');eq(order[2],'strength')
 local frame=require('abyss_events').frame(s);local old=e.intents[1];assert(C.endTurn(s))
 eq(old.effects[1].value,30);eq(frame.enemies[1].statuses.strength,-8);eq(frame.enemies[1].intents[1].effects[1].value,30)
end)
test('Fading suicide invokes death powers with a teammate without triggering Shifting or recursion',function()
 local data=Run.new(D,'1',{experimental=true}).data
 local s=battle({'transient','cultist'},nil,data);local e,ally=s.enemies[1],s.enemies[2]
 A.applyPower(s,e,'corpse_explosion',1,s.player);e.statuses.fading=1
 assert(C.endTurn(s));eq(e.hp,0);eq(ally.hp,0);assert(not e.escaped);eq(e.statuses.shackled,nil)
 eq(C.outcome(s),'victory')
end)
test('lethal player damage and early real Transient death prevent later Fading suicide',function()
 local s=battle();s.player.hp=1;s.enemies[1].statuses.fading=1
 assert(C.endTurn(s));eq(C.outcome(s),'defeat');eq(s.enemies[1].hp,999)
 local t=battle();C.damage(t,t.player,t.enemies[1],999,true);assert(C.endTurn(t))
 eq(C.outcome(t),'victory');eq(t.enemies[1].transientCount,0)
 for _,ev in ipairs(t.events)do assert(ev.kind~='enemy_suicide')end
end)
test('independent fixed-source vectors preserve five actions and full HP AI states',function()
 local vectors=dofile('tests/fixtures/act3-transient-vectors.lua');eq(#vectors,3)
 for _,v in ipairs(vectors)do
  local s=battle(nil,v.seed);local e=s.enemies[1]
  for turn,step in ipairs(v.steps)do
   e.block=step.block
   if step.kind=='hp_loss'then A.loseHp(s,e,step.damage)
   elseif step.kind=='thorns'then C.retaliate(s,s.player,e,step.damage)
   else C.damage(s,s.player,e,step.damage,step.kind=='fixed')end
   eq(e.statuses.strength,-step.shift);eq(e.statuses.shackled,step.shift)
   assert(C.endTurn(s));eq(s.player.hp,step.playerHp);eq(e.hp,step.monsterHp)
   eq(e.statuses.strength,step.strength);eq(e.statuses.shackled or 0,step.shackled)
   eq(e.statuses.fading,step.fading);eq(e.transientCount,turn)
   eq(e.intents[1].effects[1].value,step.nextBase)
  end
  same(R.snapshot(s.monsterHpRng),v.hpRng);same(R.snapshot(s.aiRng),v.aiRng)
  eq(s.cardRandomRng.counter,0);same(R.snapshot(s.shuffleRng),v.shuffleRng)
 end
end)
test('shared GainStrength identity is reused unchanged and incompatible semantics refuse construction',function()
 local data=Run.new(D,'1',{experimental=true}).data
 local prior=C.copy(data.statuses.statuses);local s=battle(nil,nil,data)
 same(data.statuses.statuses,prior);eq(s.catalog.statuses.shackled.kind,'debuff')
 local invalid=C.copy(data)
 for _,d in ipairs(invalid.statuses.statuses)do if d.id=='shackled'then d.decay='round_end_minus_1' end end
 local before=C.copy(invalid);assert(not pcall(battle,nil,nil,invalid));same(invalid,before)
end)
test('GainStrength and signed Strength keep fixed source caps during stacked damage',function()
 local s=battle();local e=s.enemies[1]
 -- Controlled pre-existing GainStrength Power; retain actual 999 source HP.
 A.applyPower(s,e,'strength',-700,s.player);A.applyPower(s,e,'shackled',700,s.player)
 C.damage(s,s.player,e,600,true);eq(e.hp,399);eq(e.maxHp,999)
 eq(e.statuses.strength,-999);eq(e.statuses.shackled,999)
 assert(C.endTurn(s));eq(e.statuses.strength,0);eq(e.statuses.shackled,nil)
end)
local function guardedEnd(r)
 -- Controlled block isolates public reward/rollback boundaries without changing
 -- HP, enemy powers, countdown, cards, energy, queue, RNG or reward inputs.
 C.block(r.combat,r.combat.player,999,true);return Run.endTurn(r)
end
test('public fifth-turn Fading gives normal source rewards rather than escape suppression',function()
 local r=stage();assert(Run.startRoomCombat(r,'normal'));local s,e=r.combat,r.combat.enemies[1]
 local goldRng=R.cloneState(r.treasureRng);local gold=R.randomIntBetween(goldRng,10,20)
 local cardCounter=r.cardRng.counter
 local potionCounter=r.shopRng and r.shopRng.potion and r.shopRng.potion.counter or 0
 local originalHp=r.hp;eq(e.gold,1)
 for i=1,5 do assert(guardedEnd(r));if i<5 then eq(r.phase,'combat')end end
 eq(r.phase,'reward');eq(r.lastResult.outcome,'victory');eq(r.lastResult.allEnemiesEscaped,false)
 eq(e.hp,0);eq(e.gold,0);eq(r.hp,originalHp);eq(s.player.maxHp,80);eq(r.victories,1)
 eq(r.rewards.gold,gold);eq(#r.rewards.cards,3);same(R.snapshot(r.treasureRng),R.snapshot(goldRng))
 assert(r.cardRng.counter>cardCounter);assert(r.shopRng.potion.counter>potionCounter)
 assert(not C.allEnemiesEscaped(s));eq(s.aiRng.counter,1)
 assert(Run.claimGoldReward(r));local before=C.copy(r);local ok=Run.claimGoldReward(r);eq(ok,false);same(r,before)
 local nextUid,size=r.nextDeckUid,#r.deck;assert(Run.claimCardReward(r,1))
 eq(#r.deck,size+1);eq(r.deck[#r.deck].uid,nextUid);eq(r.nextDeckUid,nextUid+1)
 before=C.copy(r);eq(Run.claimCardReward(r,1),false);same(r,before)
end)
test('late Shifting reaction failure restores public play original graph and can retry',function()
 local r=stage();assert(Run.startRoomCombat(r,'normal'));local s,e=r.combat,r.combat.enemies[1]
 local uid;for _,c in ipairs(s.hand)do if c.cardId=='strike'then uid=c.uid;break end end;assert(uid)
 local before=C.copy(r);local hand,events,statuses=s.hand,s.events,e.statuses
 local original=Powers.resolveShift;local reached=false
 Powers.resolveShift=function(...)original(...);reached=true;error('late Shifting failure')end
 local ok=pcall(Run.play,r,uid,1);Powers.resolveShift=original
 assert(not ok and reached);same(r,before);eq(r.combat,s);eq(s.enemies[1],e)
 eq(s.hand,hand);eq(s.events,events);eq(e.statuses,statuses);assert(Run.play(r,uid,1))
 eq(e.statuses.strength,-6);eq(e.statuses.shackled,6)
end)
test('late SuicideAction and public reward throw or reject restore every original reference',function()
 for _,mode in ipairs({'suicide','throw','reject'})do
  local r=stage();assert(Run.startRoomCombat(r,'normal'));for _=1,4 do assert(guardedEnd(r))end
  C.block(r.combat,r.combat.player,999,true)
  local s,e=r.combat,r.combat.enemies[1];local before=C.copy(r)
  local queue,deck,hand,events,statuses,rng=r.encounters,r.deck,s.hand,s.events,e.statuses,r.cardRng
  local oldSuicide,oldFinish=A.suicideTransient,Run.finishCombat;local reached=false
  if mode=='suicide'then A.suicideTransient=function(...)oldSuicide(...);reached=true;error('late suicide failure')end
  else Run.finishCombat=function(...)
   local ok,why=oldFinish(...);assert(ok,why);reached=true
   if mode=='throw'then error('late reward failure')end;return false,'late_reward_rejection'
  end end
  local called,ok,why=pcall(Run.endTurn,r);A.suicideTransient,Run.finishCombat=oldSuicide,oldFinish
  assert(reached);if mode=='reject'then assert(called);eq(ok,false);eq(why,'late_reward_rejection')else assert(not called)end
  same(r,before);eq(r.combat,s);eq(s.enemies[1],e);eq(r.encounters,queue);eq(r.deck,deck)
  eq(s.hand,hand);eq(s.events,events);eq(e.statuses,statuses);eq(r.cardRng,rng)
  assert(Run.endTurn(r));eq(r.phase,'reward');eq(r.victories,1)
 end
end)
test('late public constructor failure preserves Run queue resources and RNG aliases',function()
 local r=stage();local before=C.copy(r);local queue,deck,stream=r.encounters,r.deck,r.cardRng
 local original=C.new;local reached=false
 C.new=function(...)local s=original(...);eq(s.enemies[1].definitionId,'transient');reached=true;error('late constructor failure')end
 local ok,why=Run.startRoomCombat(r,'normal');C.new=original
 assert(reached);eq(ok,false);eq(why,'combat_unavailable');same(r,before)
 eq(r.encounters,queue);eq(r.deck,deck);eq(r.cardRng,stream)
end)
test('real Host shows shifting intent HP and both source Power details without rule writes',function()
 local H=dofile('tests/lua/support/battle_action_fixture.lua');local F=H.F
 local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,D,F.Presentation,'click',{seed=4,campaign=true,prologue=false,
  imageSource='static',color=function(red,green,blue,alpha)return{r=red,g=green,b=blue,a=alpha}end})
 assert(testStart(host));local r=host.run;r.act,r.floor,r.encounters=3,35,Q.new('4',3)
 for _=1,2 do local _,n=Q.consume(r.encounters,'normal');r.encounters=n;r.floor=r.floor+1 end
 assert(Run.startRoomCombat(r,'normal'));host:refresh()
 local panel=root:GetChild('battlePanel');local enemy=Native.actor(panel,r.combat.enemies[1]);local _,tap=H.controls(panel)
 eq(enemy:GetChild('name').text,'流散之影');eq(enemy:GetChild('hp').text,'999/999');eq(enemy:GetChild('intent').text,'30')
 enemy:GetChild('hit').click({touchId=81})
 local info=panel:GetChild('statusInfo');assert(info.visible);local texts={}
 for i=1,F.Theme.layout.statusInfo.rows do
  for _,prefix in ipairs({'name','text','note'})do local control=info:GetChild(prefix..i)
   if control and control.visible then texts[#texts+1]=control.text end end
 end
 local detail=table.concat(texts,' ');assert(detail:find('变幻',1,true)and detail:find('消逝 5',1,true))
 assert(detail:find('反伤',1,true)and detail:find('自毁',1,true)and detail:find('正常战斗奖励',1,true))
 info:GetChild('hit').click({touchId=82})
 local uid;for _,c in ipairs(r.combat.hand)do if c.cardId=='strike'then uid=c.uid;break end end
 assert(Run.play(r,uid,1));host:refresh();eq(enemy:GetChild('intent').text,'24');eq(enemy:GetChild('hp').text,'993/999')
 tap('enemy1',83);local intentDetail=inspectDetails(host.battleUI,panel);assert(not intentDetail:find('未知',1,true))
 assert(Run.endTurn(r));host:refresh();eq(enemy:GetChild('intent').text,'40');eq(r.combat.player.hp,56)
 local before=C.copy(r);host:refresh();same(r,before)
end)
test('Transient GainStrength waits for all monster actions before owner-end restoration',function()
 for _,data in ipairs({D,Run.new(D,'1',{experimental=true}).data})do
 local s=battle({'transient','cultist'},nil,data);local e,ally=s.enemies[1],s.enemies[2]
 local blur=s.catalog.statuses.blur~=nil
 if blur then A.applyPower(s,s.player,'blur',1,s.player)end
 C.damage(s,s.player,e,6);local ai=require('abyss_enemy_ai');local original=ai.beforeAction;local observed
 local schedule=require('abyss_power_schedule');local remove=schedule.remove;local atBlurRemoval
 ai.beforeAction=function(state,enemy,...)if enemy==ally then observed=e.statuses.strength end;return original(state,enemy,...)end
 schedule.remove=function(state,actor,id)
  if state==s and actor==s.player and id=='blur'then atBlurRemoval=e.statuses.strength end
  return remove(state,actor,id)
 end
 local ok,why=pcall(C.endTurn,s);ai.beforeAction=original;schedule.remove=remove;assert(ok,why)
 eq(observed,-6);eq(e.statuses.strength,0);eq(e.statuses.shackled,nil)
 if blur then eq(atBlurRemoval,0)end -- actual queued removal, not just hook construction
 end
end)
assert(registered==19 and count==last-first+1,'Transient slice coverage changed')
print('ACT3_TRANSIENT '..count..' groups; '..failed..' failed');assert(failed==0)
