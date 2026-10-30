-- Controlled source-rule and transaction setup; not natural/native acceptance.
local F=dofile('tests/lua/support/shared_special_event_fixture.lua')
local Run,C,R=F.Run,F.C,F.R
local Designer=require('abyss_designer_event')
local Hooks=require('abyss_relic_hooks')
local eq,same,choose,reject=F.eq,F.same,F.choose,F.reject
F.test('Designer constructor consumes exactly two misc booleans and keeps intro inert',function()
 local r=F.fixture(Designer,'designer');local expected=R.fromSeed(r.eventSeed)
 local a,b=R.randomBoolean(expected),R.randomBoolean(expected)
 eq(r.nodeFlow.event.adjustmentUpgradesOne,a);eq(r.nodeFlow.event.cleanUpRemovesCards,b)
 same(R.snapshot(r.miscRng),R.snapshot(expected));eq(#Designer.options(r,r.nodeFlow.event),1)
 reject(Designer,r,'adjust',nil,'invalid_event_choice');F.ready(Designer,r)
 eq(#Designer.options(r,r.nodeFlow.event),4);reject(Designer,r,'leave',nil,'invalid_event_choice')
 local before=F.snapshot(r);local view=C.copy(r.nodeFlow.event);Designer.view(r,view);same(r,before)
end)
F.test('Designer selected upgrade pays once and retains bottles; invalid UID never refunds earlier payment',function()
 local r=F.fixture(Designer,'designer');r.nodeFlow.event.adjustmentUpgradesOne=true;F.ready(Designer,r)
 r.deck[1].inBottleFlame=true;local oldRng=R.snapshot(r.miscRng)
 assert(choose(Designer,r,'adjust'));eq(r.gold,160);eq(r.nodeFlow.event.choice,'upgrade')
 local view=C.copy(r.nodeFlow.event);Designer.view(r,view);view.selectionCards[1].upgraded=true;eq(r.deck[1].upgraded,false)
 reject(Designer,r,'leave',nil,'invalid_event_choice');reject(Designer,r,'upgrade',999,'invalid_card')
 eq(r.gold,160);assert(choose(Designer,r,'upgrade',r.deck[1].uid));eq(r.deck[1].upgraded,true);eq(r.deck[1].inBottleFlame,true)
 same(R.snapshot(r.miscRng),oldRng);eq(r.nodeFlow.event.stage,'result');assert(choose(Designer,r,'leave'))
end)
F.test('Designer random adjustment uses one Collections shuffle in deck order',function()
 local r=F.fixture(Designer,'designer');r.nodeFlow.event.adjustmentUpgradesOne=false;F.ready(Designer,r)
 local expected=R.cloneState(r.miscRng);local cards=C.copy(r.deck);R.shuffle(expected,cards)
 assert(choose(Designer,r,'adjust'));eq(r.gold,160)
 same(r.nodeFlow.event.upgradedUids,{cards[1].uid,cards[2].uid});same(R.snapshot(r.miscRng),R.snapshot(expected))
 local upgraded=0;for _,c in ipairs(r.deck)do if c.upgraded then upgraded=upgraded+1 end end;eq(upgraded,2)
 reject(Designer,r,'adjust',nil,'invalid_event_choice')
end)
F.test('Designer cleanup and full service use purgeable nonbottled cards and source post-removal shuffle',function()
 local r=F.fixture(Designer,'designer');r.nodeFlow.event.cleanUpRemovesCards=true;F.ready(Designer,r)
 assert(choose(Designer,r,'cleanup'));eq(r.gold,140);r.deck[1].inBottleFlame=true
 reject(Designer,r,'remove',r.deck[1].uid,'card_not_purgeable');local uid=r.deck[2].uid
 assert(choose(Designer,r,'remove',uid));eq(#r.deck,9);eq(r.nodeFlow.event.removedUid,uid)
 r=F.fixture(Designer,'designer');F.ready(Designer,r);assert(choose(Designer,r,'full'));eq(r.gold,110)
 local expected=R.cloneState(r.miscRng);local cards=C.copy(r.deck);local removed=table.remove(cards,1);R.shuffle(expected,cards)
 assert(choose(Designer,r,'full_remove',removed.uid));eq(#r.deck,9)
 same(r.nodeFlow.event.upgradedUids,{cards[1].uid});same(R.snapshot(r.miscRng),R.snapshot(expected))
 r=F.fixture(Designer,'designer');r.deck={r.deck[1]};F.ready(Designer,r);assert(choose(Designer,r,'full'))
 expected=R.cloneState(r.miscRng);R.shuffle(expected,{})
 assert(choose(Designer,r,'full_remove',r.deck[1].uid));eq(#r.deck,0);eq(#r.nodeFlow.event.upgradedUids,0)
 same(R.snapshot(r.miscRng),R.snapshot(expected));eq(r.nodeFlow.event.stage,'result')
end)
F.test('Designer transform is an atomic ordered exact pair and obtains only after both removals',function()
 local r=F.fixture(Designer,'designer');r.nodeFlow.event.cleanUpRemovesCards=false;F.ready(Designer,r)
 assert(choose(Designer,r,'cleanup'));eq(r.gold,140);local a,b=r.deck[1].uid,r.deck[6].uid
 for _,value in ipairs({a,{a},{a,a},{a,b,999},{a,999}})do reject(Designer,r,'transform',value)end
 local old=Hooks.onObtainCard;local lengths={}
 Hooks.onObtainCard=function(staged,card,d,api)lengths[#lengths+1]=#staged.deck;return old(staged,card,d,api)end
 local ok,why=choose(Designer,r,'transform',{b,a});Hooks.onObtainCard=old;assert(ok,why)
 same(r.nodeFlow.event.removedUids,{b,a});same(lengths,{8,9});eq(#r.deck,10)
 same(r.nodeFlow.event.obtainedCardUids,{11,12});eq(r.nextDeckUid,13)
end)
F.test('Designer selected command hook failure rolls back RNG removals and new UIDs but not prior price',function()
 local r=F.fixture(Designer,'designer');r.nodeFlow.event.cleanUpRemovesCards=false;F.ready(Designer,r);assert(choose(Designer,r,'cleanup'))
 local old=Hooks.onObtainCard
 Hooks.onObtainCard=function(staged,card,d,api)old(staged,card,d,api);R.randomInt(staged.miscRng,99);error('late transform refusal')end
 local ok,why=pcall(reject,Designer,r,'transform',{1,6},'transaction_failed');Hooks.onObtainCard=old;assert(ok,why)
 eq(r.gold,140);assert(choose(Designer,r,'transform',{1,6}));eq(r.nextDeckUid,13)
end)
F.test('Designer punch uses HP loss and fatal revival while preserving other RNG owners',function()
 local r=F.fixture(Designer,'designer');r.hp=1;r.relics={'tungsten_rod'};assert(Run.obtainPotion(r,'fairy_in_a_bottle'));F.ready(Designer,r)
 local before=F.snapshot(r);assert(choose(Designer,r,'punch'));eq(r.hp,24);eq(r.nodeFlow.event.hpLost,1)
 eq(r.potions[1],nil);eq(r.gold,200);same(r.cardRng,before.cardRng);same(r.miscRng,before.miscRng)
end)
local Nloth,Skull=require('abyss_nloth_event'),require('abyss_knowing_skull_event')
local P=require('abyss_potion_random')
local function nloth()
 local r=F.fixture({prepare=function()end},'nloth');r.nodeFlow.event={id='nloth'};r.relics={'anchor','vajra','old_coin'}
 Nloth.prepare(r,r.nodeFlow.event,r.miscRng);return r
end
F.test('Nloth constructor shuffles all relics once and immutable offer identity survives reorder',function()
 local r=nloth();local before=R.fromSeed(r.eventSeed);local all={'anchor','vajra','old_coin'};R.shuffle(before,all)
 same(r.nodeFlow.event.relicChoices,{all[1],all[2]});same(R.snapshot(r.miscRng),R.snapshot(before))
 local view=Nloth.options(r,r.nodeFlow.event);view[1].relicId='sozu';eq(r.nodeFlow.event.relicChoices[1],all[1])
 r.relics={all[3],all[2],all[1]};local rng=R.snapshot(r.miscRng)
 assert(choose(Nloth,r,'trade_1'));eq(r.nodeFlow.event.removedRelicId,all[1]);eq(r.nodeFlow.event.obtainedRelicId,'nloths_gift')
 eq(#r.relics,3);same(R.snapshot(r.miscRng),rng);reject(Nloth,r,'trade_2',nil,'invalid_event_choice')
end)
F.test('Nloth already-owned Gift yields Circlet without sacrificing selected relic',function()
 local r=nloth();assert(Run.obtainRelic(r,"Nloth's Gift"));local before=C.copy(r.relics)
 assert(choose(Nloth,r,'trade_2'));eq(r.nodeFlow.event.obtainedRelicId,'circlet');eq(r.nodeFlow.event.removedRelicId,nil)
 for i,id in ipairs(before)do eq(r.relics[i],id)end;eq(#r.relics,#before+1)
end)
F.test('Nloth stale offer refuses and failed equip rolls back removal before one successful retry',function()
 local r=nloth();local selected=r.nodeFlow.event.relicChoices[1]
 for i=#r.relics,1,-1 do if r.relics[i]==selected then table.remove(r.relics,i)end end
 reject(Nloth,r,'trade_1',nil,'event_condition_unmet')
 r=nloth();local old=Hooks.onEquip
 Hooks.onEquip=function(staged,id,api)old(staged,id,api);error('late gift equip refusal')end
 local ok,why=pcall(reject,Nloth,r,'trade_1',nil,'transaction_failed');Hooks.onEquip=old;assert(ok,why)
 assert(choose(Nloth,r,'trade_1'));eq(r.nodeFlow.event.obtainedRelicId,'nloths_gift')
end)
F.test('KnowingSkull has independent 6 then 7 reward prices and unchanging 6 leave cost',function()
 local r=F.fixture(Skull,'knowing_skull');F.ready(Skull,r);local before=F.snapshot(r)
 assert(choose(Skull,r,'gold'));eq(r.hp,74);eq(r.gold,290)
 assert(choose(Skull,r,'gold'));eq(r.hp,67);eq(r.gold,380)
 local event=r.nodeFlow.event;eq(event.goldCost,8);eq(event.cardCost,6);eq(event.potionCost,6);eq(event.leaveCost,6)
 assert(choose(Skull,r,'leave'));eq(r.hp,61);eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.damageTaken,19)
 same(r.miscRng,before.miscRng);same(r.cardRng,before.cardRng);assert(choose(Skull,r,'leave'));eq(r.hp,61)
end)
F.test('KnowingSkull damage precedes gold even when fatal, and Tungsten changes damage not requested price',function()
 local r=F.fixture(Skull,'knowing_skull');r.hp=1;F.ready(Skull,r)
 assert(choose(Skull,r,'gold'));eq(r.hp,0);eq(r.gold,290);eq(r.nodeFlow.event.goldCost,7)
 r=F.fixture(Skull,'knowing_skull');r.relics={'tungsten_rod','ectoplasm'};F.ready(Skull,r)
 assert(choose(Skull,r,'gold'));eq(r.hp,75);eq(r.gold,200);eq(r.nodeFlow.event.damageTaken,6);eq(r.nodeFlow.event.hpLost,5)
end)
F.test('KnowingSkull Sozu skips potion RNG; full inventory still generates and loses potion',function()
 local r=F.fixture(Skull,'knowing_skull');r.relics={'sozu'};F.ready(Skull,r);local before=F.snapshot(r)
 assert(choose(Skull,r,'potion'));eq(r.hp,74);eq(r.nodeFlow.event.potionCost,7);eq(#r.nodeFlow.event.potions,0);same(r.shopRng,before.shopRng)
 r=F.fixture(Skull,'knowing_skull');F.ready(Skull,r)
 for i=1,Run.potionCapacity(r)do r.potions[i]='block_potion'end
 local expected=R.fromSeed(r.eventSeed);local pool=P.pool(P.character(r));local index=R.randomIntBetween(expected,0,#pool-1)
 assert(choose(Skull,r,'potion'));eq(r.hp,74);local generated=r.nodeFlow.event.potions[1]
 eq(generated.id,pool[index+1].id);eq(generated.lost,true);eq(Run.potionCount(r),Run.potionCapacity(r))
 same(R.snapshot(r.shopRng.potion),R.snapshot(expected))
end)
F.test('KnowingSkull repeated cards shuffle the shared full35 pool with a persistent room shuffle owner',function()
 local r=F.fixture(Skull,'knowing_skull');F.ready(Skull,r)
 local ids=C.copy(r.data.cards.sourcePools.colorlessRaw);local expected=Run.roomStreams(r,18).shuffleRng
 local expectedIds={}
 for n=1,2 do
  R.shuffle(expected,ids)
  for _,id in ipairs(ids)do
   local d;for _,entry in ipairs(r.data.cards.cards)do if entry.id==id then d=entry;break end end
   if d.rarity=='uncommon'then expectedIds[n]=id;break end
  end
 end
 local before=F.snapshot(r);assert(choose(Skull,r,'card'));assert(choose(Skull,r,'card'))
 eq(r.hp,67);eq(r.nodeFlow.event.cardCost,8);eq(#r.deck,12);eq(r.nodeFlow.event.cards[1].cardId,expectedIds[1]);eq(r.nodeFlow.event.cards[2].cardId,expectedIds[2])
 same(r.eventCardPools.colorless,ids);same(R.snapshot(r.nodeFlow.event.shuffleRng),R.snapshot(expected))
 same(r.cardRng,before.cardRng);same(r.miscRng,before.miscRng);eq(r.cardRarityOffset,before.cardRarityOffset)
end)
F.test('KnowingSkull late card-hook failure rolls back HP price shared pool shuffle and UID then retries',function()
 local r=F.fixture(Skull,'knowing_skull');F.ready(Skull,r);local old=Hooks.onObtainCard
 Hooks.onObtainCard=function(staged,card,d,api)old(staged,card,d,api);error('late skull card refusal')end
 local ok,why=pcall(reject,Skull,r,'card',nil,'transaction_failed');Hooks.onObtainCard=old;assert(ok,why)
 eq(r.hp,80);eq(r.nodeFlow.event.cardCost,6);eq(r.eventCardPools,nil);assert(choose(Skull,r,'card'));eq(r.hp,74);eq(r.nextDeckUid,12)
end)
F.test('Designer resource boundaries reject before payment and mandatory pickers cannot cancel',function()
 for _,choice in ipairs({'adjust','cleanup','full'})do
  local r=F.fixture(Designer,'designer');F.ready(Designer,r);r.gold=0
  reject(Designer,r,choice,nil,'insufficient_gold')
 end
 local r=F.fixture(Designer,'designer');F.ready(Designer,r)
 for _,card in ipairs(r.deck)do assert(Run.upgradeCard(r,card.uid))end
 reject(Designer,r,'adjust',nil,'card_not_upgradeable')
 r=F.fixture(Designer,'designer');F.ready(Designer,r);r.deck={}
 reject(Designer,r,'cleanup',nil,'event_condition_unmet');reject(Designer,r,'full',nil,'event_condition_unmet')
 r=F.fixture(Designer,'designer');F.ready(Designer,r);r.nodeFlow.event.cleanUpRemovesCards=false
 assert(choose(Designer,r,'cleanup'));local view=C.copy(r.nodeFlow.event);Designer.view(r,view)
 eq(view.selection.count,2);eq(view.selection.canCancel,false)
 reject(Designer,r,'cancel',nil,'invalid_event_choice');reject(Designer,r,'leave',nil,'invalid_event_choice')
end)
F.test('Nloth can sacrifice every one of the 130 current legal relic bindings without filtering',function()
 local Data,Rewards=require('abyss_data'),require('abyss_relic_rewards')
 local base=Run.new(Data,'42',{experimental=true,campaign=true,character='ironclad'})
 local n=0
 for _,tier in ipairs({'common','uncommon','rare','shop','boss'})do
  for _,source in ipairs(base.relicPool.catalog.queues[tier])do
   local def=assert(Rewards.definition(base,source));local r=F.snapshot(base)
   r.phase,r.act,r.floor='node',2,18
   -- Controlled existing inventory, not acquisition: some original onEquip
   -- effects require mandatory screens that do not occur during this event.
   r.relics={def.id,'burning_blood'};r.relicCounters={[def.id]=17}
   r.nodeFlow={type='event',event={id='nloth'}};Nloth.prepare(r,r.nodeFlow.event,r.miscRng)
   local i=r.nodeFlow.event.relicChoices[1]==def.id and 1 or 2
   local before=F.snapshot(r);assert(choose(Nloth,r,'trade_'..i),source)
   eq(r.nodeFlow.event.removedRelicId,def.id);eq(r.nodeFlow.event.obtainedRelicId,'nloths_gift')
   eq(r.relicCounters[def.id],nil);eq(#r.relics,2);eq(r.gold,before.gold);eq(r.maxHp,before.maxHp)
   same(r.cardRng,before.cardRng);same(r.miscRng,before.miscRng);same(r.relicPool,before.relicPool)
   assert(choose(Nloth,r,'leave'));n=n+1
  end
 end
 eq(n,130)
end)
F.test('Gift exact rarity thresholds retain PR357 reward modifiers and one-shot sacrifice effects',function()
 local Pool,CR=require('abyss_card_pool'),require('abyss_card_random')
 for context,bounds in pairs({normal={9,46},elite={30,70},shop={27,64}})do
  for roll=0,99 do for _,offset in ipairs({-40,0,5})do
   local n=roll+offset;eq(Pool.rarity(roll,offset,context,{'nloths_gift'}),n<bounds[1]and'rare'or n<bounds[2]and'uncommon'or'common')
  end end
  local owner=CR.new('42');owner.relics={'nloths_gift'};local rng=R.cloneState(owner.cardRng)
  local n=R.randomInt(rng,99)+5;eq(CR.rollRarity(owner,context),n<bounds[1]and'rare'or n<bounds[2]and'uncommon'or'common')
  same(R.snapshot(owner.cardRng),R.snapshot(rng));eq(owner.cardRarityOffset,5)
 end
 local r=F.fixture(Designer,'designer');r.relics={'question_card','busted_crown','nloths_gift'}
 eq(Pool.rewardCount(r),2);assert(type(Pool.prismaticPools)=='function')
 r=F.fixture(Designer,'designer');assert(Run.obtainRelic(r,'Potion Belt'))
 local capacity=Run.potionCapacity(r);assert(Run.loseRelic(r,'Potion Belt'));eq(Run.potionCapacity(r),capacity)
 assert(Run.obtainRelic(r,'Mango'));local hp,maxHp=r.hp,r.maxHp;assert(Run.loseRelic(r,'Mango'));eq(r.hp,hp);eq(r.maxHp,maxHp)
 assert(Run.obtainRelic(r,'Old Coin'));local gold=r.gold;assert(Run.loseRelic(r,'Old Coin'));eq(r.gold,gold)
end)
print('M3_RELIC_CHOICE_EVENTS '..F.count..' passed')
