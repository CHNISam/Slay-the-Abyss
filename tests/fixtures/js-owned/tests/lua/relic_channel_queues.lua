package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Rewards,P,R=require('abyss_relic_rewards'),require('abyss_relic_pool'),require('abyss_sts_random')
local C,Run,Shop=require('abyss_combat'),require('abyss_run'),require('abyss_shop')
local Data=require('abyss_data')
local count=0
local function same(a,b)
 assert(type(a)==type(b),'type mismatch')
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok relic channels '..count..' - '..name)end
local catalog={sourceCommit='test',queues={common={'Anchor','MawBank'},uncommon={'Sundial','The Courier'},rare={'r','Old Coin'},shop={'s'},boss={'b'}},spawnGates={}}
local function owner(seed)
 local run=Run.new(Data,seed or '0');local pool=P.new(seed or '0',catalog)
 local snap=P.snapshot(pool);snap.queues=C.copy(catalog.queues);run.relicPool=P.restore(snap,catalog)
 return run
end
test('merchant selects source tier and queue tail without an identity RNG draw',function()
 local run=owner('42');local pool=P.restore(P.snapshot(run.relicPool),catalog);local merchant=R.fromSeed('42')
 local offer=Rewards.shop(run,pool,merchant,1)
 assert(offer.sourceId=='MawBank' and offer.requestedTier=='common' and merchant.counter==1)
 assert(#pool.queues.common==1 and offer.trace[1]['end']==true)
 local third=Rewards.shop(run,pool,merchant,3)
 assert(third.sourceId=='s' and merchant.counter==1)
end)
test('Courier spends forbidden candidates and rerolls each tier instead of prefiltering',function()
 local run=owner('1');local pool=P.restore(P.snapshot(run.relicPool),catalog);local merchant=R.fromSeed('1')
 -- Independent signed64 primitive sequence for seed1: 55,5,88,32.
 local offer=Rewards.shop(run,pool,merchant,1,{restock=true})
 assert(offer.sourceId=='Anchor' and merchant.counter==4 and #offer.rejected==3)
 assert(offer.rejected[1].sourceId=='The Courier' and offer.rejected[1].tier=='uncommon')
 assert(offer.rejected[2].sourceId=='MawBank' and offer.rejected[2].tier=='common')
 assert(offer.rejected[3].sourceId=='Old Coin' and offer.rejected[3].tier=='rare')
 assert(#pool.queues.common==0 and #pool.queues.uncommon==1 and #pool.queues.rare==1)
end)
test('elite front and Black Star extra rolls consume the common relic RNG and pool',function()
 local run=owner('0');run.encounterTier='elite';run.relics={'black_star'}
 local before=C.copy(run);local prepared=assert(Rewards.elite(run))
 same(run,before)
 -- seed0 after the five initialization randomLongs: inclusive 0..99 =68,42.
 assert(#prepared.items==2 and prepared.items[1].sourceId=='Sundial' and prepared.items[2].sourceId=='Anchor')
 assert(prepared.relicPool.rng.counter==run.relicPool.rng.counter+2)
 assert(prepared.items[1].trace[1]['end']==false and prepared.items[2].trace[1]['end']==false)
 assert(#prepared.relicPool.queues.uncommon==1 and #prepared.relicPool.queues.common==1)
 run.encounterTier='normal';same(Rewards.elite(run),{items={}})
 run.encounterTier='boss';same(Rewards.elite(run),{items={}})
end)
test('Black Star noncamp rejection spends exact rare front candidates with no extra RNG',function()
 local cat=C.copy(catalog);cat.queues.rare={'Peace Pipe','Shovel','Girya','r'}
 local pool=P.new('0',cat);local snap=P.snapshot(pool);snap.queues=C.copy(cat.queues);pool=P.restore(snap,cat)
 local before=R.snapshot(pool.rng);local id,trace=P.noncamp(pool,'rare')
 assert(id=='r' and #trace==4 and #pool.queues.rare==0);same(R.snapshot(pool.rng),before)
end)
test('the complete formal shop keeps identity, price and RNG when definitions are missing',function()
 local run=Run.new(Data,'42');local before=C.copy(run);local stock=Shop.prepare(run,6)
 assert(stock.contentMode=='source-queues' and stock.relicPool)
 same(run,before)
 local without=C.copy(run);without.data=C.copy(run.data);without.data.relics.relics={}
 local missing=Shop.prepare(without,6)
 same(stock.relicPool,missing.relicPool);same(stock.shopRng,missing.shopRng)
 for slot,offer in ipairs(stock.relics)do
  assert(missing.relics[slot].sourceId==offer.sourceId and missing.relics[slot].price==offer.price)
  assert(missing.relics[slot].unavailable)
  assert(offer.sourceTrace[1]['end']==true)
 end
end)
test('formal elite victory publishes the shared queue reward and normal victory does not',function()
 for _,tier in ipairs({'elite','normal'})do
  local run=Run.new(Data,'42');assert(Run.startRoomCombat(run,tier))
  local before=P.snapshot(run.relicPool);local expected=assert(Rewards.elite(run))
  for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end -- explicit terminal fixture, no natural-win claim
  assert(Run.finishCombat(run));assert(run.phase=='reward')
  if tier=='elite' then
   same(run.rewards.relics,expected.items);same(P.snapshot(run.relicPool),P.snapshot(expected.relicPool))
  else assert(run.rewards.relics==nil);same(P.snapshot(run.relicPool),before)end
 end
end)
print('LUA_RELIC_CHANNEL_QUEUES_PASS '..count)
