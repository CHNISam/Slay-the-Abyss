-- Fixed 319009d5 AbstractPlayer.damage / FairyPotion.use fatal interception.
-- Battle owns a private physical inventory; Run publishes only successful commands.
local R=require('abyss_sts_random')
local M={}
function M.fatal(state)
 local actor=state.player
 if actor.hp>0 or not state.potionInventory then return false end
 local bark,flower=false,false
 for _,id in ipairs(state.relics or {})do
  if id=='mark_of_bloom' or id=='Mark of the Bloom' then return false end
  if id=='sacred_bark' or id=='SacredBark' then bark=true end
  if id=='magic_flower' or id=='Magic Flower' then flower=true end
 end
 for slot=1,state.potionCapacity or state.rules.player.potionSlots do
  if state.potionInventory[slot]=='fairy_in_a_bottle' then
   local amount=math.max(1,math.floor(R.float32(R.float32(actor.maxHp)*R.float32((bark and 60 or 30)/100))))
   if flower then amount=math.floor(R.float32(R.float32(amount)*R.float32(1.5))+.5)end
   actor.hp=math.min(actor.maxHp,amount)
   state.potionInventory[slot]=nil
   require('abyss_events').emit(state,'potion_revive',{slot=slot,id='fairy_in_a_bottle',amount=actor.hp})
   -- Fairy is an automatic fatal path: no ordinary onUsePotion dispatch.
   require('abyss_relic_hooks').hpChanged(state,actor,0)
   return true
  end
 end
 return false
end
return M
