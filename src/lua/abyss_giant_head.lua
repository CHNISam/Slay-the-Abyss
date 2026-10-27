-- Independent A0 Giant Head/Slow behavior, audited against fixed319009.
-- Actor/Combat retain arithmetic, action ownership and transaction boundaries.
local Copy=require('abyss_copy').copy
local Events=require('abyss_events')
local f32=require('abyss_sts_random').float32
local M={}
M.enemy={id='giant_head',sourceId='GiantHead',name='沉思巨像',tier='elite',hp=500,
 ai={kind='giant_head'},intents={
  {id='glare',kind='debuff',effects={{op='applyStatus',status='weak',value=1}}},
  {id='count',kind='attack',effects={{op='damage',value=13}}},
  {id='it_is_time',kind='attack',effects={{op='damage',value=30}}}}}
M.status={id='slow',sourceId='Slow',name='缓慢',kind='debuff',stack='intensity',decay='none',priority=5,
 description='每张牌结算后增加1层；普通攻击伤害每层增加10%，每轮结束归零。'}
local function select(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('unknown Giant Head intent '..tostring(id))
end
function M.advance(state,enemy,random)
 -- Even the forced repetition branch and capped ramp use RollMoveAction.
 local n=random(state,100)-1
 local count=assert(enemy.giantHeadCount,'missing Giant Head countdown')
 local id
 if count<=1 then
  count=math.max(-6,count-1);id='it_is_time'
  local intents={}
  for i,move in ipairs(enemy.intents)do
   if move.id==id then move=Copy(move);move.effects[1].value=30-count*5 end
   intents[i]=move
  end
  enemy.intents=intents -- Never mutate an earlier presentation frame's graph.
 else
  count=count-1
  local preferred=n<50 and 'glare'or 'count'
  local twice=enemy.giantHeadLast==preferred and enemy.giantHeadPrevious==preferred
  id=twice and (preferred=='glare'and 'count'or 'glare')or preferred
 end
 enemy.giantHeadCount=count
 enemy.giantHeadPrevious,enemy.giantHeadLast=enemy.giantHeadLast,id
 select(enemy,id)
end
function M.initialize(state,enemy,random)
 enemy.giantHeadCount,enemy.giantHeadLast,enemy.giantHeadPrevious=5,nil,nil
 M.advance(state,enemy,random)
end
function M.preBattle(api,state,enemy)
 api.applyPower(state,enemy,'slow',0,enemy)
end
-- UseCardAction.update dispatches this before disposal/exhaust callbacks, not
-- from useCard's constructor. ApplyPower goes to BOTTOM, not inline or TOP.
function M.afterUse(state,card,enqueue,instance)
 -- Source reads the physical card again at UseCardAction.update. A live
 -- false overrides captured true; nil retains the old definition-only ABI.
 local flag=instance and instance.dontTriggerOnUseCard
 if flag==nil then flag=card.dontTriggerOnUseCard end
 if flag then return end
 for _,enemy in ipairs(state.enemies)do
  if rawget(enemy.statuses,'slow')~=nil then
   enqueue(state,{op='giantHeadSlow',targetId=enemy.id})
  end
 end
end
function M.applySlow(api,state,effect)
 for _,enemy in ipairs(state.enemies)do if enemy.id==effect.targetId then
  -- The captured hook queues a NEW Slow Power; Artifact can block it and a
  -- dead owner cancels the action, just like any other ApplyPowerAction.
  return api.applyPower(state,enemy,'slow',1,enemy)
 end end
 return false
end
-- Slow and Vulnerable are equal-priority atDamageReceive Powers. Stable
-- acquisition order matters at binary32 boundaries; floor only after finals.
function M.receive(state,target,amount)
 local seen={}
 amount=f32(amount)
 for _,id in ipairs(target.powerOrder or {})do
  if id=='slow'and rawget(target.statuses,id)~=nil then
   local n=target.statuses[id]
   assert(type(n)=='number'and n%1==0 and n>=0 and n<=2147483647,'invalid Slow amount')
   amount=f32(amount*f32(1+f32(f32(n)*f32(.1))));seen.slow=true
  elseif id=='vulnerable'and (target.statuses[id]or 0)>0 then
   amount=f32(amount*f32(state.rules.combat.vulnerablePercent/100));seen.vulnerable=true
  end
 end
 assert(seen.slow,'missing Slow acquisition history')
 assert((target.statuses.vulnerable or 0)<=0 or seen.vulnerable,'missing Vulnerable acquisition history')
 return amount
end
function M.endRound(state,actor)
 local n=rawget(actor.statuses,'slow')
 if n==nil then return end
 actor.statuses.slow=0 -- Keep the same Power object and insertion position.
 if n~=0 then Events.emit(state,'status',{source=actor.id,target=actor.id,status='slow',amount=-n})end
end
function M.active(state)
 for _,enemy in ipairs(state.enemies)do
  if enemy.ai and enemy.ai.kind=='giant_head'or enemy.statuses.slow~=nil then return true end
 end
 return false
end
return M
