-- Private source takeTurn plans, executed by Combat's existing enemy queue.
-- These are not general effects and are deliberately absent from its whitelist.
local Actors=require('abyss_actor')
local Heart=require('abyss_corrupt_heart')
local Pair=require('abyss_spire_pair')
local Cards=require('abyss_card_actions')
local Random=require('abyss_sts_random')
local Events=require('abyss_events')
local M={}
local function append(plans,enemy,kind,target,fields)
 local plan={kind=kind,sourceId=enemy.id,targetId=target and target.id or nil}
 for key,value in pairs(fields)do plan[key]=value end
 plans[#plans+1]=plan
end
function M.plan(combat,state,enemy,intent,random)
 if Pair.owns(enemy)then
  local plans=Pair.takeTurn(state,enemy,random,function(s,e,base)
   -- Pair owns the distinct post-normal actual-damage BackAttack rounding.
   return Actors.attackAmount(s,e,s.player,base)
  end)
  local roll=table.remove(plans)
  assert(roll.kind=='roll'and roll.intentId==intent.id,'invalid final-act source RollMove')
  return plans -- Combat appends exactly one captured RollMove after owner end.
 end
 if not Heart.owns(enemy)then return nil end
 local plans={}
 for _,effect in ipairs(Heart.actions(state,enemy,intent))do
  if effect.op=='damage'then
   local amount=Actors.attackAmount(state,enemy,state.player,effect.value)
   for _=1,effect.times or 1 do append(plans,enemy,'damage',state.player,{value=effect.value,normalAmount=amount})end
  elseif effect.op=='gainStatus'or effect.op=='applyStatus'then
   append(plans,enemy,'power',effect.op=='gainStatus'and enemy or state.player,
    {status=effect.status,value=effect.value})
  else
   assert(effect.op=='heartStatusDraw','unsupported Heart source plan')
   append(plans,enemy,'drawInsert',state.player,{card=effect.card,value=effect.value})
  end
 end
 return plans
end
local function target(state,id)
 if state.player.id==id then return state.player end
 for _,enemy in ipairs(state.enemies)do if enemy.id==id then return enemy end end
 error('missing final-act action target: '..tostring(id))
end
local function insertDraw(combat,state,enemy,plan)
 for _=1,plan.value do
  local card=Cards.fresh(combat,state,plan.card)
  Cards.created(combat,state,card) -- STATUS ignores Master Reality.
  local position=#state.draw==0 and 1 or Random.randomInt(assert(state.cardRandomRng,'Heart needs card RNG'),#state.draw-1)+1
  table.insert(state.draw,position,card)
 end
 Events.emit(state,'cards_created',{source=enemy.id,cardId=plan.card,amount=plan.value,pile='draw'})
end
function M.resolve(combat,state,plan,enemy)
 assert((Heart.owns(enemy)or Pair.owns(enemy))and plan.sourceId==enemy.id,'invalid final-act action owner')
 local actor=target(state,plan.targetId)
 if plan.kind=='damage'then
  return combat.damage(state,enemy,actor,plan.value,false,nil,plan.normalAmount)
 elseif plan.kind=='power'then
  return Actors.applyPower(state,actor,plan.status,plan.value,enemy)
 elseif plan.kind=='block'then
  return Actors.block(state,actor,plan.value,true) -- Smash already froze output.
 elseif plan.kind=='discard'then
  for _=1,plan.value do
   local card=Cards.fresh(combat,state,plan.card);Cards.created(combat,state,card)
   state.discard[#state.discard+1]=card
  end
  Events.emit(state,'cards_created',{source=enemy.id,cardId=plan.card,amount=plan.value,pile='discard'})
 elseif plan.kind=='drawInsert'then return insertDraw(combat,state,enemy,plan)
 else error('unknown final-act action kind: '..tostring(plan.kind))end
 return true
end
function M.retained(plan)return plan~=nil and (plan.kind=='damage'or plan.kind=='block')end
return M
