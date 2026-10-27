package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function fixture(id)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 local n=Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=id end end
 local ok,why=Nodes.enter(r,m,n.id);assert(ok,why);return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS potion event '..count..' '..name)end
test('Lab exposes its source ID and samples exactly three uniform bottles on acceptance',function()
 eq(require('abyss_event_pool').contentId.Lab,'lab')
 local r,m=fixture('lab');local b=C.copy(r);eq(#Nodes.view(r,m).node.event.options,1)
 eq(Nodes.chooseEvent(r,'leave'),false);same(r,b);assert(Nodes.chooseEvent(r,'take'))
 eq(r.nodeFlow.event.stage,'potion_rewards');eq(#r.nodeFlow.event.potionOffers,3)
 for i,id in ipairs({'flex_potion','fire_potion','colorless_potion'})do eq(r.nodeFlow.event.potionOffers[i].id,id)end
 local s=R.snapshot(r.shopRng.potion);eq(s.counter,3);eq(s.words[1],'e60fca8540413235');eq(s.words[2],'42ce675251912b41')
 same(r.miscRng,b.miscRng);same(r.eventRng,b.eventRng);same(r.cardRng,b.cardRng);eq(r.potionChanceModifier,b.potionChanceModifier)
 b=C.copy(r);eq(Nodes.chooseEvent(r,'take'),false);same(r,b)
end)
test('Lab bottle rewards are independent permanent claims with capacity retry and optional leave',function()
 local r=fixture('lab');assert(Nodes.chooseEvent(r,'take'));r.potions={[1]='block_potion',[2]='blood_potion',[3]='fruit_juice'}
 local b=C.copy(r);eq(Nodes.chooseEvent(r,'claim_2'),false);same(r,b)
 assert(Run.discardPotion(r,2));assert(Nodes.chooseEvent(r,'claim_2'));eq(r.potions[2],'fire_potion');eq(r.nodeFlow.event.potionOffers[2].claimed,true)
 b=C.copy(r);eq(Nodes.chooseEvent(r,'claim_2'),false);same(r,b)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.nodeFlow.event.stage,'result');eq(r.potions[2],'fire_potion')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('Woman retains source eligibility and exact 20 30 40 costs for one two three uniform bottles',function()
 local P=require('abyss_event_pool');eq(P.contentId['The Woman in Blue'],'woman_in_blue')
 eq(P.isEligible('The Woman in Blue',{gold=49}),false);eq(P.isEligible('The Woman in Blue',{gold=50}),true)
 for amount,cost in ipairs({20,30,40})do
  local r,m=fixture('woman_in_blue');local b=C.copy(r);eq(#Nodes.view(r,m).node.event.options,4)
  assert(Nodes.chooseEvent(r,'buy_'..amount));eq(r.gold,b.gold-cost);eq(#r.nodeFlow.event.potionOffers,amount);eq(r.shopRng.potion.counter,amount)
  eq(r.nodeFlow.event.stage,'potion_rewards');eq(#r.potions,#b.potions)
 end
 local r=fixture('woman_in_blue');r.gold=0;local b=C.copy(r)
 eq(Nodes.chooseEvent(r,'buy_1'),false);same(r,b);assert(Nodes.chooseEvent(r,'leave'));eq(r.hp,b.hp);eq(r.gold,b.gold);same(r.miscRng,b.miscRng);eq(r.shopRng,nil)
end)
test('missing generated definitions reject all payment draws and owners without reroll',function()
 for _,id in ipairs({'lab','woman_in_blue'})do
  local r=fixture(id);r.data=C.copy(r.data)
  for i=#r.data.potions.potions,1,-1 do if r.data.potions.potions[i].id=='fire_potion'then table.remove(r.data.potions.potions,i)end end
  local b=C.copy(r);local flow,potions=r.nodeFlow,r.potions
  local ok,why=Nodes.chooseEvent(r,id=='lab' and 'take' or 'buy_3');eq(ok,false);eq(why,'unknown_potion');same(r,b);eq(r.nodeFlow,flow);eq(r.potions,potions)
 end
end)
test('Sozu consumes claimed rewards after full source sampling while granting no bottles',function()
 local r=fixture('lab');assert(Run.obtainRelic(r,'Sozu'));assert(Nodes.chooseEvent(r,'take'));eq(r.shopRng.potion.counter,3)
 local b=C.copy(r);assert(Nodes.chooseEvent(r,'claim_1'));eq(r.nodeFlow.event.potionOffers[1].claimed,true);eq(r.nodeFlow.event.potionOffers[1].blocked,true)
 same(r.potions,b.potions);same(r.shopRng,b.shopRng)
end)
print('POTION_EVENTS '..count..' passed')
