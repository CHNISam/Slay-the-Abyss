-- A0 Darkling/Regrow rules, independently implemented from sts@319009d5.
-- Actor owns death callbacks. Combat keeps the sole existing action queues.
local Events=require('abyss_events')
local M={}
function M.owns(actor)return actor and actor.ai and actor.ai.kind=='darkling'end
function M.active(state)
 for _,actor in ipairs(state.enemies)do if M.owns(actor)then return true end end
 return false
end
M.enemy={id='darkling',sourceId='Darkling',name='共生暗影',tier='normal',hp=56,
 hpRange={min=48,max=56},ai={kind='darkling'},intents={
  {id='chomp',kind='attack',effects={{op='damage',value=8,times=2}}},
  {id='harden',kind='defend',effects={{op='block',value=12}}},
  {id='nip',kind='attack',effects={{op='damage',value=7}}},
  {id='regrow',kind='unknown',effects={}},
  {id='reincarnate',kind='buff',effects={}},
 }}
M.status={id='regrow',sourceId='Life Link',name='共生',kind='buff',stack='none',decay='none',
 description='生命归零时休眠；行动一次后准备复生，再下次行动回复最大生命的一半。全部暗影同时休眠才会被击败。'}
function M.register(catalog,copy)
 assert(not catalog.enemies.darkling and not catalog.statuses.regrow,'duplicate Darkling definition')
 catalog.enemies.darkling,catalog.statuses.regrow=copy(M.enemy),copy(M.status)
end
local function select(actor,id)
 for i,intent in ipairs(actor.intents)do if intent.id==id then
  actor.intentIndex=i
  local history={};for _,old in ipairs(actor.darklingHistory or {})do history[#history+1]=old end
  history[#history+1]=id;actor.darklingHistory=history
  return
 end end
 error('unknown Darkling intent: '..tostring(id))
end
function M.prepare(state,actor,random)
 -- Constructor spends HP then Nip damage on monsterHpRng, per slot, before
 -- constructing the next actor. Animation/audio MathUtils is not game RNG.
 actor.darklingNip=6+random(state,5)
 for _,intent in ipairs(actor.intents)do if intent.id=='nip'then intent.effects[1].value=actor.darklingNip end end
end
function M.preBattle(api,state,actor)
 state.darklingsCannotLose=true
 api.applyPower(state,actor,'regrow',-1,actor)
end
local function choose(state,actor,num,random)
 if actor.halfDead then select(actor,'reincarnate');return end
 if actor.darklingFirst then
  actor.darklingFirst=false;select(actor,num<50 and 'harden'or 'nip');return
 end
 local h=actor.darklingHistory or {};local last,previous=h[#h],h[#h-1]
 while true do
  if num<40 then
   local slot
   for i,enemy in ipairs(state.enemies)do if enemy==actor then slot=i end end
   assert(slot,'Darkling needs its actual group index')
   if last~='chomp'and slot%2==1 then select(actor,'chomp');return end
   num=39+random(state,60) -- source aiRng.random(40,99), not another 0..99
  elseif num<70 then select(actor,last~='harden'and 'harden'or 'nip');return
  elseif not(last=='nip'and previous=='nip')then select(actor,'nip');return
  else num=random(state,100)-1 end
 end
end
function M.initialize(state,actor,random)
 actor.darklingFirst=true
 choose(state,actor,random(state,100)-1,random)
end
function M.afterAction(state,actor,random)
 choose(state,actor,random(state,100)-1,random)
end
function M.deathStart(state,actor,before)
 if not M.owns(actor)or before<=0 or actor.hp>0 or actor.halfDead then return false end
 -- Superclass damage calls suppressed die(), then loses old Block, before
 -- Darkling.damage visits onDeath. HP_LOSS therefore clears Block here too.
 assert(state.darklingsCannotLose,'Darkling death outside linked encounter')
 actor.block,actor.halfDead=0,true
 return true
end
function M.deathFinish(state,actor,visit,push)
 -- Darkling clears ALL Powers, after callbacks have captured their actions.
 for id in pairs(actor.statuses)do require('abyss_power_schedule').remove(state,actor,id);actor[id..'JustApplied']=nil end
 actor.statuses,actor.powerOrder={},{}
 actor.temporaryStrength,actor.temporaryDexterity,actor.temporaryPowerOrder=nil,nil,nil
 local allDead=true
 for _,enemy in ipairs(state.enemies)do if M.owns(enemy)and not enemy.halfDead then allDead=false end end
 if not allDead then
  if actor.intents[actor.intentIndex].id~='regrow'then
   select(actor,'regrow');Events.emit(state,'enemy_interrupt',{enemy=actor.id,id='regrow'})
   push(state,{op='darklingAction',kind='setRegrow',targetId=actor.id})
  end
 else
  state.darklingsCannotLose=nil
  actor.halfDead=false
  -- Source die() leaves earlier actors' halfDead flags intact. isDying is
  -- terminal: those flags must not keep the group present or allow revival.
  for _,enemy in ipairs(state.enemies)do if not enemy.isDying then
   enemy.isDying=true
   visit(enemy)
  end end
 end
end
function M.resolve(state,effect)
 local actor
 for _,enemy in ipairs(state.enemies)do if enemy.id==effect.targetId then actor=enemy;break end end
 assert(M.owns(actor)and effect.kind=='setRegrow','invalid Darkling action')
 select(actor,'regrow')
end
function M.reincarnate(api,state,actor,stage)
 assert(M.owns(actor)and not actor.isDying,'invalid Darkling revival')
 if stage=='darklingHeal'then
  assert(actor.halfDead and actor.hp==0,'Reincarnate requires halfDead')
  local amount=math.floor(actor.maxHp/2)
  actor.hp=amount;Events.emit(state,'heal',{target=actor.id,amount=amount})
 elseif stage=='darklingRevive'then actor.halfDead=false
 elseif stage=='darklingRegrow'then api.applyPower(state,actor,'regrow',-1,actor)
 else error('unknown Darkling revival stage')end
end
return M
