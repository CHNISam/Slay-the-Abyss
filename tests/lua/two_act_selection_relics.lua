local A=dofile('tests/lua/support/two_act_selection_audit.lua')
local Rewards=require('abyss_relic_rewards')
local base=A.run();local count=0
for _,tier in ipairs({'common','uncommon','rare','shop','boss'})do
 for _,source in ipairs(base.relicPool.catalog.queues[tier])do
  local r=A.run();r.relics={'burning_blood'}
  local definition=assert(Rewards.definition(r,source),source..' missing definition')
  assert(definition.rarity==tier,source..' wrong rarity')
  local ok,why=A.H.Run.obtainRelic(r,source);assert(ok,source..': '..tostring(why))
  assert(r.relics[#r.relics]==definition.id or r.relics[1]==definition.id,source..' ownership not committed')
  count=count+1
 end
end
assert(count==130,'complete competition relic source queue changed: '..count)
print('TWO_ACT_SELECTION_RELICS_PASS '..count)
