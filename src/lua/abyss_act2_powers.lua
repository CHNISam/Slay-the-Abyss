-- Source damage/death reactions. Actor supplies the current queue insertion.
local Events=require('abyss_events')
local R=require('abyss_sts_random')
local ER=require('abyss_enemy_random')
local Stasis=require('abyss_act2_stasis')
local M={}
local ops={flight_hit=true,act2Block=true,painfulWound=true,stasis_return=true,boss_dead=true,leader_dead=true}
function M.supports(op)return ops[op]==true end
function M.retained(effect)return effect.op=='act2Block' or effect.op=='boss_dead' end
function M.damaged(s,source,target,lost,fixed,push)
 if source and not fixed and lost>0 and (target.statuses.flight or 0)>0 then push(s,{op='flight_hit',targetId=target.id}) end
 if source and not fixed and lost>0 and lost<target.hp and (target.statuses.malleable or 0)>0 then
  push(s,{op='act2Block',targetId=target.id,value=target.statuses.malleable},target==s.player)
  target.statuses.malleable=target.statuses.malleable+1
 end
end
function M.inflicted(s,source,lost,fixed,push)
 if source and not fixed and lost>0 and (source.statuses.painful_stabs or 0)~=0 then
  push(s,{op='painfulWound',card='wound'})
 end
end
function M.apply(api,s,entry)
 if s.player.hp<=0 then return true end
 local live=false;for _,e in ipairs(s.enemies)do if api.isPresent(e)then live=true end end
 local target
 for _,e in ipairs(s.enemies)do if e.id==entry.targetId then target=e;break end end
 if entry.targetId==s.player.id then target=s.player end
  if entry.op=='stasis_return'then Stasis.release(api,s,entry)
  elseif entry.op=='boss_dead'then
   for _,e in ipairs(s.enemies)do if api.isActive(e)then e.hp=0;Events.emit(s,'enemy_suicide',{enemy=e.id})end end
   s.act2StasisCards=nil
  elseif entry.op=='leader_dead'then
   for _,e in ipairs(s.enemies)do if api.isActive(e)then e.escaped=true;Events.emit(s,'enemy_escape',{enemy=e.id})end end
  elseif entry.op=='flight_hit' and api.isActive(target) and (target.statuses.flight or 0)>0 then
   local e=target;e.statuses.flight=e.statuses.flight-1
   if e.statuses.flight==0 then require('abyss_power_order').remove(e,'flight')end
   Events.emit(s,'status',{source=e.id,target=e.id,status='flight',amount=-1})
   if e.statuses.flight==0 then
    for i,intent in ipairs(e.intents)do if intent.id=='stunned'then e.intentIndex=i end end
    Events.emit(s,'enemy_interrupt',{enemy=e.id,id='stunned'})
   end
  elseif entry.op=='act2Block' and api.isActive(target) then api.block(s,target,entry.value,true)
  elseif entry.op=='painfulWound' and live then
   assert(s.catalog.cards[entry.card],'unknown enemy-generated card')
   local c={cardId=entry.card,uid=s.nextUid,upgraded=false}
   s.nextUid=s.nextUid+1.0;s.discard[#s.discard+1]=c
   Events.emit(s,'cards_created',{cardId=entry.card,amount=1,pile='discard'})
  end
 return true
end
function M.afterCard(s,reactions,api)
 local amount=reactions and reactions.hex or 0
 if amount==0 or s.player.hp<=0 then return end
 local live=false;for _,e in ipairs(s.enemies)do if api.isPresent(e)then live=true end end
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
function M.stasisDied(s,e,push)
 local stasis=Stasis.death(s,e);if stasis then push(s,stasis)end
end
function M.died(s,e,push)
 -- Both source bosses queue DAMAGE-typed SuicideAction at TOP. Stasis and
 -- Leader's EscapeAction remain BOTTOM, with their original constructor data.
 if e.ai and (e.ai.policy=='collector' or e.ai.policy=='automaton')then push(s,{op='boss_dead'},true) end
 if e.ai and e.ai.policy=='leader'then push(s,{op='leader_dead'}) end
 if e.ai and e.ai.mugger and not e.muggerDeathSoundSampled then
  e.muggerDeathSoundSampled=true
  ER.integer(s,3,ER.legacyInteger)
 end
end
return M
