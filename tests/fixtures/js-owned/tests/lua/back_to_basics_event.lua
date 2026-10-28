-- Public commands on source-derived state; staged room inputs, not native play.
local C,Run,Map,Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local Data,Pool,R,Unknown=require('abyss_data'),require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_unknown')
local Curses=require('abyss_curses')
local base=Run.new(Data,'42',{experimental=true,campaign=true})
local baseMap=Map.generate(base.data,'42',2)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 if a==b then return end;path=path or 'state';eq(type(a),type(b))
 if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function snap(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(deck,character,unentered)
 local r=character and Run.new(Data,'42',{experimental=true,campaign=true,character=character}) or snap(base)
 r.act,r.floor=2,17;r.unknown.pools=Pool.new('full',false,2)
 if deck then r.deck=C.copy(deck)end
 local m=C.copy(baseMap);local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not unentered and 'back_to_basics' or nil end end
 if not unentered then assert(Nodes.enter(r,m,n.id))end
 return r,m,n.id
end
local function reject(r,choice,uid,expected)
 local before=snap(r);local deck,flow,event=r.deck,r.nodeFlow,r.nodeFlow.event
 local ok,why=Nodes.chooseEvent(r,choice,uid);eq(ok,false);eq(why,expected)
 same(r,before);eq(r.deck,deck);eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event)
end
local function selecting(deck)
 local r,m=fixture(deck);local ok,why=Nodes.chooseEvent(r,'elegance');assert(ok);eq(why,'choose_card');return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS basics '..count..' '..name)end

