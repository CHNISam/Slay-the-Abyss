package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local ordinary={common=true,uncommon=true,rare=true}
local function fixture(remaining)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 -- Keep the real catalog intact. Ownership exhausts ordinary candidates while
 -- SPECIAL/start/shop/boss entries remain unowned and must never be selected.
 for _,d in ipairs(r.data.relics.relics)do
  if ordinary[d.rarity] and d.id~=remaining then r.relics[#r.relics+1]=d.id end
 end
 local first=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='treasure';n.roomKind=nil end end
 assert(Nodes.enter(r,m,first.id));return r,m
end
local r,m=fixture(nil)
eq(r.nodeFlow.reward.relicId,nil);eq(r.nodeFlow.reward.gold,Data.rules.rewards.normalGold)
local size,gold=#r.relics,r.gold;assert(Nodes.claimTreasure(r));eq(#r.relics,size);eq(r.gold,gold+Data.rules.rewards.normalGold);eq(r.phase,'map')
print('PASS treasure only ineligible relics remain: existing gold fallback')
local a=fixture('anchor');eq(a.nodeFlow.reward.relicId,'anchor')
local count=#a.relics;assert(Nodes.claimTreasure(a));eq(#a.relics,count+1);eq(a.relics[#a.relics],'anchor');eq(a.phase,'map')
eq(Nodes.claimTreasure(a),false)
print('PASS treasure one ordinary relic remains: grant once')
print('TREASURE_RELIC_ELIGIBILITY 2 passed')
