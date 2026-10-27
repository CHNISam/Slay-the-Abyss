-- Controlled navigation and terminal enemy HP only; not natural gameplay.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C,Data=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_data')
local R=require('abyss_sts_random')
local F={}
function F.same(a,b)
 if a==b then return end
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for key,value in pairs(a)do F.same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil,tostring(key))end
end
function F.snapshot(run)return C.copy(run,{[run.data]=run.data})end
function F.beforeSelected(map)
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
local definition
for _,relic in ipairs(Data.relics.relics)do if relic.id=='black_star'then definition=relic end end
assert(definition,'BLACK_STAR_PRODUCTION_DEFINITION_MISSING')
assert(definition.sourceId=='Black Star'and definition.rarity=='boss'and definition.trigger=='hooks'and #definition.effects==0)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function dead(run)for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end end
local run=Run.new(Data,'144',{experimental=true,campaign=true})
F.same(R.snapshot(run.relicPool.rng),{words={'d332029783617f60','2ca76ce675709681'},counter=5})
local map=Map.generate(Data,run.runSeed,1,assert(Run.freezeMapContext(run)))
while Map.available(map)[1].floor<16 do assert(Map.choose(map,Map.available(map)[1].id))end
assert(Nodes.enter(run,map,Map.available(map)[1].id));dead(run)
assert(Run.finishCombat(run));assert(Run.claimCardReward(run,0))
dofile('tests/lua/support/finish_combat_rewards.lua')(run)
assert(Nodes.completeCombat(run,map))
assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id))
local items=run.nodeFlow.reward.items
eq(items[1].sourceId,'Astrolabe');eq(items[2].sourceId,'Tiny House');eq(items[3].sourceId,'Black Star')
eq(#run.relicPool.queues.boss,19);eq(#run.relicPool.catalog.queues.boss,22)
local obtain=Run.obtainRelic
local before=F.snapshot(run);local flow,deck=run.nodeFlow,run.deck
Run.obtainRelic=function(staged,id)local ok,why=obtain(staged,id);assert(ok,why);error('BLACK_STAR_LATE_OBTAIN')end
local ok,why=pcall(Nodes.claimBossTreasure,run,3)
Run.obtainRelic=obtain
assert(not ok or why==false);F.same(run,before);eq(run.nodeFlow,flow);eq(run.deck,deck)
assert(Nodes.claimBossTreasure(run,3));eq(run.relics[#run.relics],'black_star')
eq(run.phase,'act_transition')
before=F.snapshot(run);assert(not Nodes.claimBossTreasure(run,3));F.same(run,before)
print('ok Black Star public full-source Boss chest obtain, rollback and duplicate')
run.endingUnlocked=true -- controlled account history for a legal Act2 green elite.
assert(Nodes.advanceAct(run,map))
local acquired=F.snapshot(run)
-- A real source normal combat does not consume relic RNG or add relic offers.
local ordinary=C.copy(acquired,{[Data]=Data});ordinary.floor=18;ordinary.nodeFlow=nil
local rng=R.snapshot(ordinary.relicPool.rng)
assert(Run.startRoomCombat(ordinary,'normal'));dead(ordinary);assert(Run.finishCombat(ordinary))
eq(ordinary.rewards.relics,nil);F.same(R.snapshot(ordinary.relicPool.rng),rng)
print('ok Black Star normal rooms have no additional relic')
local id=F.beforeSelected(map);run.floor=map.floor;run.nodeFlow=nil
assert(Nodes.enter(run,map,id));eq(run.encounterTier,'elite');assert(run.emeraldCombat)
dead(run)
local Potion=require('abyss_potion_rewards');local prepare=Potion.prepare
before=F.snapshot(run);local pool,battle=run.relicPool,run.combat
Potion.prepare=function()error('BLACK_STAR_AFTER_BOTH_RELIC_DRAWS')end
ok,why=pcall(Run.finishCombat,run);Potion.prepare=prepare
assert(not ok);assert(tostring(why):find('BLACK_STAR_AFTER_BOTH_RELIC_DRAWS',1,true))
F.same(run,before);eq(run.relicPool,pool);eq(run.combat,battle)
assert(Run.finishCombat(run));eq(#run.rewards.relics,2)
F.same(R.snapshot(run.relicPool.rng),{words={'b45492bcb6dec9cc','ebc969f27c5c6a98'},counter=7})
local first,second=run.rewards.relics[1],run.rewards.relics[2]
eq(first.sourceId,'Toxic Egg 2');eq(first.requestedTier,'uncommon')
eq(second.sourceId,'TungstenRod');eq(second.requestedTier,'rare')
eq(#second.trace,2);eq(second.trace[1].id,'Peace Pipe');eq(second.trace[2].id,'TungstenRod')
assert(run.rewards.emeraldKey);assert(Run.claimEmeraldKey(run));assert(run.keys.emerald)
assert(not run.rewards.relics[1].claimed and not run.rewards.relics[2].claimed)
assert(Run.claimRelicReward(run,1));assert(Run.claimRelicReward(run,2))
eq(run.relics[#run.relics-1],'toxic_egg');eq(run.relics[#run.relics],'tungsten_rod')
before=F.snapshot(run);assert(not Run.claimRelicReward(run,2));assert(not Run.claimEmeraldKey(run));F.same(run,before)
print('ok Black Star independent rarity/noncamp draw, late rollback and both actual claims plus green key')
print('BLACK_STAR_PASS 3')
