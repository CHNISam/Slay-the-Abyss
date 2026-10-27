-- Separately composed Darkstone dependency; not part of Addict-only patch.
local C,Run,Map,Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local Pool,R,Relics=require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_relic_pool')
local Hooks,Data=require('abyss_relic_hooks'),require('abyss_data')
local base=Run.new(Data,'42',{experimental=true,campaign=true});base.act,base.floor=2,17
base.unknown.pools=Pool.new('full',false,2);local map=Map.generate(base.data,'42',2)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'missing '..tostring(k))end
end
local function copy(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(source,tier)
 tier=tier or 'common';local r,m=copy(base),C.copy(map);local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId='addict' end end;assert(Nodes.enter(r,m,n.id))
 local selected=false
 for n=0,31 do local s=R.atCounter(r.eventSeed,n);local t=R.cloneState(s)
  if Relics.rarity('event',R.randomInt(t,99))==tier then r.relicPool.rng=s;selected=true;break end end
 assert(selected);local q=r.relicPool.queues[tier];local found
 for i,id in ipairs(q)do if id==source then table.remove(q,i);found=true;break end end;assert(found);table.insert(q,1,source)
 r.hp=30;return r
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS addict-darkstone '..count..' '..name)end

test('New Darkstone receives previously prepared Shame after acquisition and old Fish precedes health hook',function()
 local r=fixture('Darkstone Periapt','uncommon');assert(Run.obtainRelic(r,'CeramicFish'));local hp,maxHp,gold=r.hp,r.maxHp,r.gold
 local original=Run.increaseMaxHp;local seen
 Run.increaseMaxHp=function(owner,amount)seen=true;eq(owner.gold,gold+9);eq(owner.deck[#owner.deck].cardId=='shame',false);return original(owner,amount)end
 local ok,why=Nodes.chooseEvent(r,'steal');Run.increaseMaxHp=original;assert(ok,why);assert(seen)
 eq(r.nodeFlow.event.obtainedRelicId,'darkstone_periapt');eq(r.maxHp,maxHp+6);eq(r.hp,hp+6);eq(r.gold,gold+9);eq(r.deck[#r.deck].cardId,'shame')
end)
test('Old Darkstone health hook precedes new Fish gold in actual relic ownership order',function()
 local r=fixture('CeramicFish');assert(Run.obtainRelic(r,'Darkstone Periapt'));local hp,maxHp,gold=r.hp,r.maxHp,r.gold
 local original=Hooks.gainGold;local seen
 Hooks.gainGold=function(owner,amount)seen=true;eq(owner.maxHp,maxHp+6);eq(owner.hp,hp+6);return original(owner,amount)end
 local ok,why=Nodes.chooseEvent(r,'steal');Hooks.gainGold=original;assert(ok,why);assert(seen);eq(r.gold,gold+9)
end)
test('Old Omamori blocks Shame before new Darkstone receives any hook or UID',function()
 local r=fixture('Darkstone Periapt','uncommon');assert(Run.obtainRelic(r,'Omamori'));local before=copy(r)
 assert(Nodes.chooseEvent(r,'steal'));eq(r.nodeFlow.event.obtainedRelicId,'darkstone_periapt');eq(r.relicCounters.omamori,1)
 eq(r.maxHp,before.maxHp);eq(r.hp,before.hp);eq(r.nextDeckUid,before.nextDeckUid);same(r.deck,before.deck);eq(r.nodeFlow.event.curseBlocked,true)
end)
test('New Omamori cannot retroactively protect Shame from old Darkstone hook',function()
 local r=fixture('Omamori');assert(Run.obtainRelic(r,'Darkstone Periapt'));local before=copy(r)
 assert(Nodes.chooseEvent(r,'steal'));eq(r.relicCounters.omamori,2);eq(r.maxHp,before.maxHp+6);eq(r.hp,before.hp+6)
 eq(r.deck[#r.deck].cardId,'shame');eq(r.nodeFlow.event.curseBlocked,false)
end)
test('Old Darkstone and newly acquired Strawberry settle to additive6+7 without changing protected curse behavior',function()
 for _,blocked in ipairs({false,true})do
  local r=fixture('Strawberry');assert(Run.obtainRelic(r,'Darkstone Periapt'));if blocked then assert(Run.obtainRelic(r,'Omamori'))end
  local before=copy(r);assert(Nodes.chooseEvent(r,'steal'));local gain=blocked and 7 or 13
  eq(r.maxHp,before.maxHp+gain);eq(r.hp,before.hp+gain);eq(#r.deck,#before.deck+(blocked and 0 or 1))
 end
end)
test('Health-hook refusal after old Fish rolls back gold, new Darkstone ownership, card, RNG and aliases',function()
 local r=fixture('Darkstone Periapt','uncommon');assert(Run.obtainRelic(r,'CeramicFish'));local before=copy(r)
 local deck,pool,flow=r.deck,r.relicPool,r.nodeFlow;local original=Run.increaseMaxHp
 Run.increaseMaxHp=function(owner,amount)original(owner,amount);return false,'addict_dependency_health_refusal'end
 local ok,why=Nodes.chooseEvent(r,'steal');Run.increaseMaxHp=original;eq(ok,false);eq(why,'addict_dependency_health_refusal')
 same(r,before);eq(r.deck,deck);eq(r.relicPool,pool);eq(r.nodeFlow,flow)
 assert(Nodes.chooseEvent(r,'steal'));eq(r.gold,before.gold+9);eq(r.maxHp,before.maxHp+6)
end)
test('Retained-combat health boundary fails closed without disguising an original rule',function()
 local r=fixture('Darkstone Periapt','uncommon');r.combat={boundaryFixture=true};local before=copy(r);local combat=r.combat
 local ok,why=Nodes.chooseEvent(r,'steal');eq(ok,false);eq(why,'darkstone_health_context_unavailable');same(r,before);eq(r.combat,combat)
end)
print('ADDICT_DARKSTONE_INTERACTION '..count..' passed')
