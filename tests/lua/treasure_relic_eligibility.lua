package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local Data=require('abyss_data')
local Source=dofile('tests/lua/support/source_treasure_claims.lua')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local ordinary={common=true,uncommon=true,rare=true}
local function fixture(remaining)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 -- Keep the real catalog intact. A consumed ordinary-queue checkpoint models
 -- exhaustion; ownership alone must not filter the original source catalog.
 for _,d in ipairs(r.data.relics.relics)do
  if ordinary[d.rarity] and d.id~=remaining then r.relics[#r.relics+1]=d.id end
 end
 Source.depleted(r,remaining and 'Anchor' or nil)
 -- This component checkpoint exhausts the held finite chest hook as well.
 r.relicCounters=r.relicCounters or {};r.relicCounters.matryoshka=-2
 local first=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='treasure';n.roomKind=nil end end
 assert(Nodes.enter(r,m,first.id));Source.open(r);return r,m
end
local r,m=fixture(nil)
eq(r.nodeFlow.reward.relicId,'circlet');eq(r.nodeFlow.reward.gold,23)
local size,gold=#r.relics,r.gold;assert(Nodes.claimTreasure(r));eq(#r.relics,size+1);eq(r.gold,gold+23);eq(r.phase,'map')
eq(r.relics[#r.relics],'circlet');eq(r.relicCounters.circlet,1)
print('PASS treasure ordinary queues exhausted: source Circlet plus independently rolled chest gold')
local a=fixture('anchor');eq(a.nodeFlow.reward.relicId,'anchor')
local count=#a.relics;assert(Nodes.claimTreasure(a));eq(#a.relics,count+1);eq(a.relics[#a.relics],'anchor');eq(a.phase,'map')
eq(Nodes.claimTreasure(a),false)
print('PASS treasure one ordinary relic remains: grant once')
print('TREASURE_RELIC_ELIGIBILITY 2 passed')
