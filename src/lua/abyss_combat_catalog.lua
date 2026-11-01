-- Definition ownership shared by real battles and preconstructed encounters.
-- No actors, RNG, room callbacks or enemy registration run in this boundary.
local Copy=require('abyss_copy').copy
local Colorless=require('abyss_colorless_cards')
local M={}
local function index(entries)
 local result={}
 for _,entry in ipairs(entries)do result[entry.id]=entry end
 return result
end
local function definitions(original,prepared)
 -- Copy each complete caller list once to retain aliases within that list.
 local result=index(Copy(original))
 if prepared~=original then
  for _,definition in ipairs(prepared)do
   if not result[definition.id]then result[definition.id]=definition end
  end
 end
 return result
end
function M.prepare(source)
 local prepared=Colorless.withCards(source)
 -- Registration's new definitions are already private; existing definitions
 -- still belong to the caller even when registration returned a new bundle.
 return prepared,{
  cards=definitions(source.cards.cards,prepared.cards.cards),
  statuses=definitions(source.statuses.statuses,prepared.statuses.statuses)}
end
function M.enemies(data)return index(Copy(data.enemies.enemies))end
return M
