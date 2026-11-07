-- Relic callbacks for a staged potion use, independent of Session commands.
local A=require('abyss_actor')
local Queries=require('abyss_relic_queries').hooks
local M={}

-- Outside combat this is the original direct heal, not Run's health modifier pass.
local function healRun(run,amount)if not require('abyss_potion_health').blocked(run.relics)then run.hp=math.min(run.maxHp,run.hp+amount)end end

function M.onUsePotion(run,combat)
 if not Queries.owns(run,'toy_ornithopter')then return end
 if combat then
  if not A.isActive(combat.player)then return end
  require('abyss_combat_reactions').enqueue(combat,{op='heal',value=5,relic='toy_ornithopter'},combat.player)
 else healRun(run,5)end
end

return M
