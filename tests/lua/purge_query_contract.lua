package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
-- Reuse the existing complete graph witness rather than another observer.
ABYSS_LIVING_COPY_TRACE=true
dofile('tests/lua/living_wall_copy_dependency.lua')
local Wall,Copy,R=require('abyss_living_wall'),require('abyss_copy'),require('abyss_sts_random')
local function eq(a,b,label)assert(a==b,'[PURGE_QUERY] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local keys={'Necronomicurse','CurseOfTheBell','AscendersBane','necronomicurse','curse_of_the_bell','ascenders_bane'}
local deck,metadata={},{}
for i,id in ipairs(keys)do
 deck[#deck+1]={uid=i,cardId=id}
 local localId='mapped_protected_'..i;deck[#deck+1]={uid=100+i,cardId=localId};metadata[localId]={sourceId=id}
end
for i,flag in ipairs({'inBottleFlame','inBottleLightning','inBottleTornado'})do deck[#deck+1]={uid=200+i,cardId='ordinary',[flag]=true}end
local shared={value=7};local first={uid=301,cardId='unmapped',a=shared,b=shared};first.self=first
local last={uid=302,cardId='mapped_ordinary',a=shared};metadata.mapped_ordinary={sourceId='Strike_R'}
deck[#deck+1]=first;deck[#deck+1]=last;deck[#deck+1]=first
local rng=R.fromSeed('42');local snapshot=R.snapshot(rng)
local owner={deck=deck,transformContext={cards=metadata},miscRng=rng}
local original,seen=Copy.copy,{}
Copy.copy=function(value,memo)eq(memo,nil,'independent per-card memo');seen[#seen+1]=value.uid;return original(value,memo)end
local called,rows=pcall(Wall.purgeCards,owner);Copy.copy=original;assert(called,rows)
eq(table.concat(seen,','),'301,302,301','only eligible cards copy in master order');eq(#rows,3)
eq(rows[1].a,rows[1].b,'within-card alias');eq(rows[1].self,rows[1],'cycle retained')
assert(rows[1]~=first and rows[3]~=first and rows[1]~=rows[3],'[PURGE_QUERY] repeated same source card copied independently')
assert(rows[1].a~=rows[2].a and rows[1].a~=rows[3].a and rows[1].a~=shared,'[PURGE_QUERY] each copy owns its subgraph')
rows[1].a.value=99;eq(shared.value,7);eq(rows[2].a.value,7);eq(rows[3].a.value,7)
eq(owner.deck,deck);eq(owner.transformContext.cards,metadata);eq(owner.miscRng,rng)
local after=R.snapshot(rng);eq(after.counter,snapshot.counter);eq(table.concat(after.words,','),table.concat(snapshot.words,','),'pure query RNG unchanged')
eq(#Wall.purgeCards({deck={}}),0,'empty deck')
eq(#Wall.purgeCards({deck={{uid=1,cardId='ordinary'}}}),1,'missing transformContext fallback')
eq(#Wall.purgeCards({deck={{uid=1,cardId='ordinary'}},transformContext={}}),1,'missing cards fallback')
print('PURGE_QUERY_FILTER protected=6 sourceMapped=6 bottles=3 order=301,302,301 perCardGraphs=independent')
-- The original contract dynamically reads Copy.copy for each selected card.
local sentinel={};local count=0
Copy.copy=function(value,memo)count=count+1;if count==2 then error(sentinel)end;return original(value,memo)end
local ok,why=pcall(Wall.purgeCards,owner);Copy.copy=original
eq(ok,false);eq(why,sentinel,'exact Copy error object');eq(count,2);eq(shared.value,7);eq(#deck,18,'failed query leaves deck intact')
local methods={'randomInt','randomLongHex','randomBooleanChance'};local saved={}
for _,key in ipairs(methods)do saved[key]=R[key];R[key]=function()error('[PURGE_QUERY] query consumed RNG')end end
local ok,result=pcall(Wall.purgeCards,owner)
for _,key in ipairs(methods)do R[key]=saved[key]end
assert(ok,result);eq(#result,3)
print('PURGE_QUERY_ERRORS exactCopySentinel,unchangedOwner,zeroRng PASS')
print('PURGE_QUERY_CONTRACT_PASS')
