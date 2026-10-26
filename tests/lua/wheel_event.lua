package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function state(n)return R.restore({words={'0000000000000000',string.format('%016x',n)},counter=0})end
local function fixture(outcome,deck)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 if deck then r.deck=C.copy(deck)end
 local n=Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId='wheel' end end
 local ok,why=Nodes.enter(r,m,n.id);assert(ok,why);r.miscRng=state(outcome)
 r.relicPool.rng=state(0);local q=r.relicPool.queues.common;for i,v in ipairs(q)do if v=='Anchor'then table.remove(q,i);break end end;table.insert(q,1,'Anchor')
 return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS wheel '..count..' '..name)end
test('forced spin consumes exactly one inclusive misc draw for each source outcome',function()
 eq(require('abyss_event_pool').contentId['Wheel of Change'],'wheel')
 for outcome=0,5 do
  local r,m=fixture(outcome);local b=C.copy(r);eq(#Nodes.view(r,m).node.event.options,1)
  eq(Nodes.chooseEvent(r,'leave'),false);same(r,b)
  assert(Nodes.chooseEvent(r,'spin'));eq(r.nodeFlow.event.outcome,outcome);eq(r.nodeFlow.event.stage,'wheel_result');eq(r.miscRng.counter,1)
  same(r.relicPool,b.relicPool);same(r.cardRng,b.cardRng);same(r.eventRng,b.eventRng)
  b=C.copy(r);eq(Nodes.chooseEvent(r,'spin'),false);same(r,b)
 end
end)
test('gold is applied at reveal while healing curse and damage wait for acceptance',function()
 for outcome=0,5 do
  if outcome~=1 and outcome~=4 then
   local r=fixture(outcome);r.hp=10;local b=C.copy(r);assert(Nodes.chooseEvent(r,'spin'))
   eq(r.gold,b.gold+(outcome==0 and 100 or 0));eq(r.hp,10);eq(#r.deck,#b.deck)
   assert(Nodes.chooseEvent(r,'accept'));eq(r.nodeFlow.event.stage,'result')
   eq(r.hp,outcome==2 and 80 or outcome==5 and 2 or 10)
   if outcome==3 then eq(r.deck[#r.deck].cardId,'decay');eq(r.deck[#r.deck].uid,b.nextDeckUid)end
   b=C.copy(r);eq(Nodes.chooseEvent(r,'accept'),false);same(r,b);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
  end
 end
end)
test('random relic is offered before optional claim and remains removed from pool on skip',function()
 for _,claim in ipairs({true,false})do
  local r=fixture(1);local before=#r.relics;assert(Nodes.chooseEvent(r,'spin'));assert(Nodes.chooseEvent(r,'accept'))
  eq(r.nodeFlow.event.stage,'relic_reward');eq(r.nodeFlow.event.relicOffer.sourceId,'Anchor');eq(#r.relics,before)
  eq(r.relicPool.rng.counter,1)
  local pool=C.copy(r.relicPool);assert(Nodes.chooseEvent(r,claim and 'claim_relic' or 'skip_relic'))
  eq(#r.relics,before+(claim and 1 or 0));same(r.relicPool,pool);eq(r.nodeFlow.event.stage,'result')
 end
end)
test('removal result locks source purge picker and removes only legal UID',function()
 local r,m=fixture(4,{{uid=7,cardId='strike',upgraded=true},{uid=8,cardId='bash',upgraded=false,inBottleFlame=true}})
 assert(Nodes.chooseEvent(r,'spin'));assert(Nodes.chooseEvent(r,'accept'));eq(r.nodeFlow.event.stage,'choose_card');eq(r.nodeFlow.event.choice,'purge')
 eq(#Nodes.view(r,m).node.event.purgeCards,1);local b=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,b)
 eq(Nodes.chooseAct1EventCard(r,8),false);same(r,b)
 assert(Nodes.chooseAct1EventCard(r,7));eq(#r.deck,1);eq(r.deck[1].uid,8);eq(r.nodeFlow.event.stage,'result')
 r=fixture(4,{});assert(Nodes.chooseEvent(r,'spin'));assert(Nodes.chooseEvent(r,'accept'));eq(r.nodeFlow.event.stage,'result')
end)
test('curse uses old Omamori and damage can settle defeat',function()
 local r=fixture(3);assert(Run.obtainRelic(r,'Omamori'));local b=C.copy(r)
 assert(Nodes.chooseEvent(r,'spin'));assert(Nodes.chooseEvent(r,'accept'));same(r.deck,b.deck);eq(r.relicCounters.omamori,1);eq(r.nextDeckUid,b.nextDeckUid)
 r=fixture(5);r.hp=1;assert(Nodes.chooseEvent(r,'spin'));assert(Nodes.chooseEvent(r,'accept'));eq(r.phase,'defeat');eq(r.hp,0)
end)
print('WHEEL_EVENT '..count..' passed')
