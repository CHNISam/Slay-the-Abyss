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
local function owner()
 local r=Run.new(F.D,1)
 -- Isolated eligibility boundary: exhaust the existing supported candidate
 -- set by ownership, never alter source queues or pretend this is natural play.
 for _,d in ipairs(r.data.relics.relics)do if d.id~='toxic_egg'and d.rarity~='starter'then r.relics[#r.relics+1]=d.id end end
 return r
end
test('initial restricted shop uses destination floor49 while source floor48 still offers Egg',function()
 local r=owner();r.floor=47;local a=Shop.prepare(r,48);r.floor=48;local b=Shop.prepare(r,49)
 local offered=false;for _,v in ipairs(a.relics)do if v.id=='toxic_egg'then offered=true end end;assert(offered,'seed1 must exercise uncommon shelf')
 for _,v in ipairs(b.relics)do assert(v.id~='toxic_egg','forbidden floor49 initial Egg')end
 -- Restock already owns the current room floor, and must enforce the same gate.
 r.floor=49;local flow=F.C.copy(a);flow.relics[1]={slot=1,id='toxic_egg',rarity='uncommon',sold=true}
 Shop.afterPurchase(r,flow,'relics',flow.relics[1]);assert(flow.relics[1].id~='toxic_egg')
end)
test('restricted treasure uses actual destination floor for48/49 rather than previous room floor',function()
 for _,floor in ipairs({48,49})do
  local r=owner();r.floor=floor-1;local m=F.Map.generate(F.D,1);local id=F.Map.available(m)[1].id
  for _,n in ipairs(m.nodes)do if n.id==id then n.type='treasure';n.floor=floor end end
  m.firstFloor,m.floor=floor,floor-1
  assert(Nodes.enter(r,m,id));F.eq(r.nodeFlow.reward.relicId=='toxic_egg',floor==48)
 end
end)
print('TOXIC_EGG_ELIGIBILITY '..pass..' passed; '..fail..' failed');assert(fail==0)
