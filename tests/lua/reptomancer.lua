-- Source formation and isolated component fixtures, not a natural campaign.
local C,D,R,AI,A=require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),
 require('abyss_enemy_ai'),require('abyss_actor')
local Repto=require('abyss_reptomancer')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function streams(seed)
 local out={};for _,k in ipairs({'aiRng','monsterHpRng','cardRandomRng','shuffleRng'})do out[k]=R.fromSeed(seed)end;return out
end
local function battle(ids,seed,data,hp,deck)
 local options={deck=deck or {},roomSeed=seed or '1',roomStreams=streams(seed or '1'),maxHp=5000,hp=hp or 5000}
 if ids then options.enemies=ids else options.sourceEncounter='Reptomancer';options.encounterBoundary={misc={}}end
 return C.new(data or D,options)
end
local function intent(e)return e.intents[e.intentIndex].id end
local function actor(s,id)for _,e in ipairs(s.enemies)do if e.definitionId==id then return e end end end
local function force(e,id)for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return end end;error(id)end
local function countEvents(s,kind,source,from)
 local n=0;for i=from or 1,#s.events do local ev=s.events[i]
  if ev.kind==kind and (not source or ev.detail.source==source or ev.detail.enemy==source)then n=n+1 end
 end;return n
end
local function checked(...)
 local values={...};local used=0
 return function(_,maximum)used=used+1;eq(maximum,values[used][1]);return values[used][2]end,
  function()eq(used,#values)end
end
local function verify(s,v)
 eq(#s.enemies,#v.actors);eq(s.player.hp,v.playerHp)
 for i,e in ipairs(s.enemies)do local row=v.actors[i]
  eq(e.id,row.id);eq(e.hp,row.hp);eq(e.sourcePosition.x,row.x);eq(e.sourcePosition.y,row.y);eq(intent(e),row.move)
 end
 same(R.snapshot(s.monsterHpRng),v.hpRng);same(R.snapshot(s.aiRng),v.aiRng)
 eq(countEvents(s,'cards_created'),v.wounds);eq(s.cardRandomRng.counter,0)
end
test('independent 3-seed 12-round source vectors retain corpses IDs HP AI and action order',function()
 local vectors=dofile('tests/fixtures/reptomancer-vectors.lua');eq(#vectors,3)
 for _,v in ipairs(vectors)do
  local s=battle(nil,v.seed);verify(s,v.opening)
  for _,round in ipairs(v.rounds)do
   local from=#s.events+1;assert(C.endTurn(s));verify(s,round)
   local actions={};for i=from,#s.events do local ev=s.events[i]
    if ev.kind=='intent'then actions[#actions+1]=ev.detail.enemy..':'..ev.detail.id end
   end;same(actions,round.actions)
  end
 end
end)
test('opening source HP constructors precede all AI rolls and preBattle Minion',function()
 local log={};local old=R.randomInt
 R.randomInt=function(stream,maximum)
  log[#log+1]=maximum==99 and 'ai'or 'hp:'..maximum;return old(stream,maximum)
 end
 local ok,s=pcall(battle);R.randomInt=old;assert(ok,s)
 same(log,{'hp:5','hp:10','hp:10','hp:5','ai','ai','ai'})
 eq(s.monsterHpRng.counter,4);eq(s.aiRng.counter,3);eq(s.nextEnemyId,4)
 local leader=s.enemies[2];eq(leader.sourceId,'Reptomancer');eq(leader.statuses.minion,nil)
 eq(leader.reptomancerSlots[1],s.enemies[3].id);eq(leader.reptomancerSlots[2],s.enemies[1].id)
 for _,i in ipairs({1,3})do eq(s.enemies[i].sourceId,'Dagger');eq(s.enemies[i].statuses.minion,1);eq(s.enemies[i].minion,true)end
end)
test('all A0 thresholds and recursive repeat exclusions preserve exact extra ranges',function()
 local s=battle();local e=s.enemies[2]
 for _,v in ipairs({{0,'snake_strike'},{32,'snake_strike'},{33,'summon'},{65,'summon'},{66,'big_bite'},{99,'big_bite'}})do
  e.reptomancerLast,e.reptomancerPrevious='summon',nil
  local roll,done=checked({100,v[1]+1});AI.advance(s,e,roll);done();eq(intent(e),v[2])
 end
 e.reptomancerLast='snake_strike'
 local roll,done=checked({100,1},{67,1});AI.advance(s,e,roll);done();eq(intent(e),'summon')
 e.reptomancerLast='snake_strike';roll,done=checked({100,33},{67,67});AI.advance(s,e,roll);done();eq(intent(e),'big_bite')
 e.reptomancerLast='big_bite';roll,done=checked({100,67},{66,33});AI.advance(s,e,roll);done();eq(intent(e),'snake_strike')
 e.reptomancerLast='big_bite';roll,done=checked({100,100},{66,66});AI.advance(s,e,roll);done();eq(intent(e),'summon')
 e.reptomancerLast,e.reptomancerPrevious='summon','summon';roll,done=checked({100,34});AI.advance(s,e,roll);done();eq(intent(e),'snake_strike')
end)
test('summon fills source slots in order caps four living blades and keeps old actors',function()
 local s=battle();local e=s.enemies[2];local oldLeft,oldRight=s.enemies[1],s.enemies[3]
 local hp,ai=s.monsterHpRng.counter,s.aiRng.counter
 Repto.summon(C,s,e);local upper=actor(s,'snake_dagger') -- left remains first
 eq(upper,oldLeft);eq(e.reptomancerSlots[3],'snake_dagger_4');eq(s.enemies[3].sourcePosition.x,180)
 Repto.summon(C,s,e);eq(e.reptomancerSlots[4],'snake_dagger_5');eq(s.enemies[1].sourcePosition.x,-250)
 eq(s.monsterHpRng.counter,hp+2);eq(s.aiRng.counter,ai+2);eq(#s.enemies,5)
 Repto.summon(C,s,e);eq(s.monsterHpRng.counter,hp+2);eq(s.aiRng.counter,ai+2)
 e.reptomancerLast,e.reptomancerPrevious='big_bite',nil
 local roll,done=checked({100,34});AI.advance(s,e,roll);done();eq(intent(e),'snake_strike')
 oldLeft.hp,oldRight.hp=0,0
 Repto.summon(C,s,e);eq(e.reptomancerSlots[1],'snake_dagger_6')
 Repto.summon(C,s,e);eq(e.reptomancerSlots[2],'snake_dagger_7');eq(#s.enemies,7);eq(s.nextEnemyId,8)
 local found=0;for _,a in ipairs(s.enemies)do if a==oldLeft or a==oldRight then found=found+1 end end;eq(found,2)
 eq(oldLeft.id,'snake_dagger_1');eq(oldRight.id,'snake_dagger_3')
 e.reptomancerLast,e.reptomancerPrevious='summon',nil;oldLeft.hp=0;oldRight.hp=0
 roll,done=checked({100,34});AI.advance(s,e,roll);done();eq(intent(e),'snake_strike')
end)
test('source slots bind before spawned init and Power events without mutating older frames',function()
 local s=battle();local leader=s.enemies[2];local frame=require('abyss_events').frame(s)
 local oldSlots=leader.reptomancerSlots;local opening
 for _,ev in ipairs(s.events)do if ev.kind=='status'and ev.detail.status=='minion'then opening=ev.frame;break end end
 assert(opening);eq(opening.enemies[2].reptomancerSlots[1],'snake_dagger_3')
 eq(opening.enemies[2].reptomancerSlots[2],'snake_dagger_1')
 local initialize=AI.initialize;local observed=false
 AI.initialize=function(state,e,random)
  if e.id=='snake_dagger_4'then
   observed=true;eq(leader.reptomancerSlots[3],e.id);assert(leader.reptomancerSlots~=oldSlots)
  end
  return initialize(state,e,random)
 end
 local ok,why=pcall(Repto.summon,C,s,leader);AI.initialize=initialize;assert(ok,why);assert(observed)
 eq(oldSlots[3],nil);eq(frame.enemies[2].reptomancerSlots[3],nil);eq(opening.enemies[2].reptomancerSlots[3],nil)
 for _,ev in ipairs(s.events)do if ev.kind=='enemy_spawn'and ev.detail.enemy=='snake_dagger_4'then
  eq(ev.frame.enemies[2].reptomancerSlots[3],'snake_dagger_4')
 end end
end)
test('new summons inherit Stone before opening roll but do not act in their spawn round',function()
 local s=battle();s.relics={"Philosopher's Stone"}
 local from=#s.events+1;assert(C.endTurn(s));eq(s.player.hp,4982)
 local child
 for _,e in ipairs(s.enemies)do if e.id=='snake_dagger_4'then child=e end end
 assert(child);eq(child.statuses.strength,1);eq(child.statuses.minion,1);eq(intent(child),'stab')
 eq(countEvents(s,'damage',child.id,from),0);eq(countEvents(s,'enemy_spawn',child.id,from),1)
end)
test('SnakeStrike is two modified attacks then Weak and spends Artifact only after damage',function()
 for _,artifact in ipairs({false,true})do
  local s=battle({'reptomancer'});local e=s.enemies[1];force(e,'snake_strike')
  A.applyPower(s,e,'strength',3,e);A.applyPower(s,e,'weak',1,s.player)
  A.applyPower(s,s.player,'vulnerable',2,e);A.block(s,s.player,10,true)
  if artifact then A.applyPower(s,s.player,'artifact',1,s.player)end
  local from=#s.events+1;assert(C.endTurn(s));eq(s.player.hp,4974)
  eq(countEvents(s,'damage',e.id,from),2);eq(s.player.statuses.weak or 0,artifact and 0 or 1)
  local lastDamage,status
  for i=from,#s.events do local ev=s.events[i]
   if ev.kind=='damage'and ev.detail.source==e.id then lastDamage=i end
   if ev.kind=='status'and ev.detail.status=='weak'and ev.detail.target=='player'then status=i end
  end
  if status then assert(status>lastDamage)end
 end
end)
test('Dagger Stab adds Wound even fully blocked and changes to Explode with one roll',function()
 local s=battle({'snake_dagger','cultist'});local e=s.enemies[1]
 A.block(s,s.player,99,true);local ai=s.aiRng.counter;assert(C.endTurn(s))
 eq(s.player.hp,5000);eq(countEvents(s,'cards_created'),1);eq(intent(e),'explode');eq(s.aiRng.counter,ai+2)
 local found=false;for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.cardId=='wound'then found=true end end end;assert(found)
end)
test('Stab Wound and RollMove survive caster retaliation death only while teammates live',function()
 for _,allies in ipairs({false,true})do
  local s=battle(allies and {'snake_dagger','cultist'}or {'snake_dagger'});local e=s.enemies[1]
  A.applyPower(s,s.player,'thorns',99,s.player);local ai=s.aiRng.counter
  assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,4991)
  eq(countEvents(s,'cards_created'),allies and 1 or 0);eq(s.aiRng.counter,ai+(allies and 2 or 0))
 end
end)
test('Explode uses normal attack then captured self HP_LOSS ignoring its Block',function()
 local s=battle({'snake_dagger','cultist'});local e=s.enemies[1];force(e,'explode')
 A.applyPower(s,e,'strength',5,e);A.applyPower(s,e,'weak',2,s.player)
 A.applyPower(s,s.player,'vulnerable',2,e);e.block=100
 local hp=e.hp;assert(C.endTurn(s));eq(s.player.hp,4967);eq(e.hp,0);eq(e.block,0)
 local loss
 for _,ev in ipairs(s.events)do if ev.kind=='hp_loss'and ev.detail.target==e.id then loss=ev.detail end end
 assert(loss);eq(loss.amount,hp);eq(loss.source,e.id);eq(loss.blocked,0);eq(intent(e),'explode')
end)
test('Explode captures self HP before its attack and HP_LOSS never consumes later Block',function()
 local s=battle({'snake_dagger','cultist'});local e=s.enemies[1];force(e,'explode')
 local hp=e.hp;local damage=C.damage;local sacrifice=A.sacrificeDagger;local seen=false
 C.damage=function(st,source,target,...)
  local lost=damage(st,source,target,...)
  if source==e and target==st.player then e.hp=e.hp+10;e.block=100 end
  return lost
 end
 A.sacrificeDagger=function(st,target,amount)
  eq(amount,hp);seen=true;return sacrifice(st,target,amount)
 end
 local ok,why=pcall(C.endTurn,s);C.damage=damage;A.sacrificeDagger=sacrifice
 assert(ok,why);assert(seen);eq(e.hp,10);eq(e.block,100)
end)
test('Dagger HP-loss respects Intangible and captured preattack life rather than Suicide',function()
 local s=battle({'snake_dagger','cultist'});local e=s.enemies[1];force(e,'explode')
 s.catalog.statuses.intangible={id='intangible',name='虚体',kind='buff',stack='duration',decay='none',description='伤害至多1。'}
 A.applyPower(s,e,'intangible',1,e);local before=e.hp;assert(C.endTurn(s));eq(e.hp,before-1)
 eq(countEvents(s,'enemy_suicide',e.id),0);eq(countEvents(s,'hp_loss',e.id),1)
end)
test('player death stops Explode before self HP-loss and queued RollMove',function()
 local s=battle({'snake_dagger'},'1',nil,25);local e=s.enemies[1];force(e,'explode')
 local hp,ai=e.hp,s.aiRng.counter;assert(C.endTurn(s));eq(s.player.hp,0);eq(e.hp,hp)
 eq(s.phase,'defeat');eq(s.aiRng.counter,ai);eq(countEvents(s,'hp_loss',e.id),0)
end)
test('leader death suicides blades in reverse group order with no HP-loss or escape',function()
 local s=battle();local leader=s.enemies[2];Repto.summon(C,s,leader)
 local order={};for i=#s.enemies,1,-1 do local e=s.enemies[i];if e~=leader then order[#order+1]=e.id end end
 local from=#s.events+1;C.damage(s,s.player,leader,999,true)
 local actual={};for i=from,#s.events do local ev=s.events[i]
  if ev.kind=='enemy_suicide'then actual[#actual+1]=ev.detail.enemy end
  assert(ev.kind~='enemy_escape'and ev.kind~='hp_loss')
 end;same(actual,order);eq(C.outcome(s),'victory')
 for _,e in ipairs(s.enemies)do eq(e.hp,0);if e~=leader then eq(e.gold,0)end end
end)
test('leader killed by first SnakeStrike retaliation cancels second hit Weak and all rolls',function()
 local s=battle();local e=s.enemies[2];force(e,'snake_strike');s.enemies[1].hp=0
 A.applyPower(s,s.player,'thorns',999,s.player);local ai=s.aiRng.counter
 assert(C.endTurn(s));eq(s.player.hp,4987);eq(s.phase,'victory');eq(s.player.statuses.weak,nil)
 eq(s.aiRng.counter,ai);eq(countEvents(s,'damage',e.id),1)
end)
test('Minion flags suppress Feed growth while leader remains a legal fatal reward target',function()
 for _,id in ipairs({'snake_dagger','reptomancer'})do
  local s=battle(nil,'1',nil,nil,{'feed'});local e=actor(s,id);local target
  for i,a in ipairs(s.enemies)do if a==e then target=i end end
  e.hp=1;local max=s.player.maxHp;assert(C.play(s,s.hand[1].uid,target));eq(e.hp,0)
  eq(s.player.maxHp,max+(id=='reptomancer'and 3 or 0))
 end
end)
test('both combat transactions restore actors slots source streams and events on summon failure',function()
 for _,advanced in ipairs({false,true})do
  local data=advanced and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle(nil,'1',data);local leader=s.enemies[2];local slots,enemies,rng=leader.reptomancerSlots,s.enemies,s.aiRng
  local before=C.copy(s);local old=C.summonEnemies;local fired=false
  C.summonEnemies=function(...)old(...);fired=true;error('POST_REPTOMANCER_SUMMON_FAILURE')end
  local ok=pcall(C.endTurn,s);C.summonEnemies=old
  assert(not ok and fired);same(s,before);eq(s.enemies,enemies);eq(s.enemies[2],leader);eq(leader.reptomancerSlots,slots);eq(s.aiRng,rng)
 end
end)
test('both transactions restore self-loss and leader cleanup failures without duplicate callbacks',function()
 for _,advanced in ipairs({false,true})do for _,kind in ipairs({'dagger','leader'})do
  local data=advanced and require('abyss_character_profiles').prepare(D,'ironclad')or D
  local s=battle(kind=='dagger'and {'snake_dagger','cultist'}or nil,'1',data,nil,{'bludgeon'})
  local e=kind=='dagger'and s.enemies[1]or s.enemies[2]
  if kind=='dagger'then force(e,'explode')else e.hp=1 end
  local before=C.copy(s);local key=kind=='dagger'and 'sacrificeDagger'or 'suicideReptomancerMinion'
  local old=A[key];local fired=false;A[key]=function(...)old(...);fired=true;error('POST_REPTOMANCER_DEATH_FAILURE')end
  local ok
  if kind=='dagger'then ok=pcall(C.endTurn,s)else ok=pcall(C.play,s,s.hand[1].uid,2)end
  A[key]=old;assert(not ok and fired);same(s,before);eq(s.enemies[kind=='dagger'and 1 or 2],e)
 end end
end)
print('REPTOMANCER '..count..' groups; '..failed..' failed');assert(failed==0)
