-- Seed/queue staging is an API fixture, not natural Act2 play or a PC RNG oracle.
local C,Run,Map,Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local Pool,R,Relics=require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_relic_pool')
local Hooks,Data=require('abyss_relic_hooks'),require('abyss_data')
local base=Run.new(Data,'42',{experimental=true,campaign=true})
base.act,base.floor=2,17;base.unknown.pools=Pool.new('full',false,2)
local baseMap=Map.generate(base.data,'42',2)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'missing '..tostring(k))end
end
local function snapshot(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(unentered)
 local r,m=snapshot(base),C.copy(baseMap);local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not unentered and 'addict' or nil end end
 if not unentered then assert(Nodes.enter(r,m,n.id))end
 return r,m,n.id
end
local function reject(r,choice,uid,expected)
 local before=snapshot(r);local deck,event,flow,pool=r.deck,r.nodeFlow.event,r.nodeFlow,r.relicPool
 local rng,queue,relics,counters=r.relicPool.rng,r.relicPool.queues.common,r.relics,r.relicCounters
 local ok,why=Nodes.chooseEvent(r,choice,uid);eq(ok,false);if expected then eq(why,expected)end
 same(r,before);eq(r.deck,deck);eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event);eq(r.relicPool,pool)
 eq(r.relicPool.rng,rng);eq(r.relicPool.queues.common,queue);eq(r.relics,relics);eq(r.relicCounters,counters)
end
local function frontRelics(r,tier,ids)
 local foundTier=false
 for n=0,31 do
  local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if Relics.rarity('event',R.randomInt(nextState,99))==tier then r.relicPool.rng=state;foundTier=true;break end
 end
 assert(foundTier,'bounded seeded tier input missing')
 local q=r.relicPool.queues[tier]
 for _,id in ipairs(ids)do
  local found=false
  for i,v in ipairs(q)do if v==id then table.remove(q,i);found=true;break end end
  assert(found,'missing staged source ID '..id)
 end
 for i=#ids,1,-1 do table.insert(q,1,ids[i])end
end
local function opening(id,tier)
 local r,m=fixture();frontRelics(r,tier or 'common',{id or 'Anchor'});return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS addict '..count..' '..name)end

