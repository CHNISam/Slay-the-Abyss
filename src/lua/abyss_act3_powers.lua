-- Narrow source action/power boundary. Actor and Combat own arithmetic/rollback.
local Events=require('abyss_events')
local R=require('abyss_sts_random')
local M={}
function M.active(state)
 for _,enemy in ipairs(state.enemies)do if enemy.ai and enemy.ai.kind=='act3'then return true end end
 return false
end
function M.endRound(api,state,actor)
 local amount=actor.statuses.generic_strength_up or 0
 if actor==state.player or not api.isActive(actor) or amount==0 then return end
 assert(type(amount)=='number'and amount%1==0 and amount>0 and amount<=2147483647,'invalid Growth amount')
 api.applyPower(state,actor,'strength',amount,actor)
end
function M.burnBoth(state,source)
 assert(source.ai and source.ai.kind=='act3'and source.ai.policy=='orb_walker','Orb Walker Burn only')
 local definition=state.catalog.cards.burn
 assert(definition and definition.type=='status','missing Burn definition')
 local uid=state.nextUid
 assert(type(uid)=='number'and uid>0 and uid%1==0 and uid<math.huge,'invalid nextUid')
 local second,nextUid=uid+0.0+1,uid+0.0+2
 assert(second>uid and nextUid>second and nextUid-uid==2,'nextUid cannot advance')
 -- CardGroup.addToRandomSpot excludes the original top and skips the draw only
 -- for an empty pile. This action never invokes shuffleRng.
 local position=#state.draw==0 and 1 or R.randomInt(assert(state.cardRandomRng,'Burn placement needs card RNG'),#state.draw-1)+1
 table.insert(state.draw,position,{uid=uid,cardId='burn',upgraded=false})
 state.nextUid=second
 Events.emit(state,'cards_created',{source=source.id,cardId='burn',amount=1,pile='draw'})
 state.discard[#state.discard+1]={uid=second,cardId='burn',upgraded=false}
 state.nextUid=nextUid
 Events.emit(state,'cards_created',{source=source.id,cardId='burn',amount=1,pile='discard'})
end
function M.dazedDraw(state,source)
 assert(source.ai and source.ai.kind=='act3'and source.ai.policy=='repulsor','Repulsor Dazed only')
 local d=state.catalog.cards.dazed;assert(d and d.type=='status','missing Dazed definition')
 local uid=state.nextUid
 assert(type(uid)=='number'and uid>0 and uid%1==0 and uid<math.huge,'invalid nextUid')
 local second,nextUid=uid+0.0+1,uid+0.0+2
 assert(second>uid and nextUid>second and nextUid-uid==2,'nextUid cannot advance')
 for i=0,1 do
  local position=#state.draw==0 and 1 or R.randomInt(assert(state.cardRandomRng,'Dazed placement needs card RNG'),#state.draw-1)+1
  table.insert(state.draw,position,{uid=uid+0.0+i,cardId='dazed',upgraded=false})
  state.nextUid=uid+0.0+i+1
  Events.emit(state,'cards_created',{source=source.id,cardId='dazed',amount=1,pile='draw'})
 end
end
-- takeTurn queues RollMove before duringTurn queues these actions. DAMAGE
-- survives the SuicideAction even when that was the final live monster.
function M.afterTurn(combat,state,enemy)
 if not enemy.ai or enemy.ai.kind~='act3'or enemy.ai.policy~='exploder'or enemy.hp<=0 then return end
 local amount=enemy.statuses.explosive or 0
 assert(type(amount)=='number'and amount%1==0 and amount>0,'invalid Explosive countdown')
 if amount~=1 then
  enemy.statuses.explosive=amount-1
  Events.emit(state,'status',{source=enemy.id,target=enemy.id,status='explosive',amount=-1})
  return
 end
 combat.suicideExploder(state,enemy)
 combat.retaliate(state,enemy,state.player,30)
end
return M
