package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,Pool,R,Q=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_encounter_queue')
local D=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local template=Map.generate(D,'42',3)
local deck={{uid=101,cardId='strike'},{uid=102,cardId='bash',upgraded=true},{uid=103,cardId='strike',inBottleFlame=true},
 {uid=201,cardId='defend'},{uid=202,cardId='madness'},{uid=301,cardId='inflame'},{uid=302,cardId='demon_form',upgraded=true}}
local function fixture(cards)
 local run=Run.new(D,'42',{experimental=true,campaign=true});local map=C.copy(template)
 run.act,run.floor=3,34;run.encounters=Q.new(run.runSeed,3);run.unknown.pools=Pool.new('full',true,3)
 run.deck=C.copy(cards or deck);run.nextDeckUid=1000
 local id=Map.available(map)[1].id
 for _,node in ipairs(map.nodes)do if node.id==id then node.type='event';node.eventId='falling' end end
 return run,map,id
end
local run,map,id=fixture();local ok,why=Nodes.enter(run,map,id);assert(ok,why)
eq(Pool.contentId.Falling,'falling');eq(run.nodeFlow.event.stage,'intro')
eq(run.nodeFlow.event.candidates.attack.uid,101);eq(run.nodeFlow.event.candidates.skill.uid,202);eq(run.nodeFlow.event.candidates.power.uid,302)
-- Independent integer oracle: room seed42+35=77, typed draws2/2/2.
same(R.snapshot(run.miscRng),{words={'58ecdcb139ff8c6b','4654e3216996cb9f'},counter=3})
local before=C.copy(run);local view=Nodes.view(run,map);eq(#view.node.event.options,1);eq(view.node.event.options[1].choice,'continue')
same(run,before);assert(Nodes.chooseEvent(run,'continue'));eq(run.nodeFlow.event.stage,'choice')
local rows=Nodes.view(run,map).node.event.options;eq(#rows,3);eq(rows[1].choice,'skill');eq(rows[2].choice,'power');eq(rows[3].choice,'attack')
assert(rows[1].enabled and rows[2].enabled and rows[3].enabled);eq(#run.deck,7)
local selected=run.nodeFlow.event.candidates.skill.uid;local rng=R.snapshot(run.miscRng)
assert(Nodes.chooseEvent(run,'skill',selected));eq(run.nodeFlow.event.stage,'result');eq(#run.deck,6)
for _,card in ipairs(run.deck)do assert(card.uid~=selected)end;same(R.snapshot(run.miscRng),rng)
assert(Nodes.chooseEvent(run,'leave'));eq(run.phase,'map');assert(run.nodeFlow.complete)
local settled=C.copy(run);eq(Nodes.chooseEvent(run,'leave'),false);same(run,settled)

for _,kind in ipairs({'skill','power','attack'})do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 local target=r.nodeFlow.event.candidates[kind];local beforeRng=R.snapshot(r.miscRng)
 assert(Nodes.chooseEvent(r,kind,target.uid));eq(r.nodeFlow.event.removedUid,target.uid);same(r.nodeFlow.event.removedCard,target);eq(#r.deck,6)
 local bottle=false;for _,c in ipairs(r.deck)do assert(c.uid~=target.uid);if c.uid==103 then bottle=c.inBottleFlame end end
 assert(bottle);same(R.snapshot(r.miscRng),beforeRng)
 local b=C.copy(r);eq(Nodes.chooseEvent(r,kind,target.uid),false);same(r,b)
end

do
 local r,m,n=fixture({{uid=7,cardId='defend'}});assert(Nodes.enter(r,m,n));eq(r.miscRng.counter,1)
 local b=C.copy(r);eq(Nodes.chooseEvent(r,'skill'),false);eq(Nodes.chooseEvent(r,'leave'),false);same(r,b)
 assert(Nodes.chooseEvent(r,'continue'));local rows=Nodes.view(r,m).node.event.options
 eq(#rows,3);assert(rows[1].enabled and not rows[2].enabled and not rows[3].enabled)
 eq(#r.deck,1);eq(r.nodeFlow.event.stage,'choice');eq(r.miscRng.counter,1)
 b=C.copy(r);eq(Nodes.chooseEvent(r,'power'),false);eq(Nodes.chooseEvent(r,'escape'),false);same(r,b)
 assert(Nodes.chooseEvent(r,'skill',7));eq(#r.deck,0)
end

do
 local cards={{uid=1,cardId='regret'},{uid=2,cardId='wound'},
  {uid=3,cardId='strike',inBottleTornado=true},{uid=4,cardId='defend',inBottleFlame=true},{uid=5,cardId='inflame',inBottleLightning=true}}
 local r,m,n=fixture(cards);assert(Nodes.enter(r,m,n));same(R.snapshot(r.miscRng),R.snapshot(R.fromSeed('77')))
 assert(Nodes.chooseEvent(r,'continue'));local rows=Nodes.view(r,m).node.event.options;eq(#rows,1);eq(rows[1].choice,'escape')
 local rng=R.snapshot(r.miscRng);assert(Nodes.chooseEvent(r,'escape'));same(r.deck,cards);same(R.snapshot(r.miscRng),rng)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end

for _,change in ipairs({'uid','upgrade','bottle','wrong_uid'})do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 local c=r.nodeFlow.event.candidates.skill;local actual
 for _,card in ipairs(r.deck)do if card.uid==c.uid then actual=card end end
 if change=='uid'then actual.uid=999 elseif change=='upgrade'then actual.upgraded=true elseif change=='bottle'then actual.inBottleLightning=true end
 local b=C.copy(r);local chosen=change=='wrong_uid' and c.uid+1 or c.uid
 local accepted,reason=Nodes.chooseEvent(r,'skill',chosen);eq(accepted,false);eq(reason,'stale_event_card');same(r,b)
end

for _,failure in ipairs({'return','throw'})do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 local before,beforeMap=C.copy(r),C.copy(m);local remove=Run.removeCard
 Run.removeCard=function(staged,uid)
  local removed=remove(staged,uid);assert(removed)
  if failure=='throw'then error('late Falling failure')end
  return false,'late_falling_failure'
 end
 local called,accepted=pcall(Nodes.chooseEvent,r,'skill');Run.removeCard=remove
 assert(called);eq(accepted,false);same(r,before);same(m,beforeMap)
end

do
 local r,m,n=fixture({{uid=1,cardId='missing_definition'}});local before,beforeMap=C.copy(r),C.copy(m)
 local accepted,reason=Nodes.enter(r,m,n);eq(accepted,false);eq(reason,'node_content_unavailable');same(r,before);same(m,beforeMap)
 local first=Run.new(D,'42');local firstMap=Map.generate(D,'42');local node=Map.available(firstMap)[1]
 for _,v in ipairs(firstMap.nodes)do if v.id==node.id then v.type='event';v.eventId='falling'end end
 before,beforeMap=C.copy(first),C.copy(firstMap);eq(Nodes.enter(first,firstMap,node.id),false);same(first,before);same(firstMap,beforeMap)
end

do
 local expected={'Falling','MindBloom','The Moai Head','Mysterious Sphere','SensoryStone','Tomb of Lord Red Mask','Winding Halls'}
 local full=Pool.new('full',true,3);same(full.act,expected);eq(#full.shrine,6);eq(#full.once,14)
end
print('ACT3_FALLING_EVENT_PASS exact typed RNG/UIDs, three choices, singleton/all-missing, bottles, stages, stale inputs and full rollback')