test('Intro preserves buy85/steal/leave order, threshold and detached RNG-pure views',function()
 eq(Pool.contentId.Addict,'addict')
 for _,gold in ipairs({0,84,85,86})do
  local r,m=fixture();r.gold=gold;local before=snapshot(r);local v=Nodes.view(r,m).node.event
  eq(v.stage,'intro');eq(#v.options,3);eq(v.options[1].choice,'buy');eq(v.options[1].enabled,gold>=85)
  assert(v.options[1].title:find('85'));eq(v.options[2].choice,'steal');eq(v.options[2].enabled,true)
  eq(v.options[3].choice,'leave');v.stage='result';v.options[2].enabled=false;same(r,before)
 end
end)
test('Intro leave immediately opens map without result screen, RNG, rewards or resource changes',function()
 local r=fixture();local before=snapshot(r);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 same(r.deck,before.deck);same(r.relics,before.relics);same(r.relicPool,before.relicPool)
 same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 eq(r.gold,before.gold);eq(r.hp,before.hp);reject(r,'leave',nil,'no_pending_node')
end)
test('Buy at exact85 pays once, selects one source relic and leaves a separate result screen',function()
 local r,m=opening();r.gold=85;local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'buy'));eq(r.gold,0);eq(r.nodeFlow.event.obtainedRelicId,'anchor');eq(#r.relics,#before.relics+1)
 same(r.deck,before.deck);eq(r.nextDeckUid,before.nextDeckUid);same(r.miscRng,before.miscRng)
 eq(r.relicPool.rng.counter,before.relicPool.rng.counter+1);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 eq(#Nodes.view(r,m).node.event.options,1);eq(Nodes.view(r,m).node.event.options[1].choice,'leave')
 reject(r,'buy',nil,'invalid_event_choice');reject(r,'steal',nil,'invalid_event_choice')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');reject(r,'buy',nil,'no_pending_node')
end)
test('Disabled or stale insufficient-gold buy is refused without invoking selection',function()
 local r=opening();r.gold=84;reject(r,'buy',nil,'insufficient_gold');eq(r.nodeFlow.event.stage,'intro')
end)
test('Steal at zero gold grants existing Shame once with stable UID and one tier draw, no misc draw',function()
 local r=opening();r.gold=0;local before=snapshot(r);assert(Nodes.chooseEvent(r,'steal'))
 eq(r.gold,0);eq(r.deck[#r.deck].cardId,'shame');eq(r.deck[#r.deck].uid,before.nextDeckUid)
 eq(r.nodeFlow.event.obtainedCardUid,before.nextDeckUid);eq(r.nextDeckUid,before.nextDeckUid+1)
 eq(r.nodeFlow.event.curseBlocked,false);eq(r.nodeFlow.event.stage,'result');same(r.miscRng,before.miscRng)
 eq(r.relicPool.rng.counter,before.relicPool.rng.counter+1);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 reject(r,'steal',nil,'invalid_event_choice')
end)
test('Old Omamori blocks Shame before acquisition and never allocates a permanent UID',function()
 local r=opening();assert(Run.obtainRelic(r,'Omamori'));local before=snapshot(r);assert(Nodes.chooseEvent(r,'steal'))
 eq(r.relicCounters.omamori,1);eq(r.nodeFlow.event.curseBlocked,true);same(r.deck,before.deck)
 eq(r.nextDeckUid,before.nextDeckUid);eq(r.nodeFlow.event.obtainedCardUid,nil)
end)
test('New Omamori cannot retroactively block prepared Shame and retains both constructor charges',function()
 local r=opening('Omamori');local before=snapshot(r);assert(Nodes.chooseEvent(r,'steal'))
 eq(r.nodeFlow.event.obtainedRelicId,'omamori');eq(r.relicCounters.omamori,2)
 eq(r.deck[#r.deck].cardId,'shame');eq(r.nextDeckUid,before.nextDeckUid+1);eq(r.nodeFlow.event.curseBlocked,false)
end)
test('New Ceramic Fish receives delayed Shame obtain exactly once',function()
 local r=opening('CeramicFish');local gold=r.gold;assert(Nodes.chooseEvent(r,'steal'))
 eq(r.nodeFlow.event.obtainedRelicId,'ceramic_fish');eq(r.gold,gold+9);eq(r.deck[#r.deck].cardId,'shame')
 reject(r,'steal',nil,'invalid_event_choice')
end)
test('Old Fish gets delayed Shame but not an Omamori-blocked attempt',function()
 for _,blocked in ipairs({false,true})do
  local r=opening();assert(Run.obtainRelic(r,'CeramicFish'));if blocked then assert(Run.obtainRelic(r,'Omamori'))end
  local before=snapshot(r);assert(Nodes.chooseEvent(r,'steal'));eq(r.gold,before.gold+(blocked and 0 or 9))
  eq(#r.deck,#before.deck+(blocked and 0 or 1));eq(r.nodeFlow.event.curseBlocked,blocked)
 end
end)
test('New Fish receives nothing from old-Omamori blocked Shame',function()
 local r=opening('CeramicFish');assert(Run.obtainRelic(r,'Omamori'));local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'steal'));eq(r.gold,before.gold);same(r.deck,before.deck);eq(r.relicCounters.omamori,1)
end)
test('Buying Fish neither creates a curse nor card-gold; buy does not consume old protection',function()
 local r=opening('CeramicFish');assert(Run.obtainRelic(r,'Omamori'));local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'buy'));eq(r.gold,before.gold-85);same(r.deck,before.deck);eq(r.relicCounters.omamori,2)
end)
test('Source event payment does not disable Maw Bank',function()
 local r=opening();assert(Run.obtainRelic(r,'MawBank'));assert(Nodes.chooseEvent(r,'buy'));eq(r.relicCounters.maw_bank,0)
end)
test('Screenless Whetstone exclusion consumes source queue entries and only one tier draw',function()
 local r=opening();frontRelics(r,'common',{'Whetstone','War Paint'});local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'steal'));eq(r.nodeFlow.event.obtainedRelicId,'war_paint');eq(r.deck[#r.deck].cardId,'shame')
 eq(#r.nodeFlow.event.relicOffer.trace,2);eq(r.nodeFlow.event.relicOffer.trace[1].id,'Whetstone')
 eq(r.nodeFlow.event.relicOffer.trace[2].id,'War Paint');eq(#r.relicPool.queues.common,#before.relicPool.queues.common-2)
 eq(r.relicPool.rng.counter,before.relicPool.rng.counter+1);eq(r.miscRng.counter,before.miscRng.counter+1)
end)
test('Unsupported selected uncommon and rare fail closed without reroll, payment or protection spend',function()
 for _,tier in ipairs({'uncommon','rare'})do
  for _,choice in ipairs({'buy','steal'})do
   local r=opening(tier=='uncommon' and 'Darkstone Periapt' or 'Bird Faced Urn',tier)
   -- This negative remains valid in separately composed dependency trees.
   r.data=C.copy(r.data)
   for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='darkstone_periapt' then table.remove(r.data.relics.relics,i)end end
   assert(Run.obtainRelic(r,'Omamori'));reject(r,choice,nil,'relic_content_unavailable');eq(r.relicCounters.omamori,2)
   eq(r.nodeFlow.event.stage,'intro');eq(r.nodeFlow.event.relicOffer,nil)
  end
 end
end)
test('Missing Shame rolls back prepared tier/queue without taking relic or spending old protection',function()
 local r=opening();r.data=C.copy(r.data)
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id=='shame' then table.remove(r.data.cards.cards,i)end end
 reject(r,'steal',nil,'card_content_unavailable')
end)
test('Invalid permanent UID rolls back new Fish, delayed gold, queue and tier RNG',function()
 local r=opening('CeramicFish');r.nextDeckUid=r.deck[1].uid;reject(r,'steal',nil,'invalid_deck_uid')
end)
test('Equip failure after Strawberry health/RNG mutations rolls back buy cost and recovers once',function()
 local r=opening('Strawberry');local original=Hooks.onEquip;local before=snapshot(r)
 Hooks.onEquip=function(staged,id,api)original(staged,id,api);R.randomInt(staged.miscRng,99);error('Addict equip refusal witness')end
 reject(r,'buy',nil,'transaction_failed');Hooks.onEquip=original
 assert(Nodes.chooseEvent(r,'buy'));eq(r.gold,before.gold-85);eq(r.maxHp,before.maxHp+7);eq(r.hp,before.hp+7)
end)
test('Card-hook exception rolls back newly acquired Fish/gold/UID and identical fresh choice recovers',function()
 local r=opening('CeramicFish');local original=Hooks.onObtainCard;local before=snapshot(r)
 Hooks.onObtainCard=function(staged,...)original(staged,...);error('Addict card-hook exception witness')end
 reject(r,'steal',nil,'transaction_failed');Hooks.onObtainCard=original
 assert(Nodes.chooseEvent(r,'steal'));eq(r.gold,before.gold+9);eq(r.deck[#r.deck].uid,before.nextDeckUid)
end)
test('Invalid commands and picker UIDs cannot bypass source screens or spend RNG',function()
 local r=opening()
 for _,choice in ipairs({'open','donate','confirm','purge','cancel',false,7,{}})do reject(r,choice,nil,'invalid_event_choice')end
 for _,choice in ipairs({'buy','steal','leave'})do reject(r,choice,r.deck[1].uid,'invalid_event_choice')end
 local before=snapshot(r);local ok,why=Nodes.chooseAct2EventCard(r,r.deck[1].uid);eq(ok,false);eq(why,'invalid_event_choice');same(r,before)
end)
test('Public API sequence is select then old protection then acquisition then delayed hooks/insertion',function()
 for _,choice in ipairs({'buy','steal'})do
  local r=opening('CeramicFish');local seen,originals={},{};local gold=r.gold
  for _,method in ipairs({'prepareCard','prepareRelic','obtainRelic','commitCard'})do
   originals[method]=Run[method]
   Run[method]=function(staged,...)
    seen[#seen+1]=method
    if method=='prepareCard' then eq(staged.relics[#staged.relics]=='ceramic_fish',false)end
    if method=='obtainRelic' then eq(staged.gold,gold-(choice=='buy' and 85 or 0))end
    if method=='commitCard' then eq(staged.relics[#staged.relics],'ceramic_fish')end
    return originals[method](staged,...)
   end
  end
  local ok,why=Nodes.chooseEvent(r,choice);for method,original in pairs(originals)do Run[method]=original end
  assert(ok,why);same(seen,choice=='buy' and {'prepareRelic','obtainRelic'} or {'prepareRelic','prepareCard','obtainRelic','commitCard'})
 end
end)
test('Every implemented selectable source relic has same settled ordinary state with onEquip deferred after Shame',function()
 local mappings={}
 for _,tier in ipairs({'common','uncommon','rare'})do
  for _,source in ipairs(base.relicPool.catalog.queues[tier])do
   if source~='Whetstone' and source~='Bottled Flame' and source~='Bottled Lightning' and source~='Bottled Tornado' then
    local probe=opening(source,tier);local offer=Run.prepareRelic(probe,{channel='event',screenless=true,room='event'})
    if offer and offer.sourceId==source then mappings[#mappings+1]={source,tier}end
   end
  end
 end
 assert(#mappings>=30,'supported selectable subset unexpectedly narrowed')
 for _,row in ipairs(mappings)do
  local immediate=opening(row[1],row[2]);local deferred=snapshot(immediate)
  assert(Nodes.chooseEvent(immediate,'steal'))
  local original,commit=Hooks.onEquip,Run.commitCard;local pending
  Hooks.onEquip=function(staged,id,api)pending={owner=staged,id=id,api=api}end
  Run.commitCard=function(staged,offer)
   local ok,why=commit(staged,offer)
   assert(pending and pending.owner==staged,'deferred equip must preserve real transaction owner')
   if ok then original(staged,pending.id,pending.api)end
   return ok,why
  end
  local ok,why=Nodes.chooseEvent(deferred,'steal');Hooks.onEquip=original;Run.commitCard=commit;assert(ok,why)
  -- Preserve actual ownership insertion and canonical upgrade callback/owner;
  -- only permute real onEquip until AFTER the actual card hooks+insertion.
  same(deferred,immediate)
 end
 print('ADDICT_SETTLED_EQUIP_COMMUTATION '..#mappings..' supported source relics')
end)
test('Full Act2 selection draws Addict without changing thirteen source entries or restricted seven',function()
 local expected={'Addict','Back to Basics','Beggar','Colosseum','Cursed Tome','Drug Dealer','Forgotten Altar','Ghosts','Masked Bandits','Nest','The Library','The Mausoleum','Vampires'}
 same(Pool.new('full',false,2).act,expected);local counter
 for n=0,127 do
  local stream=R.atCounter(base.eventSeed,n);local unknown=require('abyss_unknown')
  if unknown.advancePc(unknown.newPc(),R.randomFloat(stream),{})=='event' then
   local selected=Pool.draw(Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},R.atCounter(base.eventSeed,stream.counter))
   if selected=='Addict' then counter=n;break end
  end
 end
 assert(counter,'bounded complete-pool Addict input missing');local r,m,id=fixture(true);r.eventRng=R.atCounter(r.eventSeed,counter)
 assert(Nodes.enter(r,m,id));eq(r.nodeFlow.event.id,'addict');eq(r.nodeFlow.event.originalId,'Addict');eq(#r.unknown.pools.act,12)
 eq(r.miscRng.counter,0);eq(r.eventRng.counter,counter+1);eq(r.nodeFlow.selectionRng.counter,counter+3)
 local p=Pool.new('restricted-seven');eq(#p.act+#p.shrine+#p.once,7);eq(p.actNumber,nil);same(Pool.new('full',false,2).act,expected)
end)
test('Default formal Act1 unchanged; invalid Act2 floor remains a pure refusal',function()
 local r=Run.new(Data,'42');eq(r.act,nil);eq(r.campaign,nil);r.act=2;local before=snapshot(r)
 local ok,why=Run.startRoomCombat(r,'normal');eq(ok,false);eq(why,'wrong_floor');same(r,before)
end)
print('ADDICT_EVENT_CONTENT '..count..' passed')
