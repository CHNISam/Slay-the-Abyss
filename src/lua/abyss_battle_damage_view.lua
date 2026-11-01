-- Run the real command on an isolated graph. Never derive HP loss from card text.
local Combat=require('abyss_combat')
local Run=require('abyss_run')
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
-- A potion has fixed damage/status rules distinct from card modifiers. Execute
-- its real Run command on a detached graph; preview never consumes live owners.
function M.potionPreview(run,slot,target)
 if not run or run.phase~='combat' or not target then return nil end
 local isolated=Combat.copy(run,{[run.data]=run.data})
 local ok,used=pcall(Run.usePotion,isolated,slot,target)
 if not ok or not used then return nil end
 local result={}
 for i,enemy in ipairs(run.combat.enemies)do
  local after=isolated.combat.enemies[i]
  if after and after.id==enemy.id then result[i]={hp=after.hp,loss=math.max(0,enemy.hp-after.hp)}end
 end
 return result
end
return M
