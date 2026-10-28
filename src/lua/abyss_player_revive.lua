-- AbstractPlayer.damage fatal reserves: Fairy first, then one persistent Tail.
-- Call only for an actual positive player HP-loss action, after bloodied hooks.
local Tail=require('abyss_lizard_tail')
local Fairy=require('abyss_potion_fairy')
local Health=require('abyss_potion_health')
local M={}
function M.battle(state)
 if Fairy.fatal(state,true)then return true end
 local actor=state.player
 return Tail.tryRevive(state,actor,function(value)
  local amount=math.min(actor.maxHp,Health.modifyHealing(value,state.relics,true))
  actor.hp=amount
  require('abyss_events').emit(state,'heal',{target=actor.id,amount=amount,relic='lizard_tail'})
  require('abyss_relic_hooks').hpChanged(state,actor,0,true)
 end)
end
function M.outside(run,heal)
 -- The returned physical slot is authoritative, even if healing was zero.
 if Fairy.outside(run)then return true end
 return Tail.tryRevive(run,run,heal)
end
return M
