-- Independently written data/plans from pinned319009 Watcher sources.
-- The host owns the real queue, normal damage, power application and movements.
local M={}
M.ops={gainWatcherFlowPower=true,applyWatcherFlowPower=true,fearNoEvil=true,
 indignation=true,collect=true,wallop=true,triggerMarks=true,flowDamage=true}
local Actors=require('abyss_actor')
local MAX=2147483647
local function copy(x)
 if type(x)~='table' then return x end
 assert(getmetatable(x)==nil,'flow data must be plain')
 local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y
end
local function int(n,min)
 assert(type(n)=='number' and n==n and n%1==0 and n>=(min or 0) and n<=MAX,'invalid Watcher flow amount');return n
end
local function e(op,n,extra)local out=extra or {};out.op=op;if n~=nil then out.value=n end;return out end
local function gain(id,n)return e('gainWatcherFlowPower',n,{status=id})end
local function make(id,pile,up,n)
 return e('makeTempCard',n or 1,{cardId=id,pile=pile,upgraded=up==true,randomSpot=pile=='draw' or nil})
end
local specs={
 {'battle_hymn','BattleHymn','Battle Hymn','战歌','power','uncommon',1,{gain('battle_hymn',1)},nil,{innate=true}},
 {'collect','Collect','Collect','聚气','skill','uncommon',-1,{e('collect',0)},{e('collect',1)},{costMode='all_energy',exhaust=true,experimental=true}},
 {'fasting','Fasting2','Fasting','斋戒','power','uncommon',2,{e('gainStatus',3,{status='strength'}),e('gainStatus',3,{status='dexterity'}),gain('energy_down',1)},
  {e('gainStatus',4,{status='strength'}),e('gainStatus',4,{status='dexterity'}),gain('energy_down',1)}},
 {'fear_no_evil','FearNoEvil','Fear No Evil','无惧邪恶','attack','uncommon',1,{e('fearNoEvil',8)},{e('fearNoEvil',11)}},
 {'indignation','Indignation','Indignation','愤慨','skill','uncommon',1,{e('indignation',3)},{e('indignation',5)}},
 {'like_water','LikeWater','Like Water','如水','power','uncommon',1,{gain('like_water',5)},{gain('like_water',7)}},
 {'pray','Pray','Pray','祈祷','skill','uncommon',1,{e('gainMantra',3),make('insight','draw')},{e('gainMantra',4),make('insight','draw')}},
 {'reach_heaven','ReachHeaven','Reach Heaven','直达天堂','attack','uncommon',2,{e('damage',10),make('through_violence','draw')},{e('damage',15),make('through_violence','draw')}},
 {'study','Study','Study','研习','power','uncommon',2,{gain('study',1)},nil,{upgradeCost=1}},
 {'talk_to_the_hand','TalkToTheHand','Talk to the Hand','以手拒之','attack','uncommon',1,{e('damage',5),e('applyWatcherFlowPower',2,{status='block_return'})},
  {e('damage',7),e('applyWatcherFlowPower',3,{status='block_return'})},{exhaust=true}},
 {'tantrum','Tantrum','Tantrum','暴怒','attack','uncommon',1,{e('flowDamage',3,{times=3}),e('changeStance',nil,{stance='Wrath'})},
  {e('flowDamage',3,{times=4}),e('changeStance',nil,{stance='Wrath'})},{shuffleBackIntoDrawPile=true}},
 {'simmering_fury','Vengeance','Simmering Fury','酝酿怒火','skill','uncommon',1,{gain('wrath_next_turn',1),gain('draw_card_next_turn',2)},
  {gain('wrath_next_turn',1),gain('draw_card_next_turn',3)}},
 {'wallop','Wallop','Wallop','当头棒喝','attack','uncommon',2,{e('wallop',9)},{e('wallop',12)}},
 {'wheel_kick','WheelKick','Wheel Kick','回旋踢','attack','uncommon',2,{e('damage',15),e('draw',2)},{e('damage',20),e('draw',2)}},
 {'wreath_of_flame','WreathOfFlame','Wreath of Flame','火焰之环','skill','uncommon',1,{gain('vigor',5)},{gain('vigor',8)}},
 {'pressure_points','PathToVictory','Pressure Points','点穴','skill','common',1,{e('applyWatcherFlowPower',8,{status='mark'}),e('triggerMarks',1)},
  {e('applyWatcherFlowPower',11,{status='mark'}),e('triggerMarks',1)}},
 {'flurry_of_blows','FlurryOfBlows','Flurry of Blows','连打','attack','common',0,{e('flowDamage',4)},{e('flowDamage',6)}},
 {'weave','Weave','Weave','编织','attack','uncommon',0,{e('flowDamage',4)},{e('flowDamage',6)}},
}
local powers={
 battle_hymn={'战歌','BattleHymn','buff','从下回合起，回合开始时生成等同层数的未升级惩罚加入手牌。'},
 collect={'聚气','Collect','buff','恢复能量时生成一张奇迹+，随后层数减一；层数表示剩余回合数。'},
 energy_down={'能量降低','EnergyDownPower','debuff','从下回合起，回合开始时失去等同层数的能量。'},
 like_water={'如水','LikeWaterPower','buff','结束回合的手牌处理之前，若处于平静，获得等同层数的固定格挡。'},
 study={'研习','Study','buff','回合结束时，将等同层数的未升级洞见随机插入抽牌堆。'},
 block_return={'以手拒之','BlockReturnPower','debuff','受到来自其他角色的普通攻击时，即使伤害为0，给玩家等同层数的固定格挡。'},
 wrath_next_turn={'下回合愤怒','WrathNextTurnPower','buff','下个自身回合开始时进入愤怒，随后移除此状态。'},
 draw_card_next_turn={'下回合抽牌','Draw Card','buff','下个自身回合正常抽牌后，额外抽等同层数的牌，随后移除此状态。'},
 vigor={'振奋','Vigor','buff','下一张攻击的每次普通伤害增加等同层数；构造伤害后排队移除此状态。'},
 mark={'印记','PathToVictoryPower','debuff','点穴触发所有敌人的印记，使其失去等同层数的生命，无视格挡。'},
}
local powerOrder={'battle_hymn','collect','energy_down','like_water','study','block_return','wrath_next_turn','draw_card_next_turn','vigor','mark'}
local descriptions={
 battle_hymn={'从下回合起，每回合开始时将1张惩罚加入手牌。','先天。从下回合起，每回合开始时将1张惩罚加入手牌。'},
 collect={'消耗所有能量。接下来X个回合，恢复能量时生成1张奇迹+。消耗。','消耗所有能量。接下来X+1个回合，恢复能量时生成1张奇迹+。消耗。'},
 fasting={'获得3力量与3敏捷。从下回合起，每回合开始失去1能量。','获得4力量与4敏捷。从下回合起，每回合开始失去1能量。'},
 fear_no_evil={'造成8点伤害。若目标正准备攻击，随后进入平静。','造成11点伤害。若目标正准备攻击，随后进入平静。'},
 indignation={'若已处于愤怒，给所有敌人施加3易伤；否则进入愤怒。','若已处于愤怒，给所有敌人施加5易伤；否则进入愤怒。'},
 like_water={'回合结束的手牌处理之前，若处于平静，获得5固定格挡。','回合结束的手牌处理之前，若处于平静，获得7固定格挡。'},
 pray={'获得3真言。将1张未升级洞见随机插入抽牌堆。','获得4真言。将1张未升级洞见随机插入抽牌堆。'},
 reach_heaven={'造成10点伤害。将1张未升级以暴制暴随机插入抽牌堆。','造成15点伤害。将1张未升级以暴制暴随机插入抽牌堆。'},
 study={'每回合结束时，将1张洞见随机插入抽牌堆。','每回合结束时，将1张洞见随机插入抽牌堆。'},
 talk_to_the_hand={'造成5伤害。此后目标每受到一次普通攻击时，给予你2固定格挡。消耗。','造成7伤害。此后目标每受到一次普通攻击时，给予你3固定格挡。消耗。'},
 tantrum={'造成3点伤害3次。进入愤怒。打出后将本牌随机插回抽牌堆。','造成3点伤害4次。进入愤怒。打出后将本牌随机插回抽牌堆。'},
 simmering_fury={'下回合开始时进入愤怒，正常抽牌后额外抽2张牌。','下回合开始时进入愤怒，正常抽牌后额外抽3张牌。'},
 wallop={'造成9点伤害。获得等同实际扣除敌人生命的固定格挡。','造成12点伤害。获得等同实际扣除敌人生命的固定格挡。'},
 wheel_kick={'造成15点伤害。抽2张牌。','造成20点伤害。抽2张牌。'},
 wreath_of_flame={'下一张攻击的每次普通伤害增加5。','下一张攻击的每次普通伤害增加8。'},
 pressure_points={'给目标施加8印记。所有敌人失去等同自身印记层数的生命，无视格挡。','给目标施加11印记。所有敌人失去等同自身印记层数的生命，无视格挡。'},
 flurry_of_blows={'造成4伤害。每次实际改变姿态后，若本牌在弃牌堆且手牌未满，将其返回手牌。','造成6伤害。每次实际改变姿态后，若本牌在弃牌堆且手牌未满，将其返回手牌。'},
 weave={'造成4伤害。占卜非空抽牌堆后，若本牌在弃牌堆且手牌未满，将其返回手牌。','造成6伤害。占卜非空抽牌堆后，若本牌在弃牌堆且手牌未满，将其返回手牌。'},
}
function M.withCards(data)
 assert(type(data)=='table' and data.cards and data.cards.cards and data.statuses and data.statuses.statuses,'missing Watcher flow data')
 local out,ids,statuses=copy(data),{},{}
 for _,c in ipairs(out.cards.cards)do assert(not ids[c.id],'duplicate flow input card');ids[c.id]=true end
 for _,s in ipairs(out.statuses.statuses)do assert(not statuses[s.id],'duplicate flow input power');statuses[s.id]=s end
 for _,s in ipairs(specs)do
  assert(not ids[s[1]],'Watcher flow card already exists: '..s[1])
  local c={id=s[1],sourceId=s[2],sts_name=s[3],name=s[4],type=s[5],rarity=s[6],cost=s[7],color='purple',
   effects=copy(s[8]),upgrade={effects=copy(s[9] or s[8])},text=descriptions[s[1]][1],upgradeText=descriptions[s[1]][2]}
  for k,v in pairs(s[10] or {})do
   if k=='innate'then c.upgrade.innate=v elseif k=='upgradeCost'then c.upgrade.cost=v else c[k]=v end
  end
  out.cards.cards[#out.cards.cards+1]=c;ids[c.id]=true
 end
 local special={
  {id='through_violence',sourceId='ThroughViolence',sts_name='Through Violence',name='以暴制暴',cost=0,type='attack',effects={e('damage',20)},upgrade={effects={e('damage',30)}},text='保留。造成20点伤害。消耗。',upgradeText='保留。造成30点伤害。消耗。'},
  {id='insight',sourceId='Insight',sts_name='Insight',name='洞见',cost=0,type='skill',effects={e('draw',2)},upgrade={effects={e('draw',3)}},text='保留。抽2张牌。消耗。',upgradeText='保留。抽3张牌。消耗。'},
  {id='smite',sourceId='Smite',sts_name='Smite',name='惩罚',cost=1,type='attack',effects={e('damage',12)},upgrade={effects={e('damage',16)}},text='保留。造成12点伤害。消耗。',upgradeText='保留。造成16点伤害。消耗。'},
  {id='miracle',sourceId='Miracle',sts_name='Miracle',name='奇迹',cost=0,type='skill',effects={e('energy',1)},upgrade={effects={e('energy',2)}},text='保留。获得1点能量。消耗。',upgradeText='保留。获得2点能量。消耗。'},
 }
 for _,c in ipairs(special)do
  if not ids[c.id]then c.rarity='special';c.color='colorless';c.selfRetain=true;c.exhaust=true;out.cards.cards[#out.cards.cards+1]=c
  else
   for _,existing in ipairs(out.cards.cards)do if existing.id==c.id then
    assert(existing.sourceId==c.sourceId and existing.cost==c.cost and existing.type==c.type
     and existing.selfRetain==true and existing.exhaust==true,'unsupported existing flow derivative')
    assert(#existing.effects==1 and existing.effects[1].op==c.effects[1].op and existing.effects[1].value==c.effects[1].value,'unsupported existing flow derivative effects')
   end end
  end
 end
 for _,id in ipairs(powerOrder)do
  local s=powers[id]
  local existing=statuses[id]
  if existing then
   -- Production Akabeko already registers this shared source Power. Reuse its
   -- approved presentation, rejecting a conflicting identity or lifecycle.
   assert(id=='vigor' and (existing.sourceId==nil or existing.sourceId=='Vigor')
    and existing.kind=='buff' and existing.stack=='intensity' and existing.decay=='none',
    'Watcher flow power already exists: '..id)
  else
   out.statuses.statuses[#out.statuses.statuses+1]={id=id,sourceId=s[2],name=s[1],kind=s[3],stack='intensity',decay='none',
    priority=id=='draw_card_next_turn' and 20 or 5,description=s[4]}
  end
 end
 return out
end
local function plan()return {top={},bottom={},consumeAllEnergy=false}end
local function amount(state,id,actor)
 assert(powers[id],'unknown Watcher flow power')
 return int((actor or state.player).statuses[id] or 0)
end
function M.adaptDefinition(_state,_instance,definition)
 -- All current values are static. Vigor is an actor NORMAL-damage Power,
 -- not a permanent base/instance bonus and not a Strength multiplier.
 return definition
end
function M.damageBonus(state,owner,damageType)
 assert(damageType=='NORMAL' or damageType=='THORNS' or damageType=='HP_LOSS','unknown source damage type')
 return owner==state.player and damageType=='NORMAL' and amount(state,'vigor') or 0
end
function M.prepareEffect(state,effect,target)
 assert(type(effect)=='table' and M.ops[effect.op],'unknown Watcher flow card effect')
 local out=copy(effect)
 if effect.op=='fearNoEvil' or effect.op=='wallop' or effect.op=='flowDamage'then
  int(effect.value);assert(target,'missing flow damage target')
  out.normalAmount=int(Actors.attackAmount(state,state.player,target,effect.value))
  if effect.times~=nil then int(effect.times,1)end
 end
 return out
end
function M.planEffect(state,effect,context)
 context=context or {};local p=plan();local op=effect.op
 assert(M.ops[op] or op=='recallFlowCard','unknown Watcher flow effect')
 if op=='fearNoEvil'then
  int(effect.value);int(effect.normalAmount)
  p.top[1]=e('damage',effect.value,{normalAmount=effect.normalAmount})
  local target=assert(context.target,'missing Fear No Evil target')
  if require('abyss_build_actions').isAttacking(target)then p.top[2]=e('changeStance',nil,{stance='Calm'})end
 elseif op=='flowDamage'then
  int(effect.value);int(effect.normalAmount)
  local n=effect.times or 1;int(n,1)
  for _=1,n do p.top[#p.top+1]=e('damage',effect.value,{normalAmount=effect.normalAmount})end
 elseif op=='indignation'then
  int(effect.value)
  if state.player.stance=='Wrath'then
   for _,target in ipairs(state.enemies)do p.bottom[#p.bottom+1]=e('applyFlowStatus',effect.value,{status='vulnerable',targetId=target.id})end
  else p.bottom[1]=e('changeStance',nil,{stance='Wrath'})end
 elseif op=='collect'then
  assert(effect.value==0 or effect.value==1,'invalid Collect upgrade')
  assert(context.chemicalX==nil or context.chemicalX==false or context.chemicalX==0,'unsupported Collect Chemical X context override')
  assert(context.freeToPlayOnce==nil or type(context.freeToPlayOnce)=='boolean','invalid Collect free flag')
  local n=context.energyOnUse;if n==nil or n==-1 then n=state.energy end
  n=int(int(n)+0.0+effect.value+require('abyss_shop_relics').xBonus(state))
  if n>0 then p.bottom[1]=gain('collect',math.min(999,n));p.consumeAllEnergy=context.freeToPlayOnce~=true end
 elseif op=='triggerMarks'then
  assert(effect.value==1,'invalid mark trigger')
  for _,target in ipairs(state.enemies)do
   local n=amount(state,'mark',target)
   if n>0 then p.bottom[#p.bottom+1]=e('markLoseHp',n,{targetId=target.id})end
  end
 elseif op=='gainWatcherFlowPower' or op=='applyWatcherFlowPower'then
  assert(powers[effect.status],'unknown Watcher flow application')
  int(effect.value)
  p.applyPower={status=effect.status,value=effect.value,targetId=op=='gainWatcherFlowPower' and state.player.id or assert(context.target,'missing flow Power target').id}
 elseif op=='wallop'then
  int(effect.value);int(effect.normalAmount)
  p.damage={value=effect.value,normalAmount=effect.normalAmount,targetId=assert(context.target,'missing Wallop target').id,after='wallop'}
 elseif op=='recallFlowCard'then
  int(effect.uid,1)
  for _,c in ipairs(state.discard)do if c.uid==effect.uid then
   assert(c.cardId=='flurry_of_blows' or c.cardId=='weave','invalid flow recall card')
   if #state.hand<state.rules.player.maxHand then p.move={from='discard',to='hand',uid=c.uid,cardId=c.cardId,handHook=false}end
   break
  end end
 end
 return p
end
-- After the actual NORMAL damage, using clamped target.lastDamageTaken/lost.
function M.planWallop(lost)
 local p=plan();int(lost)
 if lost>0 then p.top[1]=e('block',lost,{fixed=true})end
 return p
end
-- Host invokes in source Power priority/acquisition order, not this map order.
function M.planHook(state,id,phase)
 assert(phase=='energy_recharge' or phase=='turn_start' or phase=='turn_start_post_draw'
  or phase=='turn_end_pre_cards' or phase=='turn_end','unknown Watcher flow hook phase')
 local p=plan();local n=amount(state,id)
 if n==0 then return p end
 if id=='collect' and phase=='energy_recharge'then
  p.bottom={make('miracle','hand',true),e(n>1 and 'reduceFlowPower' or 'removeFlowPower',1,{status=id})}
 elseif id=='battle_hymn' and phase=='turn_start'then p.bottom[1]=make('smite','hand',false,n)
 elseif id=='energy_down' and phase=='turn_start'then p.bottom[1]=e('loseEnergy',n)
 elseif id=='wrath_next_turn' and phase=='turn_start'then p.bottom={e('changeStance',nil,{stance='Wrath'}),e('removeFlowPower',1,{status=id})}
 elseif id=='draw_card_next_turn' and phase=='turn_start_post_draw'then p.bottom={e('draw',n),e('removeFlowPower',1,{status=id})}
 elseif id=='like_water' and phase=='turn_end_pre_cards' and state.player.stance=='Calm'then p.bottom[1]=e('block',n,{fixed=true})
 elseif id=='study' and phase=='turn_end'then p.bottom[1]=make('insight','draw',false,n)
 end
 return p
end
function M.planUseCard(state,card)
 local p=plan()
 if not card.dontTriggerOnUseCard and card.type=='attack' and amount(state,'vigor')>0 then p.bottom[1]=e('removeFlowPower',1,{status='vigor'})end
 return p
end
function M.planAttacked(state,owner,context)
 assert(type(context)=='table','missing flow attacked context')
 assert(context.damageType=='NORMAL' or context.damageType=='THORNS' or context.damageType=='HP_LOSS','unknown flow attacked type')
 local p=plan();local n=amount(state,'block_return',owner)
 if n>0 and context.damageType=='NORMAL' and context.source and context.source~=owner then p.top[1]=e('block',n,{fixed=true})end
 return p
end
local function recall(state,id)
 local p=plan()
 for _,c in ipairs(state.discard)do
  if c.cardId==id then int(c.uid,1);p.bottom[#p.bottom+1]=e('recallFlowCard',nil,{uid=c.uid})end
 end
 return p
end
function M.planStanceChange(state,old,new)
 local valid={Neutral=true,Calm=true,Wrath=true,Divinity=true}
 assert(valid[old] and valid[new] and state.player.stance==new,'invalid flow stance boundary')
 if old==new then return plan()end
 return recall(state,'flurry_of_blows')
end
-- eligible means the Scry began with a nonempty draw pile; it remains true
-- after selecting ALL candidates. Call at open and after selected-card moves.
function M.planScry(state,eligible)
 assert(type(eligible)=='boolean','missing source Scry eligibility')
 return eligible and recall(state,'weave') or plan()
end
function M.disposalPlan(state,instance,exhausted)
 assert(type(exhausted)=='boolean','missing captured exhaust decision')
 if instance.cardId~='tantrum' or exhausted then return nil end
 int(instance.uid,1);assert(state.catalog.cards.tantrum.shuffleBackIntoDrawPile==true,'Tantrum shuffle flag missing')
 return {from='in_use',to='draw',uid=instance.uid,randomSpot=true,copy=false}
end
-- Applied after Artifact prediction but before mutating the target Power.
function M.applicationPlan(state,target,id,n)
 assert(powers[id],'unknown flow application');int(n)
 local before=amount(state,id,target)
 local after=int(before+0.0+n)
 if id=='collect'then after=math.min(999,after)
 elseif id=='like_water' and target.statuses[id]~=nil then after=math.min(999,after)
 elseif id=='wrath_next_turn'then after=1 end
 return {incoming=n,after=after,sourceSentinel=id=='wrath_next_turn'}
end
return M
