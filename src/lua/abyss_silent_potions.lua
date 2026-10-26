-- Silent source-exclusive bottles, registered with the Silent runtime catalog.
local M={}
function M.register(data)
 local seen={};for _,p in ipairs(data.potions.potions)do seen[p.id]=true end
 for _,p in ipairs({
  {id='cunning_potion',name='狡诈药水',rarity='uncommon',effects={{op='silentShivs',value=3}}},
  {id='ghost_in_a_jar',name='瓶中幽灵',rarity='rare',effects={{op='silentGhost',value=1}}},
 })do if not seen[p.id]then data.potions.potions[#data.potions.potions+1]=p end end
 return data
end
function M.shivs(state,n)
 local C=require('abyss_combat');local Actions=require('abyss_card_actions')
 for _=1,n do
  local card=Actions.fresh(C,state,'shiv');assert(C.canUpgrade(state,card),'missing upgraded Shiv')
  C.upgrade(state,card);Actions.toHand(state,card)
 end
end
return M
