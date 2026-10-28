local H=dofile('tests/helpers/library_event.lua')
local eq,same,test=H.eq,H.same,H.test
local Run,Nodes,R=H.Run,H.Nodes,H.R
local function offered(r,id)
 for _,card in ipairs(r.nodeFlow.event.offers)do if card.cardId==id then return card end end
 error('missing real offered '..id)
end
local function read(r)return H.read(r)end
local function select(r,card)return Nodes.chooseEvent(r,'select',card.offerToken)end
local function reject(r,choice,token,reason)return H.reject(r,choice,token,reason or 'invalid_event_choice')end

test('intro Read/Sleep only, detached views and no intro Leave/UID bypass',function()
 local r,m=H.fixture();eq(H.Pool.contentId['The Library'],'the_library')
 local before=H.snap(r);local event=Nodes.view(r,m).node.event
 eq(#event.options,2);eq(event.options[1].choice,'read');eq(event.options[2].choice,'sleep')
 eq(event.options[1].enabled,true);eq(event.offers,nil);same(r,before)
 event.healAmount=999;event.body='mutated view';same(r,before)
 reject(r,'leave');reject(r,'cancel');reject(r,'select',1);reject(r,'read',1)
end)
test('Sleep caches binary32 .33 rounded heal at entry for source boundary maxHPs',function()
 for _,pair in ipairs({{1,0},{2,1},{3,1},{49,16},{50,17},{70,23},{72,24},{75,25},{80,26},{100,33},{2147483647,708669632}})do
  local max,amount=pair[1],pair[2];local r,m=H.fixture(nil,1,max)
  eq(r.nodeFlow.event.healAmount,amount);local before=H.snap(r)
  assert(Nodes.chooseEvent(r,'sleep'));eq(r.hp,math.min(max,1.0+amount));eq(r.nodeFlow.event.healed,r.hp-before.hp)
  eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');eq(r.nodeFlow.complete,false)
  same(r.cardRng,before.cardRng);same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng)
  eq(Nodes.view(r,m).node.event.options[1].choice,'leave');reject(r,'sleep');reject(r,'read')
  assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 end
end)
test('later maxHP changes preserve cached heal; fullHP/Bloom/Pillow and outside Magic Flower use public heal',function()
 local r=H.fixture(nil,10,80);assert(Run.increaseMaxHp(r,5));eq(r.maxHp,85);eq(r.hp,15)
 eq(r.nodeFlow.event.healAmount,26);assert(Nodes.chooseEvent(r,'sleep'));eq(r.hp,41);eq(r.nodeFlow.event.healed,26)
 for _,relics in ipairs({{}, {'regal_pillow'},{'magic_flower'},{'mark_of_bloom'},{'Mark of the Bloom'}})do
  local current=H.fixture(nil,10,80);current.relics=relics
  local calls,original=0,Run.heal
  Run.heal=function(owner,amount)calls=calls+1;eq(amount,26);return original(owner,amount)end
  assert(Nodes.chooseEvent(current,'sleep'));Run.heal=original;eq(calls,1)
  local bloom=relics[1]=='mark_of_bloom' or relics[1]=='Mark of the Bloom'
  eq(current.hp,bloom and 10 or 36)
 end
 local full=H.fixture(nil,80,80);assert(Nodes.chooseEvent(full,'sleep'));eq(full.hp,80);eq(full.nodeFlow.event.healed,0)
end)
test('failed public heal restores every owner and cached amount; same event recovers',function()
 local r=H.fixture(nil,10,80);local original=Run.heal
 Run.heal=function(owner,amount)original(owner,amount);owner.gold=999;R.randomInt(owner.miscRng,99);error('late heal failure')end
 reject(r,'sleep',nil,'transaction_failed');Run.heal=original
 assert(Nodes.chooseEvent(r,'sleep'));eq(r.hp,36)
end)
test('Read locks20 distinct source cards, no skip/decline/back; one selection then separate Leave',function()
 local r,m=H.fixture();local before=H.snap(r);local offers=read(r);eq(#offers,20)
 eq(r.nodeFlow.event.stage,'choose_offer');eq(r.phase,'node');eq(#r.deck,#before.deck)
 local snap=H.snap(r);local v=Nodes.view(r,m).node.event
 same(v.selection,{count=1,forUpgrade=false,forTransform=false,canCancel=true,forPurge=false,anyNumber=false})
 eq(#v.options,0);v.offers[1].cardId='strike';v.offers[1].upgraded=true;same(r,snap)
 for _,choice in ipairs({'leave','cancel','skip','sleep','read','decline'})do reject(r,choice)end
 for _,token in ipairs({1,true,{},'1','library:bad'})do reject(r,'select',token,'invalid_event_card')end
 reject(r,'select',nil,'invalid_event_card')
 local chosen=offers[20];assert(select(r,chosen));eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 eq(#r.deck,#before.deck+1);eq(r.deck[#r.deck].cardId,chosen.cardId);eq(r.deck[#r.deck].uid,before.nextDeckUid)
 same(r.cardRng,snap.cardRng);eq(r.cardRarityOffset,snap.cardRarityOffset)
 reject(r,'select',chosen.offerToken);reject(r,'sleep');reject(r,'read')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');reject(r,'leave',nil,'no_pending_node')
end)
test('Toxic Egg preview is detached; fresh actual obtain upgrades once and Ceramic Fish pays once',function()
 local r=H.fixture();r.relics={'toxic_egg','ceramic_fish'}
 local gold,uid,deck=r.gold,r.nextDeckUid,H.C.copy(r.deck);local previews,obtains=0,0
 local preview,obtain=H.Hooks.onPreviewObtainCard,H.Hooks.onObtainCard
 H.Hooks.onPreviewObtainCard=function(owner,card,d)previews=previews+1;eq(card.uid,nil);return preview(owner,card,d)end
 H.Hooks.onObtainCard=function(owner,card,d,api)obtains=obtains+1;eq(card.uid,uid);eq(card.upgraded,false);return obtain(owner,card,d,api)end
 read(r);eq(previews,20);eq(obtains,0);eq(r.gold,gold);eq(r.nextDeckUid,uid);same(r.deck,deck)
 local chosen=offered(r,'shockwave');eq(chosen.upgraded,true);eq(chosen.upgrades,1)
 assert(select(r,chosen));H.Hooks.onPreviewObtainCard,H.Hooks.onObtainCard=preview,obtain
 eq(previews,20);eq(obtains,1);eq(r.gold,gold+9);eq(r.nextDeckUid,uid+1)
 eq(r.deck[#r.deck].upgraded,true);eq(r.deck[#r.deck].upgrades,1);eq(chosen.uid,nil)
end)
test('Searing Blow makeCopy keeps constructor count but resets upgraded and damage, never makeStatEquivalentCopy',function()
 local r=H.fixture();r.relics={};local original=H.Hooks.onPreviewObtainCard
 H.Hooks.onPreviewObtainCard=function(owner,card,d)
  original(owner,card,d);if card.cardId=='searing_blow'then card.upgraded=true;card.upgrades=7 end
 end
 read(r);H.Hooks.onPreviewObtainCard=original
 local chosen=offered(r,'searing_blow');eq(chosen.upgrades,7);assert(select(r,chosen))
 local actual=r.deck[#r.deck];eq(actual.cardId,'searing_blow');eq(actual.upgraded,false);eq(actual.upgrades,7);eq(actual.searingBlowCopyUpgrades,7)
 local context={catalog={cards={}}};for _,d in ipairs(r.data.cards.cards)do context.catalog.cards[d.id]=d end
 eq(H.C.cardDefinition(context,actual).effects[1].value,12)
end)
test('missing or capability-rejected drawn content refuses without reroll, partial previews or RNG publication',function()
 for _,kind in ipairs({'missing','capability'})do
  local r=H.fixture();r.data=H.C.copy(r.data)
  for i=#r.data.cards.cards,1,-1 do local d=r.data.cards.cards[i]
   if d.id=='shockwave'then if kind=='missing'then table.remove(r.data.cards.cards,i)else d.effects={{op='library_unimplemented'}}end end
  end
  reject(r,'read',nil,'card_content_unavailable');eq(r.nodeFlow.event.offers,nil)
 end
end)
test('late preview exception rolls back full identity graph, pity, pools and all gameplay streams',function()
 local r=H.fixture();r.extension={shared=r.deck,cycle={}};r.extension.cycle.owner=r.extension
 local original,count=H.Hooks.onPreviewObtainCard,0
 H.Hooks.onPreviewObtainCard=function(owner,card,d)
  count=count+1;original(owner,card,d)
  if count==3 then
   owner.hp=1;owner.gold=999;owner.nextDeckUid=888;owner.relicCounters={broken=1}
   R.randomInt(owner.cardRng,99);R.randomInt(owner.miscRng,99);R.randomInt(owner.eventRng,99)
   table.remove(owner.unknown.pools.act,1);table.remove(owner.relicPool.queues.common,1)
   error('late preview')
  end
 end
 local extension=r.extension
 reject(r,'read',nil,'transaction_failed');H.Hooks.onPreviewObtainCard=original
 eq(r.extension,extension);eq(extension.shared,r.deck);eq(extension.cycle.owner,extension)
 read(r);eq(#r.nodeFlow.event.offers,20)
end)
test('late actual obtain refusal/exception or UID collision is atomic and retains offers for retry',function()
 for _,kind in ipairs({'refuse','throw','uid','overflow','gold'})do
  local r=H.fixture();r.relics={'ceramic_fish'};read(r);local token=r.nodeFlow.event.offers[1].offerToken
  local original=H.Hooks.onObtainCard
  if kind=='uid'then r.nextDeckUid=r.deck[1].uid elseif kind=='overflow'then r.nextDeckUid=9007199254740991.0
  elseif kind=='gold'then r.gold=2147483647 else
   H.Hooks.onObtainCard=function(owner,card,d,api)
    original(owner,card,d,api);owner.hp=1;R.randomInt(owner.miscRng,99);R.randomInt(owner.eventRng,99)
    if kind=='throw'then error('late obtain')end;return false,'library_late_refusal'
   end
  end
  reject(r,'select',token,(kind=='uid' or kind=='overflow') and 'invalid_deck_uid' or (kind=='throw' or kind=='gold') and 'transaction_failed' or 'library_late_refusal')
  H.Hooks.onObtainCard=original;if kind=='uid' or kind=='overflow'then r.nextDeckUid=100 elseif kind=='gold'then r.gold=100 end
  assert(Nodes.chooseEvent(r,'select',token));eq(r.nodeFlow.event.stage,'result')
 end
end)
test('source identity changed after offer refuses selection without taking a foreign or stale card',function()
 local r=H.fixture();read(r);local choice=r.nodeFlow.event.offers[1]
 r.data=H.C.copy(r.data)
 for _,d in ipairs(r.data.cards.cards)do if d.id==choice.cardId then d.sourceId='wrong source'end end
 reject(r,'select',choice.offerToken,'card_content_unavailable')
end)
test('unsupported original-V4/prepared source mapping and missing egg hooks stay honest; Sleep remains supported',function()
 for _,character in ipairs({'HT','AR','FR','RD'})do
  local r,m=H.fixture(character);eq(Nodes.view(r,m).node.event.options[1].enabled,false)
  reject(r,'read',nil,'library_source_catalog_unavailable');assert(Nodes.chooseEvent(r,'sleep'))
 end
 local prepared=require('abyss_character_profiles').prepare(H.Data,'silent')
 local legacy=Run.new(prepared,'42',{experimental=true,campaign=true})
 legacy.act,legacy.floor=2,17;legacy.unknown.pools=H.Pool.new('full',false,2)
 local map=H.Map.generate(legacy.data,'42',2);local first=H.Map.available(map)[1]
 for _,node in ipairs(map.nodes)do if node.id==first.id then node.type='event';node.eventId='the_library'end end
 assert(Nodes.enter(legacy,map,first.id));eq(legacy.data.runCardCatalog,nil)
 eq(Nodes.view(legacy,map).node.event.options[1].enabled,false);reject(legacy,'read',nil,'library_source_catalog_unavailable')
 assert(Nodes.chooseEvent(legacy,'sleep'))
 for _,egg in ipairs({'frozen_egg','Frozen Egg 2'})do
  local e=H.fixture();e.relics={egg};reject(e,'read',nil,'event_obtain_content_unavailable');assert(Nodes.chooseEvent(e,'sleep'))
 end
end)
test('full13 source pool selects The Library and removes it only once at successful room entry',function()
 local r,m,id=H.fixture(nil,nil,nil,true);local Unknown=require('abyss_unknown');local counter
 for n=0,127 do
  local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if Unknown.advancePc(Unknown.newPc(),R.randomFloat(nextState),{})=='event'then
   local source=H.Pool.draw(H.Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},R.atCounter(r.eventSeed,nextState.counter))
   if source=='The Library'then counter=n;break end
  end
 end
 assert(counter,'bounded source selection input exists');r.eventRng=R.atCounter(r.eventSeed,counter)
 local card=R.snapshot(r.cardRng)
 assert(Nodes.enter(r,m,id));eq(r.nodeFlow.event.originalId,'The Library');eq(r.nodeFlow.event.id,'the_library')
 eq(#r.unknown.pools.act,12);same(R.snapshot(r.cardRng),card)
 for _,source in ipairs(r.unknown.pools.act)do assert(source~='The Library')end
 local pools=H.C.copy(r.unknown.pools);read(r);same(r.unknown.pools,pools)
 assert(select(r,r.nodeFlow.event.offers[1]));assert(Nodes.chooseEvent(r,'leave'));same(r.unknown.pools,pools)
end)
H.finish('LIBRARY_EVENT')
