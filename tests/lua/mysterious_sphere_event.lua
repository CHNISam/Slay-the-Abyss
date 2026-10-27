-- Pure event-component contract. No Run/Nodes/Combat or map admission claim.
package.path='src/lua/?.lua;'..package.path
local Sphere=require('abyss_mysterious_sphere_event')
local R=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function fixture(seed)
 local run={act=3,phase='node',gold=17,hp=60,relics={'anchor'},relicPool={sentinel=true},
  monsterHpRng=R.fromSeed('99'),aiRng=R.fromSeed('123'),miscRng=R.fromSeed(seed or '6')}
 return run,{event={id='mysterious_sphere'}}
end
local function pending(run,flow,choice)
 local ok,result=Sphere.choose(run,flow,choice);eq(ok,true);eq(result,'pending')
end
local function rejected(run,flow,choice,uid)
 local a,b=Copy(run),Copy(flow);local ok,why=Sphere.choose(run,flow,choice,uid)
 eq(ok,false);eq(why,'invalid_event_choice');same(run,a);same(flow,b)
end
do
 local run,flow=fixture();local before=Copy(run)
 Sphere.prepare(run,flow.event);same(run,before)
 eq(flow.event.constructorEncounter,'2 Orb Walkers');eq(flow.event.stage,'intro')
 local event=Copy(flow.event);local options=Sphere.options(run,flow.event)
 eq(#options,2);eq(options[1].choice,'open');eq(options[2].choice,'leave')
 for _,row in ipairs(options)do eq(row.enabled,true);assert(type(row.title)=='string' and #row.title>0)end
 options[1].choice='forged';same(flow.event,event);same(run,before)
 rejected(run,flow,'fight');rejected(run,flow,'unknown');rejected(run,flow,'open',1)
 rejected(run,flow,'leave',{});pending(run,flow,'open');eq(flow.event.stage,'pre_combat')
 same(run,before);options=Sphere.options(run,flow.event);eq(#options,1);eq(options[1].choice,'fight')
 rejected(run,flow,'open');rejected(run,flow,'leave');rejected(run,flow,'fight','uid')
end
do
 local run,flow=fixture();Sphere.prepare(run,flow.event);local before=Copy(run)
 pending(run,flow,'leave');eq(flow.event.stage,'end');same(run,before)
 local options=Sphere.options(run,flow.event);eq(#options,1);eq(options[1].choice,'leave')
 rejected(run,flow,'open');rejected(run,flow,'fight');rejected(run,flow,'leave',false)
 local ok,result=Sphere.choose(run,flow,'leave');eq(ok,true);eq(result,'complete');same(run,before)
 eq(flow.event.combatRequest,nil)
end
-- Independent integer source interpretation vectors: inclusive11 outcomes.
for _,v in ipairs({{'6',45,'14fc879e54fc55f0','24ab922393e84868'},
 {'8',50,'68ecf1cacb69f37b','7c8ee6a72ed52f5f'},
 {'26',55,'590feead896ece2f','cfd09d2d902032c7'}})do
 local run,flow=fixture(v[1]);Sphere.prepare(run,flow.event);pending(run,flow,'open')
 local before=Copy(run);local prepared={owner='shared-constructor-placeholder'}
 flow.event.preparedCombat=prepared
 local ok,result=Sphere.choose(run,flow,'fight');eq(ok,true);eq(result,'event_combat')
 eq(flow.event.stage,'combat');eq(flow.event.preparedCombat,prepared)
 same(flow.event.combatRequest,{sourceEncounter='2 Orb Walkers',roomClass='event',gold=v[2],relicTier='rare'})
 same(R.snapshot(run.miscRng),{words={v[3],v[4]},counter=1})
 local actual=Copy(run);actual.miscRng=before.miscRng;same(actual,before)
 eq(run.phase,'node');eq(run.gold,17);eq(#run.relics,1)
 eq(#Sphere.options(run,flow.event),0)
 rejected(run,flow,'fight');rejected(run,flow,'open');rejected(run,flow,'leave')
end
do
 local run,flow=fixture();Sphere.prepare(run,flow.event)
 run.act=2;rejected(run,flow,'open');run.act=3
 flow.event.id='other';rejected(run,flow,'open');flow.event.id='mysterious_sphere'
 flow.event.stage='forged';rejected(run,flow,'fight');eq(#Sphere.options(run,flow.event),0)
end
print('MYSTERIOUS_SPHERE_COMPONENT 6 groups; 0 failed; bridge NOT_RUN')
