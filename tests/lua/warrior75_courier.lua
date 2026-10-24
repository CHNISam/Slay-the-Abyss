-- MathUtils is external session entropy, never the run's seeded cardRng.
-- Fixed sources: CardGroup.getRandomCard(type,false), ShopScreen Courier
-- restock; libGDX MathUtils.random(range) -> RandomXS128.nextInt(range+1).
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,R,N,M,C=require('abyss_data'),require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local E,P,S=require('abyss_external_random'),require('abyss_randomxs128'),require('abyss_sts_random')
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
local function shop(courier)
 local r,m=R.new(D,42),M.generate(D,42);r.gold=10000
 if courier then r.relics[#r.relics+1]='courier'end
 while not r.nodeFlow do
  local choices=M.available(m);local found=false
  for _,node in ipairs(choices)do if node.type=='shop'then assert(N.enter(r,m,node.id));found=true;break end end
  if not found then assert(M.choose(m,choices[1].id))end
 end
 return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
test('colored Courier draws only rarity from cardRng and typed identity from external entropy',function()
 E.setReplayState(P.snapshot(P.fromSeed('6')))
 local r=shop(true);local external=E.begin();local expected=S.cloneState(r.cardRng)
 assert(S.randomInt(expected,99)==95);assert(P.nextInt(external.state,14)==4)
 assert(r.nodeFlow.cards[2].id=='clothesline');assert(N.buyCardSlot(r,1))
 assert(r.nodeFlow.cards[1].id=='clothesline','same-ID stock must remain legal')
 assert(r.nodeFlow.cards[1].price==36 and r.nodeFlow.cards[2].price==42)
 same(r.cardRng,expected);assert(r.cardRng.counter==13)
 same(E.snapshot().words,P.snapshot(external.state))
end)
test('external identity changes do not change rarity, prices or seeded card stream',function()
 local outcomes={}
 for _,v in ipairs({{'6','clothesline'},{'1','wild_strike'}})do
  E.setReplayState(P.snapshot(P.fromSeed(v[1])))
  local r=shop(true);assert(N.buyCardSlot(r,1));assert(r.nodeFlow.cards[1].id==v[2])
  assert(r.nodeFlow.cards[1].rarity=='common'and r.nodeFlow.cards[1].price==36)
  outcomes[#outcomes+1]=C.copy(r.cardRng)
 end
 same(outcomes[1],outcomes[2])
end)
test('Run.new and initial shops preserve the same session entropy owner',function()
 local before=E.snapshot();R.new(D,1);R.new(D,42);shop(true);shop(false)
 same(E.snapshot(),before)
end)
test('ordinary sales and Courier potion purchases do not draw typed identity entropy',function()
 local r=shop(false);local before=E.snapshot();assert(N.buyCardSlot(r,1));same(E.snapshot(),before)
 r=shop(true);assert(N.buyPotion(r,1));same(E.snapshot(),before)
end)
test('insufficient funds and post-identity restock faults preserve all resources and entropy',function()
 local r=shop(true);r.gold=0
 local before,entropy=C.copy(r),E.snapshot()
 assert(not N.buyCardSlot(r,1));same(r,before);same(E.snapshot(),entropy)
 r.gold=10000;r.nodeFlow.shopRng.merchant={}
 before,entropy=C.copy(r),E.snapshot()
 local ok,why=N.buyCardSlot(r,1)
 assert(not ok and why=='shop_content_unavailable');same(r,before);same(E.snapshot(),entropy)
end)
test('an invalid replay state or stale entropy transaction is rejected before mutation',function()
 local before=E.snapshot();assert(not pcall(E.setReplayState,{'bad','bad'}));same(E.snapshot(),before)
 local a,b=E.begin(),E.begin();P.nextInt(a.state,14);E.commit(a)
 before=E.snapshot();assert(not pcall(E.commit,b));same(E.snapshot(),before)
end)
print('WARRIOR75_COURIER '..count..' passed; external PC session history and native shop play remain unverified')
