-- Existing frozen V4 next-attack rules must also recognize real Life Suck.
-- Dependency-only Vampire heal-before-reaction fix; no Plated queue layer.
package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local C,A,E,D=require('abyss_combat'),require('abyss_actor'),require('abyss_events'),require('abyss_data')
local P,V,R,SR=require('abyss_original_v4_profiles'),require('abyss_original_v4'),require('abyss_run'),require('abyss_sts_random')
local View=require('abyss_battle_intent_view')
local passed,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS 'or'FAIL ')..name..(ok and''or': '..tostring(why)))end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return v end end;error('missing intent '..id)end
local function battle(role,ids,hp)
 local streams=R.roomStreams({runSeed='42'},18)
 local s=C.new(P.prepare(D,role or 'HT'),{enemies=ids or {'shelled_parasite'},deck={},seed=42,hp=hp or 40,maxHp=80,roomSeed=streams.seed,roomStreams=streams})
 for _,e in ipairs(s.enemies)do if e.definitionId=='shelled_parasite'then local intent=force(e,'life_suck');eq(intent.effects[1].op,'enemyVampireDamage');eq(intent.effects[1].value,10);e.hp=10;e.block=0 end end
 s.originalV4.soften=6;s.originalV4.counter=8;s.events={};return s,s.enemies[1]
