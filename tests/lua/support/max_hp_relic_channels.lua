local F=dofile('tests/lua/support/max_hp_relics.lua');local Shop=require('abyss_shop');local H=require('abyss_relic_hooks')
local function expectedHealth(r,case)
 local gain=case.id=='pear'and 10 or case.id=='mango'and 14 or 7
 F.eq(r.maxHp,case.startingMaximum+gain);F.eq(r.hp,case.id=='lees_waffle'and case.startingMaximum+gain or 30+gain)
end
local function lateFailure(r,command)
 local original=H.onEquip;local reached=false
 H.onEquip=function(staged,id,...)original(staged,id,...);reached=true;error('LATE_CHANNEL_MAX_HP_FAILURE')end
 local called,why=pcall(function()F.snapshotFailure(r,command)end);H.onEquip=original
 assert(called,tostring(why));assert(reached)
end
return function(character)
 local count=0
 for _,case in ipairs(F.vectors.channels)do if case.character==character then
  local r=F.new(case);local rng=F.S.snapshot(r.relicPool.rng);local offer,command,frame
  if case.channel=='shop'then
   local public=F.C.copy(r);local stock=Shop.prepare(r,1);F.same(r,public)
   for i,expected in ipairs(case.offers)do F.eq(stock.relics[i].sourceId,expected.sourceId);F.eq(stock.relics[i].price,expected.price);F.same(stock.relics[i].sourceTrace,expected.trace)end
   F.same(stock.relicPool.queues,case.afterQueues);offer=stock.relics[case.slot];assert(not offer.unavailable)
   local missing=F.C.copy(r);F.remove(missing,case.sourceId);local control=Shop.prepare(missing,1)
   F.eq(control.relics[case.slot].sourceId,case.sourceId);assert(control.relics[case.slot].unavailable)
   F.same(control.relicPool,stock.relicPool);F.same(control.shopRng,stock.shopRng);F.eq(control.relics[case.slot].price,offer.price)
   F.enter(r,'shop');r.gold=1000;F.eq(r.nodeFlow.relics[case.slot].sourceId,case.sourceId)
   frame=F.C.copy(r.nodeFlow);local oldFrame=r.nodeFlow
   command=function()return F.N.buyRelic(r,case.id)end
   lateFailure(r,command);assert(command());expectedHealth(r,case)
   F.same(oldFrame,frame);F.eq(r.gold,1000-offer.price);F.same(r.relicPool.queues,case.afterQueues)
  elseif case.channel=='chest'then
   F.enter(r,'treasure');F.same(r.relicPool.queues,case.queues);F.same(F.S.snapshot(r.relicPool.rng),rng)
   F.eq(r.nodeFlow.chest.kindRoll,case.kindRoll);F.eq(r.nodeFlow.chest.rewardRoll,case.rewardRoll)
   assert(F.N.openTreasure(r));F.eq(r.nodeFlow.reward.relicSourceId,case.sourceId)
   F.same(F.S.snapshot(r.treasureRng),case.afterRng);F.eq(r.nodeFlow.reward.gold or 0,case.gold)
   local slot;for _,item in ipairs(r.nodeFlow.reward.items)do if item.kind=='relic'then slot=item.slot;break end end
   offer=assert(F.N.treasureRewardSource(r,slot));frame=F.C.copy(offer)
   command=function()return F.N.claimTreasureReward(r,offer)end
   lateFailure(r,command);assert(command());expectedHealth(r,case);F.same(offer,frame)
   local expected=F.C.copy(case.queues);table.remove(expected[case.tier],1);F.same(r.relicPool.queues,expected)
  else
   assert(F.R.startRoomCombat(r,'elite'))
   for _,enemy in ipairs(r.combat.enemies)do F.C.damage(r.combat,r.combat.player,enemy,20000,true)end
   assert(F.R.finishCombat(r));r.hp=30 -- Controlled injury; not a claimed natural deck victory.
   offer=r.rewards.relics[1];F.eq(offer.sourceId,case.sourceId);assert(not offer.unavailable)
   frame=F.C.copy(offer);local oldOffer=offer
   F.same(F.S.snapshot(r.relicPool.rng),case.afterRng)
   command=function()return F.R.claimRelicReward(r,1)end
   lateFailure(r,command);assert(command());expectedHealth(r,case);F.same(oldOffer,frame)
   local expected=F.C.copy(case.queues);table.remove(expected[case.tier],1);F.same(r.relicPool.queues,expected)
  end
  F.eq(r.relics[#r.relics],case.id);F.snapshotFailure(r,command)
  if case.channel~='elite'then F.same(F.S.snapshot(r.relicPool.rng),rng)end
  count=count+1;print('PASS '..character..' '..case.channel..' '..case.sourceId..' seed '..case.seed)
 end end
 F.eq(count,7);print('MAX_HP_RELICS_CHANNELS_PASS '..character..' '..count)
end
