-- Fixed 319009d5 LivingWall/CardGroup contracts; explicit event fixture, not pool evidence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local data=require('abyss_data')
local count,failed=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'extra '..tostring(k)) end
end
local function test(name,fn)
 count=count+1;local ok,reason=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(reason)))
end
local function enter(deck)
 local run,map=Run.new(data,'42'),Map.generate(data,'42')
 if deck then run.deck=C.copy(deck) end
 -- Explicit supported event entry; the production restricted pool is unchanged.
 local first=Map.available(map)[1];local node
 for _,entry in ipairs(map.nodes) do if entry.id==first.id then node=entry end end
 node.type='event';node.eventId='living_wall'
 assert(Nodes.enter(run,map,node.id),'Living Wall must have a real Nodes.enter handler')
 return run,map
end
local function refuse(run,choice,uid,reason)
 local before=C.copy(run);local ok,why=Nodes.chooseEvent(run,choice,uid)
 eq(ok,false);if reason then eq(why,reason) end;same(run,before)
end
test('explicit entry exposes exactly Forget Change Grow without a free Leave',function()
 local run,map=enter();local opts=Nodes.view(run,map).node.event.options
 eq(#opts,3);for i,id in ipairs({'forget','change','grow'}) do eq(opts[i].choice,id);eq(opts[i].enabled,true) end
 refuse(run,'leave',nil,'invalid_event_choice')
end)
test('Forget commits exactly one UID including the final card, without resource or RNG writes',function()
 local run,map=enter({{uid=8,cardId='strike',upgraded=true}})
 local rng=R.snapshot(run.miscRng);local uid=run.nextDeckUid;local gold,hp=run.gold,run.hp
 assert(Nodes.chooseEvent(run,'forget'));eq(run.nodeFlow.event.stage,'choose_card')
 refuse(run,'grow',8,'invalid_event_choice');refuse(run,'forget',99,'invalid_card')
 assert(Nodes.chooseEvent(run,'forget',8));eq(#run.deck,0);eq(run.phase,'map');eq(run.nodeFlow.complete,true)
 eq(run.nextDeckUid,uid);eq(run.gold,gold);eq(run.hp,hp);same(R.snapshot(run.miscRng),rng)
 refuse(run,'forget',8,'no_pending_node')
end)
test('empty Forget and Change finish without opening a nonexistent picker or consuming misc',function()
 for _,choice in ipairs({'forget','change'}) do
  local run,map=enter({});local before=R.snapshot(run.miscRng)
  local opts=Nodes.view(run,map).node.event.options;eq(opts[1].enabled,true);eq(opts[2].enabled,true);eq(opts[3].enabled,false)
  assert(Nodes.chooseEvent(run,choice));eq(run.phase,'map');eq(run.nodeFlow.eventChoice,choice);same(R.snapshot(run.miscRng),before)
  refuse(run,choice,nil,'no_pending_node')
 end
end)
test('purge group excludes three special curses and bottles, preserving source masterDeck order',function()
 local run,map=enter({{uid=1,cardId='strike',upgraded=false},{uid=2,cardId='bash',upgraded=false,inBottleFlame=true},
  {uid=3,cardId='Necronomicurse'},{uid=4,cardId='CurseOfTheBell'},{uid=5,cardId='AscendersBane'},
  {uid=6,cardId='defend',upgraded=false}})
 local rows=Nodes.view(run,map).node.event.purgeCards;eq(#rows,2);eq(rows[1].uid,1);eq(rows[2].uid,6)
 assert(Nodes.chooseEvent(run,'forget'));refuse(run,'forget',2,'card_not_purgeable');refuse(run,'forget',3,'card_not_purgeable')
 assert(Nodes.chooseEvent(run,'forget',6));eq(#run.deck,5);eq(run.deck[1].uid,1)
end)
test('Grow upgrades the selected permanent UID, preserves identity and allows a bottled target',function()
 local run,map=enter({{uid=1,cardId='strike',upgraded=false},{uid=2,cardId='bash',upgraded=false,inBottleFlame=true}})
 assert(Nodes.chooseEvent(run,'grow'));local before=R.snapshot(run.miscRng)
 assert(Nodes.chooseEvent(run,'grow',2));eq(run.deck[2].upgraded,true);eq(run.deck[2].uid,2);eq(run.deck[2].inBottleFlame,true)
 eq(run.deck[1].upgraded,false);same(R.snapshot(run.miscRng),before);refuse(run,'grow',1,'no_pending_node')
end)
test('Grow obeys source empty-purge guard even when a bottled card could upgrade',function()
 local run,map=enter({{uid=1,cardId='strike',upgraded=false,inBottleTornado=true}})
 eq(Nodes.view(run,map).node.event.options[3].enabled,true)
 assert(Nodes.chooseEvent(run,'grow'));eq(run.phase,'map');eq(run.deck[1].upgraded,false)
end)
test('Grow rejects no-upgrade groups and stale selections atomically',function()
 local run,map=enter({{uid=1,cardId='strike',upgraded=true}})
 eq(Nodes.view(run,map).node.event.options[3].enabled,false);refuse(run,'grow',nil,'card_not_upgradeable')
 run.deck[1].upgraded=false;assert(Nodes.chooseEvent(run,'grow'));run.deck[1].upgraded=true
 refuse(run,'grow',1,'card_not_upgradeable');refuse(run,'grow',1.5,'invalid_card')
end)
local pools=dofile('tests/lua/support/living_wall_source_pools.lua')
-- All 72 original non-basic red definitions now execute; unknown source
-- results still use the atomic rejection cases below.
local notImplemented={}
local function references(root)
 local saved={}
 local function visit(value)
  if type(value)~='table' or saved[value] then return end
  local fields={};saved[value]=fields
  for key,child in pairs(value)do fields[key]=child;visit(child)end
 end
 visit(root)
 return function()
  for value,fields in pairs(saved)do
   for key,child in pairs(fields)do assert(value[key]==child,'changed reference '..tostring(key))end
   for key in pairs(value)do assert(fields[key]~=nil,'new field '..tostring(key))end
  end
 end
end
local function context(run)
 local result={pools=C.copy(pools),cards={strike={sourceId='Strike_R',category='colored'}},sourceToLocal={}}
 for _,card in ipairs(run.data.cards.cards) do
  if card.sts_name then result.sourceToLocal[card.sts_name]=card.id end
 end
 return result
end
local function state(n)
 -- Independent hand-derived XS128 vector: (a=0,b=n) -> output 2n;
 -- next bounded index is n % bound, and primitive words become n,n.
 return R.restore({words={'0000000000000000',string.format('%016x',n)},counter=7})
end
test('full 72-card source transform draws each original slot once with no unsupported reroll',function()
 local run=enter();local original=C.copy(run);local candidates={}
 for _,group in ipairs({'common','srcUncommon','srcRare'}) do for _,id in ipairs(pools[group]) do candidates[#candidates+1]=id end end
 eq(#candidates,72);eq(#pools.srcColorless,35);eq(#pools.curses,10)
 local accepted,rejected=0,0
 for i,sourceId in ipairs(candidates) do
  run=C.copy(original);run.deck={{uid=1,cardId='strike',upgraded=true}};run.nextDeckUid=20
  run.miscRng=state(i-1);run.transformContext=context(run)
  assert(Nodes.chooseEvent(run,'change'));local before=C.copy(run)
  local localId=run.transformContext.sourceToLocal[sourceId]
  local unchanged=localId and notImplemented[localId] and references(run)
  local ok,reason=Nodes.chooseEvent(run,'change',1)
  if localId and not notImplemented[localId] then
   assert(ok,reason);eq(run.deck[1].cardId,localId);eq(run.deck[1].upgraded,false);eq(run.deck[1].uid,20)
   eq(run.nextDeckUid,21);eq(run.nodeFlow.event.obtainedSourceId,sourceId);eq(run.phase,'map')
   same(R.snapshot(run.miscRng),{words={string.format('%016x',i-1),string.format('%016x',i-1)},counter=8})
   eq(run.gold,before.gold);eq(run.hp,before.hp);same(run.eventRng,before.eventRng);same(run.treasureRng,before.treasureRng)
   refuse(run,'change',1,'no_pending_node');accepted=accepted+1
  else
   eq(ok,false);eq(reason,'event_content_unavailable');same(run,before);rejected=rejected+1
   if unchanged then unchanged()end
  end
 end
 eq(accepted,72);eq(rejected,0)
 print('FULL_SOURCE_TRANSFORM slots=72 supported='..accepted..' unavailable='..rejected)
end)
test('failed transform preflight preserves old UID, next UID, all streams, and pending choice',function()
 local run=enter();run.transformContext=context(run);run.miscRng=state(0)
 assert(Nodes.chooseEvent(run,'change'))
 run.nextDeckUid=run.deck[1].uid;refuse(run,'change',1,'invalid_deck_uid')
 run.nextDeckUid=100;run.transformContext.pools.common=nil;refuse(run,'change',1,'event_content_unavailable')
 run.transformContext=nil;refuse(run,'change',1,'event_content_unavailable')
end)
test('selection rejected after removal or bottling cannot complete or spend a transform draw',function()
 local run=enter();run.transformContext=context(run);assert(Nodes.chooseEvent(run,'change'))
 run.deck[1].inBottleLightning=true;refuse(run,'change',1,'card_not_purgeable')
 table.remove(run.deck,1);refuse(run,'change',1,'invalid_card')
end)
test('Grow increments repeatable Searing Blow and persists the third upgrade damage',function()
 local run=enter({{uid=1,cardId='searing_blow',upgraded=true,upgrades=2}})
 assert(Nodes.chooseEvent(run,'grow'));assert(Nodes.chooseLivingWallCard(run,1))
 eq(run.phase,'map');eq(run.deck[1].upgrades,3);eq(run.deck[1].uid,1)
 local battle=C.new(data,{deck=run.deck,enemies={'cultist'},seed=1})
 eq(C.cardDefinition(battle,battle.hand[1]).effects[1].value,27)
end)
print('LIVING_WALL '..count..' tests, '..failed..' failed');assert(failed==0)
