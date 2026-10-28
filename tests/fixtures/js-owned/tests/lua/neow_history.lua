local H=require('abyss_neow_history')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS neow history '..n..' '..name)end
test('unknown first load and invalid or failing provider never synthesize zero or full qualification',function()
 for _,provider in ipairs({false,function()error('history offline')end,function()return {bossCount=2}end,function()return {bossCount=1,known=false}end})do
  local owner=H.new(provider);local entry,why=H.read(owner,'ironclad');eq(entry,nil);eq(why,'neow_history_unavailable');eq(next(owner.entries),nil)
 end
end)
test('explicit platform values are detached, keyed per character and cached in this host only',function()
 local calls=0;local value={bossCount=1};local owner=H.new(function(role)calls=calls+1;return role=='ironclad'and value or {bossCount=0}end)
 local entry=H.read(owner,'ironclad');eq(entry.bossCount,1);eq(entry.source,'platform-history');entry.bossCount=0;value.bossCount=0
 eq(H.read(owner,'ironclad').bossCount,1);eq(calls,1);eq(H.read(owner,'silent').bossCount,0);eq(calls,2)
 eq(H.read(H.new(),'ironclad'),nil)
end)
test('last ended run overwrites eligibility by floor rather than accumulated boss kills',function()
 local owner=H.new();local early={phase='defeat',floor=15};assert(H.finish(owner,early,'defeat'));eq(H.read(owner).bossCount,0)
 local bossLoss={phase='defeat',floor=16};assert(H.finish(owner,bossLoss,'defeat'));eq(H.read(owner).bossCount,1)
 assert(H.finish(owner,{phase='defeat',floor=3},'defeat'));eq(H.read(owner).bossCount,0)
 assert(H.finish(owner,{phase='victory',floor=17},'victory'));eq(H.read(owner).bossCount,1)
 assert(H.finish(owner,{phase='combat',floor=16},'abandon'));eq(H.read(owner).bossCount,1)
 assert(H.finish(owner,{phase='map',floor=2},'abandon'));eq(H.read(owner).bossCount,0)
end)
test('in-progress runs are not endings, duplicate result cannot overwrite later history, roles stay separate',function()
 local owner=H.new();local run={phase='combat',floor=16,character='silent'}
 eq(H.finish(owner,run,'defeat'),false);eq(H.read(owner,'silent'),nil)
 run.phase='defeat';assert(H.finish(owner,run,'defeat'));eq(H.read(owner,'silent').bossCount,1)
 assert(H.finish(owner,{phase='defeat',floor=2,character='silent'},'defeat'));eq(H.read(owner,'silent').bossCount,0)
 eq(H.finish(owner,run,'defeat'),false);eq(H.read(owner,'silent').bossCount,0);eq(H.read(owner,'ironclad'),nil)
end)
print('NEOW_HISTORY '..n..' passed')
