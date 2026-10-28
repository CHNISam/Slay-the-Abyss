-- Deterministic API fixtures only: not a played route, native test or independent
-- PC RNG oracle. Seed/counter and queue staging below never enter production.
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
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not unentered and 'mausoleum' or nil end end
 if not unentered then assert(Nodes.enter(r,m,n.id))end
 return r,m,n.id
end
local function reject(r,choice,uid,expected)
 local before=snapshot(r);local deck,event,flow,pool=r.deck,r.nodeFlow.event,r.nodeFlow,r.relicPool
 local ok,why=Nodes.chooseEvent(r,choice,uid);eq(ok,false);if expected then eq(why,expected)end
 same(r,before);eq(r.deck,deck);eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event);eq(r.relicPool,pool)
end
local function boolean(r,wanted)
 for n=0,31 do
  local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if R.randomBoolean(nextState)==wanted then r.miscRng=state;return end
 end
 error('bounded seeded boolean input missing')
end
local function frontRelics(r,tier,ids)
 -- Select a real seeded tier draw, with no production retry or pool filtering.
 for n=0,31 do
  local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if Relics.rarity('event',R.randomInt(nextState,99))==tier then r.relicPool.rng=state;break end
 end
 local q=r.relicPool.queues[tier]
 for _,id in ipairs(ids)do
  local found=false
  for i,v in ipairs(q)do if v==id then table.remove(q,i);found=true;break end end
  assert(found,'missing staged source ID '..id)
 end
 for i=#ids,1,-1 do table.insert(q,1,ids[i])end
end
local function opening(cursed,id,tier)
 local r,m=fixture();boolean(r,cursed);frontRelics(r,tier or 'common',{id or 'Anchor'});return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS mausoleum '..count..' '..name)end

