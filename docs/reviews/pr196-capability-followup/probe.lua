-- Bounded independent follow-up: real head modules; no blanket capability override.
-- Navigation/funding, explicit event and RNG are disclosed fixtures, not natural play.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local override=os.getenv('CAPABILITY_OVERRIDE')
if override then package.preload.abyss_card_capability=function()return dofile(override)end end
local Run,Map,Nodes,C,R,Cap=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_card_capability')
local data=require('abyss_data')
local Routes=dofile('tests/lua/support/map_routes.lua')
local sourcePools=dofile('tests/lua/support/living_wall_source_pools.lua')
local function eq(a,b,msg)assert(a==b,(msg or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function find(rows,id,key)for _,r in ipairs(rows)do if r[key or 'id']==id then return r end end end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function references(root)
 local saved={};local function visit(t)
  if type(t)~='table' or saved[t]then return end
  local f={};saved[t]=f;for k,v in pairs(t)do f[k]=v;visit(v)end
 end;visit(root)
 return function()for t,f in pairs(saved)do for k,v in pairs(f)do assert(t[k]==v,'changed reference '..tostring(k))end;for k in pairs(t)do assert(f[k]~=nil)end end end
end
local passed,failed=0,0
local filter=os.getenv('CASE_FILTER')
local function test(name,fn)
 if filter and not name:find(filter,1,true)then return end
 local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or'FAIL ')..name..(ok and ''or': '..tostring(why)))
