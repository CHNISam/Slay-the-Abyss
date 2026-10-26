-- Fixed 319009 class-exclusive potion definitions and queued use effects.
-- Register only implemented bottles; source sampling pools remain independent.
local M={}
local definitions={
 {id='focus_potion',sourceId='FocusPotion',name='集中药水',rarity='common',effects={{op='classPotion',kind='focus',value=2}}},
 {id='potion_of_capacity',sourceId='PotionOfCapacity',name='扩容药水',rarity='uncommon',effects={{op='classPotion',kind='capacity',value=2}}},
}
local function copy(value)
 if type(value)~='table'then return value end
 local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
function M.register(data)
 local seen={};for _,p in ipairs(data.potions.potions)do seen[p.id]=true end
 for _,p in ipairs(definitions)do if not seen[p.id]then data.potions.potions[#data.potions.potions+1]=copy(p)end end
 return data
end
function M.validate(effect)
 return (effect.kind=='focus'or effect.kind=='capacity')and (effect.value==2 or effect.value==4)
end
function M.apply(combat,state,effect)
 assert(M.validate(effect),'invalid class potion effect')
 if effect.kind=='focus'then
  combat.applyEffects(state,{{op='gainStatus',status='focus',value=effect.value}},state.player,state.player)
 else
  local Orbs=require('abyss_orbs')
  if not state.orbs then Orbs.init(state,0)end
  Orbs.gainSlots(state,effect.value)
 end
end
return M
