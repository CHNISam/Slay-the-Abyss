-- Controlled earned-history/keys, skipped earlier rooms and zeroed Heart HP.
-- Real Run/Nodes/Heart construction and Proceed owner; NOT natural acceptance.
local M={Run=require('abyss_run'),Nodes=require('abyss_nodes'),Map=require('abyss_map'),C=require('abyss_combat')}
local Queue=require('abyss_encounter_queue')
function M.same(a,b)
 if a==b then return end
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do M.same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
function M.stage(run)
 run.act,run.phase,run.floor=4,'map',54
 run.endingUnlocked=true;run.keys={ruby=true,emerald=true,sapphire=true}
 run.encounters=Queue.new(run.runSeed,4)
 run.bossInitialization,run.encounters=Queue.initializeBoss(run.encounters)
 assert(M.Run.freezeMapContext(run))
 local map=M.Map.generate(run.data,run.runSeed,4,assert(M.Run.mapContext(run)))
 for _=1,3 do assert(M.Map.choose(map,M.Map.available(map)[1].id))end
 local source,nextQueue=Queue.consume(run.encounters,'elite') -- controlled preceding floor54 source consumption.
 assert(source and nextQueue);run.encounters=nextQueue
 run.nodeFlow=nil;assert(M.Nodes.enter(run,map,M.Map.available(map)[1].id))
 assert(run.encounterTier=='boss'and run.combat and run.floor==55)
 return map
end
function M.finish(run)
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 assert(M.Run.finishCombat(run))
 assert(run.phase=='ending_proceed'and run.endingProceed and not run.rewards)
 return run.endingProceed
end
function M.fixture()
 local run=M.Run.new(require('abyss_data'),'42',{experimental=true,campaign=true})
 local map=M.stage(run);local owner=M.finish(run)
 return run,map,owner
end
return M
