-- Source-mechanism contract through real Nodes; no native device evidence.
local H=dofile('tests/helpers/act2_event_ui.lua')
local Run,Nodes,R=H.Run,H.Nodes,H.Random
local eq,same=H.eq,H.same
local P=require('abyss_potion_random')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS skull '..count..' '..name)end
local function fixture(character)
 local r,m
 if character then
  r=Run.new(H.Data,'42',{experimental=true,campaign=true,character=character})
  r.act,r.floor=2,17;r.unknown.pools=H.Pool.new('full',false,2)
  m=H.Map.generate(r.data,'42',2);local first=H.Map.available(m)[1]
  for _,node in ipairs(m.nodes)do if node.id==first.id then node.type,node.eventId='event','knowing_skull'end end
  assert(Nodes.enter(r,m,first.id))
 else r,m=H.fixture('knowing_skull')end
 assert(Nodes.chooseEvent(r,'continue'));return r,m
end
local function reject(r,choice,reason,uid)
 local before=H.snapshot(r);local owners={}
 for k,v in pairs(r)do if type(v)=='table'then owners[k]=v end end
 local event=r.nodeFlow.event;local ok,why=Nodes.chooseEvent(r,choice,uid)
 eq(ok,false);if reason then eq(why,reason)end;same(r,before)
 for k,v in pairs(owners)do eq(r[k],v)end;eq(r.nodeFlow.event,event)
end
local function firstUncommon(r,ids)
 for _,id in ipairs(ids)do if r.data.cards.sourcePools.cardSourceMetadata[id].rarity=='uncommon'then return id end end
 error('missing uncommon')
end

