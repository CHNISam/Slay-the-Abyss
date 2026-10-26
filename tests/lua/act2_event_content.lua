-- Real public Nodes commands, not native UI or a natural Act2 playthrough.
local C=require('abyss_combat')
local Run=require('abyss_run')
local Map=require('abyss_map')
local Nodes=require('abyss_nodes')
local Pool=require('abyss_event_pool')
local R=require('abyss_sts_random')
local Unknown=require('abyss_unknown')
local Curses=require('abyss_curses')
local Data=require('abyss_data')
local COST=BEGGAR_SOURCE_CONTRACT and BEGGAR_SOURCE_CONTRACT.goldCost or 75
local base=Run.new(Data,'42',{experimental=true,campaign=true})
base.act,base.floor=2,17
base.unknown.pools=Pool.new('full',false,2)
local baseMap=Map.generate(base.data,'42',2)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 if a==b then return end
 path=path or 'state';eq(type(a),type(b))
 if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function snapshot(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(deck,gold,unentered)
 local r,m=snapshot(base),C.copy(baseMap)
 if deck then r.deck=C.copy(deck)end
 r.gold=gold or 100
 local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not unentered and 'beggar' or nil end end
 if not unentered then assert(Nodes.enter(r,m,n.id))end
 return r,m,n.id
end
local function reject(r,choice,uid,expected)
 local before=snapshot(r);local deck,event,flow=r.deck,r.nodeFlow.event,r.nodeFlow
 local ok,why=Nodes.chooseEvent(r,choice,uid)
 eq(ok,false);if expected then eq(why,expected)end
 same(r,before);eq(r.deck,deck);eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event)
end
local function paid(deck,gold)
 local r,m=fixture(deck,gold)
 assert(Nodes.chooseEvent(r,'donate'));eq(r.gold,(gold or 100)-COST)
 return r,m
end
local function selecting(deck,gold)
 local r,m=paid(deck,gold)
 local ok,why=Nodes.chooseEvent(r,'confirm');assert(ok);eq(why,'choose_card')
 return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS act2 content '..count..' '..name)end

