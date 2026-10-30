-- Independent real Nodes/Run integration. Controlled route/inventory fixtures,
-- not a natural campaign or native acceptance. No production handler is mocked.
local Run,N,Map,C,D=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_data')
local Pool,R,Unknown=require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_unknown')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function copy(r)return C.copy(r,{[r.data]=r.data})end
local base=Run.new(D,'42',{experimental=true,campaign=true})
local maps={Map.generate(D,'42',1),Map.generate(D,'42',2)}
local function route(map,target)
 for _,n in ipairs(Map.available(map))do
  local nextMap=C.copy(map);assert(Map.choose(nextMap,n.id))
  if n.floor==target and #n.nextIds==1 then return nextMap end
  if n.floor<target then local result=route(nextMap,target);if result then return result end end
 end
end
maps[1]=assert(route(maps[1],9));maps[2]=assert(route(maps[2],24))
local function fixture(act,id)
 local r,m=copy(base),C.copy(maps[act]);r.act,r.floor=act,m.floor
 r.encounters=require('abyss_encounter_queue').new('42',act)
 r.unknown.pools=Pool.new('full',false,act);r.gold=200;r.elapsedSeconds=900
 assert(Run.obtainRelic(r,'anchor'));assert(Run.obtainRelic(r,'vajra'))
 local available=N.available(r,m);eq(#available,1)
 local node=available[1]
 for _,n in ipairs(m.nodes)do if n.id==node.id then n.type,n.eventId='event',id end end
 return r,m,node.id
end
local function choose(r,choice,uid)local ok,why=N.chooseEvent(r,choice,uid);assert(ok,choice..': '..tostring(why))end
local function terminal(r,m)
 eq(r.phase,'map');eq(r.nodeFlow.complete,true);assert(#N.available(r,m)>0)
 local before=copy(r);assert(not N.chooseEvent(r,'leave'));same(r,before)
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS M3 completion '..count..' '..name)end
local paths={
 {'Dead Adventurer',1,{'leave','leave'}},
 {'FaceTrader',1,{'continue','touch','leave'}},
 {'Cursed Tome',2,{'read','continue','continue','continue','obtain','claim','leave'}},
 {'Drug Dealer',2,{'test_subject'}},
 {'Forgotten Altar',2,{'shed_blood','leave'}},
 {'Masked Bandits',2,{'pay','continue','continue','leave'}},
 {'Vampires',2,{'accept','leave'}},
 {'Designer',2,{'continue','full'}},
 {'Knowing Skull',2,{'continue','gold','leave','leave'}},
 {"N'loth",2,{'trade_1','leave'}},
 {'Colosseum',2,{'continue','fight'}},
}
for _,case in ipairs(paths)do test(case[1]..' sole exit reaches real map terminal',function()
 local id=assert(Pool.contentId[case[1]]);local r,m,node=fixture(case[2],id)
 assert(N.enter(r,m,node));eq(r.nodeFlow.event.id,id)
 for _,choice in ipairs(case[3])do choose(r,choice)end
 if id=='drug_dealer'or id=='designer'then
  local e=N.view(r,m).node.event;eq(e.selection.canCancel,false)
  local before=copy(r);assert(not N.chooseEvent(r,'leave'));same(r,before)
  if id=='drug_dealer'then
   eq(e.selection.count,2);local a,b=e.selectionCards[1].uid,e.selectionCards[2].uid
   assert(not N.chooseEvent(r,'transform',{a}));same(r,before)
   choose(r,'transform',{b,a});same(r.nodeFlow.event.removedUids,{b,a})
  else
   eq(e.selection.count,1);choose(r,'full_remove',e.selectionCards[1].uid);eq(r.gold,110)
  end
  choose(r,'leave')
 elseif id=='colosseum'then
  for _=1,12 do
   if r.phase~='combat'then break end
   local ok,slot=Run.obtainPotion(r,'explosive_potion');assert(ok,slot);assert(Run.usePotion(r,slot))
  end
  eq(r.lastResult.outcome,'victory');eq(r.phase,'node');eq(r.nodeFlow.event.stage,'post_combat');eq(r.rewards,nil)
  choose(r,'leave')
 end
 terminal(r,m)
end)end
-- Full source draw, not a one-entry pool. Search test stream inputs only.
local function draw(r,m,rng)
 local nextRng=R.cloneState(rng)
 if Unknown.advancePc(C.copy(r.unknown.chances),R.randomFloat(nextRng),{})~='event'then return end
 return Pool.draw(C.copy(r.unknown.pools),{floor=m.floor+1,gold=r.gold,act=r.act,hp=r.hp,relicCount=#r.relics,elapsedSeconds=r.elapsedSeconds,cursed=false},R.cloneState(nextRng))
end
test('full-pool controlled source draw keeps legal known mapping and recovers after injected missing route',function()
 local r,m,node=fixture(2,nil);local rng=R.cloneState(r.eventRng);local original
 for _=0,255 do original=draw(r,m,rng);if original=='Drug Dealer'then break end;R.randomFloat(rng)end
 eq(original,'Drug Dealer');r.eventRng=R.cloneState(rng)
 local before,map=copy(r),C.copy(m);local flow,deck,pools=r.nodeFlow,r.deck,r.unknown.pools
 local saved=Pool.contentId[original];assert(saved);Pool.contentId[original]=nil
 local ok,err=pcall(function()
  local accepted,why=N.enter(r,m,node);eq(accepted,false);eq(why,'event_not_implemented')
  same(r,before);same(m,map);eq(r.nodeFlow,flow);eq(r.deck,deck);eq(r.unknown.pools,pools)
 end)
 Pool.contentId[original]=saved;assert(ok,err)
 assert(N.enter(r,m,node));eq(r.nodeFlow.event.originalId,original)
 eq(#r.unknown.pools.act,#before.unknown.pools.act-1)
 choose(r,'jax');choose(r,'leave');terminal(r,m)
end)
print('M3_EVENT_COMPLETION_ROUTES '..count..' passed')
