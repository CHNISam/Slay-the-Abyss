package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local Data=require('abyss_data')
local SourceTreasure=dofile('tests/lua/support/source_treasure_claims.lua')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function setup(valid)
 local run,map=Run.new(Data,42),Map.generate(Data,42)
 assert(Run.obtainRelic(run,'circlet'));assert(Run.obtainRelic(run,'cursed_key'))
 if valid then assert(Run.obtainRelic(run,'omamori'));assert(run.relicCounters.omamori==2)
 else run.relics[#run.relics+1]='omamori';assert(run.relicCounters.omamori==nil)end
 SourceTreasure.depleted(run)
 while true do
  local available=Map.available(map)
  for _,node in ipairs(available)do if node.type=='treasure'then assert(Nodes.enter(run,map,node.id));return run,map end end
  assert(#available>0);assert(Map.choose(map,available[1].id))
 end
end
local run=setup(true);local gold,deckSize=run.gold,#run.deck
assert(Nodes.openTreasure(run));assert(run.relicCounters.omamori==1 and #run.deck==deckSize)
assert(run.nodeFlow.reward.relicId=='circlet' and run.nodeFlow.reward.gold==23)
assert(Nodes.claimTreasure(run));assert(run.gold==gold+23 and run.relicCounters.circlet==2 and run.phase=='map')
local invalid=setup(false);local snapshot=C.copy(invalid)
local ok,reason=Nodes.openTreasure(invalid);assert(ok==false and reason=='transaction_failed');same(invalid,snapshot)
print('NODES_DEPLETED_OWNERSHIP_PASS 2')
