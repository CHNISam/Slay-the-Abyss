-- Offline policy only: read the same public stage/candidate view as the player.
local Nodes=require('abyss_nodes')
local M={}
-- These public picker descriptors first admit an operation, then select a card.
-- Initial picker metadata is not permission to send a UID before choose_card.
local stagedPickers={living_forget='purge',living_change='purge',living_grow='upgrade'}
function M.uid(run,map,choice,scoreCard)
 local node=Nodes.view(run,map).node
 local event=node.event
 local staged=stagedPickers[choice.picker]
 if staged and event.stage~='choose_card' then return nil end
 if not choice.picker and event.stage~='choose_card' then return nil end
 local upgrade=staged=='upgrade' or choice.choice=='forge' or choice.picker and choice.picker:find('upgrade')
 local candidates=upgrade and node.upgradeCards or event.purgeCards
 local uid,worst
 for _,card in ipairs(candidates or {})do
  local score=scoreCard(run,card.cardId)
  if not worst or score<worst then uid,worst=card.uid,score end
 end
 return uid
end
return M
