-- OrbWalker.getMove: one primary roll even when history forces the other move.
local A=require('abyss_actor')
local M={}
local function select(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('unknown Act3 intent '..tostring(id))
end
function M.advance(state,enemy,random)
 assert(enemy.ai.policy=='orb_walker','unsupported Act3 AI')
 local n=random(state,100)-1
 local preferred=n<40 and 'claw' or 'laser'
 local twice=enemy.act3Last==preferred and enemy.act3Previous==preferred
 local id=twice and (preferred=='claw' and 'laser' or 'claw')or preferred
 enemy.act3Previous,enemy.act3Last=enemy.act3Last,id
 select(enemy,id)
end
function M.initialize(state,enemy,random)
 enemy.act3Last,enemy.act3Previous=nil,nil
 M.advance(state,enemy,random)
end
function M.preBattle(state,enemy)
 assert(enemy.ai.policy=='orb_walker','unsupported Act3 pre-battle policy')
 A.applyPower(state,enemy,'generic_strength_up',3,enemy)
end
-- The source RollMoveAction survives attacker death while teammates live.
function M.afterAction(state,enemy,random)
 M.advance(state,enemy,random)
end
return M
