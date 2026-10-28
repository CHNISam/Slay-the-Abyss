local N,Run,R,C,Data=require('abyss_neow'),require('abyss_run'),require('abyss_sts_random'),require('abyss_combat'),require('abyss_data')
local vectors=dofile('tests/fixtures/neow-offer-vectors.lua')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if type(a)~='table'then eq(a,b);return end
 eq(type(b),'table');for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local base=Run.new(Data,'42')
local function fixture(seed,bossCount)
 local r=C.copy(base,{[base.data]=base.data});r.runSeed=seed;r.phase='node'
 r.nodeFlow={type='event',event={id='neow'}}
 assert(N.prepare(r,r.nodeFlow.event,{bossCount=bossCount}));return r
end
local function choose(r,choice,uid)return Run.transaction(r,function(s)return N.choose(s,s.nodeFlow,choice,uid)end)end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS neow offers '..n..' '..name)end
test('missing or malformed history is explicit and cannot fabricate full rewards',function()
 for _,history in ipairs({false,{}, {bossCount=-1},{bossCount=.5},{bossCount='1'}})do
  local event={id='neow'};local ok,why=N.prepare(base,event,history);eq(ok,false);eq(why,'neow_history_unavailable');same(event,{id='neow'})
 end
 local ok,why=N.prepare(base,{},nil);eq(ok,false);eq(why,'neow_history_unavailable')
end)
test('mini blessings are source order with no Neow RNG or any global-stream consumption',function()
 for _,seed in ipairs({'0','1','42','9223372036854775807'})do
  local r=fixture(seed,0);local before=C.copy(r,{[r.data]=r.data})
  eq(N.options(r,r.nodeFlow.event)[1].choice,'continue');eq(r.nodeFlow.event.rewards,nil)
  assert(choose(r,'continue'));local e=r.nodeFlow.event
  eq(#e.rewards,2);eq(e.rewards[1].type,'THREE_ENEMY_KILL');eq(e.rewards[2].type,'TEN_PERCENT_HP_BONUS');eq(e.neowRng,nil)
  same(r.miscRng,before.miscRng);same(r.cardRng,before.cardRng);same(r.eventRng,before.eventRng);same(r.relicPool,before.relicPool)
  eq(#N.options(r,e),2)
 end
end)
test('all 128 independent integer oracle vectors preserve source categories, exclusions and five wrapper draws',function()
 eq(#vectors.cases,128);eq(vectors.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0')
 local seen={}
 for _,vector in ipairs(vectors.cases)do
  local r=fixture(vector.seed,1);local before=C.copy(r,{[r.data]=r.data});assert(choose(r,'continue'))
  local e=r.nodeFlow.event;eq(#e.rewards,4)
  for i,t in ipairs(vector.types)do eq(e.rewards[i].type,t);seen[t]=true end
  eq(e.rewards[3].drawback,vector.drawback);eq(e.rewards[1].drawback,'NONE');eq(e.rewards[2].drawback,'NONE');eq(e.rewards[4].drawback,'NONE')
  same(R.snapshot(e.neowRng),vector.after);eq(e.neowRng.counter,5)
  same(r.miscRng,before.miscRng);same(r.cardRng,before.cardRng);same(r.eventRng,before.eventRng);same(r.relicPool,before.relicPool)
  eq(#N.options(r,e),4)
  if vector.drawback=='CURSE'then assert(e.rewards[3].type~='REMOVE_TWO')end
  if vector.drawback=='NO_GOLD'then assert(e.rewards[3].type~='TWO_FIFTY_GOLD')end
  if vector.drawback=='TEN_PERCENT_HP_LOSS'then assert(e.rewards[3].type~='TWENTY_PERCENT_HP_BONUS')end
 end
 local total=0;for _ in pairs(seen)do total=total+1 end;eq(total,19)
end)
test('10 percent cache truncates Java float and 20 percent doubles cached value',function()
 for _,value in ipairs({{75,7},{72,7},{70,7},{80,8},{9,0},{99,9}})do
  local r=fixture('0',0);r.hp,r.maxHp=value[1],value[1]
  assert(N.prepare(r,r.nodeFlow.event,{bossCount=0}));assert(choose(r,'continue'));eq(r.nodeFlow.event.hpBonus,value[2])
  assert(choose(r,'reward_2'))
  eq(r.maxHp,value[1]+value[2]);eq(r.hp,value[1]+value[2]);eq(r.nodeFlow.event.stage,'neow_result')
 end
end)
test('intro and blessing UID/choice misuse refuse atomically and retained option views are detached',function()
 local r=fixture('42',1)
 for _,choice in ipairs({'leave','reward_1','skip'})do
  local before=C.copy(r,{[r.data]=r.data});local ok=choose(r,choice);eq(ok,false);same(r,before)
 end
 assert(choose(r,'continue'));local before=C.copy(r,{[r.data]=r.data})
 for _,choice in ipairs({'continue','reward_0','reward_5','reward_01','skip','leave'})do local ok=choose(r,choice);eq(ok,false);same(r,before)end
 local ok=choose(r,'reward_1',r.deck[1].uid);eq(ok,false);same(r,before)
 local rows=N.options(r,r.nodeFlow.event);rows[1].choice='reward_4';same(r,before)
end)
print('NEOW_OFFERS '..n..' passed')
