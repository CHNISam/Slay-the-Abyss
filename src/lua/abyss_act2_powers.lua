-- BOTTOM damage reactions. Actor owns the action boundary and supplies arithmetic.
local Events=require('abyss_events')
local R=require('abyss_sts_random')
local ER=require('abyss_enemy_random')
local Stasis=require('abyss_act2_stasis')
local M={}
local function push(s,action)
 s.act2Bottom=s.act2Bottom or {};s.act2Bottom[#s.act2Bottom+1]=action
end
function M.damaged(s,source,target,lost,fixed)
 if source and not fixed and lost>0 and (target.statuses.flight or 0)>0 then push(s,{op='flight_hit',target=target}) end
 if source and not fixed and lost>0 and target.ai and target.ai.policy=='parasite' and target.statuses.plated_armor==1 then
  push(s,{op='armor_break',target=target})
 end
 if source and not fixed and lost>0 and lost<target.hp and (target.statuses.malleable or 0)>0 then
  push(s,{op='block',target=target,value=target.statuses.malleable})
  target.statuses.malleable=target.statuses.malleable+1
 end
 if source and not fixed and lost>0 and (source.statuses.painful_stabs or 0)>0 then
  push(s,{op='card',card='wound'})
 end
end
function M.flush(api,s)
 local queue=s.act2Bottom;s.act2Bottom=nil
 if not queue or s.player.hp<=0 then return end
 local live=false;for _,e in ipairs(s.enemies)do if api.isActive(e)then live=true end end
 for _,entry in ipairs(queue)do
  if entry.op=='stasis_return'then Stasis.release(api,s,entry)
  elseif entry.op=='boss_dead'then
   for _,e in ipairs(s.enemies)do if api.isActive(e)then e.hp=0;Events.emit(s,'enemy_suicide',{enemy=e.id})end end
   s.act2StasisCards=nil
  elseif entry.op=='leader_dead'then
   for _,e in ipairs(s.enemies)do if api.isActive(e)then e.escaped=true;Events.emit(s,'enemy_escape',{enemy=e.id})end end
  elseif entry.op=='flight_hit' and api.isActive(entry.target) and (entry.target.statuses.flight or 0)>0 then
   local e=entry.target;e.statuses.flight=e.statuses.flight-1
   Events.emit(s,'status',{source=e.id,target=e.id,status='flight',amount=-1})
   if e.statuses.flight==0 then
    for i,intent in ipairs(e.intents)do if intent.id=='stunned'then e.intentIndex=i end end
    Events.emit(s,'enemy_interrupt',{enemy=e.id,id='stunned'})
   end
  elseif entry.op=='armor_break' and api.isActive(entry.target) then
   for i,intent in ipairs(entry.target.intents)do if intent.id=='stunned'then entry.target.intentIndex=i end end
   Events.emit(s,'enemy_interrupt',{enemy=entry.target.id,id='stunned'})
  elseif entry.op=='block' and api.isActive(entry.target) then api.block(s,entry.target,entry.value,true)
  elseif entry.op=='card' and live then
   assert(s.catalog.cards[entry.card],'unknown enemy-generated card')
   local c={cardId=entry.card,uid=s.nextUid,upgraded=false}
   s.nextUid=s.nextUid+1.0;s.discard[#s.discard+1]=c
   Events.emit(s,'cards_created',{cardId=entry.card,amount=1,pile='discard'})
  end
 end
end
function M.afterCard(s,reactions)
 local amount=reactions and reactions.hex or 0
 if amount==0 or s.player.hp<=0 then return end
 local live=false;for _,e in ipairs(s.enemies)do if e.hp>0 and not e.escaped then live=true end end
 if not live then return end
 for _=1,amount do
  assert(s.catalog.cards.dazed,'missing Hex Dazed')
  local c={cardId='dazed',uid=s.nextUid,upgraded=false};s.nextUid=s.nextUid+1.0
  if #s.draw==0 then s.draw[1]=c
  else table.insert(s.draw,R.randomInt(assert(s.cardRandomRng,'Hex needs card RNG'),#s.draw-1)+1,c) end
  Events.emit(s,'cards_created',{cardId='dazed',amount=1,pile='draw',status='hex'})
 end
end
function M.onDraw(s,card,base)
 if (s.player.statuses.confusion or 0)<=0 then return end
 base=card.combatCost or base
 if base<0 then return end
 local nextCost=R.randomInt(assert(s.cardRandomRng,'Confusion needs card RNG'),3)
 if nextCost~=base then
  card.costOverride,card.costForTurn=nextCost,nextCost
  card.combatCost,card.turnCost=nextCost,nextCost
 end
 card.freeToPlayOnce=false
end
function M.died(s,e)
 local stasis=Stasis.death(s,e);if stasis then push(s,stasis)end
 if e.ai and (e.ai.policy=='collector' or e.ai.policy=='automaton')then push(s,{op='boss_dead'}) end
 if e.ai and e.ai.policy=='leader'then push(s,{op='leader_dead'}) end
 if e.ai and e.ai.mugger and not e.muggerDeathSoundSampled then
  e.muggerDeathSoundSampled=true
  ER.integer(s,3,ER.legacyInteger)
 end
end
return M