test('Intro preserves source option order, no cost gate, and detached RNG-pure readback',function()
 eq(Pool.contentId['The Mausoleum'],'mausoleum')
 local r,m=fixture();r.gold=0;local before=snapshot(r)
 local v=Nodes.view(r,m).node.event;eq(v.stage,'intro');eq(#v.options,2)
 eq(v.options[1].choice,'open');eq(v.options[1].enabled,true);assert(v.options[1].description:find('50%%'))
 eq(v.options[2].choice,'leave');v.options[1].enabled=false;v.stage='result';same(r,before)
end)

test('Leave has RESULT then separate map leave and spends no RNG or reward resources',function()
 local r,m=fixture();local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 eq(#Nodes.view(r,m).node.event.options,1);eq(Nodes.view(r,m).node.event.options[1].choice,'leave')
 same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 same(r.relicPool,before.relicPool);same(r.deck,before.deck);same(r.relics,before.relics);eq(r.gold,before.gold);eq(r.hp,before.hp)
 reject(r,'open',nil,'invalid_event_choice');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 reject(r,'leave',nil,'no_pending_node')
end)

test('A0 false boolean grants one relic without curse or UID and retains RESULT',function()
 local r,m=opening(false);local before=snapshot(r);local expected=R.cloneState(r.miscRng);eq(R.randomBoolean(expected),false)
 assert(Nodes.chooseEvent(r,'open'));eq(r.phase,'node');eq(r.nodeFlow.complete,false);eq(r.nodeFlow.event.stage,'result')
 eq(r.nodeFlow.event.cursed,false);eq(r.nodeFlow.event.obtainedRelicId,'anchor');eq(#r.relics,#before.relics+1)
 same(r.deck,before.deck);eq(r.nextDeckUid,before.nextDeckUid);same(r.miscRng,expected)
 eq(r.relicPool.rng.counter,before.relicPool.rng.counter+1);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 eq(#Nodes.view(r,m).node.event.options,1);reject(r,'open',nil,'invalid_event_choice')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');reject(r,'open',nil,'no_pending_node')
end)

test('A0 true boolean grants innate Writhe once with permanent stable UID',function()
 local r=opening(true);local before=snapshot(r);local expected=R.cloneState(r.miscRng);eq(R.randomBoolean(expected),true)
 assert(Nodes.chooseEvent(r,'open'));eq(r.nodeFlow.event.cursed,true);eq(r.nodeFlow.event.curseBlocked,false)
 eq(#r.deck,#before.deck+1);local card=r.deck[#r.deck];eq(card.cardId,'writhe');eq(card.uid,before.nextDeckUid)
 eq(r.nextDeckUid,before.nextDeckUid+1);eq(r.nodeFlow.event.obtainedCardUid,card.uid);same(r.miscRng,expected)
 for _,def in ipairs(r.data.cards.cards)do if def.id=='writhe' then eq(def.innate,true);eq(def.cost,-2)end end
 reject(r,'open',nil,'invalid_event_choice')
end)

test('Old Omamori prevents Writhe before relic equip and never allocates UID',function()
 local r=opening(true);assert(Run.obtainRelic(r,'Omamori'));local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'open'));eq(r.relicCounters.omamori,1);eq(r.nodeFlow.event.curseBlocked,true)
 same(r.deck,before.deck);eq(r.nextDeckUid,before.nextDeckUid);eq(r.nodeFlow.event.obtainedCardUid,nil)
end)

test('New Omamori cannot retroactively prevent already prepared Writhe',function()
 local r=opening(true,'Omamori');local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'open'));eq(r.nodeFlow.event.obtainedRelicId,'omamori');eq(r.relicCounters.omamori,2)
 eq(r.deck[#r.deck].cardId,'writhe');eq(r.nextDeckUid,before.nextDeckUid+1);eq(r.nodeFlow.event.curseBlocked,false)
end)

test('New Ceramic Fish receives delayed curse obtain hook exactly once',function()
 local r=opening(true,'CeramicFish');local gold=r.gold
 assert(Nodes.chooseEvent(r,'open'));eq(r.nodeFlow.event.obtainedRelicId,'ceramic_fish');eq(r.gold,gold+9)
 eq(r.deck[#r.deck].cardId,'writhe');reject(r,'open',nil,'invalid_event_choice')
end)

test('Old Omamori prevents delayed new Ceramic Fish hook and false boolean spends no protection',function()
 for _,cursed in ipairs({true,false})do
  local r=opening(cursed,'CeramicFish');assert(Run.obtainRelic(r,'Omamori'));local before=snapshot(r)
  assert(Nodes.chooseEvent(r,'open'));eq(r.gold,before.gold);same(r.deck,before.deck)
  eq(r.relicCounters.omamori,cursed and 1 or 2);eq(r.nodeFlow.event.cursed,cursed)
 end
end)

test('Screenless source Whetstone exclusion consumes original queue without extra rarity draw',function()
 local r=opening(false);frontRelics(r,'common',{'Whetstone','War Paint'})
 local before=snapshot(r);assert(Nodes.chooseEvent(r,'open'))
 eq(r.nodeFlow.event.relicOffer.tier,'common');eq(r.nodeFlow.event.obtainedRelicId,'war_paint')
 eq(#r.nodeFlow.event.relicOffer.trace,2);eq(#r.relicPool.queues.common,#before.relicPool.queues.common-2)
 eq(r.nodeFlow.event.relicOffer.trace[1].id,'Whetstone');eq(r.nodeFlow.event.relicOffer.trace[2].id,'War Paint')
 eq(r.relicPool.rng.counter,before.relicPool.rng.counter+1)
 -- War Paint independently consumes one source misc shuffle after the boolean.
 eq(r.miscRng.counter,before.miscRng.counter+2)
end)

test('Explicitly missing selected Darkstone definition fails closed without implementation-driven reroll',function()
 local r=opening(true,'Darkstone Periapt','uncommon');assert(Run.obtainRelic(r,'Omamori'))
 r.data=C.copy(r.data)
 for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='darkstone_periapt' then table.remove(r.data.relics.relics,i)end end
 local before=snapshot(r);reject(r,'open',nil,'relic_content_unavailable')
 eq(r.nodeFlow.event.stage,'intro');eq(r.relicCounters.omamori,2);eq(r.relicPool.queues.uncommon[1],'Darkstone Periapt')
 same(r.relicPool,before.relicPool);same(r.miscRng,before.miscRng);eq(r.nodeFlow.event.relicOffer,nil)
end)

test('Missing Writhe content rolls back source boolean before any relic selection',function()
 local r=opening(true);r.data=C.copy(r.data)
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id=='writhe' then table.remove(r.data.cards.cards,i)end end
 reject(r,'open',nil,'card_content_unavailable');eq(r.nodeFlow.event.stage,'intro')
end)

test('Invalid permanent UID rolls back acquired relic, old protection, pools and RNG',function()
 local r=opening(true,'CeramicFish');r.nextDeckUid=r.deck[1].uid;local gold=r.gold
 reject(r,'open',nil,'invalid_deck_uid');eq(r.gold,gold);eq(r.relicPool.queues.common[1],'CeramicFish')
end)

test('Relic equip exception rolls back all state then same fresh command recovers',function()
 local r=opening(true,'Strawberry');local original=Hooks.onEquip;local before=snapshot(r)
 Hooks.onEquip=function(staged,id,api)original(staged,id,api);R.randomInt(staged.miscRng,99);error('bounded Mausoleum equip failure')end
 reject(r,'open',nil,'transaction_failed');Hooks.onEquip=original
 assert(Nodes.chooseEvent(r,'open'));eq(r.nodeFlow.event.obtainedRelicId,'strawberry');eq(r.maxHp,before.maxHp+7)
 eq(r.deck[#r.deck].cardId,'writhe')
end)

test('Card hook exception rolls back newly equipped relic and hook effects before retry',function()
 local r=opening(true,'CeramicFish');local original=Hooks.onObtainCard;local before=snapshot(r)
 Hooks.onObtainCard=function(staged,card,def)original(staged,card,def);error('bounded Mausoleum obtain failure')end
 reject(r,'open',nil,'transaction_failed');Hooks.onObtainCard=original
 eq(r.gold,before.gold);assert(Nodes.chooseEvent(r,'open'));eq(r.gold,before.gold+9);eq(r.deck[#r.deck].cardId,'writhe')
end)

test('Malformed choices and picker commands cannot spend RNG or bypass source screens',function()
 local r=opening(true)
 for _,choice in ipairs({'confirm','purge','cancel','donate',false,7,{}})do reject(r,choice,nil,'invalid_event_choice')end
 reject(r,'open',r.deck[1].uid,'invalid_event_choice');reject(r,'leave',r.deck[1].uid,'invalid_event_choice')
 local before=snapshot(r);local ok,why=Nodes.chooseAct2EventCard(r,r.deck[1].uid);eq(ok,false);eq(why,'invalid_event_choice');same(r,before)
end)

test('Full Act2 catalog draws Mausoleum without changing restricted seven or 13 source entries',function()
 local expected={'Addict','Back to Basics','Beggar','Colosseum','Cursed Tome','Drug Dealer','Forgotten Altar','Ghosts','Masked Bandits','Nest','The Library','The Mausoleum','Vampires'}
 same(Pool.new('full',false,2).act,expected)
 local counter
 for n=0,127 do
  local stream=R.atCounter(base.eventSeed,n)
  local unknown=require('abyss_unknown')
  if unknown.advancePc(unknown.newPc(),R.randomFloat(stream),{})=='event' then
   local selected=Pool.draw(Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},
    R.atCounter(base.eventSeed,stream.counter))
   if selected=='The Mausoleum' then counter=n;break end
  end
 end
 assert(counter,'bounded complete-pool Mausoleum input missing')
 local r,m,id=fixture(true);r.eventRng=R.atCounter(r.eventSeed,counter)
 assert(Nodes.enter(r,m,id));eq(r.nodeFlow.event.id,'mausoleum');eq(r.nodeFlow.event.originalId,'The Mausoleum')
 eq(#r.unknown.pools.act,12);eq(r.miscRng.counter,0)
 eq(r.eventRng.counter,counter+1);eq(r.nodeFlow.selectionRng.counter,counter+3)
 local p=Pool.new('restricted-seven');eq(#p.act+#p.shrine+#p.once,7);eq(p.actNumber,nil)
 same(Pool.new('full',false,2).act,expected)
end)

test('Real API observations match source boolean, old card protection, relic draw/equip then delayed card',function()
 local r=opening(true,'CeramicFish');local seen={};local originals={}
 local order={'prepareCard','prepareRelic','obtainRelic','commitCard'}
 for _,method in ipairs(order)do
  originals[method]=Run[method]
  Run[method]=function(staged,...)
   seen[#seen+1]=method;eq(staged.miscRng.counter,r.miscRng.counter+1)
   return originals[method](staged,...)
  end
 end
 local ok,why=Nodes.chooseEvent(r,'open')
 for _,method in ipairs(order)do Run[method]=originals[method]end
 assert(ok,why);same(seen,order)
end)

test('Formal Act1 launch unchanged; malformed Act2 floor refuses before queue consumption',function()
 local ordinary=Run.new(Data,'42');eq(ordinary.act,nil);eq(ordinary.campaign,nil)
 ordinary.act=2;local before=snapshot(ordinary);local ok,why=Run.startRoomCombat(ordinary,'normal')
 eq(ok,false);eq(why,'wrong_floor');same(ordinary,before)
end)
print('MAUSOLEUM_EVENT_CONTENT '..count..' passed')
