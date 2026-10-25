-- Independent facts from aeubanks/sts 319009; host Combat owns every queue.
local Actors=require('abyss_actor')
local Random=require('abyss_sts_random')
local M={}
M.ops={piercingWail=true,allOutDiscard=true,concentrateDiscard=true,cripplingPoison=true,
 escapePlan=true,expertise=true,finisherDamage=true,flechettesDamage=true,skewer=true,
 glassKnife=true,malaise=true,unload=true,stormOfSteel=true}
local MAX=2147483647
local function integer(n) return type(n)=='number' and n==n and n%1==0 and n>=0 and n<=MAX end
local function check(n) assert(integer(n),'invalid Silent tactics integer');return n end
local function uid(n)check(n);assert(n>0,'invalid Silent tactics UID');return n end
local function copy(x)
 if type(x)~='table' then return x end
 local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y
end
local function e(op,value,extra)local out=extra or {};out.op=op;out.value=value;return out end
local function status(id,value)return e('applyStatus',value,{status=id})end
local cards={
 {id='piercing_wail',sourceId='PiercingWail',name='尖啸',type='skill',rarity='common',cost=1,exhaust=true,
  effects={e('piercingWail',6)},upgrade={effects={e('piercingWail',8)}}},
 {id='all_out_attack',sourceId='All Out Attack',name='全力攻击',type='attack',rarity='uncommon',cost=1,
  effects={e('damageAll',10),e('allOutDiscard',1)},upgrade={effects={e('damageAll',14),e('allOutDiscard',1)}}},
 {id='blur',sourceId='Blur',name='残影',type='skill',rarity='uncommon',cost=1,
  effects={e('block',5),e('gainStatus',1,{status='blur'})},upgrade={effects={e('block',8),e('gainStatus',1,{status='blur'})}}},
 {id='choke',sourceId='Choke',name='勒脖',type='attack',rarity='uncommon',cost=2,
  effects={e('damage',12),status('choked',3)},upgrade={effects={e('damage',12),status('choked',5)}}},
 {id='concentrate',sourceId='Concentrate',name='集中',type='skill',rarity='uncommon',cost=0,
  effects={e('concentrateDiscard',3)},upgrade={effects={e('concentrateDiscard',2)}}},
 {id='crippling_poison',sourceId='Crippling Poison',name='致残毒云',type='skill',rarity='uncommon',cost=2,exhaust=true,
  effects={e('cripplingPoison',4)},upgrade={effects={e('cripplingPoison',7)}}},
 {id='dash',sourceId='Dash',name='冲刺',type='attack',rarity='uncommon',cost=2,
  effects={e('block',10),e('damage',10)},upgrade={effects={e('block',13),e('damage',13)}}},
 {id='escape_plan',sourceId='Escape Plan',name='逃脱计划',type='skill',rarity='uncommon',cost=0,
  effects={e('escapePlan',3)},upgrade={effects={e('escapePlan',5)}}},
 {id='expertise',sourceId='Expertise',name='独门技术',type='skill',rarity='uncommon',cost=1,
  effects={e('expertise',6)},upgrade={effects={e('expertise',7)}}},
 {id='finisher',sourceId='Finisher',name='终结技',type='attack',rarity='uncommon',cost=1,
  effects={e('finisherDamage',6)},upgrade={effects={e('finisherDamage',8)}}},
 {id='flechettes',sourceId='Flechettes',name='飞镖',type='attack',rarity='uncommon',cost=1,
  effects={e('flechettesDamage',4)},upgrade={effects={e('flechettesDamage',6)}}},
 {id='leg_sweep',sourceId='Leg Sweep',name='扫腿',type='skill',rarity='uncommon',cost=2,
  effects={status('weak',2),e('block',11)},upgrade={effects={status('weak',3),e('block',14)}}},
 {id='predator',sourceId='Predator',name='捕食者',type='attack',rarity='uncommon',cost=2,
  effects={e('damage',15),e('gainStatus',2,{status='draw_next_turn'})},upgrade={effects={e('damage',20),e('gainStatus',2,{status='draw_next_turn'})}}},
 {id='skewer',sourceId='Skewer',name='串刺',type='attack',rarity='uncommon',cost=-1,costMode='all_energy',experimental=true,
  effects={e('skewer',7)},upgrade={effects={e('skewer',10)}}},
 {id='terror',sourceId='Terror',name='恐怖',type='skill',rarity='uncommon',cost=1,exhaust=true,
  effects={status('vulnerable',99)},upgrade={cost=0}},
 {id='die_die_die',sourceId='Die Die Die',name='死吧死吧死吧',type='attack',rarity='rare',cost=1,exhaust=true,
  effects={e('damageAll',13)},upgrade={effects={e('damageAll',17)}}},
 {id='glass_knife',sourceId='Glass Knife',name='玻璃刀刃',type='attack',rarity='rare',cost=1,
  effects={e('glassKnife',8)},upgrade={effects={e('glassKnife',12)}}},
 {id='malaise',sourceId='Malaise',name='萎靡',type='skill',rarity='rare',cost=-1,costMode='all_energy',experimental=true,exhaust=true,
  effects={e('malaise',0)},upgrade={effects={e('malaise',1)}}},
 {id='unload',sourceId='Unload',name='倾泻',type='attack',rarity='rare',cost=1,
  effects={e('damage',14),e('unload',0)},upgrade={effects={e('damage',18),e('unload',0)}}},
 {id='storm_of_steel',sourceId='Storm of Steel',name='钢铁风暴',type='skill',rarity='rare',cost=1,
  effects={e('stormOfSteel',0,{upgraded=false})},upgrade={effects={e('stormOfSteel',0,{upgraded=true})}}},
}
local texts={
 piercing_wail={'所有敌人本回合失去6点力量。消耗。','所有敌人本回合失去8点力量。消耗。'},
 all_out_attack={'对所有敌人造成10点伤害。随机丢弃1张牌。','对所有敌人造成14点伤害。随机丢弃1张牌。'},
 blur={'获得5点格挡。下一回合开始时不会失去格挡。','获得8点格挡。下一回合开始时不会失去格挡。'},
 choke={'造成12点伤害。本回合每当你打出一张牌，此敌人失去3点生命。','造成12点伤害。本回合每当你打出一张牌，此敌人失去5点生命。'},
 concentrate={'丢弃3张牌。获得2点能量。','丢弃2张牌。获得2点能量。'},
 crippling_poison={'给予所有敌人4层中毒和2回合虚弱。消耗。','给予所有敌人7层中毒和2回合虚弱。消耗。'},
 dash={'获得10点格挡。造成10点伤害。','获得13点格挡。造成13点伤害。'},
 escape_plan={'抽1张牌。若抽到技能牌，获得3点格挡。','抽1张牌。若抽到技能牌，获得5点格挡。'},
 expertise={'抽牌直到手牌达到6张。','抽牌直到手牌达到7张。'},
 finisher={'本回合此前每打出一张攻击牌，造成6点伤害。','本回合此前每打出一张攻击牌，造成8点伤害。'},
 flechettes={'每有一张技能牌在手中，造成4点伤害。','每有一张技能牌在手中，造成6点伤害。'},
 leg_sweep={'给予2回合虚弱。获得11点格挡。','给予3回合虚弱。获得14点格挡。'},
 predator={'造成15点伤害。下一回合额外抽2张牌。','造成20点伤害。下一回合额外抽2张牌。'},
 skewer={'造成7点伤害，重复X次。','造成10点伤害，重复X次。'},
 terror={'给予99回合易伤。消耗。','给予99回合易伤。消耗。'},
 die_die_die={'对所有敌人造成13点伤害。消耗。','对所有敌人造成17点伤害。消耗。'},
 glass_knife={'造成8点伤害2次。本场战斗此牌的基础伤害降低2点。','造成12点伤害2次。本场战斗此牌的基础伤害降低2点。'},
 malaise={'敌人失去X点力量，获得X回合虚弱。消耗。','敌人失去X+1点力量，获得X+1回合虚弱。消耗。'},
 unload={'造成14点伤害。丢弃手中所有非攻击牌。','造成18点伤害。丢弃手中所有非攻击牌。'},
 storm_of_steel={'丢弃所有手牌。每丢弃一张牌，获得一张小刀。','丢弃所有手牌。每丢弃一张牌，获得一张升级小刀。'},
}
local powers={
 {id='blur',name='残影',kind='buff',stack='intensity',decay='none',description='保留格挡。每轮结束减少1层；保留判定先于该减少动作。'},
 {id='choked',name='勒脖',kind='debuff',stack='intensity',decay='none',description='每当你打出一张牌，此敌人失去等同层数的生命。在其回合开始时移除。'},
 {id='draw_next_turn',name='下回合抽牌',priority=20,kind='buff',stack='intensity',decay='none',description='下一回合常规抽牌后，再抽等同层数的牌，然后移除。'},
 {id='shackled',name='力量恢复',kind='debuff',stack='intensity',decay='none',description='此生物回合结束时恢复等同层数的力量，然后移除。'},
}
function M.withCardDefinitions(data)
 assert(type(data)=='table' and data.cards and data.statuses,'missing tactics data')
 local out=copy(data);local seen={}
 for _,c in ipairs(out.cards.cards)do seen[c.id]=true end
 for _,c in ipairs(cards)do
  assert(not seen[c.id],'Silent tactics card collision: '..c.id)
  local def=copy(c);def.sts_name=def.sourceId
  def.text=texts[c.id][1];def.upgradeText=texts[c.id][2]
  out.cards.cards[#out.cards.cards+1]=def;seen[c.id]=true
 end
 seen={};for _,p in ipairs(out.statuses.statuses)do seen[p.id]=true end
 for _,p in ipairs(powers)do if not seen[p.id]then out.statuses.statuses[#out.statuses.statuses+1]=copy(p)end end
 return out
end
local attackOps={finisherDamage=true,flechettesDamage=true,skewer=true,glassKnife=true}
function M.adaptDefinition(_state,instance,definition)
 if instance.cardId~='glass_knife' then return definition end
 local reduction=check(instance.glassKnifeReduction or 0)
 local out=copy(definition)
 for _,effect in ipairs(out.effects)do
  if effect.op=='glassKnife' then effect.value=math.max(0,check(effect.value)-reduction)end
 end
 return out
end
function M.prepareEffect(state,effect,target)
 local out=copy(effect)
 if attackOps[effect.op]then
  assert(target,'missing Silent tactics damage target');check(effect.value)
  out.normalAmount=check(Actors.attackAmount(state,state.player,target,effect.value))
 elseif effect.op=='escapePlan'then
  out.blockAmount=check(Actors.blockAmount(state,state.player,check(effect.value)))
 elseif effect.op=='piercingWail'then
  check(effect.value);out.targets={}
  for _,enemy in ipairs(state.enemies)do
   if Actors.isActive(enemy)then
    out.targets[#out.targets+1]={targetId=enemy.id,restore=(enemy.statuses.artifact or 0)<=0}
   end
  end
 end
 return out
end
local function definition(state,card,context)
 if context.cardDefinition then return context.cardDefinition(state,card)end
 return assert(state.catalog.cards[card.cardId],'missing tactics hand definition')
end
local function xAmount(state,context)
 local n=context.energyOnUse
 if n==nil or n==-1 then n=state.energy end
 check(n)
 assert(context.freeToPlayOnce==nil or type(context.freeToPlayOnce)=='boolean','invalid X free flag')
 assert(context.chemicalX==nil or context.chemicalX==false or context.chemicalX==0,'Chemical X not supported')
 return n
end
-- All plan arrays are in execution order; the host reverses pushes to TOP.
-- Context functions are call-local. Plans contain only serialisable records.
function M.planEffect(state,effect,context)
 context=context or {};local op=effect.op
 local plan={top={},bottom={},consumeAllEnergy=false}
 if op=='piercingWail'then
  check(effect.value);assert(type(effect.targets)=='table','unprepared Piercing Wail')
  for _,t in ipairs(effect.targets)do
   assert(type(t.targetId)=='string' and type(t.restore)=='boolean','invalid Piercing Wail target')
   plan.top[#plan.top+1]=e('applyStatus',-effect.value,{status='strength',targetId=t.targetId})
  end
  for _,t in ipairs(effect.targets)do
   if t.restore then plan.top[#plan.top+1]=e('applyStatus',effect.value,{status='shackled',targetId=t.targetId})end
  end
 elseif op=='allOutDiscard'then
  assert(effect.value==1,'unsupported random discard count')
  plan.top[1]=e('randomManualDiscard',1)
 elseif op=='concentrateDiscard'then
  assert(effect.value==2 or effect.value==3,'unsupported Concentrate count')
  plan.top={e('requestDiscard',effect.value),e('energy',2)}
 elseif op=='cripplingPoison'then
  check(effect.value)
  for _,enemy in ipairs(state.enemies)do
   if Actors.isActive(enemy)then
    plan.top[#plan.top+1]=e('applyStatus',effect.value,{status='poison',targetId=enemy.id})
    plan.top[#plan.top+1]=e('applyStatus',2,{status='weak',targetId=enemy.id})
   end
  end
 elseif op=='escapePlan'then
  plan.top[1]=e('drawWithFollowup',1,{blockAmount=check(effect.blockAmount),skillOnly=true})
 elseif op=='expertise'then
  local n=math.max(0,check(effect.value)-#state.hand)
  if n>0 then plan.top[1]=e('draw',n)end
 elseif op=='finisherDamage' or op=='flechettesDamage'then
  check(effect.value);check(effect.normalAmount)
  local n=0
  if op=='finisherDamage'then
   for _,card in ipairs(assert(state.cardsPlayedThisTurn,'missing turn history'))do if card.type=='attack'then n=n+1 end end
   n=math.max(0,n-1) -- history already includes this Finisher, at action time.
  else
   for _,card in ipairs(state.hand)do if definition(state,card,context).type=='skill'then n=n+1 end end
  end
  for _=1,n do plan.top[#plan.top+1]=e('damage',effect.value,{normalAmount=effect.normalAmount})end
 elseif op=='skewer'then
  check(effect.value);check(effect.normalAmount)
  local n=xAmount(state,context)
  if n>0 then
   plan.bottom[1]=e('skewerHits',effect.value,{remaining=n,normalAmount=effect.normalAmount})
   plan.consumeAllEnergy=context.freeToPlayOnce~=true
  end
 elseif op=='malaise'then
  assert(effect.value==0 or effect.value==1,'invalid Malaise upgrade')
  local n=xAmount(state,context)+0.0+effect.value;check(n)
  if n>0 then
   plan.bottom={status('strength',-n),status('weak',n)}
   plan.consumeAllEnergy=context.freeToPlayOnce~=true
  end
 elseif op=='glassKnife'then
  check(effect.value);check(effect.normalAmount)
  local instance=assert(context.instance,'missing Glass Knife instance')
  assert(instance.cardId=='glass_knife','wrong Glass Knife instance');uid(instance.uid)
  plan.top={e('damage',effect.value,{normalAmount=effect.normalAmount}),e('damage',effect.value,{normalAmount=effect.normalAmount}),e('reduceGlassKnife',2,{uid=instance.uid})}
 elseif op=='unload'then
  for i=#state.hand,1,-1 do
   local card=state.hand[i]
   if definition(state,card,context).type~='attack'then
    plan.top[#plan.top+1]=e('discardSpecific',0,{uid=uid(card.uid),incrementFirst=true})
   end
  end
 elseif op=='stormOfSteel'then
  assert(type(effect.upgraded)=='boolean','invalid Storm upgrade')
  local n=check(#state.hand)
  plan.top={e('requestDiscard',n),e('generateShivs',n,{upgraded=effect.upgraded})}
 else return nil end
 return plan
end
-- Call at randomManualDiscard execution, not when the parent card is prepared.
-- Source DiscardAction's <=amount branch automatically discards, without RNG.
function M.randomDiscardUid(state)
 if #state.hand==0 then return nil end
 if #state.hand==1 then return uid(state.hand[1].uid)end
 assert(state.cardRandomRng,'missing random discard RNG')
 return uid(state.hand[Random.randomInt(state.cardRandomRng,#state.hand-1)+1].uid)
end
-- ModifyDamageAction includes cardInUse, limbo and every matching UUID in 4 piles.
-- UID is this app's combat-identity analogue; no second damage state is stored.
function M.reduceGlassKnife(state,cardUid,amount)
 uid(cardUid);assert(amount==2,'unsupported Glass Knife reduction')
 local matches,seen={},{}
 local function add(card)
  if card and card.uid==cardUid and not seen[card]then
   assert(card.cardId=='glass_knife','Glass Knife UID collision')
   local base=card.upgraded and 12 or 8
   local old=check(card.glassKnifeReduction or 0)
   matches[#matches+1]={card=card,value=math.min(base,old+0.0+2)};seen[card]=true
  end
 end
 for _,name in ipairs({'hand','draw','discard','exhaust','limbo'})do for _,card in ipairs(state[name]or{})do add(card)end end
 add(state.cardInUse)
 for _,entry in ipairs(matches)do entry.card.glassKnifeReduction=entry.value end
 return #matches
end
-- Pure lifecycle plans; host supplies correctly ordered hooks and targets.
function M.planHook(state,id,hook,owner)
 owner=owner or state.player;local n=owner.statuses[id]
 if n==nil then return {}end
 check(n)
 if id=='draw_next_turn' and hook=='turn_start_post_draw'then
  return {e('draw',n),e('removeStatus',0,{status=id,targetId=owner.id})}
 elseif id=='shackled' and hook=='owner_turn_end'then
  return {e('applyStatus',n,{status='strength',targetId=owner.id}),e('removeStatus',0,{status=id,targetId=owner.id})}
 elseif id=='choked' and hook=='owner_turn_start'then
  return {e('removeStatus',0,{status=id,targetId=owner.id})}
 elseif id=='blur' and hook=='round_end'then
  if n<=1 then return {e('removeStatus',0,{status=id,targetId=owner.id})}end
  return {e('reduceStatus',1,{status=id,targetId=owner.id})}
 end
 return {}
end
function M.planChokeOnUse(state)
 local bottom={}
 for _,enemy in ipairs(state.enemies)do
  local n=enemy.statuses.choked
  if n~=nil and Actors.isActive(enemy)then
   bottom[#bottom+1]=e('loseHp',check(n),{targetId=enemy.id,sourceNull=true})
  end
 end
 return bottom
end
return M
