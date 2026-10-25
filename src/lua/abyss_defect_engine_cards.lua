-- Independently written data/plans for fixed319009 Defect engine cards.
-- Pure plans never commit RNG, instance changes, energy or queue mutations.
local Actors=require('abyss_actor')
local Random=require('abyss_sts_random')
local Events=require('abyss_events')
local M={}
M.ops={growClaws=true,stackBlock=true,loseSteamBlock=true,reduceStreamlineCost=true,
 aggregateEnergy=true,autoShields=true,blizzardDamage=true,chaosOrbs=true,chillOrbs=true,
 applyLockOn=true,removeBlock=true,randomEngineAttack=true,sunderDamage=true,
 tempestOrbs=true,multiCastOrb=true,thunderStrike=true}
local MAX=2147483647
local kinds={lightning=true,frost=true,dark=true,plasma=true}
local function copy(x)
 if type(x)~='table' then return x end
 local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y
end
local function integer(n,min)
 assert(type(n)=='number' and n==math.floor(n) and n>=(min or 0) and n<=MAX,'invalid Defect engine number')
 return n
end
local function add(a,b)return integer(a+0.0+b)end
local function e(op,value,extra)local x=extra or {};x.op=op;x.value=value;return x end
local function channel(kind)return e('channelOrb',1,{orb=kind})end
local cards={
 {id='claw',sourceId='Gash',name='利爪',type='attack',rarity='common',cost=0,
  effects={e('damage',3),e('growClaws',2)},upgrade={effects={e('damage',5),e('growClaws',2)}},
  text='造成3点伤害。本场战斗所有利爪的伤害增加2点。',upgradeText='造成5点伤害。本场战斗所有利爪的伤害增加2点。'},
 {id='stack',sourceId='Stack',name='堆栈',type='skill',rarity='common',cost=1,
  effects={e('stackBlock',0)},upgrade={effects={e('stackBlock',3)}},
  text='获得等同于弃牌堆张数的格挡。',upgradeText='获得等同于弃牌堆张数加3的格挡。'},
 {id='steam_barrier',sourceId='Steam',name='蒸汽护壁',type='skill',rarity='common',cost=0,
  effects={e('block',6),e('loseSteamBlock',1)},upgrade={effects={e('block',8),e('loseSteamBlock',1)}},
  text='获得6点格挡。本场战斗这张牌的基础格挡减少1。',upgradeText='获得8点格挡。本场战斗这张牌的基础格挡减少1。'},
 {id='streamline',sourceId='Streamline',name='精简改良',type='attack',rarity='common',cost=2,
  effects={e('damage',15),e('reduceStreamlineCost',1)},upgrade={effects={e('damage',20),e('reduceStreamlineCost',1)}},
  text='造成15点伤害。本场战斗这张牌的费用减少1。',upgradeText='造成20点伤害。本场战斗这张牌的费用减少1。'},
 {id='aggregate',sourceId='Aggregate',name='整合',type='skill',rarity='uncommon',cost=1,
  effects={e('aggregateEnergy',4)},upgrade={effects={e('aggregateEnergy',3)}},
  text='抽牌堆每有4张牌，获得1点能量。',upgradeText='抽牌堆每有3张牌，获得1点能量。'},
 {id='auto_shields',sourceId='Auto Shields',name='自动护盾',type='skill',rarity='uncommon',cost=1,
  effects={e('autoShields',11)},upgrade={effects={e('autoShields',15)}},
  text='如果你没有格挡，获得11点格挡。',upgradeText='如果你没有格挡，获得15点格挡。'},
 {id='blizzard',sourceId='Blizzard',name='暴风雪',type='attack',rarity='uncommon',cost=1,
  effects={e('blizzardDamage',0,{perOrb=2})},upgrade={effects={e('blizzardDamage',0,{perOrb=3})}},
  text='本场战斗每生成过一个冰霜充能球，对所有敌人造成2点伤害。',upgradeText='本场战斗每生成过一个冰霜充能球，对所有敌人造成3点伤害。'},
 {id='chaos',sourceId='Chaos',name='混沌',type='skill',rarity='uncommon',cost=1,
  effects={e('chaosOrbs',1)},upgrade={effects={e('chaosOrbs',2)}},
  text='生成1个随机充能球。',upgradeText='生成2个随机充能球。'},
 {id='chill',sourceId='Chill',name='冰寒',type='skill',rarity='uncommon',cost=0,exhaust=true,
  effects={e('chillOrbs',1)},upgrade={innate=true},
  text='每有一个敌人，生成1个冰霜充能球。消耗。',upgradeText='先天。每有一个敌人，生成1个冰霜充能球。消耗。'},
 {id='doom_and_gloom',sourceId='Doom and Gloom',name='愁云惨淡',type='attack',rarity='uncommon',cost=2,
  effects={e('damageAll',10),channel('dark')},upgrade={effects={e('damageAll',14),channel('dark')}},
  text='对所有敌人造成10点伤害。生成1个黑暗充能球。',upgradeText='对所有敌人造成14点伤害。生成1个黑暗充能球。'},
 {id='lock_on',sourceId='Lockon',name='锁定',type='attack',rarity='uncommon',cost=1,
  effects={e('damage',8),e('applyLockOn',2)},upgrade={effects={e('damage',11),e('applyLockOn',3)}},
  text='造成8点伤害。施加2回合锁定，使目标受到的充能球伤害增加50%。',upgradeText='造成11点伤害。施加3回合锁定，使目标受到的充能球伤害增加50%。'},
 {id='melter',sourceId='Melter',name='熔化',type='attack',rarity='uncommon',cost=1,
  effects={e('removeBlock',1),e('damage',10)},upgrade={effects={e('removeBlock',1),e('damage',14)}},
  text='移除目标的全部格挡。造成10点伤害。',upgradeText='移除目标的全部格挡。造成14点伤害。'},
 {id='rip_and_tear',sourceId='Rip and Tear',name='撕裂',type='attack',rarity='uncommon',cost=1,
  effects={e('randomEngineAttack',7,{times=2})},upgrade={effects={e('randomEngineAttack',9,{times=2})}},
  text='对随机敌人造成7点伤害，重复2次。',upgradeText='对随机敌人造成9点伤害，重复2次。'},
 {id='skim',sourceId='Skim',name='快速检索',type='skill',rarity='uncommon',cost=1,
  effects={e('draw',3)},upgrade={effects={e('draw',4)}},
  text='抽3张牌。',upgradeText='抽4张牌。'},
 {id='sunder',sourceId='Sunder',name='分离',type='attack',rarity='uncommon',cost=3,
  effects={e('sunderDamage',24)},upgrade={effects={e('sunderDamage',32)}},
  text='造成24点伤害。如果杀死目标，获得3点能量。',upgradeText='造成32点伤害。如果杀死目标，获得3点能量。'},
 {id='tempest',sourceId='Tempest',name='暴风雨',type='skill',rarity='uncommon',cost=-1,costMode='all_energy',experimental=true,exhaust=true,
  effects={e('tempestOrbs',0)},upgrade={effects={e('tempestOrbs',1)}},
  text='生成X个闪电充能球。消耗。',upgradeText='生成X+1个闪电充能球。消耗。'},
 {id='meteor_strike',sourceId='Meteor Strike',name='陨石打击',type='attack',rarity='rare',cost=5,sourceTags={'STRIKE'},
  effects={e('damage',24),channel('plasma'),channel('plasma'),channel('plasma')},
  upgrade={effects={e('damage',30),channel('plasma'),channel('plasma'),channel('plasma')}},
  text='造成24点伤害。生成3个等离子充能球。',upgradeText='造成30点伤害。生成3个等离子充能球。'},
 {id='multi_cast',sourceId='Multi-Cast',name='多重释放',type='skill',rarity='rare',cost=-1,costMode='all_energy',experimental=true,
  effects={e('multiCastOrb',0)},upgrade={effects={e('multiCastOrb',1)}},
  text='唤起最前方充能球X次，仅最后一次移除它。',upgradeText='唤起最前方充能球X+1次，仅最后一次移除它。'},
 {id='thunder_strike',sourceId='Thunder Strike',name='雷霆打击',type='attack',rarity='rare',cost=3,sourceTags={'STRIKE'},
  effects={e('thunderStrike',7)},upgrade={effects={e('thunderStrike',9)}},
  text='本场战斗每生成过一个闪电充能球，对随机敌人造成7点伤害。',upgradeText='本场战斗每生成过一个闪电充能球，对随机敌人造成9点伤害。'},
}
function M.withCards(data)
 assert(data and data.cards and data.cards.cards and data.statuses and data.statuses.statuses,'missing engine data')
 local out=copy(data);local seen={}
 for _,c in ipairs(out.cards.cards)do seen[c.id]=true end
 for _,c in ipairs(cards)do assert(not seen[c.id],'engine card collision: '..c.id);out.cards.cards[#out.cards.cards+1]=copy(c);seen[c.id]=true end
 for _,s in ipairs(out.statuses.statuses)do assert(s.id~='lock_on','Lock On status collision')end
 out.statuses.statuses[#out.statuses.statuses+1]={id='lock_on',name='锁定',kind='debuff',stack='duration',decay='none',
  description='受到的闪电与黑暗充能球伤害增加50%。每轮结束减少1回合。'}
 return out
end
function M.initHistory(state)
 assert(state.orbChannelCounts==nil,'orb channel history already initialized')
 state.orbChannelCounts={lightning=0,frost=0,dark=0,plasma=0}
end
function M.channelCount(state,kind)
 assert(kinds[kind],'unknown channel history kind')
 return integer(state.orbChannelCounts and state.orbChannelCounts[kind] or 0)
end
function M.onChannel(state,kind)
 assert(kinds[kind] and state.orbChannelCounts,'channel history not initialized')
 state.orbChannelCounts[kind]=add(M.channelCount(state,kind),1)
end
local function active(a)return Actors.isActive(a) and not a.halfDead and not a.isDying and not a.isEscaping end
local function targets(state)
 local out={};for _,a in ipairs(state.enemies)do if active(a)then out[#out+1]=a end end;return out
end
function M.adaptDefinition(state,instance,definition)
 local id=instance.cardId
 if id~='claw' and id~='stack' and id~='steam_barrier' and id~='blizzard' and id~='thunder_strike' then return definition end
 local out=copy(definition)
 if id=='claw' then out.effects[1].value=add(out.effects[1].value,integer(instance.engineClawBonus or 0))
 elseif id=='stack' then out.effects[1]=e('block',add(#state.discard,out.effects[1].value))
 elseif id=='steam_barrier' then out.effects[1].value=out.effects[1].value-integer(instance.engineBlockLoss or 0)
 elseif id=='blizzard' then out.effects[1].value=integer(M.channelCount(state,'frost')*1.0*out.effects[1].perOrb)
 elseif id=='thunder_strike' then out.effects[1].count=M.channelCount(state,'lightning') end
 return out
end
function M.prepareEffect(state,effect,target,context)
 local out=copy(effect);context=context or {}
 if effect.op=='autoShields' then
  out.enabled=state.player.block==0;out.value=integer(Actors.blockAmount(state,state.player,effect.value));out.fixed=true
 elseif effect.op=='stackBlock' then
  out=e('block',integer(Actors.blockAmount(state,state.player,add(#state.discard,effect.value))),{fixed=true})
 elseif effect.op=='blizzardDamage' then
  out.value=integer(M.channelCount(state,'frost')*1.0*integer(effect.perOrb));out.normalAmounts={}
  for _,a in ipairs(state.enemies)do out.normalAmounts[a.id]=integer(Actors.attackAmount(state,state.player,a,out.value))end
 elseif effect.op=='sunderDamage' then
  assert(target,'Sunder target missing');out.normalAmount=integer(Actors.attackAmount(state,state.player,target,effect.value))
 elseif effect.op=='chillOrbs' then out.count=integer(#targets(state)*1.0*integer(effect.value))
 elseif effect.op=='chaosOrbs' then
  assert(effect.value==1 or effect.value==2,'invalid Chaos count')
  local rng=Random.cloneState(assert(state.cardRandomRng,'Chaos requires cardRandomRng'));out.orbs={}
  local order={'dark','frost','lightning','plasma'}
  for i=1,effect.value do out.orbs[i]=order[Random.randomInt(rng,3)+1]end
  return out,rng
 elseif effect.op=='thunderStrike' then out.count=M.channelCount(state,'lightning')
 end
 return out
end
local function instanceByUid(state,uid)
 local found=state.cardInUse and state.cardInUse.uid==uid and state.cardInUse or nil
 for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust})do
  for _,c in ipairs(pile)do if c.uid==uid then assert(not found,'duplicate battle instance');found=c end end
 end
 return assert(found,'missing engine battle instance')
end
local function nextRound(op,value,remaining,extra)
 local x=extra or {};x.remaining=remaining;return e(op,value,x)
end
function M.planEffect(state,effect,context)
 context=context or {};local op=effect.op
 local p={top={},bottom={},consumeAllEnergy=false,instanceChanges={}}
 local function change(c,key,value)p.instanceChanges[#p.instanceChanges+1]={uid=c.uid,changes={[key]=value}}end
 if op=='growClaws' then
  assert(effect.value==2,'unsupported Claw increment')
  local original=context.instance or state.cardInUse
  assert(original and original.cardId=='claw','missing played Claw')
  local seen={}
  local function grow(c)if c.cardId=='claw' and not seen[c.uid]then seen[c.uid]=true;change(c,'engineClawBonus',add(integer(c.engineClawBonus or 0),2))end end
  grow(original)
  for _,pile in ipairs({state.hand,state.draw,state.discard})do for _,c in ipairs(pile)do grow(c)end end
 elseif op=='loseSteamBlock' then
  assert(effect.value==1,'unsupported Steam decrement')
  local c=instanceByUid(state,context.uid or (state.cardInUse and state.cardInUse.uid));assert(c.cardId=='steam_barrier','wrong Steam instance')
  change(c,'engineBlockLoss',add(integer(c.engineBlockLoss or 0),1))
 elseif op=='reduceStreamlineCost' then
  assert(effect.value==1,'unsupported Streamline decrement')
  local c=instanceByUid(state,context.uid or (state.cardInUse and state.cardInUse.uid));assert(c.cardId=='streamline','wrong Streamline instance')
  local def=state.catalog.cards.streamline
  local base=c.combatCost or def.cost;local turn=c.turnCost or base
  integer(base);integer(turn)
  local newBase,newTurn
  if turn>0 then newBase=math.max(0,turn-1);newTurn=newBase else newBase=math.max(0,base-1);newTurn=0 end
  p.instanceChanges[1]={uid=c.uid,changes={combatCost=newBase,turnCost=newTurn}}
 elseif op=='aggregateEnergy' then
  assert(effect.value==3 or effect.value==4,'invalid Aggregate divisor')
  p.top[1]=e('energy',math.floor(#state.draw/effect.value))
 elseif op=='autoShields' then
  assert(type(effect.enabled)=='boolean' and effect.fixed==true,'Auto Shields not prepared')
  if effect.enabled then p.top[1]=e('block',integer(effect.value),{fixed=true})end
 elseif op=='blizzardDamage' then
  assert(effect.normalAmounts,'Blizzard not prepared');p.top[1]=e('damageAll',integer(effect.value),{normalAmounts=copy(effect.normalAmounts)})
 elseif op=='chaosOrbs' then
  assert(effect.orbs and #effect.orbs==effect.value,'Chaos not prepared')
  for _,kind in ipairs(effect.orbs)do assert(kinds[kind],'invalid prepared Chaos orb');p.top[#p.top+1]=channel(kind)end
 elseif op=='chillOrbs' then
  integer(effect.count);if effect.count>0 then p.top[1]=nextRound('engineChannelRounds',1,effect.count,{orb='frost'})end
 elseif op=='randomEngineAttack' or op=='thunderStrike' then
  local count=op=='thunderStrike' and effect.count or effect.times
  integer(count);integer(effect.value)
  if count>0 then p.top[1]=nextRound('engineRandomRounds',effect.value,count)end
 elseif op=='engineRandomRounds' then
  integer(effect.remaining,1);integer(effect.value)
  local enemies=targets(state)
  if #enemies>0 then
   local rng=Random.cloneState(assert(state.cardRandomRng,'random attack requires cardRandomRng'))
   local target=enemies[Random.randomInt(rng,#enemies-1)+1]
   p.cardRandomRng=rng
   p.top[1]=e('damage',effect.value,{targetId=target.id,normalAmount=integer(Actors.attackAmount(state,state.player,target,effect.value))})
   if effect.remaining>1 then p.top[2]=nextRound(op,effect.value,effect.remaining-1)end
  end
 elseif op=='sunderDamage' then
  assert(integer(effect.normalAmount) and context.target,'Sunder not prepared')
  p.top[1]=e('damage',effect.value,{normalAmount=effect.normalAmount})
  p.top[2]=e('engineSunderRefund',3,{targetId=context.target.id})
 elseif op=='engineSunderRefund' then
  for _,a in ipairs(state.enemies)do if a.id==effect.targetId and (a.hp<=0 or a.isDying)then p.bottom[1]=e('energy',3)end end
 elseif op=='tempestOrbs' or op=='multiCastOrb' then
  assert(effect.value==0 or effect.value==1,'invalid X upgrade bonus')
  local x=context.energyOnUse;if x==nil or x==-1 then x=state.energy end;integer(x)
  assert(context.freeToPlayOnce==nil or type(context.freeToPlayOnce)=='boolean','invalid X free flag')
  assert(not context.chemicalX or context.chemicalX==0,'Chemical X unsupported')
  local count=add(x,effect.value)
  local hasOrb=state.orbs and #state.orbs.balls>0
  if count>0 and (op=='tempestOrbs' or hasOrb)then
   p.consumeAllEnergy=context.freeToPlayOnce~=true
   p.bottom[1]=nextRound(op=='tempestOrbs' and 'engineChannelRounds' or 'engineEvokeRounds',1,count,{orb=op=='tempestOrbs' and 'lightning' or nil})
  end
 elseif op=='engineChannelRounds' then
  integer(effect.remaining,1);assert(kinds[effect.orb],'invalid channel repetition')
  p.top[1]=channel(effect.orb)
  if effect.remaining>1 then p.top[2]=nextRound(op,1,effect.remaining-1,{orb=effect.orb})end
 elseif op=='engineEvokeRounds' then
  integer(effect.remaining,1)
  p.top[1]=e(effect.remaining==1 and 'evokeOrb' or 'evokeWithoutRemovingOrb',1)
  if effect.remaining>1 then p.top[2]=nextRound(op,1,effect.remaining-1)end
 else return nil end
 return p
end
function M.applyLockOn(state,target,amount)
 integer(amount,1)
 if not active(target)then return false end
 if Actors.tryBlockDebuff(state,target,'lock_on')then return false end
 Actors.status(state,target,'lock_on',amount,state.player)
 return true
end
function M.endRound(state)
 for _,target in ipairs(state.enemies)do
  local value=target.statuses.lock_on
  if value~=nil and active(target)then
   integer(value);target.statuses.lock_on=value>1 and value-1 or nil
   Events.emit(state,'status',{source=target.id,target=target.id,status='lock_on',amount=value>0 and -1 or 0})
  end
 end
end
-- Java float multiplication in AbstractOrb.applyLockOn, including int saturation.
function M.orbDamage(target,amount)
 integer(amount)
 if target.statuses.lock_on==nil then return amount end
 return math.min(MAX,math.floor(Random.float32(Random.float32(amount)*1.5)))
end
return M
