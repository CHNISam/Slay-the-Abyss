-- Fixed 319009d5 AbstractPlayer.damage / FairyPotion.use fatal interception.
-- Battle owns a private physical inventory; Run publishes only successful commands.
local R=require('abyss_sts_random')
local M={}
local function revive(actor,inventory,capacity,relics,inCombat)
 if actor.hp>0 or not inventory then return nil end
 local bark,flower=false,false
 for _,id in ipairs(relics or {})do
  if id=='mark_of_bloom' or id=='Mark of the Bloom' then return nil end
  if id=='sacred_bark' or id=='SacredBark' then bark=true end
  if id=='magic_flower' or id=='Magic Flower' then flower=true end
 end
 for slot=1,capacity do
  if inventory[slot]=='fairy_in_a_bottle' then
   local amount=math.max(1,math.floor(R.float32(R.float32(actor.maxHp)*R.float32((bark and 60 or 30)/100))))
   if flower and inCombat then amount=math.floor(R.float32(R.float32(amount)*R.float32(1.5))+.5)end
   actor.hp=math.min(actor.maxHp,amount)
   inventory[slot]=nil
   return slot
  end
 end
 return nil
end
function M.fatal(state,queuedFatal)
 local actor=state.player
 local slot=revive(actor,state.potionInventory,state.potionCapacity or state.rules.player.potionSlots,state.relics,true)
 if not slot then return false end
 require('abyss_events').emit(state,'potion_revive',{slot=slot,id='fairy_in_a_bottle',amount=actor.hp})
 -- Fairy is an automatic fatal path: no ordinary onUsePotion dispatch.
 require('abyss_relic_hooks').hpChanged(state,actor,0,queuedFatal)
 return true
end
function M.outside(run)
 -- A room owns its own current HP/inventory. A retained battle is historical,
 -- including its Powers, heal ledger and relic snapshot; never consult it here.
 return revive(run,run.potions,run.potionSlots or run.data.rules.player.potionSlots,run.relics,false)
end
return M
