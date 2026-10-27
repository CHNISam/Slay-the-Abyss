-- Fixed319009 remaining Defect cards. Combat owns actions and transactions.
local Copy=require('abyss_copy')
local Events=require('abyss_events')
local Random=require('abyss_sts_random')
local Actor=require('abyss_actor')
local Schedule=require('abyss_power_schedule')
local M={}
local function e(action,value,extra)local out=extra or {};out.op='defectFinal';out.action=action;out.value=value;return out end
local function power(id,value)return e('power',value,{status=id})end
local powers={
 rebound={'弹回','下一张非能力且未消耗的牌回抽牌堆顶；能力也消耗一次。本回合有效。'},
 equilibrium={'均衡','本回合结束保留所有非虚无手牌，每轮结束减少1层。'},
 amplify={'增幅','本回合接下来的对应张能力牌各额外打出1次。'},
 echo_form={'回响形态','每回合最先打出的对应张牌各额外打出1次；复制牌不递归触发。'},
 machine_learning={'机器学习','每回合正常抽牌数量增加对应层数。'},
 self_repair={'自我修复','战斗胜利时恢复对应层数的生命。'},
 buffer={'缓冲','抵消接下来的对应次数正数生命损失；完全格挡的伤害不消耗次数。'},
 static_discharge={'静电释放','每次受到其他单位普通攻击并失去生命时，生成对应层数的闪电球。'},
 hello_world={'你好，世界','每回合开始将对应张随机普通牌加入手牌，使用当前职业完整普通池。'},
 creative_ai={'创造性AI','每回合开始将对应张随机能力牌加入手牌，排除治疗牌，使用当前职业完整能力池。'},
}
local cards={
 {id='hello_world',sourceId='Hello World',name='你好，世界',type='power',rarity='uncommon',cost=1,effects={power('hello_world',1)},upgrade={innate=true},text='每回合开始时，将1张随机普通牌加入手牌。',upgradeText='先天。每回合开始时，将1张随机普通牌加入手牌。'},
 {id='white_noise',sourceId='White Noise',name='白噪声',type='skill',rarity='uncommon',cost=1,exhaust=true,effects={e('white_noise',1)},upgrade={cost=0},text='将1张随机能力牌加入手牌，本回合费用变为0。消耗。'},
 {id='creative_ai',sourceId='Creative AI',name='创造性AI',type='power',rarity='rare',cost=3,effects={power('creative_ai',1)},upgrade={cost=2},text='每回合开始时，将1张随机非治疗能力牌加入手牌。'},
 {id='buffer',sourceId='Buffer',name='缓冲',type='power',rarity='rare',cost=2,effects={power('buffer',1)},upgrade={effects={power('buffer',2)}},text='抵消下1次正数生命损失。',upgradeText='抵消下2次正数生命损失。'},
 {id='static_discharge',sourceId='Static Discharge',name='静电释放',type='power',rarity='uncommon',cost=1,effects={power('static_discharge',1)},upgrade={effects={power('static_discharge',2)}},text='每次受到其他单位普通攻击并失去生命时，生成1个闪电球。',upgradeText='每次受到其他单位普通攻击并失去生命时，生成2个闪电球。'},
 {id='rebound',sourceId='Rebound',name='弹回',type='attack',rarity='common',cost=1,effects={{op='damage',value=9},power('rebound',1)},upgrade={effects={{op='damage',value=12},power('rebound',1)}},text='造成9点伤害。本回合下一张牌放回抽牌堆顶。',upgradeText='造成12点伤害。本回合下一张牌放回抽牌堆顶。'},
 {id='force_field',sourceId='Force Field',name='力场',type='skill',rarity='uncommon',cost=4,effects={{op='block',value=12}},upgrade={effects={{op='block',value=16}}},text='获得12点格挡。本场战斗每打出1张能力牌，费用减少1。',upgradeText='获得16点格挡。本场战斗每打出1张能力牌，费用减少1。'},
 {id='equilibrium',sourceId='Undo',name='均衡',type='skill',rarity='uncommon',cost=2,effects={{op='block',value=13},power('equilibrium',1)},upgrade={effects={{op='block',value=16},power('equilibrium',1)}},text='获得13点格挡。本回合保留所有非虚无手牌。',upgradeText='获得16点格挡。本回合保留所有非虚无手牌。'},
 {id='amplify',sourceId='Amplify',name='增幅',type='skill',rarity='rare',cost=1,effects={power('amplify',1)},upgrade={effects={power('amplify',2)}},text='本回合下一张能力牌额外打出1次。',upgradeText='本回合接下来2张能力牌各额外打出1次。'},
 {id='echo_form',sourceId='Echo Form',name='回响形态',type='power',rarity='rare',cost=3,ethereal=true,effects={power('echo_form',1)},upgrade={ethereal=false},text='虚无。每回合最先打出的1张牌额外打出1次。',upgradeText='每回合最先打出的1张牌额外打出1次。'},
 {id='machine_learning',sourceId='Machine Learning',name='机器学习',type='power',rarity='rare',cost=1,effects={power('machine_learning',1)},upgrade={innate=true},text='每回合正常抽牌额外抽1张。',upgradeText='先天。每回合正常抽牌额外抽1张。'},
 {id='self_repair',sourceId='Self Repair',name='自我修复',type='power',rarity='uncommon',cost=1,healing=true,sourceTags={'HEALING'},effects={power('self_repair',7)},upgrade={effects={power('self_repair',10)}},text='战斗胜利时恢复7点生命。',upgradeText='战斗胜利时恢复10点生命。'},
 {id='recursion',sourceId='Redo',name='递归',type='skill',rarity='common',cost=1,effects={e('recursion',1)},upgrade={cost=0},text='唤起最前方充能球，然后将它重新生成。'},
 {id='genetic_algorithm',sourceId='Genetic Algorithm',name='遗传算法',type='skill',rarity='uncommon',cost=1,misc=1,exhaust=true,effects={e('genetic',2),{op='block',value=1}},upgrade={effects={e('genetic',3),{op='block',value=1}}},text='获得1点格挡。永久增加此牌的基础格挡2点。消耗。',upgradeText='获得1点格挡。永久增加此牌的基础格挡3点。消耗。'},
 {id='recycle',sourceId='Recycle',name='回收',type='skill',rarity='uncommon',cost=1,effects={e('recycle',1)},upgrade={cost=0},text='消耗1张手牌。获得等同于它当前费用的能量。'},
 {id='scrape',sourceId='Scrape',name='刮削',type='attack',rarity='uncommon',cost=1,effects={{op='damage',value=7},e('scrape',4)},upgrade={effects={{op='damage',value=10},e('scrape',5)}},text='造成7点伤害。抽4张牌，弃掉其中当前费用不为0且非免费打出的牌。',upgradeText='造成10点伤害。抽5张牌，弃掉其中当前费用不为0且非免费打出的牌。'},
 {id='all_for_one',sourceId='All For One',name='万物一心',type='attack',rarity='rare',cost=2,effects={{op='damage',value=10},e('all_for_one',1)},upgrade={effects={{op='damage',value=14},e('all_for_one',1)}},text='造成10点伤害。将弃牌堆所有基础费用为0或免费打出的牌加入手牌。',upgradeText='造成14点伤害。将弃牌堆所有基础费用为0或免费打出的牌加入手牌。'},
 {id='fission',sourceId='Fission',name='裂变',type='skill',rarity='rare',cost=0,exhaust=true,effects={e('fission',0)},upgrade={effects={e('fission',1)}},text='移除所有充能球，每移除1个获得1点能量并抽1张牌。消耗。',upgradeText='唤起所有充能球，每个球获得1点能量并抽1张牌。消耗。'},
 {id='reboot',sourceId='Reboot',name='重启',type='skill',rarity='rare',cost=0,exhaust=true,effects={e('reboot',4)},upgrade={effects={e('reboot',6)}},text='将手牌与弃牌堆洗入抽牌堆。抽4张牌。消耗。',upgradeText='将手牌与弃牌堆洗入抽牌堆。抽6张牌。消耗。'},
}
local allowed={white_noise={[1]=true},recursion={[1]=true},genetic={[2]=true,[3]=true},recycle={[1]=true},scrape={[4]=true,[5]=true},all_for_one={[1]=true},fission={[0]=true,[1]=true},reboot={[4]=true,[6]=true}}
function M.supports(effect)
 if effect.action=='power'then return powers[effect.status]~=nil and type(effect.value)=='number'and effect.value>=1 and effect.value%1==0 and effect.value<=2147483647 end
 return allowed[effect.action]and allowed[effect.action][effect.value]==true
