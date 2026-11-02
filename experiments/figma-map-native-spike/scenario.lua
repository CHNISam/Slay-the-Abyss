-- Explicit deterministic visual fixture: actual commands, never HP/map/RNG edits.
-- One play/endTurn/entry per step. No coroutine dependency in native LuaHost.
local M={}
function M.new(run,map,limit)
 local Run,Nodes,C=require('abyss_run'),require('abyss_nodes'),require('abyss_combat')
 local state={wins=0,steps=0,done=false,phase='enter'}
 function state:step()
  if self.done then return true end
  self.steps=self.steps+1;assert(self.steps<=1500,'visual fixture action budget exceeded')
  if self.phase=='enter'then
   local chosen;for _,node in ipairs(Nodes.available(run,map))do if node.type=='combat'then chosen=node;break end end
   if not chosen or self.wins>=limit then assert(self.wins>=1,'no real winning fixture progress');self.done=true;return true end
   assert(Nodes.enter(run,map,chosen.id));assert(run.phase=='combat');self.phase='fight';return false
  end
  if run.phase=='combat'then
   local battle=run.combat;local target
   for i,enemy in ipairs(battle.enemies)do if enemy.hp>0 then target=i;break end end
   local uid;for _,card in ipairs(battle.hand)do if C.canPlay(battle,card.uid,target)then uid=card.uid;break end end
   local ok,why
   if uid then ok,why=Run.play(run,uid,target)else ok,why=Run.endTurn(run)end
   assert(ok,why);return false
  end
  assert(run.phase=='reward','visual fixture auto-player failed; no forced outcome')
  if run.rewards.goldClaimed==false then assert(Run.claimGoldReward(run))end
  if not run.rewards.cardResolved then assert(Run.claimCardReward(run,0))end
  if run.rewards.potion then Run.claimPotionReward(run)end
  assert(Run.leaveCombatRewards(run));assert(Nodes.completeCombat(run,map))
  self.wins=self.wins+1;self.phase='enter'
  print('FIGMA_FIXTURE_REAL_WIN floor='..map.floor..' hp='..run.hp..' gold='..run.gold)
  return false
 end
 return state
end
function M.advance(run,map,limit)
 local state=M.new(run,map,limit);while not state:step()do end;return state.wins
end
return M
