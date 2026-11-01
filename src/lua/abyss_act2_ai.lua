-- Source-compatible decision history: getMove sees all previously selected moves.
local A=require('abyss_actor')
local Moves=require('abyss_act2_ai_moves')
local M={}
local function select(e,id)
 for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end
 error('unknown Act2 intent '..tostring(id))
end
local function choose(state,e,n,random)
 local policy=e.ai.policy
 local decide=Moves[policy]
 if decide then return decide({state=state,enemy=e,roll=n,random=random}) end
 error('unsupported Act2 policy '..tostring(policy))
end
local function setMove(e,id)
 if e.ai.policy=='book' and id=='multi_stab'then
  e.act2Stabs=e.act2Stabs+1
  for _,v in ipairs(e.intents)do if v.id==id then v.effects[1].times=e.act2Stabs end end
 end
 select(e,id)
end
function M.initialize(state,e,random)
 e.act2Last,e.act2Previous=nil,nil
 e.act2Stabs=1
 e.act2Turns,e.act2Forges,e.act2Enraged=0,0,false
 e.act2HexUsed=false
 e.act2TurnsTaken,e.act2UltUsed=0,false
 e.act2AutoTurns,e.act2StasisUsed=0,false
 setMove(e,choose(state,e,random(state,100)-1,random))
end
function M.advance(state,e,random)
 e.act2Previous,e.act2Last=e.act2Last,e.intents[e.intentIndex].id
 setMove(e,choose(state,e,random(state,100)-1,random))
end
function M.preBattle(state,e)
 if e.ai.policy=='automaton'then A.applyPower(state,e,'artifact',3,e) end
 if e.ai.policy=='leader'then
  e.act2GremlinSlots={}
  for i=1,2 do local ally=state.enemies[i];ally.minion=true;e.act2GremlinSlots[i]=ally.id;A.applyPower(state,ally,'minion',1,e) end
 end
 if e.ai.policy=='byrd'then A.applyPower(state,e,'flight',3,e) end
 if e.ai.policy=='parasite'then A.applyPower(state,e,'plated_armor',14,e);A.block(state,e,14,true) end
 if e.ai.policy=='snake'then A.applyPower(state,e,'malleable',3,e) end
 if e.ai.policy=='book'then A.applyPower(state,e,'painful_stabs',1,e) end
 if e.ai.policy=='sphere'then
  A.applyPower(state,e,'barricade',1,e)
  A.applyPower(state,e,'artifact',3,e)
  A.block(state,e,40,true)
 end
end
function M.beforeAction(state,e,random,intent)
 if e.ai.policy=='leader' and intent.id=='encourage'then random(state,3) end
 if e.ai.policy=='parasite' and intent.id=='stunned'then select(e,'fell') end
end
function M.afterAction(state,e,random,intent)
 if e.ai.policy=='collector'then
  e.act2TurnsTaken=e.act2TurnsTaken+1
  if intent.id=='mega_debuff'then e.act2UltUsed=true end
 end
 if e.ai.policy=='byrd' and intent.id=='headbutt'then select(e,'airborne');return end
 M.advance(state,e,random)
end
return M
