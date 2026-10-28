-- Run the real command on an isolated graph. Never derive HP loss from card text.
local Combat=require('abyss_combat')
local M={}
function M.preview(battle,uid,target)
 if not uid or not Combat.canPlay(battle,uid,target) then return nil end
 local isolated=Combat.copy(battle)
 local ok,played=pcall(Combat.play,isolated,uid,target)
 if not ok or not played then return nil end
 -- Interactive choices have not resolved the command yet.
 if isolated.pendingChoice or isolated.pendingSelection or isolated.pendingPlay or isolated.pendingDiscard
  or isolated.pendingHandChoice or isolated.pendingScry or isolated.actionQueue then return nil end
 local result={}
 for i,enemy in ipairs(battle.enemies)do
  local after=isolated.enemies[i]
  if after and after.id==enemy.id then result[i]={hp=after.hp,loss=math.max(0,enemy.hp-after.hp)}end
 end
 return result
end
return M
