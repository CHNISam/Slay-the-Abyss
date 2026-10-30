-- AbstractRoom.alterCardRarityProbabilities, fixed STS319009d5.
-- Rare modifiers precede uncommon modifiers; Gift changes only rare weight.
local M={}
function M.thresholds(context,relics)
 local rare,uncommon=3,37
 if context=='elite'then rare,uncommon=10,40
 elseif context=='shop'then rare,uncommon=9,37 end
 for _,id in ipairs(relics or {})do
  if id=='nloths_gift'or id=="Nloth's Gift"or id=='NlothsGift'then rare=rare*3 end
 end
 return rare,rare+uncommon
end
return M
