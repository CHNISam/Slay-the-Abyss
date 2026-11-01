local F=dofile('tests/lua/support/toxic_egg_fixture.lua');local Run,Nodes=F.Run,F.Nodes
local P,Shop=require('abyss_relic_pool'),require('abyss_shop')
local pass,fail=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(why))end end
test('complete source queue consumes the forbidden first Egg at49 and keeps48/endless source eligibility',function()
 for _,case in ipairs({{48,false,true},{49,false,false},{49,true,true}})do
  local p=P.new('8',F.D.relicSource);F.eq(P.rollTier(p,'event'),'uncommon')
  local id,trace=P.screenless(p,'uncommon',{floor=case[1],endless=case[2],room='event',act=3,owned={},deck={}})
  F.eq(id=='Toxic Egg 2',case[3]);F.eq(trace[1].id,'Toxic Egg 2')
  if not case[3]then F.eq(#trace,2);F.eq(trace[2]['end'],true)end
 end
end)
local function owner(fromTail)
 local r=Run.new(F.D,1)
 -- Explicit full-queue component checkpoint, never natural seed1 acquisition.
 -- Keep every source identity and definition; only move Egg to the tested end.
 local snapshot=P.snapshot(r.relicPool);local before=snapshot.queues.uncommon
 local queue,found={},false
 for _,id in ipairs(before)do
  if id=='Toxic Egg 2' then assert(not found);found=true
  elseif id~='InkBottle' then queue[#queue+1]=id end
 end
 assert(found and #queue==#before-2)
 queue[#queue+1]='InkBottle' -- always-eligible, unavailable fallback identity.
 if fromTail then queue[#queue+1]='Toxic Egg 2'else table.insert(queue,1,'Toxic Egg 2')end
 F.eq(#queue,#before);snapshot.queues.uncommon=queue
 r.relicPool=P.restore(snapshot,r.relicPool.catalog)
 -- Run/map seed1 is retained; the merchant component uses the independent
 -- seed42 checkpoint whose first relic-tier roll is77 (Uncommon).
 r.shopRng={merchant=F.R.fromSeed('42'),potion=F.R.fromSeed(r.eventSeed)}
 return r
end
test('initial source shop uses destination floor49 while source floor48 still offers Egg',function()
 local r=owner(true);r.floor=47;local a=Shop.prepare(r,48);r.floor=48;local b=Shop.prepare(r,49)
 local offered=false;for _,v in ipairs(a.relics)do if v.id=='toxic_egg'then offered=true end end;assert(offered,'seed1 Run with explicit merchant checkpoint must exercise uncommon shelf')
 for _,v in ipairs(b.relics)do assert(v.id~='toxic_egg','forbidden floor49 initial Egg')end
 F.eq(a.relics[1].sourceId,'Toxic Egg 2');F.eq(b.relics[1].sourceId,'InkBottle')
 F.eq(#b.relics[1].sourceTrace,2);F.eq(b.relics[1].sourceTrace[1].id,'Toxic Egg 2')
 F.same(F.R.snapshot(a.shopRng.merchant),F.R.snapshot(b.shopRng.merchant))
 -- Restock already owns the current room floor, and must enforce the same gate.
 assert(Run.obtainRelic(r,'courier')) -- Explicit existing Courier component owner.
 r.floor=49;local flow=F.C.copy(a);flow.relics[1]={slot=1,id='toxic_egg',rarity='uncommon',sold=true}
 flow.shopRng.merchant=F.R.fromSeed('0') -- independent next tier72: exercise Uncommon gate.
 Shop.afterPurchase(r,flow,'relics',flow.relics[1]);assert(flow.relics[1].id~='toxic_egg')
 F.eq(flow.relics[1].sourceId,'InkBottle');F.eq(#flow.relics[1].sourceTrace,2)
 F.eq(flow.relics[1].sourceTrace[1].id,'Toxic Egg 2');F.eq(flow.shopRng.merchant.counter,2)
end)
test('opened source treasure uses actual destination floor for48/49 rather than previous room floor',function()
 for _,floor in ipairs({48,49})do
  local r=owner();r.floor=floor-1;local m=F.Map.generate(F.D,1);local id=F.Map.available(m)[1].id
  -- Independent seed1 counter6 has constructor rolls63/84: Medium/Uncommon,
  -- no gold. This is a legal staged checkpoint, not a first-room route claim.
  r.treasureRng=F.R.atCounter(r.eventSeed,6)
  for _,n in ipairs(m.nodes)do if n.id==id then n.type='treasure';n.floor=floor end end
  m.firstFloor,m.floor=floor,floor-1
  assert(Nodes.enter(r,m,id));F.eq(r.nodeFlow.chest.opened,false);F.eq(r.nodeFlow.reward.relicId,nil)
  F.eq(r.treasureRng.counter,8);local rng=F.R.snapshot(r.treasureRng)
  assert(Nodes.openTreasure(r));F.eq(r.nodeFlow.chest.kindRoll,63);F.eq(r.nodeFlow.chest.rewardRoll,84)
  F.eq(r.nodeFlow.reward.relicId=='toxic_egg',floor==48)
  F.same(F.R.snapshot(r.treasureRng),rng)
  if floor==49 then F.eq(r.nodeFlow.reward.relicSourceId,'InkBottle')end
 end
end)
print('TOXIC_EGG_ELIGIBILITY '..pass..' passed; '..fail..' failed');assert(fail==0)
