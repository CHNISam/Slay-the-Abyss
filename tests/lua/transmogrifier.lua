package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function fixture(deck)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 if deck then r.deck=C.copy(deck)end
 local n=Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId='transmogrifier' end end
 local ok,why=Nodes.enter(r,m,n.id);assert(ok,why);return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS transmogrifier '..count..' '..name)end
test('formal route exposes transform and leave without changing complete source pools',function()
 eq(require('abyss_event_pool').contentId.Transmorgrifier,'transmogrifier')
 local r,m=fixture();local o=Nodes.view(r,m).node.event.options
 eq(#o,2);eq(o[1].choice,'change');eq(o[2].choice,'leave')
 local before=C.copy(r);eq(Nodes.chooseEvent(r,'forget'),false);same(r,before);eq(Nodes.chooseEvent(r,'grow'),false);same(r,before)
 local context=require('abyss_event_transform_context').new(r)
 same(context.pools,dofile('tests/lua/support/living_wall_source_pools.lua'))
end)
test('real default Run transforms permanent UID through source-order misc and leaves result',function()
 local r,m=fixture({{uid=7,cardId='strike',upgraded=true},{uid=8,cardId='bash',upgraded=false,inBottleFlame=true}})
 r.miscRng=R.restore({words={'0000000000000000','0000000000000000'},counter=0})
 local before=C.copy(r);assert(Nodes.chooseEvent(r,'change'));eq(r.nodeFlow.event.stage,'choose_card')
 eq(#Nodes.view(r,m).node.event.purgeCards,1)
 local b=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,b)
 eq(Nodes.chooseAct1EventCard(r,8),false);same(r,b)
 assert(Nodes.chooseAct1EventCard(r,7));eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 eq(#r.deck,2);eq(r.deck[1].uid,8);eq(r.deck[2].uid,before.nextDeckUid);eq(r.deck[2].cardId,'anger');eq(r.deck[2].upgraded,false)
 eq(r.miscRng.counter,1);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng)
 b=C.copy(r);eq(Nodes.chooseAct1EventCard(r,7),false);same(r,b)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('ignore and empty transform retain farewell screen and do not spend entropy',function()
 for _,choice in ipairs({'leave','change'})do
  local r=fixture({});local b=C.copy(r);assert(Nodes.chooseEvent(r,choice))
  eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result');same(r.miscRng,b.miscRng);same(r.deck,b.deck)
  assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 end
end)
test('failed obtain restores old permanent objects and every RNG',function()
 local r=fixture({{uid=7,cardId='strike',upgraded=false}});assert(Nodes.chooseEvent(r,'change'))
 r.nextDeckUid=7;local b=C.copy(r);local deck,event=r.deck,r.nodeFlow.event
 eq(Nodes.chooseAct1EventCard(r,7),false);same(r,b);eq(r.deck,deck);eq(r.nodeFlow.event,event)
end)
print('TRANSMOGRIFIER '..count..' passed')
