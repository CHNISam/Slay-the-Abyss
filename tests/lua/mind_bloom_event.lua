package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local ok,Event=pcall(require,'abyss_mind_bloom_event')
assert(ok,'MIND_BLOOM_MISSING: source MindBloom choices are not implemented')
local Run,R,Copy=require('abyss_run'),require('abyss_sts_random'),require('abyss_copy').copy
local Data=require('abyss_data')
local vectors=dofile('tests/fixtures/mind-bloom-vectors.lua')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,k)end
end
local function test(name,fn)
 count=count+1;local passed,why=pcall(fn);if not passed then failed=failed+1 end
 print((passed and 'PASS 'or 'FAIL ')..name..(passed and ''or ': '..tostring(why)))
end
local function fixture(floor,seed)
 local run={data=Copy(Data),act=3,floor=floor or 35,phase='node',hp=11,maxHp=80,gold=99,
  deck={{uid=1,cardId='strike',upgraded=false},{uid=2,cardId='defend',upgraded=false}},nextDeckUid=3,
  relics={},relicCounters={},miscRng=R.fromSeed(seed or '42')}
 -- Controlled missing-definition boundary, not evidence of production registry.
 run.data.relics.relics[#run.data.relics.relics+1]={id='mark_of_bloom',sourceId='Mark of the Bloom',
  name='绽放印记',rarity='special',trigger='hooks',effects={}}
 run.nodeFlow={event={id='mind_bloom'},type='event',complete=false}
 Event.prepare(run,run.nodeFlow.event);return run,run.nodeFlow.event
end
local function choose(run,choice,uid)
 return Run.transaction(run,function(staged)return Event.choose(staged,staged.nodeFlow,choice,uid)end)
