-- Fixed 319009 class-exclusive potion definitions and queued use effects.
-- Register only implemented bottles; source sampling pools remain independent.
local M={}
local definitions={
 {id='focus_potion',sourceId='FocusPotion',name='集中药水',rarity='common',effects={{op='classPotion',kind='focus',value=2}}},
 {id='potion_of_capacity',sourceId='PotionOfCapacity',name='扩容药水',rarity='uncommon',effects={{op='classPotion',kind='capacity',value=2}}},
}
local watcherDefinitions={
 {id='bottled_miracle',sourceId='BottledMiracle',name='瓶装奇迹',rarity='common',effects={{op='classPotion',kind='miracle',value=2}}},
 -- Source potency is unused by use(): Bark never repeats the stance change.
 {id='ambrosia',sourceId='Ambrosia',name='仙酒',rarity='rare',effects={{op='classPotion',kind='divinity',value=0}}},
}
local function copy(value)
 if type(value)~='table'then return value end
 local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
function M.register(data)
 local seen={};for _,p in ipairs(data.potions.potions)do seen[p.id]=true end
 local function add(entries)
  for _,p in ipairs(entries)do if not seen[p.id]then data.potions.potions[#data.potions.potions+1]=copy(p)end end
 end
 add(definitions)
 -- These bottles depend on the real Watcher Miracle and stance lifecycle.
 -- Sampling still draws all33 identities, independently of registration.
 if data.characterId=='watcher'then add(watcherDefinitions)end
 return data
end
function M.validate(effect)
 return (effect.kind=='focus'or effect.kind=='capacity'or effect.kind=='miracle')and (effect.value==2 or effect.value==4)
  or effect.kind=='divinity'and effect.value==0
end
function M.apply(combat,state,effect)
 assert(M.validate(effect),'invalid class potion effect')
 if effect.kind=='focus'then
  combat.applyEffects(state,{{op='gainStatus',status='focus',value=effect.value}},state.player,state.player)
 elseif effect.kind=='capacity'then
  local Orbs=require('abyss_orbs')
  if not state.orbs then Orbs.init(state,0)end
  Orbs.gainSlots(state,effect.value)
 elseif effect.kind=='miracle'then
  combat.applyEffects(state,{{op='makeTempCardInHand',card='miracle',value=effect.value}},state.player)
 else
  combat.resolvePotionActions(state,{{op='changeStance',stance='Divinity'}})
 end
end
return M
