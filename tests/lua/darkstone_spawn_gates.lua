-- Controlled source boundary fixtures, not natural later-act acquisition.
local Run,Nodes,Map,Shop,Data=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_shop'),require('abyss_data')
local C,R=require('abyss_combat'),require('abyss_sts_random')
local Source=dofile('tests/lua/support/darkstone_source_fixture.lua')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)if a==b then return end;eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function snapshot(r)return C.copy(r,{[r.data]=r.data})end
local function stockHas(stock)
 for _,o in ipairs(stock.relics)do if o.id=='darkstone_periapt' then return o end end
end
local base=Run.new(Data,'42',{experimental=true,campaign=true})
Source.queue(base,true)
-- Full source queue component checkpoint. Independent merchant seed42 first
-- relic tier roll is77 (Uncommon), after normal card pricing/sale consumption.
local merchant=0
local function fixture(floor,kind)
 local r=snapshot(base);r.act=3;r.floor=34
 r.shopRng={merchant=R.atCounter(r.eventSeed,merchant),potion=R.fromSeed(r.eventSeed)}
 local m=Map.generate(r.data,r.runSeed,3)
 while Map.available(m)[1].floor<floor do assert(Map.choose(m,Map.available(m)[1].id))end
 r.floor=m.floor -- The previous floor, deliberately 48 before destination49.
 local next=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==next.id then n.type=kind;n.roomKind=nil end end
 if kind=='treasure'then Source.chest(r)end
 return r,m,next.id
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Darkstone spawn '..count..' '..name)end

test('direct Shop.prepare is readonly and uses current floor48/49 source eligibility',function()
 local merchantAfter
 for _,floor in ipairs({48,49})do
  local r=snapshot(base);r.floor=floor;r.shopRng={merchant=R.atCounter(r.eventSeed,merchant),potion=R.fromSeed(r.eventSeed)}
  local before=snapshot(r);local stock=Shop.prepare(r);same(r,before)
  eq(stockHas(stock)~=nil,floor==48);eq(stock.contentMode,'source-queues')
  eq(stock.relics[1].sourceId,floor==48 and 'Darkstone Periapt' or 'InkBottle')
  eq(stock.relics[1].sourceTrace[1].id,'Darkstone Periapt')
  eq(#stock.relics[1].sourceTrace,floor==48 and 1 or 2)
  eq(#stock.relics[1].sourceRejected,0)
  local after=R.snapshot(stock.shopRng.merchant)
  if merchantAfter then same(after,merchantAfter)else merchantAfter=after end
  same(R.snapshot(stock.relicPool.rng),R.snapshot(r.relicPool.rng))
  local again=Shop.prepare(r);same(stock,again);same(r,before)
 end
end)

test('actual treasure entry gates destination48/49 rather than previous run.floor',function()
 for _,floor in ipairs({48,49})do
  local r,m,id=fixture(floor,'treasure');eq(r.floor,floor-1);assert(Nodes.enter(r,m,id));eq(r.floor,floor)
  eq(r.nodeFlow.chest.opened,false);eq(r.nodeFlow.reward.relicId,nil)
  local stream=R.snapshot(r.treasureRng);eq(stream.counter,2)
  assert(Nodes.openTreasure(r));eq(r.nodeFlow.chest.kind,'medium');eq(r.nodeFlow.chest.relicTier,'uncommon')
  same(R.snapshot(r.treasureRng),stream)
  local item=Source.base(r.nodeFlow)
  if floor==48 then eq(r.nodeFlow.reward.relicId,'darkstone_periapt');assert(Nodes.claimTreasure(r));eq(r.relics[#r.relics],'darkstone_periapt')
  else
   eq(r.nodeFlow.reward.relicId,'ink_bottle');eq(r.nodeFlow.reward.gold,nil)
   eq(item.sourceId,'InkBottle');eq(#item.trace,2)
   eq(item.trace[1].id,'Darkstone Periapt');eq(item.trace[2].id,'InkBottle')
   assert(Nodes.claimTreasure(r));eq(r.relics[#r.relics],'ink_bottle')
  end
 end
end)

test('actual shop entry gates destination48/49 without mutating a prepared shelf on readback',function()
 for _,floor in ipairs({48,49})do
  local r,m,id=fixture(floor,'shop');eq(r.floor,floor-1);assert(Nodes.enter(r,m,id));eq(r.floor,floor)
  eq(stockHas(r.nodeFlow)~=nil,floor==48);local before=snapshot(r);local stock=C.copy(r.nodeFlow.relics)
  Nodes.view(r,m);Nodes.view(r,m);same(r,before);same(r.nodeFlow.relics,stock)
 end
end)

test('prepared legal offer and source/local direct obtains are not backdated canSpawn checks',function()
 local r,m,id=fixture(48,'shop');assert(Nodes.enter(r,m,id));local offer=assert(stockHas(r.nodeFlow));local slot=offer.slot
 r.gold=100000;r.floor=49 -- Explicit stale-floor adversary; same owned room offer.
 local old=offer.id;Nodes.view(r,m);eq(r.nodeFlow.relics[slot].id,old)
 assert(Nodes.buyRelic(r,offer.id));eq(r.relics[#r.relics],'darkstone_periapt')
 for _,alias in ipairs({'Darkstone Periapt','darkstone_periapt'})do
  local forced=Run.new(Data,'42');forced.floor=49;assert(Run.obtainRelic(forced,alias));eq(forced.relics[#forced.relics],'darkstone_periapt')
 end
end)
print('DARKSTONE_SPAWN_GATES '..count..' passed')