test('Intro donation gold bounds match 75 exactly and are view-only',function()
 eq(Pool.contentId.Beggar,'beggar')
 for _,gold in ipairs({0,74,75,76,999})do
  local r,m=fixture(nil,gold);local before=snapshot(r)
  local options=Nodes.view(r,m).node.event.options
  eq(#options,2);eq(options[1].choice,'donate');eq(options[1].enabled,gold>=COST);eq(options[2].choice,'leave')
  eq(r.nodeFlow.event.stage,'intro');same(r,before)
  if gold<COST then reject(r,'donate',nil,'insufficient_gold')
  else assert(Nodes.chooseEvent(r,'donate'));eq(r.gold,gold-COST);eq(r.nodeFlow.event.stage,'gave_money');eq(r.phase,'node')end
 end
end)

test('Ignore has its own farewell and never gains a relic or spends a resource',function()
 local r,m=fixture();local before=snapshot(r)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.nodeFlow.event.stage,'leave');eq(r.phase,'node')
 eq(#Nodes.view(r,m).node.event.options,1);reject(r,'donate',nil,'invalid_event_choice')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 same(r.deck,before.deck);same(r.relics,before.relics);same(r.potions,before.potions)
 eq(r.hp,before.hp);eq(r.maxHp,before.maxHp);eq(r.gold,before.gold);same(r.eventRng,before.eventRng);same(r.miscRng,before.miscRng)
 reject(r,'leave',nil,'no_pending_node')
end)

test('Donation is committed once and cannot shortcut directly into UID removal',function()
 local r,m=fixture();reject(r,'donate',r.deck[1].uid,'invalid_event_choice');reject(r,'purge',r.deck[1].uid,'invalid_event_choice')
 local before=snapshot(r);assert(Nodes.chooseEvent(r,'donate'))
 eq(r.gold,before.gold-COST);same(r.deck,before.deck);same(r.relics,before.relics);same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng)
 eq(#Nodes.view(r,m).node.event.options,1);eq(Nodes.view(r,m).node.event.options[1].choice,'confirm')
 reject(r,'donate',nil,'invalid_event_choice');reject(r,'leave',nil,'invalid_event_choice');reject(r,'confirm',r.deck[1].uid,'invalid_event_choice')
 local saved=snapshot(r);local ok,why=Nodes.chooseAct2EventCard(r,r.deck[1].uid);eq(ok,false);eq(why,'invalid_event_choice');same(r,saved)
end)

test('Second confirmation opens exactly one mandatory purge and rejects zero/cancel/leave',function()
 local r,m=selecting();local before=snapshot(r);local event=Nodes.view(r,m).node.event
 eq(r.phase,'node');eq(r.nodeFlow.event.stage,'choose_card');eq(event.selection.count,1)
 eq(event.selection.canCancel,false);eq(event.selection.forPurge,true);eq(event.selection.anyNumber,false)
 eq(#event.options,1);eq(event.options[1].choice,'purge');eq(event.options[1].picker,'beggar_purge');same(r,before)
 for _,choice in ipairs({'confirm','donate','cancel','leave'})do reject(r,choice,nil,'invalid_event_choice')end
 reject(r,'purge',nil,'invalid_card');reject(r,'purge',0,'invalid_card')
end)

test('Detached view filters all bottles and protected curses with stable master-deck order',function()
 local r,m=selecting({{uid=7,cardId='strike'},{uid=8,cardId='strike',upgraded=true},{uid=9,cardId='parasite'},
  {uid=10,cardId='strike',inBottleFlame=true},{uid=11,cardId='defend',inBottleLightning=true},
  {uid=12,cardId='bash',inBottleTornado=true},{uid=13,cardId='Necronomicurse'},
  {uid=14,cardId='CurseOfTheBell'},{uid=15,cardId='AscendersBane'}})
 local before=snapshot(r);local view=Nodes.view(r,m);eq(#view.node.event.purgeCards,3)
 for i,uid in ipairs({7,8,9})do eq(view.node.event.purgeCards[i].uid,uid)end
 view.node.event.purgeCards[1].cardId='parasite';view.node.event.selection.canCancel=true;view.node.event.options[1].enabled=false
 same(r,before)
 for _,uid in ipairs({10,11,12,13,14,15})do reject(r,'purge',uid,'card_not_purgeable')end
end)

test('Selected UID survives deck reorder and canonical Parasite removal hooks run exactly once',function()
 local r,m=selecting({{uid=7,cardId='strike'},{uid=8,cardId='strike',upgraded=true},{uid=9,cardId='parasite'}})
 r.hp,r.maxHp=80,80;r.nextDeckUid=20
 local before=snapshot(r);eq(Nodes.view(r,m).node.event.purgeCards[3].uid,9)
 r.deck[1],r.deck[3]=r.deck[3],r.deck[1]
 assert(Nodes.chooseAct2EventCard(r,9));eq(r.phase,'map');eq(r.nodeFlow.complete,true);eq(r.nodeFlow.event.removedUid,9)
 eq(#r.deck,2);eq(r.deck[1].uid,8);eq(r.deck[1].upgraded,true);eq(r.deck[2].uid,7)
 eq(r.maxHp,77);eq(r.hp,77);eq(r.gold,before.gold);eq(r.nextDeckUid,20);same(r.relics,before.relics)
 same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 reject(r,'purge',9,'no_pending_node')
end)

test('Stale UID cannot select a replacement position and fresh choice recovers',function()
 local r,m=selecting({{uid=7,cardId='strike'},{uid=8,cardId='defend'}})
 eq(Nodes.view(r,m).node.event.purgeCards[1].uid,7);table.remove(r.deck,1)
 reject(r,'purge',7,'invalid_card');eq(Nodes.view(r,m).node.event.purgeCards[1].uid,8)
 assert(Nodes.chooseAct2EventCard(r,8));eq(#r.deck,0);eq(r.gold,25)
end)

test('Duplicate identities and wrong typed UIDs fail with complete state/reference purity',function()
 local r=selecting({{uid=7,cardId='strike'},{uid=7,cardId='defend'}})
 reject(r,'purge',7,'invalid_card')
 for _,uid in ipairs({'7',true,{},-1,999})do reject(r,'purge',uid,'invalid_card')end
end)

test('Removal hook exception rolls back removal but not the previous donation and supports fresh recovery',function()
 local r,m=selecting({{uid=7,cardId='parasite'}});r.hp,r.maxHp=80,80
 local original=Curses.onRemove
 Curses.onRemove=function(staged,card)
  original(staged,card);staged.gold=999;R.randomInt(staged.miscRng,99);error('bounded Beggar remove failure')
 end
 reject(r,'purge',7,'transaction_failed');eq(r.gold,25);eq(r.nodeFlow.event.stage,'choose_card')
 Curses.onRemove=original
 local fresh=Nodes.view(r,m);eq(fresh.node.event.purgeCards[1].uid,7)
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.gold,25);eq(r.maxHp,77);eq(r.hp,77);eq(#r.deck,0)
end)

test('Missing card content rejects later removal without refund then recovers against fresh data',function()
 local r,m=selecting({{uid=7,cardId='strike'}});local original=r.data
 r.data=C.copy(r.data)
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id=='strike' then table.remove(r.data.cards.cards,i)end end
 reject(r,'purge',7,'card_content_unavailable');eq(r.gold,25);eq(r.phase,'node')
 r.data=original;eq(Nodes.view(r,m).node.event.purgeCards[1].uid,7)
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.gold,25);eq(#r.deck,0)
end)

test('Empty purge groups still permit payment and confirmation but remain explicitly pending',function()
 for _,deck in ipairs({{},{{uid=7,cardId='strike',inBottleFlame=true}},{{uid=7,cardId='Necronomicurse'}}})do
  local r,m=selecting(deck,75);local before=snapshot(r);local event=Nodes.view(r,m).node.event
  eq(r.gold,0);eq(r.phase,'node');eq(r.nodeFlow.complete,false);eq(event.pendingBoundary,'empty_purge_group_source_unproven')
  eq(#event.purgeCards,0);eq(event.selection.canCancel,false);eq(event.selection.count,1);eq(event.options[1].enabled,false);same(r,before)
  reject(r,'purge',nil,'invalid_card');reject(r,'cancel',nil,'invalid_event_choice');reject(r,'leave',nil,'invalid_event_choice');reject(r,'donate',nil,'invalid_event_choice')
 end
end)

test('A stale bottled candidate cannot bypass current legality or end an empty mandatory picker',function()
 local r,m=selecting({{uid=7,cardId='strike'}});eq(#Nodes.view(r,m).node.event.purgeCards,1)
 r.deck[1].inBottleFlame=true;reject(r,'purge',7,'card_not_purgeable')
 eq(Nodes.view(r,m).node.event.pendingBoundary,'empty_purge_group_source_unproven')
 r.deck[1].inBottleFlame=nil;local fresh=Nodes.view(r,m);eq(#fresh.node.event.purgeCards,1);eq(fresh.node.event.pendingBoundary,nil)
 assert(Nodes.chooseAct2EventCard(r,7));eq(r.gold,25)
end)

-- Search only test input stream positions. Production performs one source draw,
-- never reweights, retries or drops unsupported entries to find Beggar.
local function sourceDraw(counter)
 local rng=R.atCounter(base.eventSeed,counter);local nextRng=R.cloneState(rng)
 local chances=Unknown.newPc();local kind=Unknown.advancePc(chances,R.randomFloat(nextRng),{})
 if kind~='event' then return nil end
 return Pool.draw(Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},
  R.atCounter(base.eventSeed,nextRng.counter))
end

test('Actual full-pool source draw reaches Beggar without altering the 13-entry source pool',function()
 local expected={'Addict','Back to Basics','Beggar','Colosseum','Cursed Tome','Drug Dealer','Forgotten Altar','Ghosts','Masked Bandits','Nest','The Library','The Mausoleum','Vampires'}
 same(Pool.new('full',false,2).act,expected)
 local counter
 for n=0,63 do if sourceDraw(n)=='Beggar' then counter=n;break end end
 assert(counter,'bounded full-pool Beggar input missing')
 local r,m,id=fixture(nil,100,true);r.eventRng=R.atCounter(r.eventSeed,counter)
 assert(Nodes.enter(r,m,id));eq(r.nodeFlow.event.id,'beggar');eq(r.nodeFlow.event.originalId,'Beggar')
 eq(#r.unknown.pools.act,12);eq(#r.unknown.pools.shrine,6);eq(#r.unknown.pools.once,13)
 eq(r.eventRng.counter,counter+1);eq(r.nodeFlow.selectionRng.counter,counter+3)
 local p=Pool.new('restricted-seven');eq(#p.act+#p.shrine+#p.once,7)
end)

test('Unsupported full-pool content fails closed with no reroll, depletion, map or RNG commit',function()
 local counter
 for n=0,63 do local id=sourceDraw(n);if id and not Pool.contentId[id] then counter=n;break end end
 assert(counter,'bounded unsupported input missing')
 local r,m,id=fixture(nil,100,true);r.eventRng=R.atCounter(r.eventSeed,counter)
 local before,map=snapshot(r),C.copy(m);local flow,deck,pools=r.nodeFlow,r.deck,r.unknown.pools
 local ok,why=Nodes.enter(r,m,id);eq(ok,false);eq(why,'event_not_implemented')
 same(r,before);same(m,map);eq(r.nodeFlow,flow);eq(r.deck,deck);eq(r.unknown.pools,pools)
end)

test('Legacy picker command fallback remains fail-closed and formal campaign entry remains gated',function()
 local r=selecting({{uid=7,cardId='strike'}})
 -- Until PR228 integration, legacy/unknown picker dispatch must not become a
 -- second removal path or optional completion for this new event.
 local before=snapshot(r);eq(Nodes.purifyEvent(r,7),false);same(r,before)
 local ordinary=Run.new(Data,'42');ordinary.act=2
 local saved=snapshot(ordinary);local ok,why=Run.startRoomCombat(ordinary,'normal')
 eq(ok,false);eq(why,'act_content_unavailable');same(ordinary,saved)
 local default=Run.new(Data,'42');eq(default.campaign,nil);eq(default.act,nil)
end)
print('ACT2_EVENT_CONTENT '..count..' passed')
