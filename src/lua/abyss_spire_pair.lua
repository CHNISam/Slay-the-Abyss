-- Fixed319009 A0 Shield/Spear component. Combat owns execution and rollback.
local Random=require('abyss_enemy_random')
local f32=require('abyss_sts_random').float32
local M={}
local function move(id,kind,effects)return{id=id,kind=kind,effects=effects or {}}end
M.enemies={
 {id='spire_shield',sourceId='SpireShield',name='尖塔之盾',tier='elite',hp=110,
  sourcePosition={x=-1000,y=15},spireSide='left',ai={kind='spire_pair',policy='shield'},intents={
   move('bash','attack',{{op='damage',value=12}}),move('fortify','defend'),
   move('smash','attack',{{op='damage',value=34}})}},
 {id='spire_spear',sourceId='SpireSpear',name='尖塔之矛',tier='elite',hp=160,
  sourcePosition={x=70,y=10},spireSide='right',ai={kind='spire_pair',policy='spear'},intents={
   move('burn_strike','attack',{{op='damage',value=5,times=2},{op='makeTempCardInDiscard',card='burn',value=2}}),
   move('piercer','buff'),move('skewer','attack',{{op='damage',value=10,times=3}})}}}
M.statuses={
 {id='surrounded',sourceId='Surrounded',name='被包围',kind='buff',stack='none',decay='none',
  description='转向指定目标；身后的敌人造成50%额外攻击伤害。'},
 {id='back_attack',sourceId='BackAttack',name='背刺',kind='buff',stack='none',decay='none',
  description='从玩家背后攻击，造成50%额外伤害。'}}
function M.register(catalog,copy)
 for _,entry in ipairs(M.enemies)do
  assert(not catalog.enemies[entry.id],'duplicate Spire pair enemy');catalog.enemies[entry.id]=copy(entry)
 end
 for _,entry in ipairs(M.statuses)do
  assert(not catalog.statuses[entry.id],'duplicate Spire pair Power');catalog.statuses[entry.id]=copy(entry)
 end
end
function M.owns(enemy)return enemy~=nil and enemy.ai~=nil and enemy.ai.kind=='spire_pair'end
function M.resolve(source,tier)
 if source~='Shield and Spear'then return nil,'act_content_unavailable'end
 if tier~='elite'then return nil,'encounter_tier_mismatch'end
 return{id='ending_spire_pair',tier=tier,source=source,enemies={'spire_shield','spire_spear'}}
