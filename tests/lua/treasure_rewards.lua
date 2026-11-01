package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local T,R,P=require('abyss_treasure'),require('abyss_sts_random'),require('abyss_relic_pool')
local count=0
local function same(a,b)
 assert(type(a)==type(b),'type mismatch')
 if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function copy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o end
local function test(name,fn)fn();count=count+1;print('ok treasure '..count..' - '..name)end
local catalog={sourceCommit='test',queues={common={'c1','c2','c3'},uncommon={'u1','u2'},rare={'r1'},shop={},boss={'b1','b2','b3'}},spawnGates={}}
local function run(seed)
 local definitions={}
 for _,q in pairs(catalog.queues)do for _,id in ipairs(q)do definitions[#definitions+1]={id='local_'..id,sourceId=id}end end
 local pool=P.new(seed or '0',catalog);local snap=P.snapshot(pool);snap.queues=copy(catalog.queues);pool=P.restore(snap,catalog)
 return {act=1,floor=9,data={relics={relics=definitions},cards={cards={{id='strike',type='attack',rarity='basic'}}}},
  deck={{cardId='strike'}},relics={},relicPool=pool,treasureRng=R.fromSeed(seed or '0'),cardRng=R.fromSeed(seed or '0'),relicCounters={}}
end
test('all chest size and correlated reward boundaries retain original partitions',function()
 local sizes={small=0,medium=0,large=0}
 local expected={small={75,25,0,50},medium={35,50,15,35},large={0,75,25,50}}
 for roll=0,99 do local kind=T.kind(roll,1);sizes[kind]=sizes[kind]+1;assert(T.kind(roll,4)=='medium')end
 same(sizes,{small=50,medium=33,large=17})
 for kind,want in pairs(expected)do
  local counts={common=0,uncommon=0,rare=0,gold=0}
  for roll=0,99 do local tier,gold=T.rewardRule(kind,roll);counts[tier]=counts[tier]+1;if gold then counts.gold=counts.gold+1 end end
  same({counts.common,counts.uncommon,counts.rare,counts.gold},want)
 end
 assert(not pcall(T.kind,100,1));assert(not pcall(T.kind,0,5));assert(not pcall(T.rewardRule,'invalid',0))
end)
test('preparation detaches owners and consumes the real queue without support rerolls',function()
 local owner=run();owner.data.relics.relics={};local before=copy(owner)
 local prepared=assert(T.prepare(owner))
 same(owner,before)
 local base;for _,item in ipairs(prepared.reward.items)do if item.kind=='relic'then base=item end end
 assert(base and not base.available and base.id==base.sourceId)
 assert(#base.trace==1 and base.trace[1].id==base.sourceId)
 assert(#prepared.relicPool.queues[base.tier]==#owner.relicPool.queues[base.tier]-1)
 prepared.relicPool.queues.common[1]='changed';same(owner,before)
end)
test('Boss chest takes three queue heads with no treasure stream or normal hooks',function()
 local owner=run();owner.relics={'matryoshka','cursed_key','nloths_mask'}
 local before=copy(owner);local prepared=assert(T.prepare(owner,{boss=true}))
 same(prepared.reward.relics,{'local_b1','local_b2','local_b3'});assert(#prepared.reward.items==3)
 same(prepared.treasureRng,owner.treasureRng);same(prepared.cardRng,owner.cardRng)
 same(prepared.relicCounters,owner.relicCounters);assert(#prepared.curseSourceIds==0 and #prepared.hookTrace==0)
 same(owner,before)
end)
test('Matryoshka pre-hook uses relic RNG and the shared queue; key links only base',function()
 local owner=run();owner.relics={'matryoshka'};owner.campaign,owner.endingUnlocked=true,true;owner.keys={ruby=false,emerald=false,sapphire=false}
 local prepared=assert(T.prepare(owner));assert(prepared.relicCounters.matryoshka==1)
 assert(prepared.relicPool.rng.counter==owner.relicPool.rng.counter+1)
 local relics,key={},nil
 for _,item in ipairs(prepared.reward.items)do if item.kind=='relic'then relics[#relics+1]=item elseif item.kind=='sapphire'then key=item end end
 assert(#relics==2 and relics[1].origin=='matryoshka' and relics[2].origin=='base')
 assert(key.linkedSlot==relics[2].slot and relics[2].linkedSlot==key.slot and relics[1].linkedSlot==nil)
 local before,after=0,0
 for _,q in pairs(owner.relicPool.queues)do before=before+#q end
 for _,q in pairs(prepared.relicPool.queues)do after=after+#q end
 assert(after==before-2)
 -- Independent RandomXS128 source vector: seed0 after the five queue-shuffle
 -- longs has nextFloat .9461438059806824, above Matryoshka's .75 threshold.
 assert(relics[1].tier=='uncommon' and relics[1].sourceId=='u1')
 owner.relicCounters.matryoshka=1;prepared=assert(T.prepare(owner));assert(prepared.relicCounters.matryoshka==-2)
 owner.relicCounters.matryoshka=-2;prepared=assert(T.prepare(owner));assert(prepared.relicPool.rng.counter==owner.relicPool.rng.counter)
end)
test('Nloth removes first relic after key attachment without deleting unrelated gold or base',function()
 local owner=run();owner.relics={'matryoshka','nloths_mask'};owner.campaign,owner.endingUnlocked=true,true;owner.keys={ruby=false,emerald=false,sapphire=false}
 local prepared=assert(T.prepare(owner));assert(prepared.relicCounters.nloths_mask==-2)
 local relics,key=0,nil
 for _,item in ipairs(prepared.reward.items)do if item.kind=='relic'then relics=relics+1;assert(item.origin=='base')elseif item.kind=='sapphire'then key=item end end
 assert(relics==1 and key and #prepared.hookTrace==2)
 owner.relics={'nloths_mask'};prepared=assert(T.prepare(owner))
 for _,item in ipairs(prepared.reward.items)do assert(item.kind~='relic' and item.kind~='sapphire')end
 assert(prepared.reward.relicId==nil and prepared.reward.sapphireKey==nil)
end)
test('Cursed Key draws from source cardRng once, privately, before base reward',function()
 local owner=run();owner.relics={'cursed_key'};local before=copy(owner)
 local prepared=assert(T.prepare(owner));assert(#prepared.curseSourceIds==1)
 assert(prepared.cardRng.counter==owner.cardRng.counter+1)
 same(owner,before);assert(prepared.hookTrace[1].sourceId=='Cursed Key')
end)
test('unopened chest spends only constructor rolls and can be left without opening hooks',function()
 local owner=run();owner.relics={'matryoshka','cursed_key','nloths_mask'};local before=copy(owner)
 local created=assert(T.create(owner));assert(created.chest.opened==false)
 assert(created.treasureRng.counter==owner.treasureRng.counter+2)
 same(created.relicPool,owner.relicPool);same(created.cardRng,owner.cardRng)
 same(created.relicCounters,owner.relicCounters);assert(#created.reward.items==0 and #created.curseSourceIds==0)
 same(owner,before)
 local staged=copy(owner)
 for _,key in ipairs({'treasureRng','relicPool','cardRng','relicCounters'})do staged[key]=created[key]end
 local opened=assert(T.open(staged,created.chest,created.reward));same(opened,assert(T.prepare(owner)))
 local refused,reason=T.open(staged,opened.chest,opened.reward);assert(not refused and reason=='chest_already_open')
end)
test('invalid hook or missing queue never mutates the run',function()
 local owner=run();owner.relics={'matryoshka'};owner.relicCounters.matryoshka=3;local before=copy(owner)
 assert(not pcall(T.prepare,owner));same(owner,before)
 owner.relicPool=nil;local prepared,why=T.prepare(owner);assert(not prepared and why=='relic_pool_unavailable')
end)
test('each reward claims independently; blue key removes only linked relic and repeats refuse',function()
 local reward={items={{slot=1,kind='relic',id='extra',sourceId='Extra',available=true},
  {slot=2,kind='gold',amount=25},{slot=3,kind='relic',id='missing',sourceId='Missing',available=false,linkedSlot=4},
  {slot=4,kind='sapphire',linkedSlot=3,relicId='missing'}}}
 local before=copy(reward)
 local refused,reason=T.take(reward,3);assert(not refused and reason=='relic_content_unavailable');same(reward,before)
 local key=assert(T.take(reward,4));assert(key.item.kind=='sapphire');same(reward,before)
 assert(#key.reward.items==2 and key.reward.items[1].id=='extra' and key.reward.items[2].amount==25)
 local gold=assert(T.take(key.reward,2));assert(gold.item.amount==25 and #gold.reward.items==1)
 local extra=assert(T.take(gold.reward,1));assert(extra.item.id=='extra' and #extra.reward.items==0)
 assert(not T.take(extra.reward,1));assert(not T.take(extra.reward,4))
 reward.items[3].available=true
 local relic=assert(T.take(reward,3));assert(relic.item.id=='missing' and #relic.reward.items==2)
 reward.items[4].linkedSlot=999;assert(not T.take(reward,3))
end)
if ABYSS_TREASURE_FIXTURE then
 local f=ABYSS_TREASURE_FIXTURE
 test('independent continuous combat/chest vectors retain values, source identities and every RNG word',function()
  for _,sample in ipairs(f.cases)do
   local owner=run(sample.seed);owner.relicPool=P.new(sample.seed,f.catalog);owner.data.relics.relics={}
   for _,step in ipairs(sample.steps)do
    assert(R.randomIntBetween(owner.treasureRng,10,20)==step.combatGold)
    same(R.snapshot(owner.treasureRng),step.afterCombat);owner.act=step.act
    local original=copy(owner);local prepared=assert(T.prepare(owner))
    same(owner,original)
    assert(prepared.chest.kind==step.kind and prepared.chest.kindRoll==step.kindRoll)
    assert(prepared.chest.rewardRoll==step.rewardRoll and prepared.chest.relicTier==step.tier)
    assert((prepared.reward.gold or 0)==step.gold);same(R.snapshot(prepared.treasureRng),step.afterChest)
    same(prepared.relicPool.queues,step.queues)
    same(prepared.reward.items[#prepared.reward.items].trace,step.relic.consumed)
    assert(prepared.reward.relicSourceId==step.relic.resolvedId)
    same(prepared.cardRng,owner.cardRng);same(prepared.relicPool.rng,owner.relicPool.rng)
    owner.treasureRng,owner.relicPool=prepared.treasureRng,prepared.relicPool
   end
  end
 end)
end
print('LUA_TREASURE_PASS '..count)