end
local function hits(s,e)
 local result={};for _,v in ipairs(s.events)do if type(v.detail)=='table'and v.detail.target==e.id and(v.kind=='heal'or v.kind=='status_damage')then result[#result+1]=v end end;return result
end
local function noHeal(s)for _,v in ipairs(s.events)do assert(v.kind~='heal','must not heal')end end
local function unchanged(root)
 local saved={};local function visit(t)if type(t)~='table'or saved[t]then return end;local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;visit(k);visit(v)end end;visit(root)
 return function()for t,values in pairs(saved)do for k,v in pairs(values)do eq(t[k],v,'original key '..tostring(k))end;for k,v in pairs(t)do eq(v,values[k],'extra key '..tostring(k))end end end
end
local function spyRoll(s,fn)
 local old=SR.randomInt;local calls={}
 SR.randomInt=function(rng,max)if rng==s.aiRng then calls[#calls+1]={events=#s.events,hp=s.enemies[1].hp,counter=s.originalV4.counter,soften=s.originalV4.soften,maximum=max}end;return old(rng,max)end
 local ok,why=pcall(fn,calls);SR.randomInt=old;assert(ok,why)
end
test('real C.endTurn independently settles4 damage and counter kill, not old10 damage with no counter',function()
 local s,e=battle();e.hp=1;assert(C.endTurn(s))
 print('V4_VAMPIRE_REAL_ENDTURN playerHp='..s.player.hp..' sourceHp='..e.hp..' phase='..s.phase)
 eq(s.player.hp,36);eq(e.hp,0);eq(s.phase,'victory');eq(s.originalV4.soften,0);eq(s.originalV4.counter,0)
end)
test('existing Weak/Vulnerable rounding11 precedes soften6 and captured-loss heal5',function()
 local s,e=battle();A.applyPower(s,e,'weak',1,e);A.applyPower(s,s.player,'vulnerable',1,s.player)
 eq(View.intentView(s,1).value,'5');assert(C.endTurn(s));eq(s.player.hp,35);eq(e.hp,7);eq(hits(s,e)[1].detail.amount,5)
end)
for _,role in ipairs({'HT','AR','FR','RD'})do
 test(role..' real Life Suck preview4, heal4, Thorns5, counter8, then actual Roll',function()
  local s,e=battle(role);A.applyPower(s,s.player,'thorns',5,s.player);s.events={}
  local check=unchanged(s);eq(V.intentReduction(s,1),6);eq(View.intentView(s,1).value,'4');check()
  local counter=s.aiRng.counter
  spyRoll(s,function(calls)
   assert(C.endTurn(s));eq(s.player.hp,36);eq(e.hp,1);eq(s.phase,'player');eq(s.aiRng.counter,counter+1);eq(#calls,1)
   local trace=hits(s,e);eq(#trace,3);eq(trace[1].kind,'heal');eq(trace[1].detail.amount,4);eq(trace[1].frame.enemies[1].hp,14)
   eq(trace[1].frame.originalV4.soften,0);eq(trace[1].frame.originalV4.counter,8)
   eq(trace[2].kind,'status_damage');eq(trace[2].detail.amount,5);eq(trace[2].frame.enemies[1].hp,9)
   eq(trace[3].detail.amount,8);eq(trace[3].frame.enemies[1].hp,1);eq(trace[3].frame.originalV4.counter,0)
   eq(calls[1].hp,1);eq(calls[1].counter,0);eq(calls[1].soften,0);eq(calls[1].maximum,99)
   eq(s.events[calls[1].events].frame.enemies[1].hp,1)
  end)
 end)
end
test('first Life Suck alone spends next-attack soften and counter; second remains10',function()
 local s,e=battle('HT',{'shelled_parasite','shelled_parasite'});eq(View.intentView(s,1).value,'4');eq(View.intentView(s,2).value,'10')
 assert(C.endTurn(s));eq(s.player.hp,26);eq(e.hp,6);eq(s.enemies[2].hp,20);eq(#hits(s,e),2);eq(#hits(s,s.enemies[2]),1)
end)
test('real nonattack Cultist chant preserves resources for following Life Suck',function()
 local s=battle('HT',{'cultist','shelled_parasite'});local e=s.enemies[2]
 eq(V.intentReduction(s,1),0);eq(View.intentView(s,2).value,'4');assert(C.endTurn(s));eq(s.player.hp,36);eq(e.hp,6)
 local found=false;for _,v in ipairs(s.events)do if v.kind=='status'and v.detail.target==s.enemies[1].id and v.detail.status=='ritual'then found=true;eq(v.frame.originalV4.soften,6);eq(v.frame.originalV4.counter,8)end end;assert(found)
end)
test('fully blocked Life Suck consumes both attack resources but schedules no heal',function()
 local s,e=battle();s.player.block=100;assert(C.endTurn(s));eq(s.player.hp,40);eq(e.hp,2);eq(#hits(s,e),1);noHeal(s)
 local hit=hits(s,e)[1];eq(hit.detail.amount,8);eq(hit.frame.originalV4.soften,0);eq(hit.frame.originalV4.counter,0)
end)
for _,row in ipairs({{'HT','HT2-031','HT2-049',17},{'AR','AR2-021','AR2-036',13}})do
 test(row[1]..' real frozen soften/counter cards feed blocked Life Suck boundary',function()
  local s,e=battle(row[1]);s.originalV4.soften=0;s.originalV4.counter=0
  for _,id in ipairs({row[2],row[3]})do local card={uid=s.nextUid,cardId=id,upgraded=false};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=card;s.energy=20;assert(C.play(s,card.uid))end
  eq(s.player.block,row[4]);eq(s.originalV4.counter,4);assert(s.originalV4.soften>0)
  assert(C.endTurn(s));eq(s.player.hp,40);eq(e.hp,6);noHeal(s);eq(hits(s,e)[1].detail.amount,4)
 end)
end
test('non-Fairy lethal Life Suck consumes soften but never heals or counters after defeat',function()
 local s,e=battle('HT',nil,3);local counter=s.aiRng.counter;assert(C.endTurn(s));eq(s.player.hp,0);eq(e.hp,10);eq(s.phase,'defeat');eq(s.aiRng.counter,counter);eq(s.originalV4.soften,0);eq(s.originalV4.counter,8);eq(s.originalV4.enemyAction,nil);noHeal(s);eq(#hits(s,e),0)
end)
for _,extra in ipairs({false,true})do
 test('counter kills attacker '..(extra and 'with teammate: retained Roll' or 'as final enemy: clear Roll'),function()
  local s,e=battle('AR',extra and {'shelled_parasite','cultist'}or nil);e.hp=1;e.v4Directive={mature=true};local counter=s.aiRng.counter;local intent=e.intentIndex
  assert(C.endTurn(s));eq(s.player.hp,36);eq(e.hp,0);eq(s.originalV4.bond,4);eq(e.v4Directive,nil)
  eq(s.aiRng.counter,counter+(extra and 2 or 0));eq(s.phase,extra and 'player'or'victory')
  if extra then eq(e.act2Last,'life_suck')else eq(e.intentIndex,intent)end
  local trace=hits(s,e);eq(#trace,2);eq(trace[1].kind,'heal');eq(trace[1].detail.amount,4);eq(trace[2].detail.amount,5)
 end)
end
for _,stage in ipairs({'heal','counter','roll'})do
 test('atomic C.endTurn restores all table identities, V4 resources and real RNG after '..stage..' failure',function()
  local s,e=battle('AR',{'shelled_parasite','cultist'});e.hp=1;e.v4Directive={mature=true}
  local check=unchanged(s);local emit,random=E.emit,SR.randomInt;local injected=false
  E.emit=function(state,kind,detail)local result=emit(state,kind,detail);if(stage=='heal'and kind=='heal'and detail.target==e.id)or(stage=='counter'and kind=='status_damage'and detail.target==e.id)then injected=true;error('v4 vampire injected '..stage)end;return result end
  SR.randomInt=function(rng,max)local value=random(rng,max);if stage=='roll'and rng==s.aiRng then injected=true;error('v4 vampire injected roll')end;return value end
  local ok,why=pcall(C.endTurn,s);E.emit=emit;SR.randomInt=random
  assert(injected,'fault not reached');assert(not ok and tostring(why):find('v4 vampire injected '..stage,1,true),tostring(why));check()
 end)
end
for _,kind in ipairs({'stunned','zero_vampire','negative_vampire'})do
 test(kind..' is not an attack and preserves resources until normal cleanup',function()
  local s,e=battle();local intent=force(e,'stunned')
  -- Isolated synthetic zero/negative opcode cases do not modify the real Life Suck.
  if kind~='stunned'then intent.effects={{op='enemyVampireDamage',value=kind=='zero_vampire'and 0 or -1}}end
  eq(V.intentReduction(s,1),0)
  local found=false;local old=V.endEnemyAction
  V.endEnemyAction=function(combat,state)found=true;eq(state.originalV4.enemyAction.attacking,false);eq(state.originalV4.soften,6);eq(state.originalV4.counter,8);return old(combat,state)end
  local ok,why=pcall(C.endTurn,s);V.endEnemyAction=old;assert(ok,why);assert(found);eq(s.player.hp,40);eq(e.hp,10);eq(#hits(s,e),0)
 end)
end
print(passed..' V4 Vampire attack groups passed; '..failed..' failed');assert(failed==0)
