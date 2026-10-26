-- OrbWalker.getMove: one primary roll even when history forces the other move.
local A=require('abyss_actor')
local Copy=require('abyss_copy').copy
local M={}
local function select(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('unknown Act3 intent '..tostring(id))
end
function M.advance(state,enemy,random)
 local policy=enemy.ai.policy
 assert(policy=='orb_walker'or policy=='repulsor'or policy=='spiker'or policy=='exploder'
  or policy=='maw'or policy=='spire_growth','unsupported Act3 AI')
 local n=random(state,100)-1
 if policy=='maw'then
  enemy.mawTurn=enemy.mawTurn+1
  local id
  if not enemy.mawRoared then id='roar'
  elseif n<50 and enemy.act3Last~='nom'then id='nom'
  elseif enemy.act3Last=='slam'or enemy.act3Last=='nom'then id='drool'
  else id='slam'end
  -- Frames keep the old intent graph. Replace the changing move instead of
  -- mutating its effects through a previously emitted presentation frame.
  local intents={}
  for i,move in ipairs(enemy.intents)do
   if move.id=='nom'then move=Copy(move);move.effects[1].times=math.floor(enemy.mawTurn/2)end
   intents[i]=move
  end
  enemy.intents=intents
  enemy.act3Last=id;select(enemy,id);return
 elseif policy=='spire_growth'then
  local twiceTackle=enemy.act3Last=='tackle'and enemy.act3Previous=='tackle'
  local twiceSmash=enemy.act3Last=='smash'and enemy.act3Previous=='smash'
  local id
  if n<50 and not twiceTackle then id='tackle'
  elseif (state.player.statuses.constricted or 0)<=0 and enemy.act3Last~='constrict'then id='constrict'
  elseif not twiceSmash then id='smash'else id='tackle'end
  enemy.act3Previous,enemy.act3Last=enemy.act3Last,id;select(enemy,id);return
 elseif policy=='repulsor'then
  local id=n<20 and enemy.act3Last~='attack'and 'attack'or 'daze'
  enemy.act3Last=id;select(enemy,id);return
 elseif policy=='spiker'then
  local id=enemy.spikeCount>5 and 'attack'or n<50 and enemy.act3Last~='attack'and 'attack'or 'spike'
  enemy.act3Last=id;select(enemy,id);return
 elseif policy=='exploder'then
  select(enemy,enemy.exploderTurns<2 and 'attack'or 'wait');return
 end
 local preferred=n<40 and 'claw' or 'laser'
 local twice=enemy.act3Last==preferred and enemy.act3Previous==preferred
 local id=twice and (preferred=='claw' and 'laser' or 'claw')or preferred
 enemy.act3Previous,enemy.act3Last=enemy.act3Last,id
 select(enemy,id)
end
function M.initialize(state,enemy,random)
 enemy.act3Last,enemy.act3Previous=nil,nil
 enemy.spikeCount=enemy.ai.policy=='spiker'and 0 or nil
 enemy.exploderTurns=enemy.ai.policy=='exploder'and 0 or nil
 if enemy.ai.policy=='maw'then enemy.mawTurn,enemy.mawRoared=1,false end
 M.advance(state,enemy,random)
end
function M.preBattle(state,enemy)
 local policy=enemy.ai.policy
 if policy=='orb_walker'then A.applyPower(state,enemy,'generic_strength_up',3,enemy)
 elseif policy=='spiker'then A.applyPower(state,enemy,'thorns',3,enemy)
 elseif policy=='exploder'then A.applyPower(state,enemy,'explosive',3,enemy)
 else assert(policy=='repulsor'or policy=='maw'or policy=='spire_growth','unsupported Act3 pre-battle policy')end
end
function M.beforeAction(_,enemy,_,intent)
 if enemy.ai.policy=='spiker'and intent.id=='spike'then enemy.spikeCount=enemy.spikeCount+1 end
 if enemy.ai.policy=='exploder'then enemy.exploderTurns=enemy.exploderTurns+1 end
 if enemy.ai.policy=='maw'and intent.id=='roar'then enemy.mawRoared=true end
end
-- The source RollMoveAction survives attacker death while teammates live.
function M.afterAction(state,enemy,random)
 M.advance(state,enemy,random)
end
return M
