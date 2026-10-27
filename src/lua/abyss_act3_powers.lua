-- Narrow source action/power boundary. Actor and Combat own arithmetic/rollback.
local Events=require('abyss_events')
local R=require('abyss_sts_random')
local M={ownerEndIds={constricted=true}}
local function transient(actor)
 return actor.ai and actor.ai.kind=='act3'and actor.ai.policy=='transient'
end
-- AbstractMonster.onAttacked gets damage after block/modifiers, before the HP
-- clamp. Shifting has no DamageType filter; capture Artifact at hook time.
function M.attacked(_,actor,amount,reactions)
 if not transient(actor)or (actor.statuses.shifting or 0)<=0 or amount<=0 then return end
 reactions[#reactions+1]={effect={op='transientShift',target=actor,value=amount,
  restore=(actor.statuses.artifact or 0)<=0}}
end
function M.resolveShift(api,state,effect)
 local target,n=effect.target,effect.value
 assert(transient(target)and type(n)=='number'and n>0 and n%1==0,'invalid Shifting reaction')
 if not api.isActive(target)then return end
 -- The second addToTop resolves first. Both ApplyPower actions cancel on death.
 if effect.restore then
  api.applyPower(state,target,'shackled',math.min(999,n),target)
  if (target.statuses.shackled or 0)>999 then
   target.statuses.shackled=999;state.events[#state.events].frame=Events.frame(state)
  end
 end
 api.applyPower(state,target,'strength',-n,target)
end
function M.ownerEnd(api,state,actor)
 require('abyss_nemesis').ownerEnd(api,state,actor)
 if not transient(actor)or not api.isActive(actor)then return end
 local n=actor.statuses.shackled
 if n==nil then return end
 api.applyPower(state,actor,'strength',n,actor)
 actor.statuses.shackled=nil;require('abyss_power_schedule').remove(state,actor,'shackled')
 Events.emit(state,'status',{source=actor.id,target=actor.id,status='shackled',amount=-n})
end
-- Fading.duringTurn queues behind takeTurn's attack and ahead of the later
-- monster owner-end phase. This is not escape and does not suppress rewards.
function M.duringTurn(combat,state,enemy)
 if not transient(enemy)or enemy.hp<=0 then return end
 local n=enemy.statuses.fading
 assert(type(n)=='number'and n%1==0 and n>0,'invalid Fading countdown')
 if n==1 then combat.suicideTransient(state,enemy)
 else enemy.statuses.fading=n-1;Events.emit(state,'status',{source=enemy.id,target=enemy.id,status='fading',amount=-1})end
end
function M.active(state)
 for _,enemy in ipairs(state.enemies)do if enemy.ai and enemy.ai.kind=='act3'then return true end end
 return false
end
function M.ownerEndPlan(state,id,amount)
 assert(id=='constricted','unsupported Act3 owner-end Power')
 assert(type(amount)=='number'and amount%1==0 and amount>0 and amount<=2147483647
  and amount==state.player.statuses.constricted,'invalid Constricted amount')
 local source=state.constrictedSource
 assert(type(source)=='table'and source~=state.player and source.ai and source.ai.kind=='act3'and source.ai.policy=='spire_growth',
  'missing Constricted source actor')
 local found=false
 for _,enemy in ipairs(state.enemies)do if enemy==source then found=true;break end end
 assert(found,'Constricted source must be the original actor')
 -- Fixed ConstrictedPower has no source-death removal hook. A THORNS action
 -- survives its dead owner; capture that object and the amount when enqueueing,
 -- never resolve it again from a mutable slot or a similarly named actor.
 return {bottom={{op='ownerEndThorns',source=source,value=amount}}}
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
