local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
-- Chapter/queue placement fixtures, not a natural Act3 route.
local C,Run,Q,R,AI,A=require('abyss_combat'),require('abyss_run'),require('abyss_encounter_queue'),
 require('abyss_sts_random'),require('abyss_enemy_ai'),require('abyss_actor')
local D=require('abyss_data')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))end
local function streams(seed)
 local s={seed=seed};for _,id in ipairs({'aiRng','monsterHpRng','cardRandomRng','shuffleRng'})do s[id]=R.fromSeed(seed)end
 return s
end
local function battle(ids,seed,deck,data,hp)
 return C.new(data or D,{deck=deck or {},enemies=ids or {'exploder'},roomSeed=seed or '1',
  roomStreams=streams(seed or '1'),hp=hp})
end
local function intent(e)return e.intents[e.intentIndex].id end
local function primary(n)return function(_,max)eq(max,100);return n+1 end end
local function stage(seed,skip)
 local r=Run.new(D,seed,{experimental=true,campaign=true})
 r.act,r.floor,r.encounters=3,35,Q.new(seed,3)
 for _=1,skip or 0 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
 return r
end
local function shape(source,seed)
 local room=streams(seed);local misc=R.fromSeed(seed)
 local s=C.new(D,{deck={},sourceEncounter=source,roomSeed=seed,roomStreams=room,
  encounterBoundary={misc={integer=function(lo,hi)return R.randomIntBetween(misc,lo,hi)end}}})
 return s,misc
