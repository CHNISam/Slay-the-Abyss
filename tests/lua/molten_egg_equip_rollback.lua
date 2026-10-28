local F=dofile('tests/lua/support/toxic_egg_fixture.lua');local H=require('abyss_relic_hooks')
local r=F.Run.new(F.D,42);r.phase='reward';r.rewards={cards={'strike','defend'},cardUpgrades={false,false},cardResolved=false}
local graph={};graph.self=graph;r.testGraph,r.alias=graph,graph
local before=F.C.copy(r);local reward,flags,relics=r.rewards,r.rewards.cardUpgrades,r.relics
local original=H.onPreviewObtainCard;local reached=false
H.onPreviewObtainCard=function(owner,c,d)original(owner,c,d);if c.upgraded then reached=true;error('AFTER_EGG_EQUIP_PREVIEW')end end
local ok=F.Run.obtainRelic(r,'Molten Egg 2');H.onPreviewObtainCard=original
F.eq(ok,false);assert(reached);F.same(r,before);F.eq(r.rewards,reward);F.eq(r.rewards.cardUpgrades,flags);F.eq(r.relics,relics);F.eq(r.alias,r.testGraph);F.eq(r.alias.self,r.alias)
assert(F.Run.obtainRelic(r,'Molten Egg 2'));F.eq(r.rewards.cardUpgrades[1],true);F.eq(r.rewards.cardUpgrades[2],false)
print('MOLTEN_EGG_EQUIP_ROLLBACK_PASS partial preview failure restores original private reward/flags/owners and cycle, real retry succeeds')