test('real entry and repeat choices charge individual escalating prices, leave always six',function()
 local r,m=H.fixture('knowing_skull');eq(r.nodeFlow.event.stage,'intro')
 eq(H.Pool.contentId['Knowing Skull'],'knowing_skull')
 reject(r,'gold');reject(r,'leave');assert(Nodes.chooseEvent(r,'continue'))
 -- Options are read through the dispatcher below; no synthetic leaf owner.
 eq(#require('abyss_act2_events').options(r,r.nodeFlow.event),4)
 local hp,gold=r.hp,r.gold
 assert(Nodes.chooseEvent(r,'gold'));eq(r.hp,hp-6);eq(r.gold,gold+90)
 assert(Nodes.chooseEvent(r,'gold'));eq(r.hp,hp-13);eq(r.gold,gold+180)
 local e=r.nodeFlow.event;eq(e.goldCost,8);eq(e.cardCost,6);eq(e.potionCost,6);eq(e.leaveCost,6)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.hp,hp-19);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 reject(r,'gold');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');reject(r,'leave')
end)
test('Sozu pays and escalates without consuming potion RNG; full slots consume draw and lose bottle',function()
 local r=fixture();r.relics={'sozu'};local before=H.snapshot(r);assert(Nodes.chooseEvent(r,'potion'))
 eq(r.hp,before.hp-6);eq(r.nodeFlow.event.potionCost,7);same(r.shopRng,before.shopRng)
 local classDraw
 for n=0,255 do
  local state=R.atCounter(r.eventSeed,n);local probe=R.cloneState(state)
  if R.randomIntBetween(probe,0,32)==0 then classDraw=state;break end
 end
 assert(classDraw,'bounded first class-exclusive potion draw')
 local exclusive={ironclad='blood_potion',silent='poison_potion',defect='focus_potion',watcher='bottled_miracle'}
 for _,character in ipairs({'ironclad','silent','defect','watcher'})do
  r=fixture(character);eq(P.character(r),character)
  r.shopRng={merchant=R.fromSeed(r.eventSeed),potion=R.cloneState(classDraw)}
  for i=1,Run.potionCapacity(r)do r.potions[i]='block_potion'end
  local hp=r.hp;local old=H.Copy(r.potions);local rng=(r.shopRng and R.cloneState(r.shopRng.potion)or R.fromSeed(r.eventSeed))
  local pool=P.pool(P.character(r));local expected=pool[R.randomIntBetween(rng,0,#pool-1)+1]
  assert(Nodes.chooseEvent(r,'potion'));eq(r.hp,hp-6);eq(r.nodeFlow.event.potionCost,7)
  same(r.potions,old);same(r.shopRng.potion,rng);eq(r.nodeFlow.event.lastPotionId,expected.id);eq(expected.id,exclusive[character])
  eq(r.nodeFlow.event.potionLost,true)
 end
end)
test('successful potion obtains first free slot and unknown content rolls everything back',function()
 local r=fixture();r.potions[1]='block_potion';local rng=(r.shopRng and R.cloneState(r.shopRng.potion)or R.fromSeed(r.eventSeed))
 local pool=P.pool(P.character(r));local expected=pool[R.randomIntBetween(rng,0,#pool-1)+1]
 assert(Nodes.chooseEvent(r,'potion'));eq(r.potions[2],expected.id);eq(r.nodeFlow.event.potionLost,false)
 r=fixture();r.data=H.Copy(r.data);r.data.potions.potions={};reject(r,'potion','unknown_potion')
end)
test('cards shuffle all35 current cards on same room stream and preserve uncommon acquisition hooks',function()
 local r=fixture();r.relics={'ceramic_fish','molten_egg','toxic_egg','frozen_egg'}
 local ids=H.Copy(r.data.cards.sourcePools.colorlessRaw);local rng=Run.roomStreams(r,r.floor).shuffleRng
 -- A prior consumer changes the current canonical pool; do not reconstruct it.
 ids[1],ids[35]=ids[35],ids[1];r.colorlessCardPool={act=2,cards=H.Copy(ids)}
 local cardRng,rarity=H.Copy(r.cardRng),r.cardRarityOffset
 for i=1,2 do
  R.shuffle(rng,ids);local expected=firstUncommon(r,ids);local before=#r.deck
  assert(Nodes.chooseEvent(r,'card'));eq(#r.deck,before+1);eq(r.deck[#r.deck].cardId,expected)
  eq(r.deck[#r.deck].upgraded,true);same(r.colorlessCardPool.cards,ids)
  same(r.nodeFlow.event.shuffleRng,rng)
 end
 eq(r.hp,67);eq(r.gold,118);same(r.cardRng,cardRng);eq(r.cardRarityOffset,rarity)
end)
test('stale act pool resets, malformed full pool and missing selected card refuse without reroll',function()
 local r=fixture();r.colorlessCardPool={act=1,cards={'broken'}}
 assert(Nodes.chooseEvent(r,'card'));eq(r.colorlessCardPool.act,2);eq(#r.colorlessCardPool.cards,35)
 r=fixture();r.colorlessCardPool={act=2,cards={'broken'}};reject(r,'card','skull_source_pool_unavailable')
 r=fixture();r.data=H.Copy(r.data);local ids=H.Copy(r.data.cards.sourcePools.colorlessRaw)
 R.shuffle(Run.roomStreams(r,r.floor).shuffleRng,ids);local selected=firstUncommon(r,ids)
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id==selected then table.remove(r.data.cards.cards,i)end end
 reject(r,'card','card_content_unavailable')
end)
test('fatal cost still grants reward; Fairy and Lizard Tail precede reward; Tungsten Ectoplasm apply',function()
 for _,spec in ipairs({{hp=6,after=0},{hp=6,fairy=true,after=24},{hp=6,relic='lizard_tail',after=40},
  {hp=6,relic='tungsten_rod',after=1},{hp=20,relic='ectoplasm',after=14}})do
  local r=fixture();r.hp=spec.hp;r.relics={}
  if spec.relic then assert(Run.obtainRelic(r,spec.relic))end
  if spec.fairy then assert(Run.obtainPotion(r,'fairy_in_a_bottle'))end
  local gold=r.gold;assert(Nodes.chooseEvent(r,'gold'));eq(r.hp,spec.after)
  eq(r.gold,spec.relic=='ectoplasm'and gold or gold+90)
  eq(r.phase,spec.after==0 and 'defeat'or'node')
 end
 local r=fixture();r.hp=6;local n=#r.deck;assert(Nodes.chooseEvent(r,'card'));eq(r.phase,'defeat');eq(#r.deck,n+1)
end)
test('late failure restores health revival pool UID RNG and costs; invalid commands are inert',function()
 local r=fixture();r.hp=6;assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 local old=H.Hooks.onObtainCard
 H.Hooks.onObtainCard=function(...)old(...);error('injected late obtain failure')end
 local ok,why=pcall(reject,r,'card','transaction_failed');H.Hooks.onObtainCard=old;assert(ok,why)
 assert(Nodes.chooseEvent(r,'card'));eq(r.hp,24);eq(r.potions[1],nil)
 r=fixture();for _,c in ipairs({'continue','bogus',false,1,{}})do reject(r,c)end
 reject(r,'gold','invalid_event_choice',1)
 r.nodeFlow.event.goldCost=2147483647;reject(r,'gold','invalid_skull_cost')
end)
test('RNG failure is not swallowed as potion-full; overflow gold transaction does not charge',function()
 local r=fixture();r.shopRng={potion={}};reject(r,'potion','transaction_failed')
 r=fixture();r.gold=2147483600;reject(r,'gold','transaction_failed')
end)
test('generic generated buttons carry original title and stale repeat actions cannot charge twice',function()
 local r,m=H.fixture('knowing_skull');local ui,get,shown,click=H.setup(r,m)
 eq(get('eventView/name').text,'问骨回声');assert(click('eventView/option1'))
 local old=ui.actions['eventView/option2'].handler
 H.parity(r,m,'gold',nil,function()return click('eventView/option2')end)
 H.unchanged(r,m,old);eq(r.hp,74)
 assert(click('eventView/option4'));eq(r.hp,68);assert(shown('eventView'))
 assert(click('eventView/option1'));eq(r.phase,'map')
end)
test('unmodified full source pool naturally enters Skull once and pays mandatory exit',function()
 local r=Run.new(H.Data,'42',{experimental=true,campaign=true});r.act,r.floor,r.gold=2,17,100
 r.unknown.pools=H.Pool.new('full',false,2)
 local counter;local Unknown=require('abyss_unknown')
 for n=0,1023 do
  local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if Unknown.advancePc(Unknown.newPc(),R.randomFloat(nextState),{})=='event'then
   local id=H.Pool.draw(H.Pool.new('full',false,2),
    {floor=18,gold=r.gold,act=2,hp=r.hp,relicCount=#r.relics,elapsedSeconds=0,cursed=false},nextState)
   if id=='Knowing Skull'then counter=n;break end
  end
 end
 assert(counter,'bounded full source draw for Knowing Skull');r.eventRng=R.atCounter(r.eventSeed,counter)
 local m=H.Map.generate(r.data,'42',2);local first=H.Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='event';node.eventId=nil end end
 local initial=#r.unknown.pools.once;assert(Nodes.enter(r,m,first.id))
 eq(r.nodeFlow.event.originalId,'Knowing Skull');eq(r.nodeFlow.event.id,'knowing_skull')
 eq(#r.unknown.pools.once,initial-1)
 for _,id in ipairs(r.unknown.pools.once)do assert(id~='Knowing Skull')end
 assert(Nodes.chooseEvent(r,'continue'));local hp=r.hp
 assert(Nodes.chooseEvent(r,'leave'));eq(r.hp,hp-6)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
print('KNOWING_SKULL_EVENT '..count..' passed')
