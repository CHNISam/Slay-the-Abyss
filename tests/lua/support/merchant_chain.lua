-- Controlled funding/navigation/relic prerequisites; actual source queues,
-- public Nodes.enter and transactional buy interfaces, no fixture stock edits.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,N,M,C,D=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_data')
local R,Pool,E=require('abyss_sts_random'),require('abyss_relic_pool'),require('abyss_external_random')
local Rewards=require('abyss_relic_rewards')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
local function shelf(flow)
 local out={cards={},relics={},potions={}}
 for _,k in ipairs({'cards','relics','potions'})do
  for _,v in ipairs(flow[k])do
   local o={sourceId=v.sourceCardId or v.sourceId,rarity=v.rarity,price=v.price}
   if k=='cards'then o.type=v.type:upper();o.sale=v.sale==true end
   if k=='relics'then o.rejected={};for _,r in ipairs(v.sourceRejected or {})do o.rejected[#o.rejected+1]=r.sourceId end end
   out[k][#out[k]+1]=o
  end
 end
 return out
end
return function(f,initialQueues,externalWords)
 local run,map=Run.new(D,f.seed),M.generate(D,f.seed)
 run.gold=10000
 if f.courier then assert(Run.obtainRelic(run,'courier'))end
 if f.membership then assert(Run.obtainRelic(run,'membership_card'))end
 run.relicPool=Pool.new(f.relicSeed,run.data.relicSource)
 same(run.relicPool.queues,initialQueues,'independent host-Java initial relic queues')
 E.setReplayState(externalWords)
 local shop;local byId={};for _,node in ipairs(map.nodes)do byId[node.id]=node end
 local function reachesShop(node)
  if node.type=='shop'then return true end
  for _,id in ipairs(node.nextIds)do if reachesShop(byId[id])then return true end end
  return false
 end
 while not shop do
  local selected
  for _,node in ipairs(M.available(map))do if reachesShop(node)then selected=node;break end end
  assert(selected,'generated map has no reachable shop')
  if selected.type=='shop'then shop=selected else assert(M.choose(map,selected.id))end
 end
 local untouched={}
 local relicRng=R.snapshot(run.relicPool.rng)
 local traces={merchant={},card={},potion={}};local merchantOwners={}
 local raw={int=R.randomInt,between=R.randomIntBetween,float=R.randomFloat,floatBetween=R.randomFloatBetween,relic=Rewards.shop}
 Rewards.shop=function(r,p,merchant,...)merchantOwners[merchant]=true;return raw.relic(r,p,merchant,...)end
 local function record(owner,name,kind,lo,hi,fn,...)
  local before=R.snapshot(owner);local value=fn(owner,...)
  local rows=traces[name];rows[#rows+1]={kind=kind,minimum=lo,maximum=hi,value=value,before=before,after=R.snapshot(owner)}
  return value
 end
 R.randomInt=function(owner,hi,...)return record(owner,merchantOwners[owner]and'merchant'or'card','int',0,hi,raw.int,hi,...)end
 R.randomIntBetween=function(owner,lo,hi,...)return record(owner,'potion','int',lo,hi,raw.between,lo,hi,...)end
 R.randomFloatBetween=function(owner,lo,hi,...)merchantOwners[owner]=true;return record(owner,'merchant','floatBetween',lo,hi,raw.floatBetween,lo,hi,...)end
 R.randomFloat=function(owner,...)merchantOwners[owner]=true;return record(owner,'merchant','float',0,1,raw.float,...)end
 local function check(i)
  local wanted=f.steps[i]
  for name,rows in pairs(traces)do
   assert(#rows==wanted.traceCounts[name],wanted.label..' '..name..' exact draw count')
   for j,row in ipairs(rows)do same(row,f.trace[name][j],wanted.label..' '..name..' draw '..j)end
  end
  same(shelf(run.nodeFlow),{cards=wanted.cards,relics=wanted.relics,potions=wanted.potions},wanted.label..' full shelf')
  same(R.snapshot(run.shopRng.merchant),wanted.states.merchant,wanted.label..' merchant final')
  same(R.snapshot(run.cardRng),wanted.states.card,wanted.label..' card identity final')
  same(R.snapshot(run.shopRng.potion),wanted.states.potion,wanted.label..' potion identity final')
  same(run.relicPool.queues,wanted.queues,wanted.label..' queue consumption')
  same(E.snapshot().words,wanted.externalWords,wanted.label..' separate MathUtils identity state')
  assert(run.cardRarityOffset==5,'shop does not update reward blizzard offset')
  same(R.snapshot(run.relicPool.rng),relicRng,'relic queue draw does not spend its shuffle stream')
  for key,state in pairs(untouched)do same(R.snapshot(run[key]),state,'unrelated '..key)end

 end
 assert(N.enter(run,map,shop.id))
 for _,key in ipairs({'eventRng','miscRng','treasureRng'})do if run[key]then untouched[key]=R.snapshot(run[key])end end
 check(1)
 local snapshot=C.copy(run);N.view(run,map);same(run,snapshot,'read-only view')
 -- Rejected payments and slot references must not draw/reprice.
 run.gold=0;snapshot=C.copy(run);assert(not N.buyCardSlot(run,1));same(run,snapshot,'unaffordable atomic')
 assert(not N.buyCardSlot(run,0));same(run,snapshot,'invalid slot atomic');run.gold=10000;check(1)
 local finalIndex=1
 if f.membershipPurchase then
  local offer=run.nodeFlow.relics[3];assert(offer.sourceId=='Membership Card')
  local gold=run.gold;assert(N.buyRelic(run,offer.id));assert(run.gold==gold-offer.price,'membership paid original price')
  check(2);finalIndex=2
  local before=C.copy(run);assert(not N.buyRelic(run,offer.id));same(run,before,'membership duplicate atomic')
 end
 if f.courier then
  -- Force a real post-draw restock failure, after payment/master grant have
  -- staged. Rejected transaction must publish none of these private changes.
  local rollbackBefore,entropy,savedTraces=C.copy(run),E.snapshot(),C.copy(traces)
  local float=R.randomFloatBetween
  R.randomFloatBetween=function(...)
   float(...);error('controlled restock failure after merchant draw')
  end
  local accepted,reason=N.buyCardSlot(run,1)
  R.randomFloatBetween=float
  assert(not accepted and reason=='shop_content_unavailable','restock fault rejected')
  assert(#traces.merchant==#savedTraces.merchant+1,'failure really consumed a staged merchant draw')
  assert(#traces.card==#savedTraces.card+1,'failure really rolled replacement rarity')
  same(run,rollbackBefore,'post-draw failure full Run rollback');same(E.snapshot(),entropy,'uncommitted external identity rollback')
  traces=savedTraces;check(1)
  local function buy(i,fn)
   local before=run.gold;local flow=run.nodeFlow;local price=i==2 and flow.cards[1].price or i==3 and flow.cards[6].price or i==4 and flow.potions[1].price or flow.relics[1].price
   assert(fn());assert(run.gold==before-price,'actual payment');check(i)
  end
  local count,uid,id=#run.deck,run.nextDeckUid,run.nodeFlow.cards[1].id
  buy(2,function()return N.buyCardSlot(run,1)end)
  assert(#run.deck==count+1 and run.deck[#run.deck].cardId==id and run.deck[#run.deck].uid==uid,'actual colored master identity')
  uid,id=run.nextDeckUid,run.nodeFlow.cards[6].id
  buy(3,function()return N.buyCardSlot(run,6)end)
  assert(#run.deck==count+2 and run.deck[#run.deck].cardId==id and run.deck[#run.deck].uid==uid,'actual colorless master identity')
  id=run.nodeFlow.potions[1].id;buy(4,function()return N.buyPotion(run,1)end)
  assert(Run.potionCount(run)==1 and run.potions[1]==id,'actual purchased potion identity')
  id=run.nodeFlow.relics[1].id;buy(5,function()return N.buyRelic(run,id)end)
  local owned=false;for _,held in ipairs(run.relics)do if held==id then owned=true end end;assert(owned,'actual purchased relic identity')
  local before=C.copy(run);assert(not N.buyRelic(run,id));same(run,before,'duplicate owned identity atomic');check(5)
 else
  local offer,gold,uid=run.nodeFlow.cards[1],run.gold,run.nextDeckUid
  assert(N.buyCardSlot(run,1));assert(run.gold==gold-offer.price)
  assert(run.deck[#run.deck].cardId==offer.id and run.deck[#run.deck].uid==uid,'ordinary exact master grant')
  assert(run.nodeFlow.cards[1].sold);local before=C.copy(run)
  assert(not N.buyCardSlot(run,1));same(run,before,'sold duplicate atomic')
  check(finalIndex) -- ordinary sales never draw replacements from any identity stream
 end
 R.randomInt,R.randomIntBetween,R.randomFloat,R.randomFloatBetween,Rewards.shop=raw.int,raw.between,raw.float,raw.floatBetween,raw.relic
 print('MERCHANT_CHAIN_PASS '..f.caseId)
end
