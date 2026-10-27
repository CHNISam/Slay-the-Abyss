-- Controlled history/navigation/late relic queues, never natural-play evidence.
local Run,Nodes,Map,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local Data=require('abyss_data')
local M={Run=Run,Nodes=Nodes,Map=Map,C=C,Data=Data}
function M.same(a,b)
 if a==b then return end
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do M.same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
function M.snapshot(run)return C.copy(run,{[run.data]=run.data})end
function M.beforeSelected(map)
 local target=map.emeraldSelection.nodeId
 local index={};for _,node in ipairs(map.nodes)do index[node.id]=node end
 local function find(id)
  if id==target then return {id}end
  for _,nextId in ipairs(index[id].nextIds)do
   local path=find(nextId);if path then table.insert(path,1,id);return path end
  end
 end
 local path
 for _,node in ipairs(Map.available(map))do path=find(node.id);if path then break end end
 assert(path)
 for i=1,#path-1 do assert(Map.choose(map,path[i]))end
 return target
end
function M.data(blackStar)
 local data=Data
 if blackStar then
  data=C.copy(Data)
  data.relics.relics[#data.relics.relics+1]={id='black_star',sourceId='Black Star',name='黑星',rarity='boss',trigger='none',effects={}}
 end
 return data
end
function M.queues(run)
 run.relicPool.queues.common={'Anchor','Vajra'}
 run.relicPool.queues.uncommon={'The Courier','Darkstone Periapt'}
 run.relicPool.queues.rare={'TungstenRod'}
end
function M.fixture(blackStar)
 local data=M.data(blackStar)
 local run=Run.new(data,'42',{experimental=true,campaign=true})
 run.endingUnlocked=true -- controlled provider result, not earned account history.
 if blackStar then run.relics[#run.relics+1]='black_star'end
 local context=assert(Run.freezeMapContext(run))
 local map=Map.generate(run.data,run.runSeed,1,context)
 local id=M.beforeSelected(map);run.floor=map.floor
 -- Existing source queues stay in charge of tier rolls; these are explicit
 -- late-run remaining identities with implemented obtain paths, not rerolls.
 M.queues(run)
 return run,map,id
end
function M.victory(run)
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end -- controlled victory boundary.
 assert(Run.finishCombat(run));assert(run.phase=='reward')
 return run.rewards
end
return M
