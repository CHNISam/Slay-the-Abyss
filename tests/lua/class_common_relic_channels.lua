package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,A,N,Map=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_nodes'),require('abyss_map')
local Rewards,Pool,S,Shop=require('abyss_relic_rewards'),require('abyss_relic_pool'),require('abyss_sts_random'),require('abyss_shop')
local D=require('abyss_data')
local vectors=dofile('tests/fixtures/class-common-relic-queue-vectors.lua')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 assert(type(a)==type(b),'type differs');if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra key '..tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function new(case)
 local r=R.new(D,case.seed,{experimental=true,character=case.character})
 same(r.relicPool.queues,case.queues);same(S.snapshot(r.relicPool.rng),case.afterInitialization)
 return r
end
local function removeDefinition(run,sourceId)
 run.data=C.copy(run.data)
 for i,d in ipairs(run.data.relics.relics)do if d.sourceId==sourceId then table.remove(run.data.relics.relics,i);return end end
 error('definition not found')
end

test('natural full queue heads resolve targets without removing or rerolling any other identity',function()
 for _,case in ipairs(vectors)do if case.seed=='113'then
  local r=new(case);local pool=Pool.restore(Pool.snapshot(r.relicPool),r.relicPool.catalog);local before=S.snapshot(pool.rng)
  local item=Rewards.draw(r,pool,'common');eq(item.sourceId,case.sourceId);assert(not item.unavailable);eq(#item.trace,1)
  local expected=C.copy(case.queues);table.remove(expected.common,1);same(pool.queues,expected);same(S.snapshot(pool.rng),before)
  same(r.relicPool.queues,case.queues)
  assert(R.obtainRelic(r,item.sourceId));eq(r.relics[#r.relics],item.id)
 end end
end)
test('formal elite victory and public claim preserve the full source queue and once-only owner',function()
 for _,case in ipairs(vectors)do if case.seed=='113'then
  local r=new(case);assert(R.startRoomCombat(r,'elite'))
  for _,enemy in ipairs(r.combat.enemies)do C.damage(r.combat,r.combat.player,enemy,20000,true)end
  -- This is a controlled terminal state through actual damage, not a claim of
  -- a natural deck/route win. Reward creation and claiming use the public API.
  assert(R.finishCombat(r));eq(r.phase,'reward');local offer=r.rewards.relics[1]
  eq(offer.sourceId,case.sourceId);assert(not offer.unavailable);eq(#offer.trace,1)
  local expected=C.copy(case.queues);table.remove(expected.common,1);same(r.relicPool.queues,expected)
  same(S.snapshot(r.relicPool.rng),case.afterEliteRoll)
  local rng=S.snapshot(r.relicPool.rng);assert(R.claimRelicReward(r,1));eq(r.relics[#r.relics],offer.id)
  local before=C.copy(r);assert(not R.claimRelicReward(r,1));same(r,before);same(S.snapshot(r.relicPool.rng),rng)
 end end
end)
test('formal unopened chest then public claim grants each natural queue-head identity once',function()
 for _,case in ipairs(vectors)do if case.seed=='113'then
  local r=new(case);local map=Map.generate(D,case.seed);local first=Map.available(map)[1]
  for _,node in ipairs(map.nodes)do if node.id==first.id then node.type='treasure';node.roomKind=nil end end
  assert(N.enter(r,map,first.id));same(r.relicPool.queues,case.queues)
  eq(r.nodeFlow.chest.kindRoll,case.chestKindRoll);eq(r.nodeFlow.chest.rewardRoll,case.chestRewardRoll)
  assert(N.openTreasure(r));local item
  for _,offer in ipairs(r.nodeFlow.reward.items)do if offer.kind=='relic'then item=offer end end
  assert(item and item.available);eq(item.sourceId,case.sourceId);eq(#item.trace,1)
  local expected=C.copy(case.queues);table.remove(expected.common,1);same(r.relicPool.queues,expected)
  same(S.snapshot(r.relicPool.rng),case.afterInitialization)
  local token=assert(N.treasureRewardSource(r,item.slot));assert(N.claimTreasureReward(r,token));eq(r.relics[#r.relics],item.id)
  local before=C.copy(r);assert(not N.claimTreasureReward(r,token));same(r,before)
 end end
end)
test('formal shop uses the natural full-queue tail; purchase is transactional and does not run equip effects',function()
 for _,case in ipairs(vectors)do if case.seed=='17'then
  local r=new(case);local before=C.copy(r);local stock=Shop.prepare(r,1);same(r,before)
  local offer=stock.relics[1];eq(offer.sourceId,case.sourceId);assert(not offer.unavailable);eq(#offer.sourceTrace,1)
  assert(offer.sourceTrace[1]['end']);eq(stock.relicPool.queues.common[#stock.relicPool.queues.common],case.queues.common[#case.queues.common-1])
  local missing=C.copy(r);removeDefinition(missing,case.sourceId);local control=Shop.prepare(missing,1)
  eq(control.relics[1].sourceId,case.sourceId);assert(control.relics[1].unavailable);eq(control.relics[1].price,offer.price)
  same(control.relicPool,stock.relicPool);same(control.shopRng,stock.shopRng)
  r.gold=1000;r.phase='node';r.nodeFlow=stock;r.nodeFlow.type='shop';r.nodeFlow.complete=false;r.relicPool=stock.relicPool
  local gold=r.gold;assert(N.buyRelic(r,offer.id));eq(r.gold,gold-offer.price);eq(r.relics[#r.relics],offer.id);assert(r.nodeFlow.relics[1].sold)
  local obtained=C.copy(r);assert(not N.buyRelic(r,offer.id));same(r,obtained)
 end end
end)
test('unimplemented source identities remain unavailable with no alternate draw or queue entropy',function()
 local r=R.new(D,'113',{experimental=true,character='silent'})
 -- Production Sundial now exists. Consume the original sequence, obtain the
 -- selected identity through Run, then verify its third real shuffle reward.
 local production=Pool.restore(Pool.snapshot(r.relicPool),r.relicPool.catalog)
 local selected
 for _=1,#production.queues.uncommon do
  local item=Rewards.draw(r,production,'uncommon')
  if item.sourceId=='Sundial'then selected=item;break end
 end
 assert(selected and not selected.unavailable)
 assert(R.obtainRelic(r,selected.sourceId));assert(R.startRoomCombat(r,'normal'))
 local state=r.combat;local energy=state.energy
 state.draw,state.discard={},{}
 for i=1,3 do
  C.shuffleDiscardIntoDraw(state);require('abyss_card_actions').drain(C,state)
  eq(state.energy,energy+(i==3 and 2 or 0))
 end
 eq(state.relicCounters.sundial,0)
 -- The missing-definition oracle remains deliberate and independent of how
 -- much production content is implemented; retain every refusal/RNG check.
 r=R.new(D,'113',{experimental=true,character='silent'});removeDefinition(r,'Sundial')
 local pool=Pool.restore(Pool.snapshot(r.relicPool),r.relicPool.catalog)
 -- Move no queues: use the real sequence until the removed identity appears.
 local before=S.snapshot(pool.rng);local found=false
 for _=1,#pool.queues.uncommon do
  local item=Rewards.draw(r,pool,'uncommon')
  if item.sourceId=='Sundial'then assert(item.unavailable and #item.trace==1);found=true;break end
 end
 assert(found);same(S.snapshot(pool.rng),before)
 local case=vectors[2];r=new(case);removeDefinition(r,case.sourceId);r.encounterTier='elite'
 local prepared=assert(Rewards.elite(r));eq(prepared.items[1].sourceId,case.sourceId);assert(prepared.items[1].unavailable)
 r.relicPool=prepared.relicPool;r.phase='reward';r.rewards={relics=prepared.items}
 local snapshot=C.copy(r);local owner=r.relicPool;local ok,why=R.claimRelicReward(r,1)
 assert(not ok and why=='relic_content_unavailable');same(r,snapshot);eq(r.relicPool,owner)
end)
assert(failed==0,tostring(failed)..' class common channel cases failed')
print('CLASS_COMMON_RELIC_CHANNELS_PASS '..count)
