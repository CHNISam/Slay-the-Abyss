-- Legal API ownership under controlled tier/transition inputs; not natural play.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,R,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_sts_random'),require('abyss_combat')
local Data=(...)or require('abyss_data')
local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();n=n+1;print('PASS Tail persistence '..n..' '..name)end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
test('JDK source seed65536 rare head is a real production obtainable Tail without editing pools',function()
 local r=Run.new(Data,'65536',{experimental=true,campaign=true})
 -- The independently frozen JDK oracle has this same first rare identity.
 eq(r.relicPool.queues.rare[1],'Lizard Tail')
 local before=R.snapshot(r.relicPool.rng);local queue=C.copy(r.relicPool.queues.rare)
 local offer,pool=Run.prepareRelic(r,{tier='rare',room='event'})
 assert(offer);eq(offer.sourceId,'Lizard Tail');eq(offer.id,'lizard_tail')
 same(r.relicPool.queues.rare,queue);same(R.snapshot(r.relicPool.rng),before)
 assert(Run.transaction(r,function(staged)
  staged.relicPool=pool;return Run.obtainRelic(staged,offer.id)
 end))
 eq(r.relics[#r.relics],'lizard_tail');eq(r.relicCounters.lizard_tail,-1)
 eq(#r.relicPool.queues.rare,#queue-1);same(R.snapshot(r.relicPool.rng),before)
end)
test('actual spent owner survives chapter transition strict map restoration and the next real battle',function()
 local r=Run.new(Data,42,{experimental=true,campaign=true});assert(Run.obtainRelic(r,'lizard_tail'))
 r.hp,r.phase=1,'node';assert(Run.eventDamage(r,5));eq(r.hp,40);eq(r.relicCounters.lizard_tail,-2)
 -- Prior rooms and boss completion are controlled boundary inputs only.
 r.phase,r.floor,r.pendingAct='act_transition',17,2
 r.nodeFlow={floor=17,complete=true,roomKind='boss_treasure',result='boss_treasure_complete'}
 assert(Run.advanceAct(r));eq(r.act,2);eq(r.relicCounters.lizard_tail,-2)
 local map=Map.generate(r.data,r.runSeed,2,assert(Run.mapContext(r)))
 local counter=r.relicCounters;local restored=assert(Nodes.restoreMap(r,Map.snapshot(map)))
 eq(r.relicCounters,counter);eq(r.relicCounters.lizard_tail,-2)
 same(Map.snapshot(map),Map.snapshot(restored));assert(Nodes.enter(r,restored,Map.available(restored)[1].id))
 eq(r.combat.relicCounters.lizard_tail,-2);r.combat.player.hp=1
 C.damage(r.combat,r.combat.enemies[1],r.combat.player,999,true)
 eq(r.combat.player.hp,0);eq(r.combat.relicCounters.lizard_tail,-2)
end)
test('legacy source alias cannot obtain a duplicate and rearm its persistent spent counter',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'lizard_tail'))
 r.relics[#r.relics]='Lizard Tail';r.relicCounters.lizard_tail=-2
 local owner=r.relicCounters;local old=C.copy(r,{[r.data]=r.data})
 local ok,why=Run.obtainRelic(r,'lizard_tail')
 eq(ok,false);eq(why,'relic_already_owned');eq(r.relicCounters,owner);same(r,old)
end)
print('LIZARD_TAIL_PERSISTENCE_PASS '..n..' groups; controlled/offline only')