end
test('source option order floor modulo boundaries and view purity',function()
 for _,v in ipairs(vectors.floors)do
  local run,event=fixture(v.floor);local before=Copy(run);local rows=Event.options(run,event)
  eq(#rows,3);eq(rows[1].choice,'fight');eq(rows[2].choice,'awake');eq(rows[3].choice,v.choice)
  for _,row in ipairs(rows)do eq(row.enabled,true);assert(type(row.title)=='string'and type(row.description)=='string')end
  same(run,before);eq(event.stage,'intro');eq(run.miscRng.counter,0)
 end
end)
test('independent 24 shuffle vectors consume one misc Long and only request shared event combat',function()
 for _,v in ipairs(vectors.shuffle)do
  local run=fixture(35,v.seed);run.miscRng=R.restore(v.before)
  local before=Copy(run);local accepted,result=choose(run,'fight');assert(accepted,result);eq(result,'event_combat')
  local event=run.nodeFlow.event;eq(event.stage,'fight');same(R.snapshot(run.miscRng),v.after)
  same(event.combatRequest,{sourceEncounter=v.boss,roomClass='event',gold=50,relicTier='rare',metric='Mind Bloom Boss Battle'})
  eq(run.combat,nil);eq(run.gold,before.gold);same(run.deck,before.deck);same(run.relics,before.relics)
  eq(run.floor,35);eq(run.act,3);eq(run.hp,11)
  local saved=Copy(run);eq(choose(run,'fight'),false);same(run,saved);eq(#Event.options(run,event),0)
 end
end)
test('999 direct gold precedes two physical Normality obtains and keeps all RNG unchanged',function()
 local run=fixture(40);local before=R.snapshot(run.miscRng);local first=run.nextDeckUid
 assert(choose(run,'rich'));eq(run.gold,1098);eq(#run.deck,4)
 for i=3,4 do eq(run.deck[i].cardId,'normality');eq(run.deck[i].uid,first+i-3);eq(run.deck[i].upgraded,false)end
 same(R.snapshot(run.miscRng),before);eq(run.nodeFlow.event.stage,'result')
 local saved=Copy(run);eq(choose(run,'rich'),false);same(run,saved)
 local accepted,result=choose(run,'leave');assert(accepted);eq(result,'complete')
end)
test('Ectoplasm and Omamori zero one two counters preserve independent obtain attempts',function()
 for _,remaining in ipairs({0,1,2})do
  local run=fixture(35);run.relics={'ectoplasm','omamori'};run.relicCounters.omamori=remaining
  assert(choose(run,'rich'));eq(run.gold,99);eq(run.relicCounters.omamori,0)
  eq(#run.deck,4-remaining);eq(run.nextDeckUid,5-remaining)
 end
end)
test('healthy heals first then obtains Doubt through real permanent hooks',function()
 local run=fixture(41);run.relics={'darkstone_periapt'};local rng=R.snapshot(run.miscRng)
 assert(choose(run,'healthy'));eq(run.maxHp,86);eq(run.hp,86);eq(run.deck[3].cardId,'doubt')
 eq(run.nodeFlow.event.healed,69);same(R.snapshot(run.miscRng),rng)
 local blocked=fixture(49);blocked.relics={'mark_of_bloom','omamori'};blocked.relicCounters.omamori=1
 assert(choose(blocked,'healthy'));eq(blocked.hp,11);eq(#blocked.deck,2);eq(blocked.relicCounters.omamori,0)
end)
test('wrong late branch unknown choices stale UID and premature leave are atomic',function()
 for _,entry in ipairs({{40,'healthy'},{41,'rich'},{40,'unknown'},{40,'leave'},{40,'fight',1},{40,'awake',2}})do
  local run=fixture(entry[1]);local before=Copy(run)
  eq(choose(run,entry[2],entry[3]),false);same(run,before)
 end
end)
test('second curse failure restores earlier gold card UID and permanent hooks',function()
 local run=fixture(40);run.relics={'darkstone_periapt'};local before=Copy(run)
 local original,calls=Run.obtainCard,0
 Run.obtainCard=function(...)
  calls=calls+1;if calls==2 then return false,'injected_second_curse'end
  return original(...)
 end
 local accepted,why=choose(run,'rich');Run.obtainCard=original
 eq(accepted,false);eq(why,'injected_second_curse');eq(calls,2);same(run,before)
end)
test('late Mark obtain failure restores every earlier permanent upgrade',function()
 local run=fixture(40);local before=Copy(run);local original=Run.obtainRelic
 Run.obtainRelic=function()return false,'injected_mark'end
 local accepted,why=choose(run,'awake');Run.obtainRelic=original
 eq(accepted,false);eq(why,'injected_mark');same(run,before)
end)
test('awake delegates permanent eligibility upgrade once in deck order before Mark',function()
 assert(type(Run.canUpgradeCard)=='function'and type(Run.upgradeCard)=='function','shared permanent upgrade API missing')
 local run=fixture(40);run.deck[1].inBottleFlame=true;run.deck[2].upgraded=true;run.deck[2].upgrades=1
 local first=run.nextDeckUid;assert(Run.obtainCard(run,'searing_blow',{upgrades=3}));assert(Run.obtainCard(run,'normality'))
 local rng=R.snapshot(run.miscRng);local original=Copy(run.deck)
 assert(choose(run,'awake'));eq(run.deck[1].upgrades,1);eq(run.deck[1].inBottleFlame,true)
 eq(run.deck[2].upgrades,1);eq(run.deck[3].uid,first);eq(run.deck[3].upgrades,4)
 eq(run.deck[4].cardId,'normality');eq(run.deck[4].upgraded,false)
 eq(run.relics[#run.relics],'mark_of_bloom');same(R.snapshot(run.miscRng),rng)
 for i,c in ipairs(run.deck)do eq(c.uid,original[i].uid)end
 eq(#run.nodeFlow.event.upgradedUids,2);eq(run.nodeFlow.event.upgradedUids[1],1);eq(run.nodeFlow.event.upgradedUids[2],first)
 local hp=run.hp;eq(Run.heal(run,999),0);eq(run.hp,hp)
end)
print('MIND_BLOOM_EVENT '..count..' groups; '..failed..' failed');assert(failed==0)
