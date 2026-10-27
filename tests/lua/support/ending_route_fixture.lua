-- Only history, keys, prior progress and late relic queues are controlled.
-- Battle damage is a controlled real API input, not a natural winning deck.
local Run,Nodes,Map,C,R,Q=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),
 require('abyss_combat'),require('abyss_sts_random'),require('abyss_encounter_queue')
local F={Run=Run,Nodes=Nodes,Map=Map,C=C,R=R,Q=Q}
function F.same(a,b)
 if a==b then return end;assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do F.same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
function F.snapshot(run)return C.copy(run,{[run.data]=run.data})end
function F.ready(role)
 local run=Run.new(require('abyss_data'),'42',{experimental=true,campaign=true,character=role or 'ironclad'})
 run.act,run.floor,run.endingUnlocked,run.keys=3,51,true,{ruby=true,emerald=true,sapphire=true}
 run.encounters=Q.new(run.runSeed,3)
 run.phase,run.pendingAct='act_transition',4
 run.nodeFlow={id='51:4',floor=51,type='event',roomKind='ending',complete=true,result='ending_door'}
 assert(Run.advanceAct(run));assert(run.floor==51 and run.act==4 and run.phase=='map')
 return run,Map.generate(run.data,run.runSeed,4,assert(Run.mapContext(run)))
end
function F.enter(run,map,floor)
 local available=Map.available(map);assert(#available==1 and available[1].floor==floor)
 local ok,why=Nodes.enter(run,map,available[1].id);assert(ok,why)
 return run.nodeFlow
end
function F.beforeElite(role)
 local run,map=F.ready(role)
 F.enter(run,map,52);assert(Nodes.rest(run));assert(run.phase=='map')
 F.enter(run,map,53);assert(Nodes.leaveShop(run));assert(run.phase=='map')
 -- Explicit late remaining source identities. Eligibility/fallback stays real;
 -- uncommon late-floor gates may fall through to the retained rare queue.
 run.relicPool.queues.common={'Anchor','Vajra'}
 run.relicPool.queues.uncommon={'The Courier','Darkstone Periapt'}
 run.relicPool.queues.rare={'TungstenRod'}
 return run,map
end
function F.eliteWon(role)
 local run,map=F.beforeElite(role);F.enter(run,map,54)
 assert(run.encounterSource=='Shield and Spear'and run.encounterTier=='elite')
 assert(#run.combat.enemies==2 and run.combat.monsterHpRng.counter==2)
 for _,enemy in ipairs(run.combat.enemies)do C.damage(run.combat,run.combat.player,enemy,999,false)end
 assert(C.outcome(run.combat)=='victory')
 return run,map
end
return F
