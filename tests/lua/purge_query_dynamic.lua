package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Wall,Boss,Run,D,R=require('abyss_living_wall'),require('abyss_boss_relics'),require('abyss_run'),require('abyss_data'),require('abyss_sts_random')
local function eq(a,b,label)assert(a==b,'[PURGE_QUERY_DYNAMIC] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local original=Wall.purgeCards;local calls=0
Wall.purgeCards=function(owner)calls=calls+1;return {}end
local flow={event={}};local owner={deck={{uid=1,cardId='strike'}}}
local ok,why=Wall.choose(owner,flow,'forget',nil,function()return false end,function()return {}end)
eq(ok,true);eq(why,'complete');eq(flow.event.empty,true);eq(calls,1,'choose observes public replacement')
Wall.purgeCards=nil;eq(Wall.purgeCards,nil,'ordinary nil read');Wall.purgeCards=original;eq(Wall.purgeCards,original,'ordinary restoration')
local sentinel={};Wall.purgeCards=function()error(sentinel)end
local called,reason=pcall(Wall.choose,owner,{event={}},'forget',nil,function()return false end,function()return {}end)
Wall.purgeCards=original;eq(called,false);eq(reason,sentinel,'choose preserves query error object')
local run=Run.new(D,'42');local deckCount=#run.deck;local before=R.snapshot(run.miscRng)
Wall.purgeCards=function(staged)calls=calls+1;assert(staged~=run,'[PURGE_QUERY_DYNAMIC] Run owns private staged graph');return {}end
local called,ok,why=pcall(Run.obtainRelic,run,'empty_cage');Wall.purgeCards=original
assert(called,ok);eq(ok,true);eq(#run.deck,deckCount,'Boss observes empty replacement');eq(run.pendingBossRelic,nil);eq(calls,2)
local after=R.snapshot(run.miscRng);eq(after.counter,before.counter);eq(table.concat(after.words,','),table.concat(before.words,','),'no RNG for empty selection')
local nextRun=Run.new(D,'42');assert(Run.obtainRelic(nextRun,'empty_cage'))
local uid=nextRun.deck[1].uid;local deck,pending=nextRun.deck,nextRun.pendingBossRelic
Wall.purgeCards=function()calls=calls+1;return {}end
local called,ok,why=pcall(Boss.select,nextRun,uid);Wall.purgeCards=original
assert(called,ok);eq(ok,false);eq(why,'invalid_card');eq(nextRun.deck,deck,'selection refusal retains deck owner');eq(nextRun.pendingBossRelic,pending,'selection refusal retains pending owner');eq(#pending.selectedUids,0);eq(calls,3)
-- A later restored replacement must be read again, rather than captured at load.
Wall.purgeCards=function(run)calls=calls+1;return original(run)end
local called,ok,why=pcall(Boss.select,nextRun,uid);Wall.purgeCards=original
assert(called,ok);eq(ok,true,why);eq(calls,4);eq(#nextRun.pendingBossRelic.selectedUids,1)
print('PURGE_QUERY_DYNAMIC_PASS choose,BossEquip,BossSelect,stagedOwner,nilRestore,errorIdentity,warmRead calls=4')