end
function M.withCards(data)
 local out=Copy.copy(data);local seen={};for _,c in ipairs(out.cards.cards)do seen[c.id]=true end
 for _,card in ipairs(cards)do
  assert(not seen[card.id],'duplicate final Defect card');local c=Copy.copy(card);c.experimental=true;c.color='blue'
  out.cards.cards[#out.cards.cards+1]=c
 end
 local statuses={};for _,definition in ipairs(out.statuses.statuses)do statuses[definition.id]=true end
 for id,definition in pairs(powers)do
  assert(not statuses[id],'duplicate final Defect Power')
  out.statuses.statuses[#out.statuses.statuses+1]={id=id,name=definition[1],description=definition[2],kind='buff',stack='intensity',decay='none'}
 end
 return out
end
function M.adaptDefinition(_state,instance,definition)
 if instance.cardId=='genetic_algorithm'then definition.effects[2].value=instance.misc or 1 end
 return definition
end
function M.describe(effect)
 local action,n=effect.action,tostring(effect.value)
 if action=='power'then return '获得 '..n..' 层'..assert(powers[effect.status])[1]..'：'..powers[effect.status][2]
 elseif action=='genetic'then return '永久增加此牌的基础格挡 '..n..' 点'
 elseif action=='scrape'then return '抽 '..n..' 张牌，主动弃掉其中当前费用非0且非免费打出的牌'
 elseif action=='fission'then return (effect.value==1 and '唤起' or '移除')..'所有充能球；每个球获得 1 点能量并抽 1 张牌'
 elseif action=='reboot'then return '将手牌与弃牌堆洗入抽牌堆，抽 '..n..' 张牌'
 end
 return assert(({white_noise='将1张随机非治疗能力牌加入手牌，本回合费用变为0；使用当前职业完整能力池',recursion='唤起最前方充能球，然后将同一个球重新生成',recycle='选择并消耗1张手牌，获得等同其当前费用的能量；X按当前能量计算',all_for_one='将弃牌堆所有基础费用为0或免费打出的牌加入手牌；满手时留在弃牌堆'})[action],'unknown final Defect description')
end
function M.pool(state,kind)
 local pools=assert(state.sourcePools,'missing class source pools');local list={}
 local function add(id)
  local card=assert(state.catalog.cards[id],'incomplete '..kind..' source pool: '..id)
  assert(require('abyss_card_capability').isImplemented(card),'unimplemented '..kind..' source candidate: '..id)
  assert(kind~='common'or card.rarity=='common','invalid common source candidate')
  assert(kind~='power'or card.type=='power'and not card.healing,'invalid Power source candidate')
  list[#list+1]=id
 end
 if kind=='common'then
  for _,id in ipairs(assert(pools.reward and pools.reward.common,'missing live common pool'))do add(id)end
 elseif kind=='power'then
  for _,rarity in ipairs({'common','uncommon','rare'})do
   for _,id in ipairs(assert(pools.src and pools.src[rarity],'missing src rarity pool'))do
    local metadata=(pools.cardSourceMetadata or {})[id]or state.catalog.cards[id]
    assert(metadata,'incomplete source candidate metadata: '..id)
    if metadata.type=='power'and not metadata.healing then add(id)end
   end
  end
 else error('unknown generated pool')end
 assert(#list>0,'empty complete source pool');return list
end
local function select(state,kind)
 local pool=M.pool(state,kind);return pool[Random.randomInt(assert(state.cardRandomRng),#pool-1)+1]
end
function M.prepareEffects(state,effects)
 for _,effect in ipairs(effects)do if effect.op=='defectFinal'and effect.action=='white_noise'then effect.cardId=select(state,'power')end end
 return effects
end
function M.turnStartActions(state,id,n)
 local out={};local kind=id=='hello_world'and'common'or'power'
 for _=1,n do out[#out+1]=e('generate',1,{cardId=select(state,kind)})end
 return out
end
function M.created(state,card)
 if card.cardId~='force_field'then return end
 local cost=4
 for _,played in ipairs(state.cardsPlayedThisCombat or {})do if played.type=='power'then cost=math.max(0,cost-1)end end
 card.combatCost,card.turnCost=cost,cost
end
function M.needsQueue(state)
 for id in pairs(powers)do if state.player.statuses[id]~=nil then return true end end
 for _,name in ipairs({'hand','draw','discard'})do for _,c in ipairs(state[name])do if c.cardId=='force_field'then return true end end end
 return false
end
function M.removePower(state,id)
 Schedule.remove(state,state.player,id);state.player.statuses[id]=nil
 if id=='rebound'then state.reboundJustEvoked=nil end
end
function M.reducePower(state,id)
 local old=state.player.statuses[id]or 0
 if old<=1 then M.removePower(state,id)else state.player.statuses[id]=old-1 end
end
function M.incoming(state,target,amount)
 if target==state.player and target.statuses.buffer~=nil then
  if amount>0 then M.reducePower(state,'buffer')end
  return 0
 end
 return amount
end
function M.static(state,count)
 for _=1,count do
  require('abyss_card_actions').enqueueReaction(state,{op='channelOrb',orb='lightning',value=1},true)
 end
end
function M.onUse(state,card)
 if card.type~='power'then return end
 for _,name in ipairs({'hand','draw','discard'})do for _,c in ipairs(state[name])do if c.cardId=='force_field'then
  local base=c.combatCost or 4;local turn=c.costForTurn or c.turnCost or base;local cost=math.max(0,base-1)
  c.combatCost,c.turnCost=cost,math.max(0,cost-(base-turn))
  if c.costForTurn~=nil then c.costForTurn=c.turnCost end
 end end end
end
function M.copyTrigger(state,id,card)
 if id=='echo_form'then
  local doubled=state.echoDoubledThisTurn or 0
  if #(state.cardsPlayedThisTurn or {})-doubled<=(state.player.statuses.echo_form or 0)then state.echoDoubledThisTurn=doubled+1;return true end
 elseif id=='amplify'and card.type=='power'then state.player.statuses.amplify=state.player.statuses.amplify-1;return true end
 return false
end
function M.afterUse(state,card,purge,exhaust)
 if state.player.statuses.amplify==0 then M.removePower(state,'amplify')end
 local rebound=false
 if state.player.statuses.rebound then
  if state.reboundJustEvoked then state.reboundJustEvoked=nil
  else rebound=card.type~='power'and not purge and not exhaust;M.reducePower(state,'rebound')end
 end
 return rebound
end
function M.startTurn(state)state.echoDoubledThisTurn=0 end
function M.endTurn(state,combat)
 for _,entry in ipairs(Schedule.list(state,{rebound=true,amplify=true,equilibrium=true}))do
  if entry.id=='equilibrium'then
   for _,c in ipairs(state.hand)do if not combat.cardDefinition(state,c).ethereal then c.finalRetain=true end end
  else M.removePower(state,entry.id)end
 end
end
function M.endRound(state)
 if state.player.statuses.equilibrium~=nil then M.reducePower(state,'equilibrium')end
end
function M.drawCount(state,base)return base+(state.player.statuses.machine_learning or 0)end
function M.victory(combat,state)
 local n=state.player.statuses.self_repair or 0
 if n>0 and not state.selfRepairResolved then
  state.selfRepairResolved=true
  require('abyss_card_actions').apply(combat,state,{effect={op='heal',value=n},source=state.player})
 end
end
local function push(queue,state,effect,bottom)
 if bottom then queue.pushBottom(state,{kind='effect',effect=effect})else queue.pushTop(state,{kind='effect',effect=effect})end
end
local function genetic(state,value)
 local original=assert(state.cardInUse);local uuid=original.uuid or original.uid;local seen={}
 local function grow(c)
  if not c or seen[c]then return end;seen[c]=true
  if (c.uuid or c.uid)==uuid then
   assert(c.cardId=='genetic_algorithm','Genetic logical identity mismatch')
   c.misc=(c.misc or 1)+0.0+value;assert(c.misc<=2147483647,'Genetic misc overflow')
  end
 end
 grow(original)
 for _,name in ipairs({'hand','draw','discard','exhaust','limbo'})do for _,c in ipairs(state[name]or {})do grow(c)end end
 for _,entry in ipairs(state.queuedCards or {})do grow(entry.card)end
 for _,entry in ipairs(state.cardActions or {})do grow(entry.instance)end
 if original.deckUid then
  for i,c in ipairs(assert(state.masterDeck,'missing permanent deck snapshot'))do if c.uid==original.deckUid then
   local changed=Copy.copy(c);changed.misc=(c.misc or 1)+0.0+value;assert(changed.misc<=2147483647,'permanent misc overflow')
   state.masterDeck[i]=changed;state.masterDeckChanges=state.masterDeckChanges or {}
   state.masterDeckChanges[c.uid]=Copy.copy(changed);break
  end end
 end
end
function M.recycle(state,card,queue)
 local view=Copy.copy(card);view.freeToPlayOnce=nil
 local cost=require('abyss_combat').cardDefinition(state,view).cost
 local energy=cost==-1 and state.energy or math.max(0,cost)
 if energy>0 then push(queue,state,{op='energy',value=energy})end
 require('abyss_exhaust').move(state,card,'hand',queue,{onExhaustRelics=state.onExhaustRelics or {}})
end
function M.execute(combat,state,effect,queue)
 local action=effect.action
 if action=='generate'or action=='white_noise'then
  local actions=require('abyss_card_actions');local id=assert(effect.cardId,'unprepared generated Power');local card=actions.fresh(combat,state,id)
  if action=='white_noise'then card.costForTurn=0 end
  actions.created(combat,state,card);actions.created(combat,state,card)
  if (state.player.statuses.corruption or 0)~=0 then require('abyss_corruption').created(state,card)end
  local pile=#state.hand<state.rules.player.maxHand and'hand'or'discard'
  actions.toHand(state,card);Events.emit(state,'cards_created',{source=state.player.id,cardId=card.cardId,amount=1,pile=pile})
 elseif action=='power'then
  local old=state.player.statuses[effect.status]
  Actor.applyPower(state,state.player,effect.status,effect.value,state.player)
  if effect.status=='rebound'and old==nil then state.reboundJustEvoked=true end
 elseif action=='genetic'then genetic(state,effect.value)
 elseif action=='recursion'then
  local first=assert(state.orbs).balls[1]
  if first then
   push(queue,state,e('rechannel',1,{ball=first}));push(queue,state,{op='evokeOrb',value=1})
  end
 elseif action=='rechannel'then require('abyss_orbs').rechannel(state,effect.ball,combat)
 elseif action=='recycle'then return require('abyss_hand_choice').begin(state,'recycle',1,queue)
 elseif action=='scrape'then
  local drawn=combat.draw(state,effect.value);local discard={}
  for _,c in ipairs(drawn)do if combat.cardDefinition(state,c).cost~=0 and not c.freeToPlayOnce then discard[#discard+1]=c.uid end end
  for i=#discard,1,-1 do push(queue,state,{op='discardSpecific',uid=discard[i],incrementFirst=false})end
 elseif action=='all_for_one'then
  for _,c in ipairs(state.discard)do
   local base=c.combatCost or combat.combatBaseCost(state,c)
   if base==0 or c.freeToPlayOnce then push(queue,state,e('discard_to_hand',1,{uid=c.uid}),true)end
  end
 elseif action=='discard_to_hand'then
  if #state.hand<state.rules.player.maxHand then for i,c in ipairs(state.discard)do if c.uid==effect.uid then
   table.remove(state.discard,i);state.hand[#state.hand+1]=c;break
  end end end
 elseif action=='fission'then
  local count=#assert(state.orbs).balls;push(queue,state,{op='draw',value=count});push(queue,state,{op='energy',value=count})
  if effect.value==1 then for _=1,state.orbs.slots do push(queue,state,{op='evokeOrb',value=1})end
  else for i=#state.orbs.balls,1,-1 do state.orbs.balls[i]=nil end end
 elseif action=='reboot'then
  assert(state.shuffleRng and state.cardRandomRng,'Reboot requires source RNG streams')
  Random.shuffle(state.shuffleRng,state.discard)
  for _,c in ipairs(state.discard)do state.draw[#state.draw+1]=c end
  for i=#state.discard,1,-1 do state.discard[i]=nil end
  while #state.hand>0 do state.draw[#state.draw+1]=table.remove(state.hand,Random.randomInt(state.cardRandomRng,#state.hand-1)+1)end
  Random.shuffle(state.shuffleRng,state.draw);push(queue,state,{op='draw',value=effect.value})
  Events.emit(state,'reshuffle')
 else error('unknown final Defect action: '..tostring(action))end
 return true
end
return M
