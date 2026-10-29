local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map=require('abyss_run'),require('abyss_map')
local N=require('abyss_relic_names')
local h,root=F.fixture();assert(F.start(h))
for _=1,F.Data.rules.map.bossFloor-1 do assert(Map.choose(h.map,Map.available(h.map)[1].id))end
assert(F.Nodes.enter(h.run,h.map,Map.available(h.map)[1].id))
for _,e in ipairs(h.run.combat.enemies)do e.hp=0 end
assert(Run.finishCombat(h.run));assert(Run.claimCardReward(h.run,0))
dofile('tests/lua/support/finish_combat_rewards.lua')(h.run);h:refresh()
assert(h.mapUI:choose(F.Nodes.available(h.run,h.map)[1].id))
assert(h.nodeUI:press('treasureView/chest'));h.nodeUI:update(2)
local chest=root:GetChild('nodePanel'):GetChild('treasureView')
local count=0
for _,definition in ipairs(h.run.data.relics.relics)do if definition.rarity=='boss' then
 count=count+1
 -- Isolated UI coverage only: keep the real opened source chest and its slot
 -- metadata, substitute the authored defined identity in each rendered slot.
 for _,item in ipairs(h.run.nodeFlow.reward.items)do
  item.id=definition.id;item.sourceId=definition.sourceId or require('abyss_relic_rewards').sourceId(h.run,definition.id)
  item.available=true;item.unavailable=false
 end
 h:refresh()
 local description=chest:GetChild('reward'):GetChild('description').text
 assert(description~='' and description:find('[\228-\233]'),'empty/non-Chinese Boss description '..definition.id)
 assert(chest:GetChild('reward'):GetChild('name').text=='遗物 · '..N.get(h.run.data,definition.id))
 assert(N.get(h.run.data,h.run.nodeFlow.reward.items[1].sourceId)==N.get(h.run.data,definition.id))
end end
assert(count>0)
print('RELIC_DEFINED_BOSS_DESCRIPTION_PASS '..count)
