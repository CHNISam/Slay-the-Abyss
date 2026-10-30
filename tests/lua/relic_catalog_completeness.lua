package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,D,Rewards=require('abyss_run'),require('abyss_data'),require('abyss_relic_rewards')
local r=Run.new(D,42);local count=0
for _,tier in ipairs({'common','uncommon','rare','shop','boss'})do
 for _,source in ipairs(r.relicPool.catalog.queues[tier])do
  local d=Rewards.definition(r,source)
  assert(d,'legal '..tier..' source has no runtime definition: '..source)
  assert(d.rarity==tier,'wrong source rarity: '..source)
  assert(type(d.description)=='string'and #d.description>0 or #d.effects>0 or d.trigger=='shop','missing real effect or description: '..source)
  count=count+1
 end
end
assert(count==130,'complete Ironclad source catalog changed without explicit review')
print('RELIC_CATALOG_COMPLETENESS_PASS '..count)
