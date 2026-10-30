-- Controlled module commands, not natural or native-device acceptance.
local F=dofile('tests/lua/support/shared_special_event_fixture.lua')
local Run,C,R=F.Run,F.C,F.R
local Face,Nloth,Skull=require('abyss_face_trader_event'),require('abyss_nloth_event'),require('abyss_knowing_skull_event')
local Hooks,P=require('abyss_relic_hooks'),require('abyss_potion_random')
local eq,same,choose,reject=F.eq,F.same,F.choose,F.reject
F.test('FaceTrader caches damage at construction and touch gains gold before NORMAL damage',function()
 local r=F.fixture(Face,'face_trader');eq(r.nodeFlow.event.damage,8);r.maxHp=99;F.ready(Face,r)
 local before=F.snapshot(r);local old=Run.eventNormalDamage;local seen=false
 Run.eventNormalDamage=function(staged,value)seen=true;eq(staged.gold,275);eq(value,8);return old(staged,value)end
 local ok,why=choose(Face,r,'touch');Run.eventNormalDamage=old;assert(ok,why);assert(seen);eq(r.hp,72)
 eq(r.nodeFlow.event.stage,'result');same(r.miscRng,before.miscRng);same(r.cardRng,before.cardRng)
 reject(Face,r,'touch',nil,'invalid_event_choice');assert(choose(Face,r,'leave'))
 r=F.fixture(Face,'face_trader');r.relics={'ectoplasm','tungsten_rod'};F.ready(Face,r);assert(choose(Face,r,'touch'))
 eq(r.gold,200);eq(r.hp,73)
end)
F.test('FaceTrader uses exact unowned five-face list in source order and singleton shuffle Circlet fallback',function()
 local faces={'CultistMask','FaceOfCleric','GremlinMask','NlothsMask','SsserpentHead'}
 for selected=1,#faces do
  local r=F.fixture(Face,'face_trader');r.relics={}
  for i,id in ipairs(faces)do if i~=selected then assert(Run.obtainRelic(r,id))end end
  F.ready(Face,r);local before=R.cloneState(r.miscRng);R.shuffle(before,{faces[selected]})
  assert(choose(Face,r,'trade'));eq(r.nodeFlow.event.obtainedSourceId,faces[selected]);same(R.snapshot(r.miscRng),R.snapshot(before))
 end
 local r=F.fixture(Face,'face_trader');r.relics={};for _,id in ipairs(faces)do assert(Run.obtainRelic(r,id))end
 F.ready(Face,r);local before=R.cloneState(r.miscRng);R.shuffle(before,{'Circlet'})
 assert(choose(Face,r,'trade'));eq(r.nodeFlow.event.obtainedRelicId,'circlet');same(R.snapshot(r.miscRng),R.snapshot(before))
end)
F.test('FaceTrader unsupported selected face rolls back shuffle without filtering or rerolling',function()
 local r=F.fixture(Face,'face_trader');F.ready(Face,r);local expected=R.cloneState(r.miscRng)
 local ids={'CultistMask','FaceOfCleric','GremlinMask','NlothsMask','SsserpentHead'};R.shuffle(expected,ids)
 r.data=C.copy(r.data)
 for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].sourceId==ids[1]then table.remove(r.data.relics.relics,i)end end
 reject(Face,r,'trade',nil,'relic_content_unavailable')
 r=F.fixture(Face,'face_trader');r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'));F.ready(Face,r)
 assert(choose(Face,r,'touch'));eq(r.hp,24);eq(r.gold,275);eq(r.potions[1],nil)
end)
local function nloth()
 local r=F.fixture(Face,'face_trader');r.nodeFlow.event={id='nloth'};r.relics={'anchor','vajra','old_coin'}
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
print('FACE_NLOTH_SKULL '..F.count..' passed')