test('intro uses two source choices without price, render writes or UID shortcuts',function()
 eq(Pool.contentId['Back to Basics'],'back_to_basics')
 for _,gold in ipairs({0,74,75,999})do
  local r,m=fixture();r.gold=gold;local before=snap(r);local e=Nodes.view(r,m).node.event
  eq(#e.options,2);eq(e.options[1].choice,'elegance');eq(e.options[1].enabled,true)
  eq(e.options[2].choice,'simplicity');eq(e.options[2].enabled,true);same(r,before)
  reject(r,'leave',nil,'invalid_event_choice');reject(r,'elegance',r.deck[1].uid,'invalid_event_choice')
  reject(r,'purge',r.deck[1].uid,'invalid_event_choice')
 end
end)
test('Elegance opens four-argument grid metadata and result needs separate Leave',function()
 local r,m=selecting({{uid=7,cardId='strike'}});r.gold=0
 local before=snap(r);local e=Nodes.view(r,m).node.event
 same(e.selection,{count=1,forUpgrade=false,forTransform=false,canCancel=true,forPurge=false,anyNumber=false})
 eq(e.options[1].picker,'basics_purge');same(r,before)
 reject(r,'cancel',nil,'invalid_event_choice');reject(r,'leave',nil,'invalid_event_choice')
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.gold,0);eq(#r.deck,0);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 eq(Nodes.view(r,m).node.event.options[1].choice,'leave');reject(r,'purge',7,'invalid_event_choice')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 reject(r,'leave',nil,'no_pending_node')
end)
test('empty or entirely protected/bottled Elegance completes selection without opening a grid',function()
 for _,deck in ipairs({{},{{uid=7,cardId='strike',inBottleFlame=true}},{{uid=7,cardId='Necronomicurse'}}})do
  local r,m=fixture(deck);local before=snap(r);assert(Nodes.chooseEvent(r,'elegance'))
  eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');same(r.deck,before.deck);eq(r.gold,before.gold)
  eq(Nodes.view(r,m).node.event.selection,nil);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 end
end)
test('all bottles and protected cards excluded; stale current legality is rechecked',function()
 local r,m=selecting({{uid=7,cardId='strike'},{uid=8,cardId='parasite'},
  {uid=9,cardId='strike',inBottleFlame=true},{uid=10,cardId='defend',inBottleLightning=true},
  {uid=11,cardId='bash',inBottleTornado=true},{uid=12,cardId='Necronomicurse'},
  {uid=13,cardId='CurseOfTheBell'},{uid=14,cardId='AscendersBane'}})
 local before=snap(r);local e=Nodes.view(r,m).node.event;eq(#e.purgeCards,2);eq(e.purgeCards[1].uid,7);eq(e.purgeCards[2].uid,8)
 e.purgeCards[1].cardId='parasite';e.selection.canCancel=false;same(r,before)
 for uid=9,14 do reject(r,'purge',uid,'card_not_purgeable')end
 r.deck[1].inBottleFlame=true;reject(r,'purge',7,'card_not_purgeable')
 table.remove(r.deck,1);reject(r,'purge',7,'invalid_card');assert(Nodes.chooseAct2EventCard(r,8));eq(r.phase,'node')
end)
test('duplicate identities and wrong typed/stale UIDs never select first match',function()
 local r=selecting({{uid=7,cardId='strike'},{uid=7,cardId='defend'}})
 reject(r,'purge',7,'invalid_card')
 for _,uid in ipairs({'7',true,{},-1,999})do reject(r,'purge',uid,'invalid_card')end
 reject(r,'purge',nil,'invalid_card')
end)
test('Parasite hook executes once, order-independent UID and unrelated owners stay unchanged',function()
 local r=selecting({{uid=7,cardId='strike'},{uid=8,cardId='strike',upgraded=true},{uid=9,cardId='parasite'}})
 r.hp,r.maxHp=80,80;r.nextDeckUid=20;local before=snap(r)
 r.deck[1],r.deck[3]=r.deck[3],r.deck[1]
 assert(Nodes.chooseAct2EventCard(r,9));eq(r.maxHp,77);eq(r.hp,77);eq(#r.deck,2)
 eq(r.deck[1].uid,8);eq(r.deck[1].upgraded,true);eq(r.deck[2].uid,7);eq(r.nextDeckUid,20)
 eq(r.gold,before.gold);same(r.relics,before.relics);same(r.potions,before.potions)
 same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 reject(r,'purge',9,'invalid_event_choice');assert(Nodes.chooseEvent(r,'leave'));eq(r.maxHp,77)
end)
test('remove-hook exception rolls back every owner and recovers from same event',function()
 local r=selecting({{uid=7,cardId='parasite'}});r.hp,r.maxHp=80,80
 local original=Curses.onRemove
 Curses.onRemove=function(staged,card)original(staged,card);staged.gold=999;R.randomInt(staged.miscRng,99);error('basics removal failure')end
 reject(r,'purge',7,'transaction_failed');Curses.onRemove=original
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.maxHp,77);eq(r.phase,'node')
end)
test('explicit remove refusal after staged mutation is not committed',function()
 local r=selecting({{uid=7,cardId='parasite'}});local original=Run.removeCard
 Run.removeCard=function(staged,uid)local ok=original(staged,uid);assert(ok);return false,'bounded_remove_refusal'end
 reject(r,'purge',7,'bounded_remove_refusal');Run.removeCard=original
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.nodeFlow.event.stage,'result')
end)
test('unavailable removal content refuses atomically without charge or completion',function()
 local r=selecting({{uid=7,cardId='strike'}});local original=r.data;r.data=C.copy(r.data)
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id=='strike'then table.remove(r.data.cards.cards,i)end end
 reject(r,'purge',7,'card_content_unavailable');r.data=original
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.nodeFlow.event.stage,'result')
end)
test('all eight actual source starter definitions upgrade; class extras do not',function()
 local seen={}
 for _,character in ipairs({'ironclad','silent','defect','watcher'})do
  local r=fixture(nil,character);local before=snap(r);local expected=0
  for _,card in ipairs(r.deck)do
   for _,def in ipairs(r.data.cards.cards)do if def.id==card.cardId and def.sourceId and (def.sourceId:match('^Strike_[RGBP]$') or def.sourceId:match('^Defend_[RGBP]$'))then expected=expected+1;seen[def.sourceId]=true end end
  end
  assert(Nodes.chooseEvent(r,'simplicity'));eq(#r.nodeFlow.event.upgradedUids,expected);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
  for i,card in ipairs(r.deck)do
   local isStarter=false;for _,uid in ipairs(r.nodeFlow.event.upgradedUids)do if uid==card.uid then isStarter=true end end
   if isStarter then eq(card.upgraded,true);eq(card.upgrades,1)else same(card,before.deck[i])end
  end
  eq(r.gold,before.gold);same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
  reject(r,'simplicity',nil,'invalid_event_choice');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 end
 local n=0;for _ in pairs(seen)do n=n+1 end;eq(n,8)
end)
test('upgraded starters excluded, bottles upgraded, BASIC/name/STRIKE/starter-deck heuristics excluded',function()
 local r=fixture({{uid=7,cardId='strike',inBottleFlame=true},{uid=8,cardId='defend',inBottleLightning=true},
  {uid=9,cardId='strike',upgraded=true,upgrades=1},{uid=10,cardId='bash'},
  {uid=11,cardId='pommel_strike'},{uid=12,cardId='defend',upgraded=true}})
 local before=snap(r);assert(Nodes.chooseEvent(r,'simplicity'))
 same(r.nodeFlow.event.upgradedUids,{7,8});eq(r.deck[1].upgrades,1);eq(r.deck[2].upgrades,1)
 eq(r.deck[1].inBottleFlame,true);eq(r.deck[2].inBottleLightning,true)
 for i=3,6 do same(r.deck[i],before.deck[i])end
 -- Even a BASIC named Strike with generic STRIKE tag is not STARTER_STRIKE.
 local other=fixture({{uid=7,cardId='pommel_strike'}});other.data=C.copy(other.data)
 for _,def in ipairs(other.data.cards.cards)do if def.id=='pommel_strike'then def.rarity='basic';def.name='Strike';def.sourceTags={'STRIKE'}end end
 assert(Nodes.chooseEvent(other,'simplicity'));eq(#other.nodeFlow.event.upgradedUids,0);eq(other.deck[1].upgraded,nil)
end)
test('zero eligible Simplicity remains a valid result then Leave',function()
 for _,deck in ipairs({{},{{uid=7,cardId='bash'}},{{uid=7,cardId='strike',upgraded=true}}})do
  local r,m=fixture(deck);local before=snap(r);assert(Nodes.chooseEvent(r,'simplicity'))
  eq(#r.nodeFlow.event.upgradedUids,0);eq(r.phase,'node');same(r.deck,before.deck)
  eq(Nodes.view(r,m).node.event.options[1].choice,'leave');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 end
end)
test('all four V4 profiles support Elegance but explicitly decline unresolved Simplicity',function()
 for _,role in ipairs({'HT','AR','FR','RD'})do
  local r,m=fixture(nil,role);eq(r.characterProfile.originalV4,true)
  local e=Nodes.view(r,m).node.event;eq(e.options[1].enabled,true);eq(e.options[2].enabled,false)
  assert(e.options[2].description:find('映射尚未确认'));reject(r,'simplicity',nil,'starter_tags_unresolved')
  local uid=r.deck[1].uid;assert(Nodes.chooseEvent(r,'elegance'));assert(Nodes.chooseAct2EventCard(r,uid))
  eq(r.nodeFlow.event.removedUid,uid);eq(r.phase,'node');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 end
end)
test('Simplicity refuses ambiguous candidate UID before any upgrade',function()
 local r=fixture({{uid=7,cardId='defend'},{uid=8,cardId='strike'},{uid=8,cardId='bash'}})
 reject(r,'simplicity',nil,'invalid_card');eq(r.deck[1].upgraded,nil)
end)
test('missing or unsupported starter upgrade content refuses before any upgrade then recovers',function()
 for _,mode in ipairs({'missing_upgrade','unsupported_upgrade','missing_definition'})do
  local r=fixture({{uid=7,cardId='defend'},{uid=8,cardId='strike'}});local original=r.data;r.data=C.copy(r.data)
  for i=#r.data.cards.cards,1,-1 do
   local def=r.data.cards.cards[i]
   if def.id=='strike'then
    if mode=='missing_upgrade'then def.upgrade={}
    elseif mode=='unsupported_upgrade'then def.upgrade={effects={{op='basics_missing_operation'}}}
    else table.remove(r.data.cards.cards,i)end
   end
  end
  reject(r,'simplicity',nil,'card_content_unavailable');eq(r.deck[1].upgraded,nil)
  r.data=original;assert(Nodes.chooseEvent(r,'simplicity'));same(r.nodeFlow.event.upgradedUids,{7,8})
 end
end)
test('production full Act2 source draw reaches new event without rewriting any pool',function()
 local source=Pool.new('full',false,2);eq(#source.act,13);eq(source.act[2],'Back to Basics')
 local counter
 for n=0,127 do
  local rng=R.atCounter(base.eventSeed,n);local nextRng=R.cloneState(rng)
  if Unknown.advancePc(Unknown.newPc(),R.randomFloat(nextRng),{})=='event' then
   local id=Pool.draw(Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},R.atCounter(base.eventSeed,nextRng.counter))
   if id=='Back to Basics'then counter=n;break end
  end
 end
 assert(counter,'bounded source input missing')
 local r,m,id=fixture(nil,nil,true);r.eventRng=R.atCounter(r.eventSeed,counter)
 assert(Nodes.enter(r,m,id));eq(r.nodeFlow.event.id,'back_to_basics');eq(r.nodeFlow.event.originalId,'Back to Basics')
 eq(#r.unknown.pools.act,12);eq(#r.unknown.pools.shrine,6);eq(#r.unknown.pools.once,13)
 eq(r.eventRng.counter,counter+1);eq(r.nodeFlow.selectionRng.counter,counter+3)
end)
test('default restricted seven and old event route retain their prior controls',function()
 local p=Pool.new('restricted-seven');eq(#p.act+#p.shrine+#p.once,7)
 for _,list in ipairs({p.act,p.shrine,p.once})do for _,id in ipairs(list)do assert(id~='Back to Basics')end end
 local r=Run.new(Data,'42');eq(r.campaign,nil);eq(r.act,nil)
end)
print('BACK_TO_BASICS_EVENT '..count..' passed')
