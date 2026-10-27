-- Source room/arithmetic/transaction boundaries, not a natural campaign route.
local Run,D,Q,C,A,R,AI,Jaw=require('abyss_run'),require('abyss_data'),require('abyss_encounter_queue'),
 require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random'),require('abyss_enemy_ai'),require('abyss_jaw_worm_ai')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function stage()
 local r=Run.new(D,'15',{experimental=true,campaign=true});r.act,r.floor,r.encounters=3,35,Q.new('15',3)
 for _=1,2 do local _,n=Q.consume(r.encounters,'normal');r.encounters=n;r.floor=r.floor+1 end
 return r
end
local function battle(seed,ids,data)
 seed=seed or '1';local streams={seed=seed}
 for _,key in ipairs({'monsterHpRng','aiRng','miscRng','cardRandomRng','shuffleRng'})do streams[key]=R.fromSeed(seed)end
 -- Explicit 1000 player HP observes five full rounds, not natural survival.
 return C.new(data or D,{enemies=ids or {'jaw_worm_hard','jaw_worm_hard','jaw_worm_hard'},deck={},
  roomSeed=seed,roomStreams=streams,hp=1000,maxHp=1000})
end
local function intent(e)return e.intents[e.intentIndex].id end
local function force(e,id)for i,m in ipairs(e.intents)do if m.id==id then e.intentIndex=i;return end end;error(id)end
local function open()local r=stage();local ok,why=Run.startRoomCombat(r,'normal');assert(ok,why);return r end
test('public unchanged strong queue constructs three hard actors and preserves source data',function()
 local r=stage();eq(Q.peek(r.encounters,'normal'),'Jaw Worm Horde');local old,data=r.encounters,C.copy(r.data)
 assert(Run.startRoomCombat(r,'normal'));local s=r.combat;eq(s.roomSeed,'52');eq(#s.enemies,3)
 local positions={{-490,-5},{-150,20},{175,5}}
 for i,e in ipairs(s.enemies)do
  eq(e.definitionId,'jaw_worm_hard');eq(e.sourceId,'JawWorm');eq(e.ai.hardMode,true)
  assert(e.hp>=40 and e.hp<=44);eq(e.maxHp,e.hp);eq(e.statuses.strength,3);eq(e.block,6)
  eq(e.sourcePosition.x,positions[i][1]);eq(e.sourcePosition.y,positions[i][2])
 end
 eq(s.monsterHpRng.counter,3);eq(s.aiRng.counter,3);eq(s.miscRng.counter,0);eq(r.miscRng.counter,0)
 eq(#old.normal,#r.encounters.normal+1);eq(r.roomGeneration,1);eq(s.player.hp,80);same(r.data,data)
end)
test('formation makes all three source positions without misc or visual sampling',function()
 local trace={};local rows=require('abyss_encounter_formation').assemble('Jaw Worm Horde',{
  misc={boolean=function()error('unexpected boolean')end,integer=function()error('unexpected index')end},
  visualFloat=function()error('unexpected visual sample')end,
  construct=function(id,x,y)trace[#trace+1]={id,x,y};return {serial=#trace}end})
 same(trace,{{'jaw_worm_hard',-490,-5},{'jaw_worm_hard',-150,20},{'jaw_worm_hard',175,5}});eq(#rows,3)
end)
test('real construction spends HP1 HP2 HP3 before all opening AI then prebattle powers',function()
 local prepare,initialize,preBattle=AI.prepare,AI.initialize,Jaw.preBattle;local trace={}
 AI.prepare=function(s,e,...)
  if e.ai.hardMode then trace[#trace+1]='hp'..s.monsterHpRng.counter..'/ai'..s.aiRng.counter end
  return prepare(s,e,...)
 end
 AI.initialize=function(s,e,...)
  if e.ai.hardMode then trace[#trace+1]='init'..s.monsterHpRng.counter..'/ai'..s.aiRng.counter end
  return initialize(s,e,...)
 end
 Jaw.preBattle=function(s,e,...)
  if e.ai.hardMode then trace[#trace+1]='pre'..s.monsterHpRng.counter..'/ai'..s.aiRng.counter..'/shuffle'..s.shuffleRng.counter end
  return preBattle(s,e,...)
 end
 local ok,why=pcall(battle);AI.prepare,AI.initialize,Jaw.preBattle=prepare,initialize,preBattle;assert(ok,why)
 same(trace,{'hp1/ai0','hp2/ai0','hp3/ai0','init3/ai0','init3/ai1','init3/ai2',
  'pre3/ai3/shuffle1','pre3/ai3/shuffle1','pre3/ai3/shuffle1'})
end)
test('hard opening has all source integer branches and no conditional float draw',function()
 local s=battle();local e=s.enemies[1];local before=R.snapshot(s.aiRng)
 for n=0,99 do
  local calls=0;AI.initialize(s,e,function(_,maximum)eq(maximum,100);calls=calls+1;return n+1 end)
  eq(calls,1);eq(intent(e),n<25 and'chomp'or n<55 and'thrash'or'bellow')
  eq(e.jawLast,nil);eq(e.jawPrevious,nil)
 end;same(R.snapshot(s.aiRng),before)
end)
test('independent four-seed five-round group vectors preserve actions and complete RNG words',function()
 local vectors=dofile('tests/fixtures/jaw-worm-horde-vectors.lua');eq(#vectors,4)
 for _,v in ipairs(vectors)do
  local s=battle(v.seed)
  for i,e in ipairs(s.enemies)do eq(e.hp,v.initial.hp[i]);eq(intent(e),v.initial.moves[i]);eq(e.block,6)end
  same(R.snapshot(s.aiRng),v.initial.ai)
  for _,round in ipairs(v.rounds)do
   local start=#s.events;assert(C.endTurn(s));eq(s.player.hp,round.playerHp)
   for i,e in ipairs(s.enemies)do local row=round.actors[i]
    eq(e.jawLast,row.move);eq(intent(e),row.next);eq(e.block,row.block);eq(e.statuses.strength,row.strength)
    local hits=0;for j=start+1,#s.events do local ev=s.events[j]
     if ev.kind=='damage'and ev.detail.source==e.id then hits=hits+1;eq(ev.detail.amount,row.damage)end
    end;eq(hits,row.damage>0 and 1 or 0)
   end;same(R.snapshot(s.aiRng),round.ai)
  end
  same(R.snapshot(s.monsterHpRng),v.hpRng);same(R.snapshot(s.miscRng),v.miscRng);eq(s.cardRandomRng.counter,0)
 end
end)
test('initial Block absorbs player damage and resets before Chomp Thrash Bellow actions',function()
 local s=battle();local a,b,c=table.unpack(s.enemies);local hp=a.hp
 C.damage(s,s.player,a,8);eq(a.hp,hp-2);eq(a.block,0)
 force(a,'chomp');force(b,'thrash');force(c,'bellow');local before=s.player.hp
 assert(C.endTurn(s));eq(s.player.hp,before-24);eq(a.block,0);eq(b.block,5);eq(c.block,6);eq(c.statuses.strength,6)
end)
test('source float boundaries are strict and consumed only for forbidden repeats',function()
 local ai=battle().enemies[1].ai
 for _,row in ipairs({{'chomp','thrash',24,.5625,'bellow','thrash'},
  {'thrash','thrash',25,.3569999933242798,'chomp','bellow'},
  {'bellow','chomp',55,.41600000858306885,'chomp','thrash'}})do
  for _,at in ipairs({false,true})do local calls=0
   local actual=Jaw.choose(ai,row[1],row[2],row[3],function()calls=calls+1;return row[4]-(at and 0 or 1/16777216)end)
   eq(actual,row[at and 6 or 5]);eq(calls,1)
  end
 end
 eq(Jaw.choose(ai,'thrash','chomp',25,function()error('unneeded float')end),'thrash')
end)
test('each actor owns its history and fresh groups never inherit previous decisions',function()
 local s=battle();force(s.enemies[1],'chomp');force(s.enemies[2],'thrash');force(s.enemies[3],'bellow')
 assert(C.endTurn(s));eq(s.enemies[1].jawLast,'chomp');eq(s.enemies[2].jawLast,'thrash');eq(s.enemies[3].jawLast,'bellow')
 local t=battle();for _,e in ipairs(t.enemies)do eq(e.jawLast,nil);eq(e.jawPrevious,nil);eq(e.statuses.strength,3)end
end)
test('lethal retaliation cancels dead-owner Thrash block but keeps its queued roll with allies',function()
 local s=battle();local e=s.enemies[1];e.hp=1;force(e,'thrash')
 force(s.enemies[2],'bellow');force(s.enemies[3],'bellow');A.applyPower(s,s.player,'thorns',1,s.player)
 local original=AI.afterAction;local delta
 AI.afterAction=function(state,actor,...)
  local before=state.aiRng.counter;local result=original(state,actor,...)
  if actor==e then delta=state.aiRng.counter-before end;return result
 end
 local ok,why=pcall(C.endTurn,s);AI.afterAction=original;assert(ok,why)
 eq(e.hp,0);eq(e.block,0);eq(e.jawLast,'thrash');eq(delta,1);eq(C.outcome(s),nil)
end)
test('final retaliation death clears the pending roll and later action tail',function()
 local s=battle(nil,{'jaw_worm_hard'});local e=s.enemies[1];e.hp=1;force(e,'thrash')
 A.applyPower(s,s.player,'thorns',1,s.player);local before=R.snapshot(s.aiRng)
 assert(C.endTurn(s));eq(e.hp,0);eq(e.block,0);eq(C.outcome(s),'victory');same(R.snapshot(s.aiRng),before)
end)
test('poison final death performs no attack or queued AI roll',function()
 local s=battle(nil,{'jaw_worm_hard'});local e=s.enemies[1];e.hp=1;A.applyPower(s,e,'poison',1,s.player)
 local ai=R.snapshot(s.aiRng);local hp=s.player.hp;assert(C.endTurn(s))
 eq(e.hp,0);eq(s.player.hp,hp);same(R.snapshot(s.aiRng),ai);eq(C.outcome(s),'victory')
end)
test('real source victory offers ordinary rewards and claims a permanent card UID once',function()
 local r=open();local s=r.combat;local rng=R.snapshot(s.aiRng)
 -- Controlled actual damage isolates reward ownership; not a natural win.
 for _,e in ipairs(s.enemies)do C.damage(s,s.player,e,1000,true)end
 assert(Run.finishCombat(r));eq(r.phase,'reward');eq(r.lastResult.allEnemiesEscaped,false)
 assert(r.rewards.gold>=10 and r.rewards.gold<=20);eq(#r.rewards.cards,3);same(R.snapshot(s.aiRng),rng)
 local uid,size=r.nextDeckUid,#r.deck;assert(Run.claimCardReward(r,1));eq(#r.deck,size+1);eq(r.deck[#r.deck].uid,uid)
 local before=C.copy(r);eq(Run.claimCardReward(r,1),false);same(r,before)
end)
test('second constructor failure publishes no queue HP AI RNG or resource changes',function()
 local r=stage();local before=C.copy(r);local queue,deck,rng=r.encounters,r.deck,r.cardRng
 local original=AI.prepare;local reached=false
 AI.prepare=function(s,e,...)
  local result=original(s,e,...)
  if e.ai.hardMode and s.monsterHpRng.counter==2 then reached=true;eq(s.aiRng.counter,0);error('late second constructor')end
  return result
 end
 local ok,why=Run.startRoomCombat(r,'normal');AI.prepare=original
 assert(reached);eq(ok,false);eq(why,'combat_unavailable');same(r,before)
 eq(r.encounters,queue);eq(r.deck,deck);eq(r.cardRng,rng);assert(Run.startRoomCombat(r,'normal'))
end)
test('last prebattle buff and block failure restores the entire public Run graph',function()
 local r=stage();local before=C.copy(r);local queue,deck,rng=r.encounters,r.deck,r.cardRng
 local original=Jaw.preBattle;local reached=false
 Jaw.preBattle=function(s,e,...)
  local result=original(s,e,...)
  if e.ai.hardMode and e.id:match('_3$')then
   eq(e.statuses.strength,3);eq(e.block,6);eq(s.aiRng.counter,3);reached=true;error('late hard prebattle')
  end;return result
 end
 local ok,why=Run.startRoomCombat(r,'normal');Jaw.preBattle=original
 assert(reached);eq(ok,false);eq(why,'combat_unavailable');same(r,before)
 eq(r.encounters,queue);eq(r.deck,deck);eq(r.cardRng,rng);assert(Run.startRoomCombat(r,'normal'))
end)
test('late real second-actor decision failure restores all battle aliases and retries',function()
 local r=open();local s=r.combat;local before=C.copy(r);local enemies,hand,events,rng=s.enemies,s.hand,s.events,s.aiRng
 local actor=s.enemies[2];local original=Jaw.advance;local reached=false
 Jaw.advance=function(state,e,...)
  local result=original(state,e,...);if e==actor then reached=true;error('late second RollMove')end;return result
 end
 local called=pcall(Run.endTurn,r);Jaw.advance=original
 assert(not called and reached);same(r,before);eq(r.combat,s);eq(s.enemies,enemies);eq(s.enemies[2],actor)
 eq(s.hand,hand);eq(s.events,events);eq(s.aiRng,rng);assert(Run.endTurn(r))
end)
test('new source Darklings and Writhing rooms keep full-graph setup atomicity and tier guards',function()
 local r=Run.new(D,'1',{experimental=true,campaign=true});r.act,r.floor,r.encounters=3,35,Q.new('1',3)
 eq(Q.peek(r.encounters,'normal'),'3 Darklings')
 local function checkAliases(root)
  local refs,seen={},{}
  local function capture(owner)
   if seen[owner]then return end;seen[owner]=true
   for key,value in pairs(owner)do if type(value)=='table'then
    refs[#refs+1]={owner,key,value};capture(value)
   end end
  end
  capture(root)
  return function()for _,ref in ipairs(refs)do eq(ref[1][ref[2]],ref[3])end end
 end
 do
  local before=C.copy(r);local queue=r.encounters;local aliases=checkAliases(r);local original=C.new
  C.new=function(...)original(...);error('INJECTED_LATE_DARKLINGS_ROOM_SETUP')end
  local called,ok,why=pcall(Run.startRoomCombat,r,'normal');C.new=original
  assert(called);eq(ok,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,queue);aliases()
  assert(Run.startRoomCombat(r,'normal'));eq(r.encounterSource,'3 Darklings');eq(#r.combat.enemies,3)
  local resolved,reason=require('abyss_act3_enemies').resolve('3 Darklings','elite')
  eq(resolved,nil);eq(reason,'encounter_tier_mismatch')
 end
 -- Use a fresh original source queue for the existing Writhing late failure.
 r=Run.new(D,'1',{experimental=true,campaign=true});r.act,r.floor,r.encounters=3,35,Q.new('1',3)
 while Q.peek(r.encounters,'normal')~='Writhing Mass'do
  local source,nextQueue=Q.consume(r.encounters,'normal');assert(source);r.encounters=nextQueue;r.floor=r.floor+1
 end
 local before=C.copy(r);local queue=r.encounters;local aliases=checkAliases(r)
 local original=C.new
 C.new=function(...)original(...);error('INJECTED_LATE_WRITHING_ROOM_SETUP')end
 local called,ok,why=pcall(Run.startRoomCombat,r,'normal');C.new=original
 assert(called);eq(ok,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,queue);aliases()
 assert(Run.startRoomCombat(r,'normal'));eq(r.encounterSource,'Writhing Mass')
 eq(r.combat.enemies[1].definitionId,'writhing_mass')
 local resolved,reason=require('abyss_act3_enemies').resolve('Writhing Mass','elite')
 eq(resolved,nil);eq(reason,'encounter_tier_mismatch')
end)
test('first-act Jaw Worm keeps its forced opening and has no hard prebattle bonuses',function()
 local s=battle(nil,{'jaw_worm'});local e=s.enemies[1];eq(intent(e),'jaw_worm_1');eq(e.block,0);eq(e.statuses.strength,nil)
 for n=0,99 do local calls=0
  AI.initialize(s,e,function(_,max)eq(max,100);calls=calls+1;return n+1 end);eq(calls,1);eq(intent(e),'jaw_worm_1')
 end
end)
test('real Host keeps three hard actors HP intent strength help and target ownership',function()
 local H=dofile('tests/lua/support/battle_action_fixture.lua');local F=H.F
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,D,F.Presentation,'click',{seed=15,campaign=true,prologue=false,
  imageSource='static',color=function(red,green,blue,alpha)return{r=red,g=green,b=blue,a=alpha}end})
 assert(host:start());local r=host.run;r.act,r.floor,r.encounters=3,35,Q.new('15',3)
 for _=1,2 do local _,n=Q.consume(r.encounters,'normal');r.encounters=n;r.floor=r.floor+1 end
 assert(Run.startRoomCombat(r,'normal'));host:refresh();local s=r.combat;local panel=root:GetChild('battlePanel')
 for i,e in ipairs(s.enemies)do local box=panel:GetChild('enemy'..i)
  assert(box.visible);eq(box:GetChild('name').text,'石颚兽');eq(box:GetChild('hp').text,string.format('%d/%d',e.hp,e.maxHp))
  eq(box:GetChild('block').text,'6');assert(not box:GetChild('intent').text:find('未知',1,true))
 end
 assert(not panel:GetChild('enemy4').visible)
 panel:GetChild('enemy1'):GetChild('statusRow'):GetChild('hit').click({touchId=71})
 local info=panel:GetChild('statusInfo');assert(info.visible);local text={}
 for i=1,F.Theme.layout.statusInfo.rows do local name=info:GetChild('name'..i);if name.visible then text[#text+1]=name.text end end
 assert(table.concat(text,' '):find('力量 3',1,true));info:GetChild('hit').click({touchId=72})
 local hp={};for i,e in ipairs(s.enemies)do hp[i]=e.hp end
 local uid;for _,c in ipairs(s.hand)do if c.cardId=='strike'or c.cardId=='bash'then uid=c.uid;break end end;assert(uid)
 assert(Run.play(r,uid,2));host:refresh();eq(s.enemies[1].hp,hp[1]);eq(s.enemies[3].hp,hp[3]);eq(s.enemies[2].block,0)
 eq(panel:GetChild('enemy2'):GetChild('hp').text,string.format('%d/%d',s.enemies[2].hp,s.enemies[2].maxHp))
 local before=C.copy(r);host:refresh();same(r,before)
end)
print('JAW_WORM_HORDE '..count..' groups; '..failed..' failed');assert(failed==0)