end
local function blasts(s,from)
 local result={};for i=from or 1,#s.events do local ev=s.events[i]
  if ev.kind=='status_damage'and ev.detail.source:match('exploder')and ev.detail.status=='thorns'
   and ev.detail.target==s.player.id then result[#result+1]=ev.detail end
 end;return result
end
test('real source queue opens three Shapes without replacing the mother pool',function()
 local r=Run.new(D,'3',{experimental=true,campaign=true})
 r.act,r.floor,r.encounters=3,35,Q.new('3',3)
 eq(Q.peek(r.encounters,'normal'),'3 Shapes');local old=r.encounters
 local ok,why=Run.startRoomCombat(r,'normal');assert(ok,why)
 eq(r.encounterSource,'3 Shapes');eq(#r.combat.enemies,3)
 eq(r.combat.monsterHpRng.counter,3);eq(r.combat.aiRng.counter,3);eq(r.miscRng.counter,3)
 eq(#r.encounters.normal,#old.normal-1);eq(#old.normal,15)
end)
test('real fourth-member and Sphere rooms preserve exact source actors HP and streams',function()
 for _,v in ipairs({{'1',3,'4 Shapes',{'repulsor','spiker','exploder','spiker'},{34,56,30,47},4},
  {'12',2,'Sphere and 2 Shapes',{'exploder','repulsor','spheric_guardian'},{30,30,20},2}})do
  local r=stage(v[1],v[2]);eq(Q.peek(r.encounters,'normal'),v[3]);local before=#r.encounters.normal
  assert(Run.startRoomCombat(r,'normal'));eq(r.encounterSource,v[3]);eq(#r.encounters.normal,before-1)
  local s=r.combat;eq(#s.enemies,#v[4]);eq(s.monsterHpRng.counter,v[6]);eq(r.miscRng.counter,v[6])
  eq(s.aiRng.counter,#v[4])
  for i,e in ipairs(s.enemies)do eq(e.definitionId,v[4][i]);eq(e.hp,v[5][i]);eq(e.id,e.definitionId..'_'..i)end
  if v[6]==2 then local sphere=s.enemies[3]
   eq(sphere.block,40);eq(sphere.statuses.artifact,3);eq(sphere.statuses.barricade,1)
  end
 end
end)
test('independent three-seed formations retain HP and all stream counters',function()
 local vectors=dofile('tests/fixtures/act3-shapes-vectors.lua');eq(#vectors,9)
 for _,v in ipairs(vectors)do
  local s,misc=shape(v.source,v.seed)
  for i,e in ipairs(s.enemies)do eq(e.definitionId,v.members[i]);eq(e.hp,v.hp[i]);eq(intent(e),v.openingMoves[i])end
  same(R.snapshot(s.monsterHpRng),v.monsterHp);same(R.snapshot(misc),v.misc);same(R.snapshot(s.aiRng),v.ai)
  eq(s.cardRandomRng.counter,0)
 end
end)
test('formation constructs each choice before the next misc draw then initializes AI',function()
 for _,source in ipairs({'4 Shapes','Sphere and 2 Shapes'})do
  local log={};local misc=R.fromSeed('1');local original=R.randomInt
  R.randomInt=function(s,max)
   log[#log+1]=max==99 and 'ai' or max==14 and 'hp:spiker'or max==6 and 'hp:repulsor'or 'hp:exploder'
   return original(s,max)
  end
  local called,s=pcall(C.new,D,{deck={},sourceEncounter=source,roomSeed='1',roomStreams=streams('1'),
   encounterBoundary={misc={integer=function(lo,hi)log[#log+1]='misc:'..hi;return R.randomIntBetween(misc,lo,hi)end}}})
  R.randomInt=original;assert(called,s)
  local expected=source=='4 Shapes'and {'misc:5','hp:spiker','misc:4','hp:repulsor','misc:3','hp:repulsor','misc:2','hp:exploder','ai','ai','ai','ai'}
   or {'misc:2','hp:exploder','misc:2','hp:repulsor','ai','ai','ai'}
  same(log,expected)
  eq(s.enemies[1].sourcePosition.x,source=='4 Shapes'and -480 or -435)
  eq(s.enemies[#s.enemies].sourcePosition.x,source=='4 Shapes'and 240 or 110)
 end
end)
test('Repulsor 19 and 20 boundaries prevent consecutive attacks',function()
 local s=battle({'repulsor'});local e=s.enemies[1]
 AI.initialize(s,e,primary(19));eq(intent(e),'attack')
 AI.advance(s,e,primary(19));eq(intent(e),'daze')
 AI.advance(s,e,primary(19));eq(intent(e),'attack')
 AI.advance(s,e,primary(20));eq(intent(e),'daze')
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp)
end)
test('Spiker starts at three Thorns and exactly six reinforcement actions cap at fifteen',function()
 local s=battle({'spiker'});local e=s.enemies[1];eq(e.statuses.thorns,3)
 AI.initialize(s,e,primary(49));eq(intent(e),'attack')
 AI.advance(s,e,primary(49));eq(intent(e),'spike')
 for i=1,6 do
  AI.advance(s,e,primary(50));eq(intent(e),'spike')
  assert(C.endTurn(s));eq(e.spikeCount,i);eq(e.statuses.thorns,3+i*2)
 end
 eq(intent(e),'attack');local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-7)
 eq(e.spikeCount,6);eq(e.statuses.thorns,15)
 AI.advance(s,e,primary(99));eq(intent(e),'attack')
 hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-7);eq(e.spikeCount,6);eq(e.statuses.thorns,15)
end)
test('real player attacks receive separate Spiker retaliation without recursion',function()
 local s=battle({'spiker'},'1',{'twin_strike'});local e=s.enemies[1];local hp=s.player.hp
 assert(C.play(s,s.hand[1].uid,1));eq(s.player.hp,hp-6)
 local hits=0;for _,ev in ipairs(s.events)do if ev.kind=='status_damage'and ev.detail.source==e.id then hits=hits+1;eq(ev.detail.amount,3)end end
 eq(hits,2);eq(e.hp,e.maxHp-10)
end)
test('Repulsor inserts two separate default Dazed with real UID and empty-pile random timing',function()
 for _,size in ipairs({0,1,2})do
  local deck={};for _=1,size>0 and 5+size or 0 do deck[#deck+1]='strike'end
  local s=battle({'repulsor'},'1',deck);local e=s.enemies[1];AI.initialize(s,e,primary(20))
  local top=s.draw[#s.draw];local uid=s.nextUid;local random,shuffle=s.cardRandomRng.counter,s.shuffleRng.counter
  C.applyEffects(s,e.intents[e.intentIndex].effects,e,s.player)
  eq(#s.draw,size+2);eq(#s.discard,0);eq(s.nextUid,uid+2)
  eq(s.cardRandomRng.counter,random+(size==0 and 1 or 2));eq(s.shuffleRng.counter,shuffle)
  local found={};for _,card in ipairs(s.draw)do if card.cardId=='dazed'then
   assert(not found[card.uid]and not card.upgraded and card.deckUid==nil);found[card.uid]=card
  end end
  assert(found[uid]and found[uid+1]and found[uid]~=found[uid+1]);if top then eq(s.draw[#s.draw],top)end
  if size==0 then eq(s.draw[1].uid,uid+1);eq(s.draw[2].uid,uid)end
 end
end)
test('real double Dazed draw and Ethereal exhaustion preserve placement then empty shuffle order',function()
 local s=battle({'repulsor'});local hp=s.player.hp;local uid=s.nextUid;local shuffle=s.shuffleRng.counter
 eq(intent(s.enemies[1]),'daze');assert(C.endTurn(s));eq(#s.hand,2)
 eq(s.hand[1].uid,uid);eq(s.hand[2].uid,uid+1);eq(s.cardRandomRng.counter,1);eq(s.shuffleRng.counter,shuffle+1)
 eq(intent(s.enemies[1]),'attack');assert(C.endTurn(s));eq(#s.exhaust,2);eq(s.player.hp,hp-11)
 eq(s.exhaust[1].uid,uid);eq(s.exhaust[2].uid,uid+1)
end)
test('Exploder attacks twice then rolls before suicide and retained fixed THORNS damage',function()
 for _,allies in ipairs({false,true})do
  local s=battle(allies and {'cultist','exploder'}or {'exploder'});local e=s.enemies[#s.enemies]
  eq(e.hp,30);eq(e.statuses.explosive,3);eq(intent(e),'attack')
  assert(C.endTurn(s));eq(e.statuses.explosive,2);eq(e.exploderTurns,1);eq(intent(e),'attack')
  assert(C.endTurn(s));eq(e.statuses.explosive,1);eq(e.exploderTurns,2);eq(intent(e),'wait')
  local rng=s.aiRng.counter;local from=#s.events+1;assert(C.endTurn(s))
  eq(e.hp,0);eq(e.exploderTurns,3);eq(s.aiRng.counter,rng+(allies and 2 or 1))
  local damage=blasts(s,from);eq(#damage,1);eq(damage[1].amount,30);eq(damage[1].target,s.player.id)
  local deaths=0;for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='enemy_suicide'and ev.detail.enemy==e.id then deaths=deaths+1;eq(s.events[i+1].kind,'status_damage')end
  end;eq(deaths,1)
  eq(s.player.hp,s.player.maxHp-(allies and 63 or 48))
  if allies then eq(C.outcome(s),nil)else eq(C.outcome(s),'victory')end
 end
end)
test('Exploder retained damage respects block and Intangible but ignores normal modifiers and Thorns',function()
 for _,v in ipairs({{10,false,20},{40,false,0},{0,true,1},{1,true,0}})do
  local s=battle();local e=s.enemies[1];assert(C.endTurn(s));assert(C.endTurn(s))
  A.applyPower(s,e,'strength',25,e);A.applyPower(s,e,'weak',2,s.player)
  A.applyPower(s,s.player,'vulnerable',2,e);A.applyPower(s,s.player,'thorns',99,s.player)
  if v[2]then
   -- Metadata registers the already-supported Intangible arithmetic; no card
   -- acquisition or complete Power lifecycle is claimed by this local fixture.
   s.catalog.statuses.intangible={id='intangible',name='Intangible',kind='buff',stack='duration',decay='none',description='Incoming damage capped at 1.'}
   A.applyPower(s,s.player,'intangible',1,s.player)
  end
  A.block(s,s.player,v[1],true);local hp=s.player.hp;local from=#s.events+1
  assert(C.endTurn(s));eq(s.player.hp,hp-v[3]);eq(e.hp,0)
  local hits=blasts(s,from);eq(#hits,1);eq(hits[1].amount,v[3]);eq(hits[1].blocked,math.min(v[1],v[2]and 1 or 30))
  local retaliation=0;for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='status_damage'and ev.detail.source==s.player.id then retaliation=retaliation+1 end
  end;eq(retaliation,0)
 end
end)
test('player death from the last explosion takes precedence over simultaneous final enemy death',function()
 for _,hp in ipairs({48,47})do
  local s=battle(nil,'1',nil,nil,hp);assert(C.endTurn(s));assert(C.endTurn(s));assert(C.endTurn(s))
  eq(s.enemies[1].hp,0);eq(s.player.hp,0);eq(C.outcome(s),'defeat');eq(s.phase,'defeat')
 end
end)
test('killed or poisoned Exploders never queue their later suicide and explosion',function()
 for _,poison in ipairs({false,true})do
  local s=battle({'exploder','cultist'});local e=s.enemies[1];assert(C.endTurn(s));assert(C.endTurn(s))
  local ai=s.aiRng.counter
  if poison then A.applyPower(s,e,'poison',30,s.player)else C.damage(s,s.player,e,30,true)end
  local from=#s.events+1;assert(C.endTurn(s));eq(e.hp,0);eq(#blasts(s,from),0)
  eq(s.aiRng.counter,ai+1);eq(e.exploderTurns,2)
 end
end)
test('both dispatchers restore every owner when Dazed second placement or explosion tail throws',function()
 for _,experimental in ipairs({false,true})do for _,kind in ipairs({'repulsor','exploder'})do
  local data=experimental and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle({kind},'1',{},data);eq(s.experimentalMechanics==true,experimental)
  if kind=='exploder'then assert(C.endTurn(s));assert(C.endTurn(s))end
  local before=C.copy(s);local draw,enemy,rng=s.draw,s.enemies[1],s.cardRandomRng
  local random,retaliate=R.randomInt,C.retaliate;local fired=false
  if kind=='repulsor'then R.randomInt=function(stream,max)
   local value=random(stream,max);if stream==rng then fired=true;error('SECOND_DAZED_FAILURE')end;return value
  end else C.retaliate=function(...)retaliate(...);fired=true;error('EXPLOSION_TAIL_FAILURE')end end
  local ok=pcall(C.endTurn,s);R.randomInt,C.retaliate=random,retaliate
  assert(not ok and fired);same(s,before);eq(s.draw,draw);eq(s.enemies[1],enemy);eq(s.cardRandomRng,rng)
 end end
end)
test('late formation setup failure preserves real Run queue resources and room streams',function()
 for _,v in ipairs({{'3',0},{'1',3},{'12',2}})do
  local r=stage(v[1],v[2]);local before=C.copy(r);local queue=r.encounters;local make=C.new
  C.new=function(...)make(...);error('LATE_SHAPES_FAILURE')end
  local called,ok,why=pcall(Run.startRoomCombat,r,'normal');C.new=make
  assert(called);eq(ok,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,queue)
 end
end)
test('real Host shows Shape actors Dazed destination and changing Explosive countdown',function()
 local H=dofile('tests/lua/support/battle_action_fixture.lua');local F=H.F
 local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,D,F.Presentation,'click',{seed=1,campaign=true,prologue=false,
  imageSource='static',color=function(red,green,blue,alpha)return{r=red,g=green,b=blue,a=alpha}end})
 assert(testStart(host));local r=host.run;r.act,r.floor,r.encounters=3,35,Q.new('1',3)
 for _=1,3 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
 assert(Run.startRoomCombat(r,'normal'));host:refresh()
 local panel=root:GetChild('battlePanel');local ui=host.battleUI;local _,tap=H.controls(panel)
 eq(ui.run,r);eq(#r.combat.enemies,4)
 for i,e in ipairs(r.combat.enemies)do local box=monsterControl(panel,'enemy'..i)
  assert(box.visible);eq(box:GetChild('name').text,e.name);eq(box:GetChild('hp').text,string.format('%d/%d',e.hp,e.maxHp))
 end
 assert(not monsterControl(panel,'enemy5'))
 tap('enemy1',71);local text=inspectDetails(ui,panel)
 assert(text:find(r.combat.catalog.cards.dazed.name,1,true)and text:find('抽牌堆',1,true)and text:find('2',1,true),text)
 assert(not text:find('未知',1,true),text)
 for turn=0,2 do
  if turn>0 then assert(Run.endTurn(r));host:refresh()end
  local e=r.combat.enemies[3];eq(e.statuses.explosive,3-turn)
  local hit=dofile('tests/lua/support/monster_power_control_fixture.lua')(monsterControl(panel,'enemy3'),'explosive'):GetChild('hit')
  hit.click({touchId=80+turn});eq(ui.info.id,e.id);eq(ui.info.index,3)
  local info=panel:GetChild('statusInfo');assert(info.visible)
  local names,details={},{}
  for i=1,F.Theme.layout.statusInfo.rows do
   local name=info:GetChild('name'..i);if name.visible then names[#names+1]=name.text end
   local line=info:GetChild('text'..i);if line.visible then details[#details+1]=line.text end
  end
  assert(table.concat(names,' '):find('自爆 '..(3-turn),1,true))
  assert(table.concat(details,' '):find('30',1,true))
  info:GetChild('hit').click({touchId=90+turn})
 end
 eq(intent(r.combat.enemies[3]),'wait')
 eq(monsterControl(panel,'enemy3'):GetChild('intentIcon').imageId,F.Theme.icon.intent.unknown)
 assert(Run.endTurn(r));host:refresh();eq(r.phase,'combat')
 eq(r.combat.enemies[3].hp,0);eq(r.combat.player.hp,r.combat.player.maxHp-73)
 for slot,index in ipairs({1,2,4})do
  local box,e=monsterControl(panel,'enemy'..slot),r.combat.enemies[index]
  assert(box.visible);eq(box:GetChild('name').text,e.name);eq(box:GetChild('hp').text,string.format('%d/%d',e.hp,e.maxHp))
 end
 assert(not monsterControl(panel,'enemy4') and not monsterControl(panel,'enemy5'))
end)
test('invalid Dazed UID refuses both creations and restores source RNG',function()
 local s=battle({'repulsor'});s.nextUid=9007199254740992
 local before=C.copy(s);assert(not pcall(C.endTurn,s));same(s,before)
end)
print('ACT3_SHAPES '..count..' groups; '..failed..' failed');assert(failed==0)
