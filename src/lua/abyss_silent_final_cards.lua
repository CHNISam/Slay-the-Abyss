-- Final Silent definitions and source action contracts, pinned STS1 319009.
-- Plans are pure data; shared Combat owns identity, selections and auto play.
local M={}
M.ops={silentFinal=true}
local function copy(x)if type(x)~='table'then return x end;local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y end
local function effect(op,value,extra)
 local t=extra or {};t.op=op;t.value=value
 if op~='damage'and op~='applyStatus'then t.op='silentFinal';t.kind=op end
 return t
end
local function power(id,n)return effect('gainSilentFinalPower',n,{status=id})end
local defs={
 {id='distraction',sourceId='Distraction',name='声东击西',type='skill',rarity='uncommon',cost=1,exhaust=true,effects={effect('distraction',1)},upgrade={cost=0},text='随机获得一张技能牌。本回合该牌费用为0。消耗。'},
 {id='endless_agony',sourceId='Endless Agony',name='无尽苦痛',type='attack',rarity='uncommon',cost=0,exhaust=true,effects={effect('damage',4)},upgrade={effects={effect('damage',6)}},text='造成4点伤害。抽到此牌时，获得一张复制。消耗。',upgradeText='造成6点伤害。抽到此牌时，获得一张复制。消耗。'},
 {id='masterful_stab',sourceId='Masterful Stab',name='精巧刺击',type='attack',rarity='uncommon',cost=0,effects={effect('damage',12)},upgrade={effects={effect('damage',16)}},text='造成12点伤害。本场战斗每次受到生命伤害，此牌费用增加1。',upgradeText='造成16点伤害。本场战斗每次受到生命伤害，此牌费用增加1。'},
 {id='setup',sourceId='Setup',name='计划',type='skill',rarity='uncommon',cost=1,effects={effect('setup',1)},upgrade={cost=0},text='将一张手牌放在抽牌堆顶。若其基础费用大于0，下次打出免费。'},
 {id='well_laid_plans',sourceId='Well Laid Plans',name='早有计划',type='power',rarity='uncommon',cost=1,effects={power('well_laid_plans',1)},upgrade={effects={power('well_laid_plans',2)}},text='回合结束时可以保留至多1张牌。',upgradeText='回合结束时可以保留至多2张牌。'},
 {id='bullet_time',sourceId='Bullet Time',name='子弹时间',type='skill',rarity='rare',cost=3,effects={effect('bulletTime',1)},upgrade={cost=2},text='本回合不能抽牌。当前所有非X且可打出手牌的本回合费用变为0。'},
 {id='burst',sourceId='Burst',name='爆发',type='skill',rarity='rare',cost=1,effects={power('burst',1)},upgrade={effects={power('burst',2)}},text='本回合下一张技能牌打出两次。',upgradeText='本回合下两张技能牌打出两次。'},
 {id='corpse_explosion',sourceId='Corpse Explosion',name='尸爆',type='skill',rarity='rare',cost=2,effects={effect('applyStatus',6,{status='poison'}),effect('applyStatus',1,{status='corpse_explosion'})},upgrade={effects={effect('applyStatus',9,{status='poison'}),effect('applyStatus',1,{status='corpse_explosion'})}},text='给予6层中毒。此敌人死亡时，对所有敌人造成等同其最大生命值的伤害。',upgradeText='给予9层中毒。此敌人死亡时，对所有敌人造成等同其最大生命值的伤害。'},
 {id='doppelganger',sourceId='Doppelganger',name='分身',type='skill',rarity='rare',cost=-1,costMode='all_energy',experimental=true,exhaust=true,effects={effect('doppelganger',0)},upgrade={effects={effect('doppelganger',1)}},text='下一回合额外获得X能量并抽X张牌。消耗。',upgradeText='下一回合额外获得X+1能量并抽X+1张牌。消耗。'},
 {id='nightmare',sourceId='Nightmare',name='噩梦',type='skill',rarity='rare',cost=3,exhaust=true,effects={effect('nightmare',3)},upgrade={cost=2},text='选择一张手牌。下一回合获得其3张复制。消耗。'},
 {id='phantasmal_killer',sourceId='Phantasmal Killer',name='幻影杀手',type='skill',rarity='rare',cost=1,effects={power('phantasmal',1)},upgrade={cost=0},text='下一回合你的普通攻击伤害翻倍。'},
 {id='tools_of_the_trade',sourceId='Tools of the Trade',name='必备工具',type='power',rarity='rare',cost=1,effects={power('tools_of_the_trade',1)},upgrade={cost=0},text='每回合开始时，额外抽1张牌，再丢弃1张牌。'},
 {id='alchemize',sourceId='Alchemize',name='炼药',type='skill',rarity='rare',cost=1,exhaust=true,tags={'HEALING'},effects={effect('alchemize',1)},upgrade={cost=0},text='获得一瓶随机药水。消耗。'},
 {id='wraith_form',sourceId='Wraith Form v2',name='幽魂形态',type='power',rarity='rare',cost=3,effects={power('intangible',2),power('wraith_form',-1)},upgrade={effects={power('intangible',3),power('wraith_form',-1)}},text='获得2回合无实体。每回合结束时失去1点敏捷。',upgradeText='获得3回合无实体。每回合结束时失去1点敏捷。'},
}
local powerSpecs={
 {'well_laid_plans','早有计划','buff',5},{'burst','爆发','buff',5},{'corpse_explosion','尸爆','debuff',5},
 {'nightmare','噩梦','buff',5},{'phantasmal','幻影','buff',5},{'double_damage','双倍伤害','buff',6},
 {'tools_of_the_trade','必备工具','buff',25},{'intangible','无实体','buff',75},{'wraith_form','幽魂形态','debuff',5},
}
local descriptions={
 well_laid_plans='回合结束时，可以选择保留至多对应层数的手牌。',burst='本回合接下来的对应层数张技能牌，各额外打出一次。回合结束移除。',
 corpse_explosion='死亡时，每层对所有其他敌人造成等于此敌人最大生命值的伤害，不受攻击伤害修正。',
 nightmare='下回合开始时，获得先前选中卡牌的对应层数张临时复制，然后移除此能力。',
 phantasmal='下一回合开始获得双倍伤害；每回合开始减少1层。',double_damage='普通攻击伤害翻倍，每回合结束减少1层。',
 tools_of_the_trade='每回合正常抽牌后，额外抽对应层数张牌，再手动丢弃等量手牌。',
 intangible='每次受到的伤害或生命损失最多为1。每回合结束减少1层。',wraith_form='每个自己的回合结束时，失去对应数值的敏捷。此减益和敏捷减少分别可被人工制品抵挡。',
}
function M.withCardDefinitions(data)
 local out=copy(data);local seen={}
 for _,d in ipairs(out.cards.cards)do seen[d.id]=true end
 for _,d in ipairs(defs)do
  assert(not seen[d.id],'Silent final card collision: '..d.id)
  local c=copy(d);c.sts_name=c.sourceId;c.silentFinalCard=true
  c.target=(c.id=='corpse_explosion'or c.id=='endless_agony'or c.id=='masterful_stab')and 'ENEMY'or 'SELF'
  if c.target=='ENEMY'then c.silentFinalLegacy=true;c.experimental=true end
  if c.id=='alchemize'then c.healing=true end
  out.cards.cards[#out.cards.cards+1]=c
 end
 seen={};for _,d in ipairs(out.statuses.statuses)do seen[d.id]=d end
 for _,p in ipairs(powerSpecs)do if not seen[p[1]]then
  out.statuses.statuses[#out.statuses.statuses+1]={id=p[1],name=p[2],kind=p[3],priority=p[4],
   stack='intensity',decay=(p[1]=='intangible'or p[1]=='double_damage')and 'round_end_minus_1'or 'none',
   description=descriptions[p[1]]}
 end end
 return require('abyss_silent_potions').register(out)
end
local function A()return require('abyss_actor')end
local function actions()return require('abyss_card_actions')end
local function remove(s,id)
 require('abyss_power_schedule').remove(s,s.player,id);s.player.statuses[id]=nil
end
function M.describe(card,dynamic)
 local definition
 for _,candidate in ipairs(defs)do if candidate.id==card.id then definition=candidate;break end end
 assert(definition,'unknown Silent final display')
 local text=card._upgraded and (definition.upgradeText or definition.text)or definition.text
 if dynamic and (card.id=='endless_agony'or card.id=='masterful_stab')then text=text:gsub('造成%d+点伤害','造成{effects.0.value}点伤害')end
 return text
end
function M.allowedAfterVictory(e)
 return e.kind=='corpseDamage'or e.kind=='trigger'and (e.action.op=='block'or e.action.op=='cardTriggerDamageAll')
end
function M.powerDescription(actor,id)
 local n=actor.statuses[id]or 0
 local number=require('abyss_numbers').integer
 if id=='wraith_form'then return '每个自己的回合结束时，失去'..number(-n)..'点敏捷；敏捷减少可被人工制品抵挡。'
 elseif id=='nightmare'then return '下回合开始，获得'..number(n)..'张'..(actor.nightmareCardName or '所选卡牌')..'的临时复制，然后移除此能力。'end
end
function M.adapt(s,c,d)
 if c.cardId=='masterful_stab'then
  local n=c.masterfulLosses or 0
  if c.costOverride==nil and c.combatCost==nil and c.turnCost==nil and c.costForTurn==nil then d.cost=d.cost+n end
 end
 if c.silentRetainTurn==s.turn then d.selfRetain=true end
 return d
end
function M.onHpLost(s)
 for _,name in ipairs({'hand','draw','discard'})do for _,c in ipairs(s[name])do if c.cardId=='masterful_stab'then
  c.masterfulLosses=(c.masterfulLosses or 0)+1
  if c.combatCost~=nil then c.combatCost=c.combatCost+1 end
  if c.turnCost~=nil then c.turnCost=c.turnCost+1 end
  if c.costOverride~=nil then c.costOverride=c.costOverride+1 end
  if c.costForTurn~=nil and c.costForTurn>=0 then c.costForTurn=c.costForTurn+1 end
 end end end
end
function M.onDraw(s,c)
 if c.cardId=='endless_agony'then
  local e={op='silentFinal',kind='copyHand',value=1,template=copy(c)}
  if s.actionQueue then require('abyss_action_queue').pushTop(s,{kind='effect',effect=e})
  else actions().enqueue(s,e,nil,nil,nil,true)end
 end
end
local function find(s,uid)for i,c in ipairs(s.hand)do if c.uid==uid then return c,i end end end
local function chooseOne(combat,s,kind,c)
 if kind=='setup'then
  local _,at=find(s,c.uid);table.remove(s.hand,at)
  if combat.combatBaseCost(s,c)>0 then c.freeToPlayOnce=true end
  s.draw[#s.draw+1]=c
 elseif kind=='nightmare'then
  local template=copy(c);template.uid=nil;template.deckUid=nil;template.costForTurn=nil;template.turnCost=nil;template.silentRetainTurn=nil
  if not s.player.statuses.nightmare then s.nightmareTemplate=template;s.player.nightmareCardName=s.catalog.cards[c.cardId].name end
  A().applyPower(s,s.player,'nightmare',3,s.player)
  local _,at=find(s,c.uid);table.remove(s.hand,at);s.hand[#s.hand+1]=c
 end
end
local function selection(combat,s,kind)
 if #s.hand==0 then return end
 if #s.hand==1 then return chooseOne(combat,s,kind,s.hand[1])end
 s.choiceSerial=(s.choiceSerial or 0)+1
 local ids={};for _,c in ipairs(s.hand)do ids[#ids+1]=c.uid end
 s.pendingChoice={op='silentFinal',kind=kind,token=s.choiceSerial,uids=ids,turn=s.turn}
end
function M.choose(combat,s,token,uid)
 local p=s.pendingChoice
 if not p or p.op~='silentFinal'or p.token~=token or p.turn~=s.turn then return false,'stale_card_choice'end
 if p.multiple then
  if uid==0 then
   for _,id in ipairs(p.selected)do local c=find(s,id);if not c then return false,'stale_card_choice'end end
   for _,id in ipairs(p.selected)do local c,at=find(s,id);c.silentRetainTurn=s.turn;table.remove(s.hand,at);s.hand[#s.hand+1]=c end
   s.pendingChoice=nil;s.silentRetainCommittedTurn=s.turn
   return combat.endTurn(s)
  end
  if not find(s,uid)then return false,'invalid_card_choice'end
  for i,id in ipairs(p.selected)do if id==uid then table.remove(p.selected,i);s.choiceSerial=s.choiceSerial+1;p.token=s.choiceSerial;return true end end
  if #p.selected>=p.maximum then return false,'invalid_card_choice'end
  p.selected[#p.selected+1]=uid;s.choiceSerial=s.choiceSerial+1;p.token=s.choiceSerial;return true
 end
 local valid=false;for _,id in ipairs(p.uids)do if id==uid then valid=true end end
 local c=find(s,uid);if not valid or not c then return false,'invalid_card_choice'end
 chooseOne(combat,s,p.kind,c);s.pendingChoice=nil;actions().drain(combat,s);return true
end
function M.beginRetain(s)
 local n=s.player.statuses.well_laid_plans or 0
 if n<=0 or #s.hand==0 or s.silentRetainCommittedTurn==s.turn then return false end
 for _,id in ipairs(s.relics or {})do if id=='runic_pyramid'or id=='Runic Pyramid'then return false end end
 if (s.player.statuses.equilibrium or 0)>0 then return false end
 s.choiceSerial=(s.choiceSerial or 0)+1;local ids={}
 for _,c in ipairs(s.hand)do ids[#ids+1]=c.uid end
 s.pendingChoice={op='silentFinal',kind='retain',multiple=true,selected={},maximum=n,
  token=s.choiceSerial,uids=ids,turn=s.turn}
 s.silentRetainResume=true;return true
end
function M.onUse(combat,s,d,c,targetIndex,x,purge)
 if purge or d.type~='skill'or (s.player.statuses.burst or 0)<=0 then return end
 s.player.statuses.burst=s.player.statuses.burst-1
 if s.player.statuses.burst==0 then remove(s,'burst')end
 s.queuedCards=s.queuedCards or {}
 table.insert(s.queuedCards,1,{card=actions().sameInstance(combat,s,c),targetIndex=targetIndex,energyOnUse=x,purge=true,autoplay=true,exhaustCards=false})
end
function M.startTurn(s,post)
 local p=s.player
 if not post then
  for _,id in ipairs(A().powerSequence(p,{'nightmare','phantasmal'}))do
   local n=p.statuses[id]
   if id=='nightmare'then
    actions().enqueue(s,{op='silentFinal',kind='copyHand',value=n,template=copy(s.nightmareTemplate)})
    actions().enqueue(s,{op='silentFinal',kind='remove',status=id,value=0})
   else
    actions().enqueue(s,{op='silentFinal',kind='phantasmalGain',value=n})
   end
  end
 else
  local n=p.statuses.tools_of_the_trade or 0
  if n>0 then actions().enqueue(s,{op='silentFinal',kind='tools',value=n})end
 end
end
function M.endTurn(s,actor)
 if actor~=s.player then return end
 if actor.statuses.burst then remove(s,'burst')end
end
function M.death(s,actor,before,push)
 local n=actor.statuses.corpse_explosion or 0
 if before<=0 or actor.hp>0 or n<=0 or actor.escaped or actor==s.player then return end
 local live=false;for _,e in ipairs(s.enemies)do if A().isPresent(e)then live=true end end
 if live then (push or actions().enqueueReaction)(s,{op='silentFinal',kind='corpseDamage',value=actor.maxHp*n})end
end
function M.prepare(combat,s,e)
 if e.op~='silentFinal'then return e end
 if e.kind=='alchemize'then
  local P=require('abyss_potion_random');local R=require('abyss_sts_random')
  local owner={potionRng=R.cloneState(assert(s.potionRng,'missing persistent potion RNG'))}
  e.potionId=P.sample(owner,{limited=true,character=s.potionCharacter or 'silent'}).id
  s.potionRng=owner.potionRng;s.potionRngChanged=true
 elseif e.kind=='distraction'then
  local pool={}
  for _,rarity in ipairs({'common','uncommon','rare'})do for _,id in ipairs(s.sourcePools.src[rarity])do
   local d=assert(s.catalog.cards[id],'missing source skill');if d.type=='skill'and not d.healing then pool[#pool+1]=id end
  end end
  e.cardId=pool[combat.cardRandom(s,#pool)]
 end
 return e
end
function M.apply(combat,s,item)
 local e=item.effect;local k=e.kind
 if k=='gainSilentFinalPower'then A().applyPower(s,s.player,e.status,e.value,s.player)
 elseif k=='potionShivs'then require('abyss_silent_potions').shivs(s,e.value)
 elseif k=='trigger'then
  local a=e.action
  if a.op=='cardTriggerDamageAll'then require('abyss_card_triggers').resolveDamageAll(s,a,combat)
  elseif a.op=='cardTriggerStorm'then
   for _,entry in ipairs(require('abyss_card_triggers').expandStorm(s,a))do actions().enqueue(s,{op='silentFinal',kind='trigger',action=entry.effect},nil,nil,nil,true)end
  else combat.applyEffects(s,{a},s.player,item.target,item.instance)end
 elseif k=='choke'then
  for _,enemy in ipairs(s.enemies)do if enemy.id==e.targetId and A().isActive(enemy)then
   local before=enemy.hp;A().loseHp(s,enemy,e.value);require('abyss_enemy_ai').hpLost(s,enemy,before,true);break
  end end
 elseif k=='setup'or k=='nightmare'then selection(combat,s,k)
 elseif k=='bulletTime'then
  A().applyNoDraw(s,s.player)
  for _,c in ipairs(s.hand)do if combat.cardDefinition(s,c).cost>=0 then c.costForTurn=0 end end
 elseif k=='copyHand'then
  for _=1,e.value do
   local c=actions().fresh(combat,s,e.template.cardId,e.template)
   actions().created(combat,s,c);actions().created(combat,s,c)
   actions().toHand(s,c)
  end
 elseif k=='distraction'then
  assert(e.cardId,'uncaptured Distraction');local c=actions().fresh(combat,s,e.cardId)
  c.costForTurn=0;actions().created(combat,s,c);actions().created(combat,s,c)
  actions().toHand(s,c)
 elseif k=='doppelganger'then
  local n=(e.energyOnUse or (s.pendingPlay and s.pendingPlay.energyOnUse)or 0)+e.value
  for _,id in ipairs(s.relics or {})do if id=='chemical_x'or id=='Chemical X'then n=n+2 end end
  if n>0 then A().applyPower(s,s.player,'energized',n,s.player);A().applyPower(s,s.player,'draw_next_turn',n,s.player)end
 elseif k=='phantasmalGain'then
  local n=(s.player.statuses.double_damage or 0)>0 and e.value or 1
  A().applyPower(s,s.player,'double_damage',n,s.player)
  s.player.statuses.phantasmal=s.player.statuses.phantasmal-1
  if s.player.statuses.phantasmal<=0 then remove(s,'phantasmal')end
 elseif k=='remove'then remove(s,e.status);if e.status=='nightmare'then s.nightmareTemplate=nil;s.player.nightmareCardName=nil end
 elseif k=='tools'then combat.draw(s,e.value);assert(require('abyss_discard').begin(s,e.value))
 elseif k=='startPower'then
  if e.status=='nightmare'then
   M.apply(combat,s,{effect={kind='copyHand',value=e.value,template=copy(s.nightmareTemplate)}})
   remove(s,'nightmare');s.nightmareTemplate=nil;s.player.nightmareCardName=nil
  else M.apply(combat,s,{effect={kind='phantasmalGain',value=e.value}})end
 elseif k=='corpseDamage'then
  local reactions={};for _,enemy in ipairs(s.enemies)do if A().isActive(enemy)then combat.damage(s,nil,enemy,e.value,true,reactions)end end
  A().resolveDamageReactions(s,reactions,combat.retaliate)
 elseif k=='alchemize'then
  local id=assert(e.potionId,'uncaptured Alchemize')
  actions().enqueue(s,{op='obtainPotion',id=id,unavailable=not s.catalog.potions[id]})
 else error('unknown Silent final action '..tostring(k))end
end
return M