end
local function enter(run,map,kind)
 if run.nodeFlow and run.nodeFlow.complete then run.nodeFlow=nil end
 local route=Routes.to(map,function(node)return node.type==kind end)
 for i=1,#route-1 do assert(Map.choose(map,route[i]))end
 assert(Nodes.enter(run,map,route[#route]))
end
local cases={{id='clash',seed=7,slot=2,price=53},{id='whirlwind',seed=16,slot=1,price=81}}
local function buyAndCamp(c)
 local run,map=Run.new(data,c.seed),Map.generate(data,c.seed)
 enter(run,map,'shop');local offer=run.nodeFlow.cards[c.slot]
 eq(offer.id,c.id);eq(offer.unavailable,false);eq(offer.price,c.price)
 local oldUid=run.nextDeckUid;local oldCount=#run.deck
 run.gold=offer.price;assert(Nodes.buyCardSlot(run,c.slot))
 eq(run.gold,0);eq(#run.deck,oldCount+1);local card=run.deck[#run.deck]
 eq(card.uid,oldUid);eq(card.cardId,c.id);eq(card.upgraded,false);eq(run.nextDeckUid,oldUid+1)
 local before=C.copy(run);local unchanged=references(run)
 local ok,why=Nodes.buyCardSlot(run,c.slot);eq(ok,false);eq(why,'item_unavailable');same(run,before);unchanged()
 assert(Nodes.leaveShop(run));enter(run,map,'camp')
 return run,map,card
end
for _,c in ipairs(cases)do
 test('channel '..c.id..' real shop -> camp -> next battle',function()
  local run,map,card=buyAndCamp(c);local uid=card.uid
  local rng=C.copy(run.cardRng);local misc=C.copy(run.miscRng)
  -- Mutation-only boundary swap reproduces the original camp blocker after
  -- a valid purchase. Baseline never sets this variable or changes the gate.
  local late=os.getenv('LATE_CAPABILITY_OVERRIDE');local original=Cap.isImplemented
  if late then Cap.isImplemented=dofile(late).isImplemented end
  local ok,why=Nodes.upgrade(run,uid);Cap.isImplemented=original
  assert(ok,why);eq(card.upgraded,true);eq(card.upgrades,1);eq(card.uid,uid)
  same(run.cardRng,rng);same(run.miscRng,misc)
  enter(run,map,'boss');eq(run.phase,'combat')
  local held=find(run.combat.hand,uid,'uid') or find(run.combat.draw,uid,'uid')
  assert(held,'same permanent UID missing in next battle');eq(held.cardId,c.id);eq(held.upgraded,true)
  print('DETAIL '..c.id..' seed='..c.seed..' slot='..c.slot..' price='..c.price..' uid='..uid..' upgrades=1')
 end)
 test('combat '..c.id..' basic/upgrade and temporary availability',function()
  local def=find(data.cards.cards,c.id);assert(Cap.isImplemented(def))
  for _,up in ipairs({false,true})do
   local state=C.new(data,{deck={{uid=1,cardId=c.id,upgraded=up}},enemies={'cultist'},seed=17})
   state.energy=3;state.enemies[1].hp=100;state.enemies[1].block=0;state.enemies[1].statuses={}
   assert(C.canPlay(state,1,1));assert(C.play(state,1,1))
   local damage=c.id=='clash'and(up and 18 or 14)or(up and 24 or 15)
   eq(state.enemies[1].hp,100-damage);eq(state.energy,c.id=='clash'and 3 or 0)
  end
  if c.id=='clash'then
   local s=C.new(data,{deck={{uid=1,cardId='clash'},{uid=2,cardId='defend'}},enemies={'cultist'},seed=17})
   local ok,why=C.canPlay(s,1,1);eq(ok,false);eq(why,'requires_only_attacks');assert(Cap.isImplemented(def))
  else
   local s=C.new(data,{deck={{uid=1,cardId='whirlwind'}},enemies={'cultist'},seed=17})
   s.energy=0;local hp=s.enemies[1].hp;assert(C.canPlay(s,1,1));assert(C.play(s,1,1));eq(s.enemies[1].hp,hp);assert(Cap.isImplemented(def))
  end
 end)
end
local flattened={};for _,name in ipairs({'common','srcUncommon','srcRare'})do for _,id in ipairs(sourcePools[name])do flattened[#flattened+1]=id end end
eq(#flattened,72)
local function transformSetup(id)
 local run,map=Run.new(data,42),Map.generate(data,42)
 local first=Map.available(map)[1];for _,node in ipairs(map.nodes)do if node.id==first.id then node.type='event';node.eventId='living_wall' end end
 assert(Nodes.enter(run,map,first.id))
 local context={pools=C.copy(sourcePools),cards={},sourceToLocal={}}
 for _,d in ipairs(run.data.cards.cards)do context.cards[d.id]={sourceId=d.sourceId or d.sts_name,category='colored'};context.sourceToLocal[d.sourceId or d.sts_name]=d.id end
 run.transformContext=context
 local definition=find(run.data.cards.cards,id);local slot
 for i,source in ipairs(flattened)do if source==definition.sourceId then slot=i end end
 -- Fixed source-pool fixture puts Clash at slot 9; the historical cross-PR
 -- probe built its own pool from data and used slot 12. Preserve source order.
 assert(slot);eq(slot,id=='clash'and 9 or 40)
 run.miscRng=R.restore({words={'0000000000000000',string.format('%016x',slot-1)},counter=7})
 assert(Nodes.chooseEvent(run,'change'))
 return run,map,slot,definition
end
for _,c in ipairs(cases)do
 test('transform '..c.id..' full72 single draw',function()
  local run,map,slot,definition=transformSetup(c.id)
  local count,uid,removed=#run.deck,run.nextDeckUid,run.deck[1].uid
  local hp,gold,event,treasure,card=run.hp,run.gold,C.copy(run.eventRng),C.copy(run.treasureRng),C.copy(run.cardRng)
  assert(Nodes.chooseLivingWallCard(run,removed))
  eq(#run.deck,count);eq(find(run.deck,removed,'uid'),nil)
  local got=run.deck[#run.deck];eq(got.cardId,c.id);eq(got.uid,uid);eq(got.upgraded,false);eq(run.nextDeckUid,uid+1)
  eq(run.nodeFlow.event.obtainedSourceId,definition.sourceId);eq(run.phase,'map');eq(run.nodeFlow.complete,true)
  same(R.snapshot(run.miscRng),{words={string.format('%016x',slot-1),string.format('%016x',slot-1)},counter=8})
  eq(run.hp,hp);eq(run.gold,gold);same(run.eventRng,event);same(run.treasureRng,treasure);same(run.cardRng,card)
  local before=C.copy(run);local unchanged=references(run);local ok,why=Nodes.chooseLivingWallCard(run,removed)
  eq(ok,false);eq(why,'no_pending_node');same(run,before);unchanged()
  print('DETAIL transform '..c.id..' fullPool=72 slot='..slot..' uid='..removed..'->'..uid..' miscCounter=7->8')
 end)
end
local invalid={
 {name='condition',change=function(d)d.condition='unknown_condition'end},
 {name='costMode',change=function(d)d.costMode='unknown_cost_mode'end},
 {name='effect',change=function(d)d.effects={{op='not_implemented'}}end},
}
for _,v in ipairs(invalid)do
 test('negative capability '..v.name,function()
  local d=C.copy(find(data.cards.cards,'strike'));v.change(d);eq(Cap.isImplemented(d),false)
 end)
 test('negative camp '..v.name..' atomic rejection',function()
  local run,map,card=buyAndCamp(cases[1]);local def=find(run.data.cards.cards,'clash');v.change(def.upgrade)
  local before=C.copy(run);local unchanged=references(run);local ok,why=Nodes.upgrade(run,card.uid)
  eq(ok,false);eq(why,'card_not_upgradeable');same(run,before);unchanged()
 end)
 test('negative transform '..v.name..' full72 atomic rejection',function()
  local run,map,slot,def=transformSetup(v.name=='costMode'and'whirlwind'or'clash');v.change(def)
  local before=C.copy(run);local unchanged=references(run);local ok,why=Nodes.chooseLivingWallCard(run,run.deck[1].uid)
  eq(ok,false);eq(why,'event_content_unavailable');same(run,before);unchanged();eq(run.miscRng.counter,7)
 end)
end
test('registered status/curse are not blanket allowed',function()
 for _,id in ipairs({'regret','dazed','slimed','wound','burn'})do
  local d=C.copy(find(data.cards.cards,id));assert(Cap.isImplemented(d),id);d.id='unknown_'..id;eq(Cap.isImplemented(d),false)
 end
end)
print('RESULT '..passed..' passed; '..failed..' failed; bounded two-card review only')
assert(failed==0,'bounded integration review failed')
