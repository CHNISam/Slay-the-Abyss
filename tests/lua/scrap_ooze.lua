package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function state(n)return R.restore({words={'0000000000000000',string.format('%016x',n)},counter=0})end
local function fixture()
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 local n=Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId='scrap_ooze' end end
 local ok,why=Nodes.enter(r,m,n.id);assert(ok,why)
 r.relicPool.rng=state(0);local q=r.relicPool.queues.common
 for i,v in ipairs(q)do if v=='Anchor'then table.remove(q,i);break end end;table.insert(q,1,'Anchor')
 return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS scrap-ooze '..count..' '..name)end
test('real route exposes initial 3 damage 25 display then increments failures without relic RNG',function()
 eq(require('abyss_event_pool').contentId['Scrap Ooze'],'scrap_ooze')
 local r,m=fixture();r.miscRng=state(73);local b=C.copy(r)
 eq(r.nodeFlow.event.damage,3);eq(r.nodeFlow.event.chance,25);eq(#Nodes.view(r,m).node.event.options,2)
 assert(Nodes.chooseEvent(r,'search'));eq(r.hp,b.hp-3);eq(r.nodeFlow.event.damage,4);eq(r.nodeFlow.event.chance,35)
 eq(r.nodeFlow.event.totalDamage,3);eq(r.miscRng.counter,1);same(r.relicPool,b.relicPool);same(r.eventRng,b.eventRng)
 r.miscRng=state(0);assert(Nodes.chooseEvent(r,'search'));eq(r.hp,b.hp-7);eq(r.nodeFlow.event.damage,5);eq(r.nodeFlow.event.chance,45);eq(r.nodeFlow.event.totalDamage,7)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 b=C.copy(r);eq(Nodes.chooseEvent(r,'search'),false);same(r,b);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('inclusive threshold succeeds at 74 consumes one misc and one relic tier then grants exactly once',function()
 local r=fixture();r.miscRng=state(74);local b=C.copy(r)
 assert(Nodes.chooseEvent(r,'search'));eq(r.hp,b.hp-3);eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.obtainedRelicId,'anchor')
 eq(r.miscRng.counter,1);eq(r.relicPool.rng.counter,b.relicPool.rng.counter+1);eq(#r.relicPool.queues.common,#b.relicPool.queues.common-1)
 b=C.copy(r);eq(Nodes.chooseEvent(r,'search'),false);same(r,b)
end)
test('missing selected relic refuses complete operation with damage and entropy rolled back',function()
 local r=fixture();r.miscRng=state(99);r.data=C.copy(r.data)
 for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='anchor'then table.remove(r.data.relics.relics,i)end end
 local b=C.copy(r);local event,deck,pool=r.nodeFlow.event,r.deck,r.relicPool
 local ok,why=Nodes.chooseEvent(r,'search');eq(ok,false);eq(why,'relic_content_unavailable');same(r,b);eq(r.nodeFlow.event,event);eq(r.deck,deck);eq(r.relicPool,pool)
end)
test('ignoring consumes no entropy and fatal exploration settles defeat immediately',function()
 local r=fixture();local b=C.copy(r);assert(Nodes.chooseEvent(r,'leave'));same(r.miscRng,b.miscRng);same(r.relicPool,b.relicPool);eq(r.hp,b.hp)
 r=fixture();r.hp=2;r.miscRng=state(0);assert(Nodes.chooseEvent(r,'search'));eq(r.hp,0);eq(r.phase,'defeat');eq(r.nodeFlow.complete,true);eq(r.miscRng.counter,1)
 b=C.copy(r);eq(Nodes.chooseEvent(r,'search'),false);same(r,b)
end)
test('source display is not capped at 100 and the ninth zero roll is guaranteed',function()
 local r=fixture();r.hp=1000;r.maxHp=1000
 for attempt=1,8 do r.miscRng=state(0);assert(Nodes.chooseEvent(r,'search'));eq(r.nodeFlow.event.stage,nil)end
 eq(r.nodeFlow.event.chance,105);eq(r.nodeFlow.event.damage,11)
 r.miscRng=state(0);assert(Nodes.chooseEvent(r,'search'));eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.totalDamage,63);eq(r.hp,937)
end)
print('SCRAP_OOZE '..count..' passed')
