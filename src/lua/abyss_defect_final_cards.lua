-- Fixed319009 remaining Defect cards. Combat owns actions and transactions.
local Copy=require('abyss_copy')
local Events=require('abyss_events')
local Random=require('abyss_sts_random')
local M={}
local function e(action,value,extra)local out=extra or {};out.op='defectFinal';out.action=action;out.value=value;return out end
local cards={
 {id='recursion',sourceId='Redo',name='递归',type='skill',rarity='common',cost=1,effects={e('recursion',1)},upgrade={cost=0},text='唤起最前方充能球，然后将它重新生成。'},
 {id='genetic_algorithm',sourceId='Genetic Algorithm',name='遗传算法',type='skill',rarity='uncommon',cost=1,misc=1,exhaust=true,effects={e('genetic',2),{op='block',value=1}},upgrade={effects={e('genetic',3),{op='block',value=1}}},text='获得1点格挡。永久增加此牌的基础格挡2点。消耗。',upgradeText='获得1点格挡。永久增加此牌的基础格挡3点。消耗。'},
 {id='recycle',sourceId='Recycle',name='回收',type='skill',rarity='uncommon',cost=1,effects={e('recycle',1)},upgrade={cost=0},text='消耗1张手牌。获得等同于它当前费用的能量。'},
 {id='scrape',sourceId='Scrape',name='刮削',type='attack',rarity='uncommon',cost=1,effects={{op='damage',value=7},e('scrape',4)},upgrade={effects={{op='damage',value=10},e('scrape',5)}},text='造成7点伤害。抽4张牌，弃掉其中当前费用不为0且非免费打出的牌。',upgradeText='造成10点伤害。抽5张牌，弃掉其中当前费用不为0且非免费打出的牌。'},
 {id='all_for_one',sourceId='All For One',name='万物一心',type='attack',rarity='rare',cost=2,effects={{op='damage',value=10},e('all_for_one',1)},upgrade={effects={{op='damage',value=14},e('all_for_one',1)}},text='造成10点伤害。将弃牌堆所有基础费用为0或免费打出的牌加入手牌。',upgradeText='造成14点伤害。将弃牌堆所有基础费用为0或免费打出的牌加入手牌。'},
 {id='fission',sourceId='Fission',name='裂变',type='skill',rarity='rare',cost=0,exhaust=true,effects={e('fission',0)},upgrade={effects={e('fission',1)}},text='移除所有充能球，每移除1个获得1点能量并抽1张牌。消耗。',upgradeText='唤起所有充能球，每个球获得1点能量并抽1张牌。消耗。'},
 {id='reboot',sourceId='Reboot',name='重启',type='skill',rarity='rare',cost=0,exhaust=true,effects={e('reboot',4)},upgrade={effects={e('reboot',6)}},text='将手牌与弃牌堆洗入抽牌堆。抽4张牌。消耗。',upgradeText='将手牌与弃牌堆洗入抽牌堆。抽6张牌。消耗。'},
}
local allowed={recursion={[1]=true},genetic={[2]=true,[3]=true},recycle={[1]=true},scrape={[4]=true,[5]=true},all_for_one={[1]=true},fission={[0]=true,[1]=true},reboot={[4]=true,[6]=true}}
function M.supports(effect)return allowed[effect.action]and allowed[effect.action][effect.value]==true end
function M.withCards(data)
 local out=Copy.copy(data);local seen={};for _,c in ipairs(out.cards.cards)do seen[c.id]=true end
 for _,card in ipairs(cards)do
  assert(not seen[card.id],'duplicate final Defect card');local c=Copy.copy(card);c.experimental=true;c.color='blue'
  out.cards.cards[#out.cards.cards+1]=c
 end
 return out
end
function M.adaptDefinition(_state,instance,definition)
 if instance.cardId=='genetic_algorithm'then definition.effects[2].value=instance.misc or 1 end
 return definition
end
function M.describe(effect)
 local action,n=effect.action,tostring(effect.value)
 if action=='genetic'then return '永久增加此牌的基础格挡 '..n..' 点'
 elseif action=='scrape'then return '抽 '..n..' 张牌，主动弃掉其中当前费用非0且非免费打出的牌'
 elseif action=='fission'then return (effect.value==1 and '唤起' or '移除')..'所有充能球；每个球获得 1 点能量并抽 1 张牌'
 elseif action=='reboot'then return '将手牌与弃牌堆洗入抽牌堆，抽 '..n..' 张牌'
 end
 return assert(({recursion='唤起最前方充能球，然后将同一个球重新生成',recycle='选择并消耗1张手牌，获得等同其当前费用的能量；X按当前能量计算',all_for_one='将弃牌堆所有基础费用为0或免费打出的牌加入手牌；满手时留在弃牌堆'})[action],'unknown final Defect description')
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
 if action=='genetic'then genetic(state,effect.value)
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