end
local function select(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('unknown Spire pair intent: '..tostring(id))
end
function M.advance(state,enemy,random)
 assert(M.owns(enemy),'Spire pair AI owner required')
 random(state,100) -- AbstractMonster.rollMove consumes num even though ignored.
 local phase,id=enemy.spireMoveCount%3
 if enemy.ai.policy=='shield'then
  if phase==0 then id=Random.boolean(state,random)and 'fortify'or 'bash'
  elseif phase==1 then id=enemy.spireLast=='bash'and 'fortify'or 'bash'
  else id='smash'end
 else
  assert(enemy.ai.policy=='spear','unsupported Spire pair AI')
  if phase==0 then id=enemy.spireLast=='burn_strike'and 'piercer'or 'burn_strike'
  elseif phase==1 then id='skewer'
  else id=Random.boolean(state,random)and 'piercer'or 'burn_strike'end
 end
 enemy.spireMoveCount=enemy.spireMoveCount+1;select(enemy,id)
end
function M.initialize(state,enemy,random)
 enemy.spireMoveCount,enemy.spireLast=0,nil;M.advance(state,enemy,random)
end
function M.afterAction(state,enemy,random,executed)
 -- Source RollMoveAction has no owner-death guard. Shared queue decides whether
 -- combat has ended; a surviving partner preserves this already queued roll.
 assert(M.owns(enemy),'Spire pair RollMove owner required')
 local found=false;for _,intent in ipairs(enemy.intents)do if intent.id==executed.id then found=true end end
 assert(found,'unknown captured Spire pair intent')
 enemy.spireLast=executed.id;M.advance(state,enemy,random)
end
function M.backAttack(state,enemy)
 local facing=state.spirePair
 return M.owns(enemy)and facing~=nil and (state.player.statuses.surrounded or 0)>0
  and (facing.facingLeft and enemy.spireSide=='right'or not facing.facingLeft and enemy.spireSide=='left')or false
end
function M.refreshFacing(api,state)
 for _,enemy in ipairs(state.enemies)do
  if M.owns(enemy)and api.isActive(enemy)then
   if M.backAttack(state,enemy)then
    if (enemy.statuses.back_attack or 0)==0 then api.applyPower(state,enemy,'back_attack',1,nil)end
   elseif (enemy.statuses.back_attack or 0)~=0 then api.removePower(state,enemy,'back_attack')end
  end
 end
end
function M.preBattle(api,state,enemy)
 assert(M.owns(enemy),'Spire pair preBattle owner required')
 if enemy.ai.policy=='shield'then
  state.spirePair={facingLeft=false};api.applyPower(state,state.player,'surrounded',1,enemy)
 end
 api.applyPower(state,enemy,'artifact',1,enemy);M.refreshFacing(api,state)
end
function M.faceTarget(api,state,target)
 if not M.owns(target)or not api.isActive(target)or not state.spirePair
  or (state.player.statuses.surrounded or 0)<=0 then return false end
 state.spirePair.facingLeft=target.spireSide=='left';M.refreshFacing(api,state);return true
end
function M.actualDamage(state,enemy,normalOutput)
 assert(type(normalOutput)=='number'and normalOutput%1==0 and normalOutput>=0,'invalid ordinary damage output')
 if not M.backAttack(state,enemy)then return normalOutput end
 return math.floor(f32(f32(normalOutput)*1.5))
end
function M.intentDamage(state,enemy,preFinal,finalReceive)
 local value=preFinal
 if M.backAttack(state,enemy)then
  value=f32(f32(value)*1.5);value=value<0 and math.ceil(value)or math.floor(value)
 end
 return math.max(0,math.floor(finalReceive(value)))
end
local function append(actions,kind,enemy,target,fields)
 local action={kind=kind,sourceId=enemy.id,targetId=target and target.id or nil}
 for key,value in pairs(fields or {})do action[key]=value end
 actions[#actions+1]=action
end
local function attacks(actions,state,enemy,base,times,snapshotDamage)
 local output=M.actualDamage(state,enemy,snapshotDamage(state,enemy,base))
 for _=1,times do append(actions,'damage',enemy,state.player,{value=base,normalAmount=output})end
 return output
end
function M.takeTurn(state,enemy,random,snapshotDamage)
 assert(M.owns(enemy),'Spire pair action owner required')
 local intent=assert(enemy.intents[enemy.intentIndex],'missing Spire pair intent').id
 local actions={}
 if intent=='bash'then
  attacks(actions,state,enemy,12,1,snapshotDamage)
  local focus=state.orbs and state.orbs.slots>0 and Random.boolean(state,random)
  append(actions,'power',enemy,state.player,{status=focus and 'focus'or 'strength',value=-1})
 elseif intent=='fortify'or intent=='piercer'then
  for _,target in ipairs(state.enemies)do
   append(actions,intent=='fortify'and 'block'or 'power',enemy,target,
    intent=='fortify'and {value=30}or {status='strength',value=2})
  end
 elseif intent=='smash'then
  local output=attacks(actions,state,enemy,34,1,snapshotDamage)
  append(actions,'block',enemy,enemy,{value=output})
 elseif intent=='burn_strike'then
  attacks(actions,state,enemy,5,2,snapshotDamage)
  append(actions,'discard',enemy,state.player,{card='burn',value=2})
 elseif intent=='skewer'then attacks(actions,state,enemy,10,3,snapshotDamage)
 else error('unknown Spire pair action: '..tostring(intent))end
 append(actions,'roll',enemy,nil,{intentId=intent});return actions
end
function M.died(state,enemy,enqueue)
 if not M.owns(enemy)or enemy.hp>0 or enemy.spireDeathQueued then return false end
 enemy.spireDeathQueued=true
 for _,survivor in ipairs(state.enemies)do
  if survivor.hp>0 and not survivor.isDying and not survivor.escaped then
   if (state.player.statuses.surrounded or 0)>0 then
    assert(state.spirePair and M.owns(survivor),'Spire pair death requires its encounter owner')
    state.spirePair.facingLeft=survivor.spireSide=='left'
    enqueue({op='removeStatus',targetId=state.player.id,status='surrounded'})
   end
   if (survivor.statuses.back_attack or 0)>0 then
    enqueue({op='removeStatus',targetId=survivor.id,status='back_attack'})
   end
  end
 end
 return true
end
return M
