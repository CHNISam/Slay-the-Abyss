package.path='src/lua/?.lua;'..package.path
local P=require('abyss_relic_pool')
local function same(a,b)
 assert(type(a)==type(b),'type mismatch')
 if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'extra key '..tostring(k)) end
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local tiers={'common','uncommon','rare','shop','boss'}
local tiny={sourceCommit='test',queues={common={'a','b','c'},uncommon={'u','v'},rare={'r'},shop={'s'},boss={'x','y'}},spawnGates={}}
local function state(queues)
 local s=P.new('0',tiny)
 local snap=P.snapshot(s);snap.queues=queues or tiny.queues
 return P.restore(snap,tiny)
end
local empty={common={},uncommon={},rare={},shop={},boss={}}
test('front rejection spends candidate then uses same-tier tail and source IDs',function()
 local s=state();local calls={};local id,trace=P.draw(s,'common',{canSpawn=function(id)calls[#calls+1]=id;return id~='a' end})
 assert(id=='c');same(s.queues.common,{'b'});same(calls,{'a','c'});assert(#trace==2)
end)
test('tail requests, boss head, tier exhaustion and sentinel resolution',function()
 local s=state();assert(P.draw(s,'common',nil,true)=='c');assert(P.draw(s,'boss',nil,true)=='x')
 local q={common={},uncommon={'u','v'},rare={'r'},shop={},boss={}}
 s=state(q);assert(P.draw(s,'shop',nil,true)=='u');assert(P.draw(s,'common')=='v');assert(P.draw(s,'common')=='r')
 assert(P.draw(s,'common')=='Circlet');local id,trace=P.draw(s,'boss');assert(id=='Circlet');assert(trace[1].id=='Red Circlet')
end)
test('callback failure preserves original queue tables values and RNG',function()
 local s=state();local before=P.snapshot(s);local q=s.queues;local c=q.common
 assert(not pcall(P.draw,s,'common',{canSpawn=function()error('adapter unavailable')end}))
 same(P.snapshot(s),before);assert(s.queues==q and s.queues.common==c)
end)
test('invalid requests and snapshots reject before mutation',function()
 local s=state();local before=P.snapshot(s)
 assert(not pcall(P.draw,s,'special'));same(P.snapshot(s),before)
 local bad=P.snapshot(s);bad.queues.common={'missing'};assert(not pcall(P.restore,bad,tiny))
 bad=P.snapshot(s);bad.queues.common={'a','a'};assert(not pcall(P.restore,bad,tiny))
 bad=P.snapshot(s);bad.queues.common={[2]='a'};assert(not pcall(P.restore,bad,tiny))
 bad=P.snapshot(s);bad.extra=true;assert(not pcall(P.restore,bad,tiny))
 local detached=P.snapshot(s);detached.queues.common[1]='c';same(P.snapshot(s),before)
end)
test('rarity boundaries use complete original partitions',function()
 local expected={elite={50,33,17},event={50,33,17},shovel={50,33,17},shop={48,34,18},['small-chest']={75,25,0},['medium-chest']={35,50,15},['large-chest']={0,75,25}}
 for channel,want in pairs(expected)do
  local n={common=0,uncommon=0,rare=0}
  for roll=0,99 do local tier=P.rareness(channel,roll);n[tier]=n[tier]+1 end
  same({n.common,n.uncommon,n.rare},want)
 end
 assert(not pcall(P.rareness,'shop',100));assert(not pcall(P.rareness,'unknown',1))
 local s=state();local n=s.rng.counter;P.rollTier(s,'event');assert(s.rng.counter==n+1)
end)
if ABYSS_RELIC_FIXTURE then
 local f=ABYSS_RELIC_FIXTURE
 test('all 12 complete source-order initialization vectors and locked/owned filters',function()
  for _,sample in ipairs(f.cases)do
   local s=P.new(sample.seed,f.catalog,{locked=sample.locked,removedAfterShuffle=sample.removedAfterShuffle})
   same(s.queues,sample.queues);assert(s.rng.counter==5)
   same(P.snapshot(P.restore(P.snapshot(s),f.catalog)),P.snapshot(s))
  end
 end)
 test('screenless filters consume all forbidden candidates without shifting RNG',function()
  local s=P.new('0',f.catalog);local snap=P.snapshot(s)
  snap.queues.common={'Whetstone','Boot'};snap.queues.uncommon={'Bottled Flame','Bottled Lightning','Bottled Tornado','Sundial'}
  s=P.restore(snap,f.catalog);local n=s.rng.counter
  local context={canSpawn=function()return true end}
  local id,trace=P.screenless(s,'common',context);assert(id=='Boot' and #trace==2)
  id,trace=P.screenless(s,'uncommon',context);assert(id=='Sundial' and #trace==4);assert(s.rng.counter==n)
 end)
 test('default source spawn gates use room, cards, starter and campfire inventory',function()
  local s=P.new('0',f.catalog);local snap=P.snapshot(s)
  snap.queues.common={'Smiling Mask','Boot'};s=P.restore(snap,f.catalog)
  assert(P.draw(s,'common',{room='shop'})=='Boot')
  snap.queues.boss={'Black Blood','Busted Crown'};s=P.restore(snap,f.catalog)
  assert(P.draw(s,'boss',{owned={}})=='Busted Crown')
  s=P.restore(snap,f.catalog);assert(P.draw(s,'boss',{owned={'Burning Blood'}})=='Black Blood')
  snap.queues.uncommon={'Bottled Flame','Sundial'};s=P.restore(snap,f.catalog)
  assert(P.draw(s,'uncommon',{deck={{type='ATTACK',rarity='BASIC'}}})=='Sundial')
  snap.queues.rare={'Girya','Shovel','Peace Pipe','Old Coin'};s=P.restore(snap,f.catalog)
  assert(P.draw(s,'rare',{owned={'Girya','Shovel'}})=='Old Coin')
 end)
 test('360 shared-queue draws match independent JS oracle through exhaustion',function()
  for _,track in ipairs(f.tracks)do
   local s=P.new(track.seed,f.catalog)
   local context={canSpawn=function(id)
    for _,refused in ipairs(track.refused)do if refused==id then return false end end
    return true
   end}
   for _,step in ipairs(track.steps)do
    local id,trace,requested
    if step.screenless then id,trace,requested=P.screenless(s,step.tier,context)
    else id,trace,requested=P.draw(s,step.tier,context,step.fromTail)end
    assert(id==step.result.resolvedId and requested==step.result.requestedId)
    same(trace,step.result.consumed);same(s.queues,step.queues);assert(s.rng.counter==5)
   end
  end
 end)
end
print('LUA_RELIC_POOL_PASS '..count)
