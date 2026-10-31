-- Offline policy only: read the same public stage/candidate view as the player.
local Nodes=require('abyss_nodes')
local M={}
function M.uid(run,map,choice,scoreCard)
 local node=Nodes.view(run,map).node
 local event=node.event
 if not choice.picker and event.stage~='choose_card' then return nil end
 local upgrade=choice.choice=='forge' or choice.picker and choice.picker:find('upgrade')
 local candidates=upgrade and node.upgradeCards or event.purgeCards
 local uid,worst
 for _,card in ipairs(candidates or {})do
  local score=scoreCard(run,card.cardId)
  if not worst or score<worst then uid,worst=card.uid,score end
 end
 return uid
end
return M
