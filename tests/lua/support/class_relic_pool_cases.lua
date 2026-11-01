-- Whole queues from host-JDK HashMap + Collections.shuffle over fixed facts.
-- Availability never changes these class boundaries or queue/RNG histories.
local Run,D,P,R,C=require('abyss_run'),require('abyss_data'),require('abyss_relic_pool'),require('abyss_sts_random'),require('abyss_combat')
local Shop,Rewards,T=require('abyss_shop'),require('abyss_relic_rewards'),require('abyss_treasure')
local vectors=dofile('tests/fixtures/sts1-class-relic-pool-vectors.lua')
local function same(a,b)
 assert(type(a)==type(b),'type mismatch')
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local red={['Black Blood']=true,Brimstone=true,['Champion Belt']=true,["Charon's Ashes"]=true,
 ['Magic Flower']=true,['Mark of Pain']=true,['Paper Frog']=true,['Red Skull']=true,['Runic Cube']=true,['Self Forming Clay']=true}
local marker={silent='Ring of the Serpent',defect='Inserter',watcher='HolyWater'}
return function(character)
 local count=0
 for _,case in ipairs(vectors[character].cases)do
  local r=Run.new(D,case.seed,{experimental=true,character=character})
  same(r.relicPool.queues,case.queues);assert(r.relicPool.rng.counter==case.relicRngCounterAfter)
  assert(r.data.relicSource.character==character and r.relicPool.catalog.character==character)
  local seen={};for _,q in pairs(r.relicPool.queues)do for _,id in ipairs(q)do assert(not red[id],id);seen[id]=true end end
  assert(seen[marker[character]],'class relic missing')
  same(P.restore(P.snapshot(r.relicPool),r.data.relicSource).queues,case.queues)
  count=count+1
 end
 -- Existing prepared-profile ABI must select the same source without mutating
 -- caller-owned content, and must not infer an original V4 -> STS mapping.
 local prepared=require('abyss_character_profiles').prepare(D,character)
 local before=C.copy(prepared);local legacy=Run.new(prepared,'42')
 same(legacy.relicPool.queues,Run.new(D,'42',{experimental=true,character=character}).relicPool.queues)
 same(prepared,before)
 local r=Run.new(D,'42',{experimental=true,character=character})
 before=C.copy(r)
 local stock=Shop.prepare(r,9);assert(stock.relicPool.catalog.character==character)
 same(r,before)
 for _,offer in ipairs(stock.relics)do assert(not red[offer.sourceId],'shop crossed source class')end
 r.encounterTier='elite';local elite=assert(Rewards.elite(r))
 assert(elite.relicPool.catalog.character==character);for _,offer in ipairs(elite.items)do assert(not red[offer.sourceId])end
 local chest=assert(T.prepare(r));assert(chest.relicPool.catalog.character==character)
 for _,item in ipairs(chest.reward.items)do if item.kind=='relic'then assert(not red[item.sourceId])end end
 -- Spawn eligibility retains each class's real starter-replacement condition.
 local replacement=character=='silent'and 'Ring of the Serpent'or character=='defect'and 'FrozenCore'or 'HolyWater'
 local with=C.copy(r);local without=C.copy(r);without.relics={}
 local function front(run)
  local snap=P.snapshot(run.relicPool);local ids=snap.queues.boss
  for i,id in ipairs(ids)do if id==replacement then table.remove(ids,i);table.insert(ids,1,id);break end end
  return P.restore(snap,run.relicPool.catalog)
 end
 local a=front(with);local b=front(without)
 local found=P.draw(a,'boss',Rewards.context(with,{room='treasure'}));assert(found==replacement)
 local rejected,trace=P.draw(b,'boss',Rewards.context(without,{room='treasure'}));assert(rejected~=replacement and trace[1].id==replacement)
 print('CLASS_RELIC_POOL '..character..' '..count..' JVM vectors + profile/shop/elite/chest/gate checks passed')
end
