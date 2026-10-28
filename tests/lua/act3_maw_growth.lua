local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
-- Explicit source queue/chapter boundary fixtures, not natural campaign play.
local Run,C,D,Q,R,AI,A=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
 require('abyss_encounter_queue'),require('abyss_sts_random'),require('abyss_enemy_ai'),require('abyss_actor')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function stage(seed)
 local r=Run.new(D,seed,{experimental=true,campaign=true});r.act,r.floor,r.encounters=3,35,Q.new(seed,3)
 for _=1,2 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
 return r
end
local function battle(ids,seed,deck,data,hp)
 local streams={seed=seed or '1'}
 for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[key]=R.fromSeed(seed or '1')end
 -- Isolated long arithmetic fixtures deliberately survive eight moves. Actual
 -- Run/Host cases below retain the source character HP and real starter deck.
 return C.new(data or D,{enemies=ids or {'spire_growth'},deck=deck or {},roomSeed=streams.seed,
  roomStreams=streams,maxHp=1000,hp=hp or 1000})
end
local function intent(e)return e.intents[e.intentIndex].id end
local function primary(n)return function(_,maximum)eq(maximum,100);return n+1 end end
local function force(s,e,id)
 for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return move.effects end end;error(id)
end
local function bind(s,source,amount)return A.applyPower(s,s.player,'constricted',amount or 10,source or s.enemies[1])end
local function constrictHits(s,from)
 local hits={};for i=from or 1,#s.events do local ev=s.events[i]
  if ev.kind=='status_damage'and ev.detail.status=='thorns'and ev.detail.target==s.player.id
   and ev.detail.source:match('spire_growth')then hits[#hits+1]=ev.detail end
 end;return hits
end
test('real Run opens Maw and Spire Growth from their unchanged source queue',function()
 for _,v in ipairs({{'2','Maw','maw',300,0},{'3','Spire Growth','spire_growth',170,1}})do
  local r=stage(v[1]);eq(Q.peek(r.encounters,'normal'),v[2]);local old=r.encounters
  local ok,why=Run.startRoomCombat(r,'normal');assert(ok,why)
  eq(r.encounterSource,v[2]);eq(r.combat.enemies[1].definitionId,v[3]);eq(r.combat.enemies[1].hp,v[4])
  eq(r.combat.monsterHpRng.counter,v[5]);eq(r.combat.aiRng.counter,1);eq(r.miscRng.counter,0)
  eq(#r.encounters.normal,#old.normal-1);eq(#old.normal,13)
 end
end)
test('independent three-seed eight-turn vectors lock full HP AI and actual multi-hit damage',function()
 local vectors=dofile('tests/fixtures/act3-maw-growth-vectors.lua');eq(#vectors,6)
 for _,v in ipairs(vectors)do
  local s=battle({v.policy},v.seed);local e=s.enemies[1];eq(e.hp,v.monsterHp)
  for _,step in ipairs(v.steps)do
   eq(intent(e),step.intent)
   if v.policy=='maw'then eq(e.mawTurn,step.counterBefore)end
   local from=#s.events+1;local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-step.playerLoss)
   eq(s.player.hp,step.hpAfter);eq(e.statuses.strength or 0,step.strengthAfter)
   eq(s.player.statuses.constricted or 0,step.constrictedAfter)
   local hits=0;for i=from,#s.events do local ev=s.events[i]
    if ev.kind=='damage'and ev.detail.source==e.id then hits=hits+1;eq(ev.detail.amount,step.unitDamage)end
   end;eq(hits,step.hits)
  end
  eq(intent(e),v.nextIntent);if v.policy=='maw'then eq(e.mawTurn,v.nextCounter)end
  same(R.snapshot(s.monsterHpRng),v.hpRng);same(R.snapshot(s.aiRng),v.aiRng)
  eq(s.cardRandomRng.counter,0)
 end
end)
test('Maw counter increments on getMove and only actual Roar sets its opening flag',function()
 local s=battle({'maw'});local e=s.enemies[1]
 eq(e.mawTurn,2);eq(e.mawRoared,false);eq(intent(e),'roar')
 AI.advance(s,e,primary(49));eq(e.mawTurn,3);eq(intent(e),'roar');eq(e.mawRoared,false)
 assert(C.endTurn(s));eq(e.mawRoared,true);eq(e.mawTurn,4)
 local events={};for _,ev in ipairs(s.events)do if ev.kind=='status'and ev.detail.target==s.player.id then events[#events+1]=ev.detail.status end end
 eq(events[1],'weak');eq(events[2],'frail');eq(s.player.statuses.weak,3);eq(s.player.statuses.frail,3)
 eq(intent(e),'nom')
 AI.advance(s,e,primary(49));eq(intent(e),'drool');eq(e.mawTurn,5)
 AI.advance(s,e,primary(49));eq(intent(e),'nom');eq(e.mawTurn,6)
 AI.advance(s,e,primary(50));eq(intent(e),'drool')
 AI.advance(s,e,primary(50));eq(intent(e),'slam')
 AI.advance(s,e,primary(50));eq(intent(e),'drool')
end)
test('Maw odd counters floor the real Nom hit count and stop normal hits after lethal retaliation',function()
 for _,counter in ipairs({4,5})do
  local s=battle({'maw'});local e=s.enemies[1];e.mawRoared=true;e.mawTurn=counter;e.act3Last='drool'
  AI.advance(s,e,primary(49));eq(e.mawTurn,counter+1)
  local times=math.floor((counter+1)/2);eq(e.intents[e.intentIndex].effects[1].times,times)
  local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-times*5)
 end
 for _,allies in ipairs({false,true})do
  local s=battle(allies and {'maw','cultist'}or {'maw'});local e=s.enemies[1]
  e.mawRoared=true;e.mawTurn=5;e.act3Last='drool';AI.advance(s,e,primary(49))
  A.applyPower(s,s.player,'thorns',999,s.player)
  local hp,ai=s.player.hp,s.aiRng.counter;assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,hp-5)
  eq(s.aiRng.counter,ai+(allies and 2 or 0))
 end
end)
test('Maw Roar spends Artifact in Weak then Frail order without postponing its next move',function()
 for _,amount in ipairs({1,2})do
  local s=battle({'maw'});A.applyPower(s,s.player,'artifact',amount,s.player)
  assert(C.endTurn(s));eq(s.player.statuses.artifact,0);eq(s.player.statuses.weak or 0,0)
  eq(s.player.statuses.frail or 0,amount==1 and 3 or 0);eq(s.enemies[1].mawRoared,true)
  eq(s.aiRng.counter,2);assert(intent(s.enemies[1])~='roar')
 end
end)
test('Growth A0 49 and 50 branches retain two-move history and do not force an opening Constrict',function()
 local s=battle();local e=s.enemies[1]
 AI.initialize(s,e,primary(49));eq(intent(e),'tackle')
 AI.advance(s,e,primary(49));eq(intent(e),'tackle')
 AI.advance(s,e,primary(49));eq(intent(e),'constrict')
 AI.advance(s,e,primary(50));eq(intent(e),'smash')
 assert(bind(s,e));eq(s.constrictedSource,e)
 AI.advance(s,e,primary(99));eq(intent(e),'smash')
 AI.advance(s,e,primary(99));eq(intent(e),'tackle')
 AI.advance(s,e,primary(49));eq(intent(e),'tackle')
 AI.advance(s,e,primary(49));eq(intent(e),'smash')
end)
test('Constricted respects Artifact and stacked Power retains its first real source object',function()
 local s=battle({'spire_growth','spire_growth'});local first,second=s.enemies[1],s.enemies[2]
 A.applyPower(s,s.player,'artifact',1,s.player);eq(bind(s,first),false)
 eq(s.player.statuses.constricted,nil);eq(s.constrictedSource,nil);eq(s.player.statuses.artifact,0)
 assert(bind(s,first));assert(bind(s,second));eq(s.player.statuses.constricted,20);eq(s.constrictedSource,first)
 eq(s.player.constrictedSourceId,first.id);eq(s.player.constrictedSourceName,first.name)
 eq(first.sourceId,'Serpent');assert(first~=second and first.id~=second.id)
end)
test('dead source with a living teammate still owns the retained Constricted THORNS hit',function()
 local s=battle({'spire_growth','cultist'});local source=s.enemies[1]
 assert(bind(s,source));C.damage(s,s.player,source,170,true);eq(source.hp,0)
 eq(s.player.statuses.constricted,10);eq(s.constrictedSource,source)
 local hp,from=s.player.hp,#s.events+1;assert(C.endTurn(s));eq(s.player.hp,hp-10)
 local hits=constrictHits(s,from);eq(#hits,1);eq(hits[1].source,source.id);eq(hits[1].amount,10)
 eq(s.constrictedSource,source);eq(s.player.statuses.constricted,10)
end)
test('final source killed by a real card ends combat rather than deleting the Power',function()
 local s=battle(nil,'1',{'bludgeon'});local source=s.enemies[1]
 assert(bind(s,source));A.applyPower(s,s.player,'strength',200,s.player)
 assert(C.play(s,s.hand[1].uid,1));eq(source.hp,0);eq(C.outcome(s),'victory')
 eq(s.player.statuses.constricted,10);eq(s.constrictedSource,source)
 local before=C.copy(s);local ok,why=C.endTurn(s);eq(ok,false);eq(why,'not_player_turn');same(s,before)
 local fresh=battle();eq(fresh.player.statuses.constricted,nil);eq(fresh.constrictedSource,nil)
end)
test('Constricted fixed damage uses block Intangible and original source without recursive Thorns',function()
 for _,v in ipairs({{0,false,10},{6,false,4},{15,false,0},{0,true,1},{1,true,0}})do
  local s=battle();local source=s.enemies[1];assert(bind(s,source))
  A.applyPower(s,source,'strength',50,source);A.applyPower(s,source,'weak',2,s.player)
  A.applyPower(s,s.player,'vulnerable',2,source);A.applyPower(s,s.player,'thorns',999,s.player)
  if v[2]then
   s.catalog.statuses.intangible={id='intangible',name='Intangible',kind='buff',stack='duration',decay='none',description='Incoming damage capped at 1.'}
   A.applyPower(s,s.player,'intangible',1,s.player)
  end
  A.block(s,s.player,v[1],true);A.applyPower(s,source,'poison',170,s.player)
  local hp,from=s.player.hp,#s.events+1;assert(C.endTurn(s));eq(s.player.hp,hp-v[3])
  local hits=constrictHits(s,from);eq(#hits,1);eq(hits[1].amount,v[3]);eq(hits[1].blocked,math.min(v[1],v[2]and 1 or 10))
  local recursive=0;for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='status_damage'and ev.detail.source==s.player.id then recursive=recursive+1 end
  end;eq(recursive,0)
 end
end)
test('Constricted runs after automatic Burn but before Ethereal and enemy actions in both dispatchers',function()
 for _,experimental in ipairs({false,true})do for _,hp in ipairs({2,12})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle(nil,'1',{'burn','dazed'},data,hp);eq(s.experimentalMechanics==true,experimental)
  assert(bind(s));local ai=s.aiRng.counter;local from=#s.events+1
  assert(C.endTurn(s));eq(s.player.hp,0);eq(C.outcome(s),'defeat');eq(s.aiRng.counter,ai)
  local hits=constrictHits(s,from);eq(#hits,hp==2 and 0 or 1)
  eq(#s.exhaust,0)
  local dazed=false;for _,card in ipairs(s.hand)do if card.cardId=='dazed'then dazed=true end end;assert(dazed)
  if hp==12 then eq(s.discard[1].cardId,'burn');eq(hits[1].amount,10)
  else eq(s.cardInUse.cardId,'burn')end
 end end
end)
test('queued Constricted damage survives Combust killing its final source after Burn',function()
 for _,experimental in ipairs({false,true})do for _,hp in ipairs({13,14})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle(nil,'1',{'combust','burn','dazed'},data,hp);local source=s.enemies[1]
  local card;for _,c in ipairs(s.hand)do if c.cardId=='combust'then card=c end end
  assert(C.play(s,card.uid));eq(s.player.statuses.combust,5);eq(s.player.combustHpLoss,1)
  assert(bind(s));C.damage(s,s.player,source,165,true);eq(source.hp,5)
  local from=#s.events+1;assert(C.endTurn(s));eq(source.hp,0);eq(s.player.hp,hp-13)
  local hits=constrictHits(s,from);eq(#hits,1);eq(hits[1].amount,10);eq(s.constrictedSource,source)
  eq(C.outcome(s),hp==13 and 'defeat'or 'victory')
  local endings=0;for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='victory'or ev.kind=='defeat'then endings=endings+1;eq(ev.kind,hp==13 and 'defeat'or 'victory')end
  end;eq(endings,1)
 end end
end)
test('late Constricted application and end-damage failures restore all original aliases',function()
 for _,experimental in ipairs({false,true})do for _,kind in ipairs({'apply','damage'})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle(nil,'1',{},data);local source=s.enemies[1];AI.initialize(s,source,primary(50))
  if kind=='damage'then assert(bind(s))end
  local before=C.copy(s);local player,enemy,rng=s.player,s.enemies[1],s.aiRng
  local apply,retaliate=A.applyPower,C.retaliate;local fired=false
  if kind=='apply'then A.applyPower=function(...)
   local ok=apply(...);local _,_,id=...;if id=='constricted'then fired=true;error('LATE_CONSTRICTED_APPLY')end;return ok
  end else C.retaliate=function(st,actor,target,amount)
   eq(st,s);eq(actor,source);eq(target,s.player);eq(amount,10)
   retaliate(st,actor,target,amount);fired=true;error('LATE_CONSTRICTED_DAMAGE')
  end end
  local ok=pcall(C.endTurn,s);A.applyPower,C.retaliate=apply,retaliate
  assert(not ok and fired);same(s,before);eq(s.player,player);eq(s.enemies[1],enemy);eq(s.aiRng,rng)
  if kind=='damage'then eq(s.constrictedSource,source)else eq(s.constrictedSource,nil)end
 end end
end)
test('late formal-room construction leaves Run queue resources and stream aliases intact',function()
 for _,seed in ipairs({'2','3'})do
  local r=stage(seed);local before=C.copy(r);local queue,cardRng=r.encounters,r.cardRng;local make=C.new
  C.new=function(...)make(...);error('LATE_MAW_GROWTH_CONSTRUCTOR')end
  local called,ok,why=pcall(Run.startRoomCombat,r,'normal');C.new=make
  assert(called);eq(ok,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,queue);eq(r.cardRng,cardRng)
 end
end)
test('Maw changing Nom counts and Constricted source identity do not mutate old presentation frames',function()
 local s=battle({'maw'});assert(C.endTurn(s));assert(C.endTurn(s));assert(C.endTurn(s))
 local e=s.enemies[1];eq(intent(e),'nom');eq(e.intents[e.intentIndex].effects[1].times,2)
 local frame=require('abyss_events').frame(s);local old=frame.enemies[1].intents[frame.enemies[1].intentIndex]
 assert(C.endTurn(s));eq(old.effects[1].times,2)
 local nominal;for _,move in ipairs(e.intents)do if move.id=='nom'then nominal=move end end
 eq(nominal.effects[1].times,3);assert(nominal~=old)
 s=battle();assert(bind(s));local source=s.enemies[1]
 frame=require('abyss_events').frame(s)
 eq(frame.constrictedSource,nil);eq(frame.player.constrictedSource,nil)
 eq(frame.player.constrictedSourceId,source.id);eq(frame.player.constrictedSourceName,source.name)
 frame.player.constrictedSourceName='frame-only';frame.enemies[1].hp=1
 eq(source.hp,170);eq(s.constrictedSource,source);eq(s.player.constrictedSourceName,source.name)
end)
test('default-priority temporary Strength restores before lethal priority105 Constricted',function()
 for _,experimental in ipairs({false,true})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle(nil,'1',{},data,10);assert(bind(s))
  A.addTemporaryStrength(s.player,4,s);eq(s.player.statuses.strength,4)
  local from=#s.events+1;assert(C.endTurn(s));eq(s.player.hp,0)
  eq(s.player.statuses.strength,0);eq(s.player.temporaryStrength,0)
  local strength,damage
  for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='status'and ev.detail.status=='strength'and ev.detail.amount==-4 then strength=i end
   if ev.kind=='status_damage'and ev.detail.source==s.enemies[1].id then damage=i end
  end
  assert(strength and damage and strength<damage)
 end
end)
test('real Host reads Maw Roar and Growth Constricted source without mutating rules or RNG',function()
 local H=dofile('tests/lua/support/battle_action_fixture.lua');local F=H.F
 for _,seed in ipairs({'2','3'})do
  local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
  local host=F.GameUI.new(root,D,F.Presentation,'click',{seed=tonumber(seed),campaign=true,prologue=false,
   imageSource='static',color=function(red,green,blue,alpha)return{r=red,g=green,b=blue,a=alpha}end})
  assert(testStart(host));local r=host.run;r.act,r.floor,r.encounters=3,35,Q.new(seed,3)
  for _=1,2 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
  assert(Run.startRoomCombat(r,'normal'));host:refresh()
  local panel=root:GetChild('battlePanel');local ui=host.battleUI;local _,tap=H.controls(panel)
  local s,e=r.combat,r.combat.enemies[1];eq(ui.run,r)
  eq(panel:GetChild('enemy1'):GetChild('name').text,e.name)
  eq(panel:GetChild('enemy1'):GetChild('hp').text,string.format('%d/%d',e.hp,e.maxHp))
  assert(not panel:GetChild('enemy2').visible)
  if seed=='2'then
   tap('enemy1',51);local notice=panel:GetChild('notice').text
   assert(notice:find(s.catalog.statuses.weak.name,1,true)and notice:find(s.catalog.statuses.frail.name,1,true))
   assert(Run.endTurn(r));host:refresh();eq(s.player.hp,s.player.maxHp)
   eq(panel:GetChild('enemy1'):GetChild('intent').text,'25')
  else
   assert(Run.endTurn(r));host:refresh();eq(s.player.hp,s.player.maxHp-16)
   tap('enemy1',52);local notice=panel:GetChild('notice').text
   assert(notice:find('束缚',1,true)and notice:find('10',1,true)and not notice:find('未知',1,true))
   assert(Run.endTurn(r));host:refresh();eq(s.constrictedSource,e);eq(s.player.statuses.constricted,10)
   panel:GetChild('hero'):GetChild('statusRow'):GetChild('hit').click({touchId=53})
   local info=panel:GetChild('statusInfo');assert(info.visible)
   local names,notes={},{}
   for i=1,F.Theme.layout.statusInfo.rows do
    local name,note=info:GetChild('name'..i),info:GetChild('note'..i)
    if name.visible then names[#names+1]=name.text end;if note.visible then notes[#notes+1]=note.text end
   end
   assert(table.concat(names,' '):find('束缚 10',1,true))
   assert(table.concat(notes,' '):find('来源：'..e.name,1,true),'Constricted source remains readable')
   info:GetChild('hit').click({touchId=54})
   local before=C.copy(r);host:refresh();same(r,before)
   assert(Run.endTurn(r));host:refresh();eq(s.player.hp,s.player.maxHp-48)
  end
 end
end)
test('owner-end extension captures the real dead-capable actor and rejects a same-ID clone',function()
 local powers=require('abyss_act3_powers');assert(powers.ownerEndIds.constricted)
 local s=battle({'spire_growth','cultist'});assert(bind(s));local source=s.enemies[1]
 local plan=powers.ownerEndPlan(s,'constricted',10);eq(#plan.bottom,1)
 eq(plan.bottom[1].op,'ownerEndThorns');eq(plan.bottom[1].source,source);eq(plan.bottom[1].value,10)
 C.damage(s,s.player,source,170,true)
 local deadPlan=powers.ownerEndPlan(s,'constricted',10);eq(deadPlan.bottom[1].source,source);eq(source.hp,0)
 assert(require('abyss_action_queue').start(s,{{kind='effect',effect=deadPlan.bottom[1]}}))
 eq(s.actionQueue.actions[1].effect.source,source)
 local frame=require('abyss_events').frame(s);eq(frame.actionQueue,nil);eq(frame.constrictedSource,nil)
 s.constrictedSource=C.copy(source);local before=C.copy(s)
 local ok,why=pcall(powers.ownerEndPlan,s,'constricted',10)
 assert(not ok and tostring(why):find('original actor',1,true));same(s,before)
end)
print('ACT3_MAW_GROWTH '..count..' groups; '..failed..' failed');assert(failed==0)
