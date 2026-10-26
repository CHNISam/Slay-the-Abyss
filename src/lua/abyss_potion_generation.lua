-- EntropicBrew generates potionSlots candidates, including attempts which
-- Sozu or a full inventory later rejects. All attempts share potionRng.
local R=require('abyss_sts_random')
local P=require('abyss_potion_random')
local H=require('abyss_relic_hooks')
local M={}
function M.available(run,id)
 for _,definition in ipairs(run.data.potions.potions)do if definition.id==id then return true end end
 return false
end
function M.prepare(run,inCombat)
 if not inCombat and H.owns(run,'sozu')then return {}end
 local owner={potionRng=run.shopRng and R.cloneState(run.shopRng.potion)
  or R.fromSeed(run.eventSeed or string.format('%.0f',run.seed))}
 local generated={}
 for _=1,run.potionSlots or run.data.rules.player.potionSlots do
  generated[#generated+1]=P.sample(owner,{limited=inCombat,character=P.character(run)}).id
 end
 return generated,owner.potionRng
end
function M.obtain(inventory,capacity,id,blocked)
 if blocked then return false end
 for slot=1,capacity do if not inventory[slot]then inventory[slot]=id;return true end end
 return false
end
return M
