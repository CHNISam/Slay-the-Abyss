local Run,D=require('abyss_run'),require('abyss_data')
local vectors=dofile('tests/fixtures/sts1-class-relic-pool-vectors.lua').ironclad.cases
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
for _,case in ipairs(vectors)do
 local r=Run.new(D,case.seed);same(r.relicPool.queues,case.queues);assert(r.relicPool.rng.counter==5)
end
for _,role in ipairs({'HT','AR','FR','RD'})do
 local r=Run.new(D,'0',{experimental=true,character=role})
 same(r.relicPool.queues,vectors[1].queues);assert(r.relicPool.rng.counter==5)
 assert(r.data.relicSource.character==nil,'original V4 has no newly inferred STS class')
end
assert(#vectors==10);print('CLASS_RELIC_POOL default 10 JVM vectors and four original roles passed')
