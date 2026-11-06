-- Combat relic rules on existing action/candidate owners; no Session commands.
local A=require('abyss_actor')
local E=require('abyss_events')
local S=require('abyss_sts_random')
local R=S
local boss,uncommon,rare,shop,common

do
local Queries=require('abyss_relic_queries').boss
local queryFields={canPlay=true,cardRewardCount=true,drawBonus=true,energyBonus=true,hidesIntents=true,localId=true,retainsHand=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
local owns=Queries.privateOwns
boss=M
function M.atTurnStart(state)
 if owns(state,'velvet_choker')then
  state.relicCounters=state.relicCounters or {};state.relicCounters.velvet_choker=0
 end
end
function M.onPlayCard(state)
 if owns(state,'velvet_choker')then
  state.relicCounters.velvet_choker=math.min(6,(state.relicCounters.velvet_choker or 0)+1)
 end
end
function M.wasHpLost(state,actor,amount)
 if actor==state.player and amount>0 and owns(state,'runic_cube')then
  local combat=false;for _,e in ipairs(state.enemies)do if A.isPresent(e)then combat=true;break end end
  if combat then require('abyss_combat_reactions').enqueueReaction(state,{op='draw',value=1},true)end
 end
end
function M.preBattle(state,owner)
 if owns(owner or state,'snecko_eye')then A.applyPower(state,state.player,'confusion',1,state.player)end
end
function M.onSpawnMonster(state,enemy)
 if owns(state,'philosophers_stone')then
  -- Source monster.addPower bypasses Artifact/debuff application hooks.
  A.addStatus(enemy,'strength',1)
 end
end
function M.battleStart(state,id)
 id=M.localId(id)
 if id=='philosophers_stone'then for _,enemy in ipairs(state.enemies)do M.onSpawnMonster(state,enemy)end
 elseif id=='mark_of_pain'then
  -- This hook is dispatched by the already ordered after-draw opening group.
  -- Use the native MakeTempCard helper, whose random spot excludes the top
  -- slot exactly as CardGroup.addToRandomSpot does in the pinned source.
  require('abyss_build_actions').makeCard(state,{cardId='wound',value=2,pile='draw',randomSpot=true})
 else error('unsupported boss battle hook '..tostring(id))end
end
end

do
local Queries=require('abyss_relic_queries').uncommon
local queryFields={isBottled=true,localId=true,owns=true,rewardCardCount=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
uncommon=M
local function counters(owner)owner.relicCounters=owner.relicCounters or {};return owner.relicCounters end
local function effect(op,value,extra)
 local e=extra or {};e.op=op;e.value=value;return e
end
function M.onVictory(state)
 for _,id in ipairs({'letter_opener','kunai','shuriken','ornamental_fan'})do
  if M.owns(state,id)then counters(state)[id]=-1 end
 end
end
function M.atTurnStart(state,singleId)
 local out,c={},counters(state)
 for _,id in ipairs(singleId and {singleId}or state.relics or {})do
  id=M.localId(id)
  if id=='kunai'or id=='shuriken'or id=='ornamental_fan'or id=='letter_opener'then c[id]=0
  elseif id=='horn_cleat'and state.turn==2 then out[#out+1]=effect('block',14,{fixed=true})
  elseif id=='mercury_hourglass'then out[#out+1]=effect('damageAll',3,{fixed=true,nullSource=true})end
 end
 return out
end
local function advance(owner,id,limit)
 local c=counters(owner);local old=c[id]or 0
 assert(type(old)=='number'and old%1==0 and old>=0 and old<limit,'invalid '..id..' counter')
 c[id]=(old+1)%limit;return c[id]==0
end
function M.onShuffle(state)
 if M.owns(state,'sundial')and advance(state,'sundial',3)then return {effect('energy',2)}end
 return {}
end
local function mummifiedCost(state,card)
 local base=assert(state.catalog.cards[card.cardId]);local cost=card.combatCost or card.costOverride or base.cost
 if card.upgraded and base.upgrade and base.upgrade.cost~=nil and card.combatCost==nil and card.costOverride==nil then cost=base.upgrade.cost end
 return cost
end
local function mummifiedEligible(card,instance,queued,cost,current)
 return card~=instance and not queued[card]and cost>0 and current.cost>0 and not card.freeToPlayOnce and not current.costMode
end
local function mummify(state,instance,combat)
 assert(combat and combat.cardDefinition and combat.cardRandom,'Mummified Hand requires card API')
 local eligible,queued={},{}
 for _,entry in ipairs(state.queuedCards or {})do local card=entry.card or entry.instance;if card then queued[card]=true end end
 for _,card in ipairs(state.hand)do
  local cost=mummifiedCost(state,card)
  local current=combat.cardDefinition(state,card)
  if mummifiedEligible(card,instance,queued,cost,current)then eligible[#eligible+1]=card end
 end
 if #eligible>0 then local card=eligible[combat.cardRandom(state,#eligible)];card.costForTurn=0;if card.turnCost~=nil then card.turnCost=0 end end
end
local function advanceAttackRelic(state,definition,id)
 return definition.type=='attack'and(id=='kunai'or id=='shuriken'or id=='ornamental_fan')and advance(state,id,3)
end
local function useHeldRelic(state,definition,instance,combat,id,out)
 if advanceAttackRelic(state,definition,id)then
  if id=='ornamental_fan'then out[#out+1]=effect('block',4,{fixed=true})
  else out[#out+1]=effect('gainStatus',1,{status=id=='kunai'and 'dexterity'or 'strength'})end
 elseif id=='letter_opener'and definition.type=='skill'and advance(state,id,3)then out[#out+1]=effect('damageAll',5,{fixed=true,nullSource=true})
 elseif id=='ink_bottle'and advance(state,id,10)then out[#out+1]=effect('draw',1)
 elseif id=='blue_candle'and definition.type=='curse'then
  assert(instance,'Blue Candle requires card instance');instance.exhaust=true;out[#out+1]=effect('loseHp',1)
 elseif id=='mummified_hand'and definition.type=='power'then mummify(state,instance,combat)end
end
function M.onUseCard(state,definition,instance,combat)
 local out={}
 for _,held in ipairs(state.relics or {})do
  local id=M.localId(held)
  useHeldRelic(state,definition,instance,combat,id,out)
 end
 return out
end
function M.onMonsterDeath(state,enemy)
 if not M.owns(state,'gremlin_horn')or enemy.hp~=0 then return {}end
 for _,other in ipairs(state.enemies)do
  if other~=enemy and require('abyss_actor').isPresent(other)and not other.isDying then return {effect('energy',1),effect('draw',1)}end
 end
 return {}
end
function M.wasHpLost(state,actor,amount)
 if actor==state.player and amount>0 and M.owns(state,'self_forming_clay')then return {effect('gainStatus',3,{status='next_turn_block'})}end
 return {}
end
function M.strikeBonus(owner,definition)return definition.strikeTag and M.owns(owner,'strike_dummy')and 3 or 0 end
function M.vulnerablePercent(owner,target)if target~=owner.player and M.owns(owner,'paper_frog')then return 175 end end
function M.canPlayCurse(owner,definition)return definition.type=='curse'and M.owns(owner,'blue_candle')end
end

do
local Queries=require('abyss_relic_queries').rare
local queryFields={canSpawn=true,extraCardRewards=true,localId=true,owns=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
local owns=Queries.privateOwns
rare=M
local function counters(s)s.relicCounters=s.relicCounters or {};return s.relicCounters end
local function flags(s)s.rareRelicCombat=s.rareRelicCombat or {};return s.rareRelicCombat end
local function enqueue(s,e,top)require('abyss_combat_reactions').enqueueReaction(s,e,top)end
local function living(s)
 for _,enemy in ipairs(s.enemies or {})do if A.isPresent(enemy)then return true end end
 return false
end
function M.bindBattle(s)
 s.rareRelicCombat={firstPocketTurn=true,gamblingActivated=false,topCanDraw=false,topDisabled=false}
 for _,id in ipairs({'stone_calendar','captains_wheel','pocketwatch'})do if owns(s,id)then counters(s)[id]=0 end end
end
function M.battleStart(s,id,execute)
 id=M.localId(id)
 local power,n
 if id=='thread_and_needle'then power,n='plated_armor',4
 elseif id=='girya'or id=='du_vu_doll'then power,n='strength',counters(s)[id]or 0 end
 if power and n>0 then
  if execute then A.applyPower(s,s.player,power,n,s.player)
  else enqueue(s,{op='gainStatus',status=power,value=n},true)end
 end
end
local function advanceTurnRelic(s,id,c,push)
 if id=='stone_calendar'then c[id]=(c[id]or 0)+1
 elseif id=='captains_wheel'and (c[id]or 0)>=0 then
  c[id]=(c[id]or 0)+1
  if c[id]==3 then c[id]=-1;push(s,{op='block',value=18,fixed=true})end
 elseif id=='incense_burner'then
  c[id]=(c[id]==-1 and 1 or (c[id]or 0)+1)
  if c[id]==6 then c[id]=0;push(s,{op='gainStatus',status='intangible',value=1,nullSource=true})end
 end
end
function M.atTurnStart(s,singleId,emit)
 local push=emit or enqueue
 local c=counters(s);local f=flags(s)
 f.topCanDraw=true;f.topDisabled=false
 for _,held in ipairs(singleId and {singleId}or s.relics or {})do
  local id=M.localId(held)
  advanceTurnRelic(s,id,c,push)
 end
end
function M.postDraw(s,singleId)
 local c,f=counters(s),flags(s)
 for _,held in ipairs(singleId and {singleId}or s.relics or {})do
  local id=M.localId(held)
  if id=='pocketwatch'then
   if not f.firstPocketTurn and (c[id]or 0)<=3 then enqueue(s,{op='draw',value=3})end
   f.firstPocketTurn=false;c[id]=0
  elseif id=='gambling_chip'and not f.gamblingActivated then
   f.gamblingActivated=true;enqueue(s,{op='rareGamblingChip'})
  end
 end
end
function M.onPlayCard(s)
 if owns(s,'pocketwatch')then local c=counters(s);c.pocketwatch=(c.pocketwatch or 0)+1 end
end
function M.onUseCard(s,d)
 if d.type=='power'and owns(s,'bird_faced_urn')then enqueue(s,{op='heal',value=2,relic='bird_faced_urn'},true)end
end
function M.onPlayerEndTurn(s)
 flags(s).topCanDraw=false
 if s.relicEndTurnResolved~=s.turn and owns(s,'stone_calendar')and counters(s).stone_calendar==7 then
  enqueue(s,{op='rareRelicDamageAll',value=52,relic='stone_calendar'})
 end
end
function M.disableTop(s)flags(s).topDisabled=true end
function M.onRefreshHand(s,canDraw)
 local f=flags(s)
 if canDraw and owns(s,'unceasing_top')and f.topCanDraw and not f.topDisabled and s.phase=='player'
  and A.isActive(s.player)and living(s)and #s.hand==0 and #s.draw+#s.discard>0
  and not s.player.noDraw and not s.pendingChoice and not s.pendingDiscard then
  enqueue(s,{op='draw',value=1});return true
 end
 return false
end
function M.blockPower(s,target,id)
 return target==s.player and (id=='weak'and owns(s,'ginger')or id=='frail'and owns(s,'turnip'))or false
end
function M.onVulnerableApplied(s,target)
 if target~=s.player and owns(s,'champion_belt')then enqueue(s,{op='rareRelicWeak',targetId=target.id,value=1})end
end
function M.onAttacked(s,owner,damageType,amount)
 if owns(s,'torii')and owner~=nil and damageType=='normal'and amount>1 and amount<=5 then return 1 end
 return amount
end
function M.blockAtTurnStart(s,amount)return owns(s,'calipers')and math.max(0,amount-15)or 0 end
function M.rechargeEnergy(s,base)return owns(s,'ice_cream')and s.energy+0.0+base or base end
function M.modifyHealing(s,amount,inCombat)
 if owns(s,'magic_flower')and inCombat then return math.floor(S.float32(S.float32(amount)*1.5)+.5)end
 return amount
end
function M.randomCardId(s)
 local pool={}
 for _,rarity in ipairs({'common','uncommon','rare'})do
  for _,id in ipairs(assert(s.sourcePools.src[rarity]))do
   if not assert(s.catalog.cards[id],'unknown source card').healing then pool[#pool+1]=id end
  end
 end
 assert(#pool>0,'empty Dead Branch pool')
 return pool[S.randomInt(assert(s.cardRandomRng,'missing combat card RNG'),#pool-1)+1]
end
function M.onExhaust(s,emit)
 emit=emit or enqueue
 for _,held in ipairs(s.relics or {})do
  local id=M.localId(held)
  if id=='charons_ashes'then emit(s,{op='rareRelicDamageAll',value=3,relic=id},true)
  elseif id=='dead_branch'and living(s)then emit(s,{op='rareRelicGenerate',card=M.randomCardId(s)})end
 end
end
local function beginGambling(s)
 s.choiceSerial=(s.choiceSerial or 0)+1
 local uids={};for _,c in ipairs(s.hand)do uids[#uids+1]=c.uid end
 s.pendingChoice={token=s.choiceSerial,op='rareGamblingChip',uids=uids,multiple=true,selected={},allowEmpty=true}
 E.emit(s,'card_choice',{token=s.choiceSerial,op='rareGamblingChip'})
end
local function validateGamblingSelection(s,uids,p)
 local allowed,seen,count={},{},0
 for _,uid in ipairs(p.uids)do allowed[uid]=true end
 for k,uid in pairs(uids)do
  count=count+1
  if type(k)~='number'or k%1~=0 or k<1 or k>#uids or not allowed[uid]or seen[uid]then return false,'invalid_choice'end
  local found=false;for _,card in ipairs(s.hand)do if card.uid==uid then found=true end end
  if not found then return false,'stale_choice'end
  seen[uid]=true
 end
 if count~=#uids then return false,'invalid_choice'end
 return true
end
function M.chooseGambling(combat,s,uids,token)
 local p=s.pendingChoice
 if not p or p.op~='rareGamblingChip'or token~=p.token then return false,'stale_choice'end
 if type(uids)~='table'then return false,'invalid_choice'end
 local valid,reason=validateGamblingSelection(s,uids,p)
 if not valid then return false,reason end
 s.pendingChoice=nil
 -- Chip increments discard before each card's manual-discard trigger.
 enqueue(s,{op='draw',value=#uids},true)
 for _,uid in ipairs(uids)do
  local ok,why=require('abyss_discard').discardSpecific(s,uid,true,combat);assert(ok,why)
 end
 return true
end
function M.applyEffect(combat,s,e)
 if e.op=='rareGamblingChip'then beginGambling(s)
 elseif e.op=='rareRelicGenerate'then
  combat.applyEffects(s,{{op='makeTempCardInHand',card=e.card,value=1}},s.player)
 elseif e.op=='rareRelicDamageAll'then
  local reactions={}
  for _,target in ipairs(s.enemies)do if A.isActive(target)then combat.damage(s,nil,target,e.value,true,reactions)end end
  A.resolveDamageReactions(s,reactions,combat.retaliate)
 elseif e.op=='rareRelicWeak'then
  for _,target in ipairs(s.enemies)do if target.id==e.targetId then A.applyPower(s,target,'weak',1,s.player,false)end end
 else return false end
 return true
end
function M.onVictory(s)
 for _,id in ipairs({'stone_calendar','pocketwatch','captains_wheel'})do if owns(s,id)then counters(s)[id]=-1 end end
end
end

do
local Queries=require('abyss_relic_queries').shop
local queryFields={aliases=true,drawOrderVisible=true,localId=true,owns=true,xBonus=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
shop=M
function M.battleStartActions(state,context)
 local actions={}
 if M.owns(state,'sling')and context and (context.eliteTrigger==true or context.tier=='elite'and context.eliteTrigger~=false)then
  actions[#actions+1]={op='gainStatus',status='strength',value=2,relic='sling',top=true}
 end
 if M.owns(state,'clockwork_souvenir')then
  actions[#actions+1]={op='gainStatus',status='artifact',value=1,relic='clockwork_souvenir',top=true}
 end
 return actions
end
function M.turnStartActions(state,singleId)
 state.shopRelicCombat=state.shopRelicCombat or {}
 state.shopRelicCombat.pellets={}
 local actions={}
 if (not singleId or M.localId(singleId)=='brimstone')and M.owns(state,'brimstone')then
  -- Source inserts enemies at TOP after player; reverse enemy iteration.
  for i=#state.enemies,1,-1 do local enemy=state.enemies[i]
   actions[#actions+1]={op='applyStatus',status='strength',value=1,targetId=enemy.id,relic='brimstone',top=true}
  end
  actions[#actions+1]={op='gainStatus',status='strength',value=2,relic='brimstone',top=true}
 end
 return actions
end
function M.onBlockBroken(state,target)
 if M.owns(state,'hand_drill')and target~=state.player then
  require('abyss_combat_reactions').enqueueReaction(state,
   {op='shopRelic',kind='handDrill',targetId=target.id},false)
 end
end
function M.onShuffle(state,effectsOnly)
 if M.owns(state,'the_abacus')then
  local effect={op='block',value=6,fixed=true,relic='the_abacus'}
  if effectsOnly then return effect end
  require('abyss_combat_reactions').enqueueReaction(state,effect,false)
 end
end
function M.medicalCard(state,definition)
 if definition.type~='status'or not M.owns(state,'medical_kit')then return definition end
 local copy={};for k,v in pairs(definition)do copy[k]=v end
 -- Burn/Dazed/Wound/Slimed become usable; costed statuses keep their cost.
 if copy.cost==-2 then copy.cost=0 end
 copy.exhaust=true;return copy
end
function M.exhaustAfterUse(state,definition,exhaust,purge)
 if not exhaust or purge or definition.type=='power'or not M.owns(state,'strange_spoon')then return exhaust end
 assert(state.cardRandomRng,'Strange Spoon requires cardRandomRng')
 return not R.randomBoolean(state.cardRandomRng)
end
function M.onUseCard(state,definition)
 if not M.owns(state,'orange_pellets')then return end
 state.shopRelicCombat=state.shopRelicCombat or {}
 local c=state.shopRelicCombat.pellets or {};state.shopRelicCombat.pellets=c
 c[definition.type]=true
 if c.attack and c.skill and c.power then
  state.shopRelicCombat.pellets={}
  require('abyss_combat_reactions').enqueueReaction(state,{op='shopRelic',kind='pellets'},false)
 end
end
local function removeDebuff(state,target,id)
 local n=id=='no_draw'and target.noDraw and 1 or target.statuses[id];if n==nil then return end
 require('abyss_power_schedule').remove(state,target,id)
 if id=='no_draw'then target.noDraw=false end
 target.statuses[id]=nil;target[id..'JustApplied']=nil
 local order={};for _,old in ipairs(target.powerOrder or {})do if old~=id then order[#order+1]=old end end
 target.powerOrder=order
 E.emit(state,'status',{source=target.id,target=target.id,status=id,amount=-n})
end
local function executeHandDrill(state,effect)
  for _,target in ipairs(state.enemies)do if target.id==effect.targetId and A.isActive(target)then
   A.applyPower(state,target,'vulnerable',2,state.player,false);break
  end end
end
local function pelletDebuff(id,n,d)
 return d and (d.kind=='debuff'or (id=='strength'or id=='dexterity'or id=='focus')and n<=0)
end
local function executePellets(state)
  local target=state.player;local powers,order={},{}
  if not A.isActive(target)then return end
  for i,id in ipairs(target.powerOrder or {})do order[id]=i end
  for id,n in pairs(target.statuses)do local d=target.statusDefinitions[id]
   if pelletDebuff(id,n,d)then
    powers[#powers+1]={id=id,priority=d.priority or 5,order=order[id]or math.huge}
   end
  end
  if target.noDraw then powers[#powers+1]={id='no_draw',priority=5,order=order.no_draw or math.huge}end
  table.sort(powers,function(a,b)
   if a.priority~=b.priority then return a.priority<b.priority end
   if a.order~=b.order then return a.order<b.order end
   return a.id<b.id
  end)
  for i=#powers,1,-1 do removeDebuff(state,target,powers[i].id)end
end
function M.execute(state,effect)
 if effect.kind=='handDrill'then executeHandDrill(state,effect)
 elseif effect.kind=='pellets'then executePellets(state)
 else error('unknown shop relic effect '..tostring(effect.kind))end
end
function M.beginToolbox(combat,state)
 assert(M.owns(state,'toolbox'),'Toolbox ownership required')
 assert(not state.pendingChoice,'card choice already pending')
 local pool=require('abyss_potion_discovery').pool(state,'colorless')
 local cards,used={},{}
 while #cards<3 do local id=pool[combat.cardRandom(state,#pool)]
  if not used[id]then used[id]=true;cards[#cards+1]={uid=#cards+1,cardId=id,upgraded=false}end
 end
 state.choiceSerial=(state.choiceSerial or 0)+1
 state.pendingChoice={op='toolbox',token=state.choiceSerial,uids={1,2,3},cards=cards,turn=state.turn}
 E.emit(state,'card_choice',{op='toolbox',token=state.choiceSerial})
end
function M.chooseToolbox(combat,state,token,index,actions)
 local p=state.pendingChoice
 if not p or p.op~='toolbox'or p.token~=token or p.turn~=state.turn then return false,'stale_card_choice'end
 if type(index)~='number'or index%1~=0 or not p.cards[index]then return false,'invalid_card_choice'end
 local card=actions.fresh(combat,state,p.cards[index].cardId)
 if (state.player.statuses.master_reality or 0)>0 and combat.canUpgrade(state,card)then combat.upgrade(state,card)end
 actions.toHand(state,card);state.pendingChoice=nil
 E.emit(state,'card_choice_resolved',{op='toolbox',cardId=card.cardId});return true
end
end

do
local Queries=require('abyss_relic_queries').hooks
local queryFields={localId=true,owns=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
common=M
local function integer(n)return type(n)=='number' and n%1==0 and n>=0 and n<=2147483647 end
local function counters(owner)
 owner.relicCounters=owner.relicCounters or {};return owner.relicCounters
end
local function healEventGold(run,amount)
 if require('abyss_potion_health').blocked(run.relics)then return end
 if run.phase=='combat'and M.owns(run,'magic_flower')then amount=math.floor(amount*1.5)end
 run.hp=math.min(run.maxHp,run.hp+amount)
end
function M.gainGold(run,amount)
 assert(integer(amount) and integer(run.gold),'invalid gold')
 if M.owns(run,'ectoplasm')then return 0 end
 assert(run.gold+0.0+amount<=2147483647,'gold overflow')
 run.gold=run.gold+0.0+amount
 if run.scoreStats then run.scoreStats.goldGained=run.scoreStats.goldGained+amount end
 require('abyss_act2_event_relics').gainGold(run,amount,function(n)return healEventGold(run,n)end)
 return amount
end
function M.beforeObtainCard(run,definition)
 assert(type(definition)=='table' and type(definition.type)=='string','invalid card definition')
 if (definition.type=='curse' or definition.type=='CURSE') and M.owns(run,'omamori')then
  local c=counters(run);local remaining=c.omamori
  assert(integer(remaining) and remaining<=2,'missing/invalid Omamori counter')
  if remaining>0 then c.omamori=remaining-1;return false,'curse_prevented' end
 end
 return true
end
local eggTypes={toxic_egg='skill',molten_egg='attack',frozen_egg='power'}
local function eggUpgrade(card,definition,kind)
 assert(type(definition)=='table','missing permanent card definition')
 if definition.type==kind and not card.upgraded and type(definition.upgrade)=='table' and next(definition.upgrade)then
  card.upgrades=(card.upgrades or 0)+1;card.upgraded=true
 end
end
function M.onPreviewObtainCard(run,card,definition)
 for _,id in ipairs(run.relics or {})do
  local kind=eggTypes[M.localId(id)]
  if kind then eggUpgrade(card,definition,kind)end
 end
end
local function previewDefinition(run,card)
 for _,d in ipairs(run.data.cards.cards)do if d.id==card.cardId then return d end end
end
function M.previewCardReward(run,reward,skipUpgraded)
 if not M.owns(run,'toxic_egg')and not M.owns(run,'molten_egg')and not M.owns(run,'frozen_egg')then return end
 for i,value in ipairs(reward.cards or {})do
  local card=type(value)=='table' and value or {cardId=value,upgraded=reward.cardUpgrades and reward.cardUpgrades[i]==true}
  local definition=previewDefinition(run,card)
  -- getRewardCards continues after a successful random upgrade. onEquip and
  -- RewardItem(COLORLESS) instead dispatch every card, even already upgraded.
  if not skipUpgraded or not card.upgraded then M.onPreviewObtainCard(run,card,definition)end
  if type(value)=='string' and card.upgraded then
   reward.cardUpgrades=reward.cardUpgrades or {};reward.cardUpgrades[i]=true
  end
 end
end
local function obtainCurseHealth(run,permanentApi)
 -- The source tests CURSE color, not STATUS type. No onEquip retroactivity.
 -- Ordinary active/retained contexts still refuse; only an explicit owner-
 -- matched adapter supplies source combat healing and permanent health sync.
 local combatApi=run.combat and permanentApi and permanentApi.combatContext==run.combat
 if (run.phase=='combat' or run.combat or run.pendingCombatRewards)and not combatApi then
  return false,'darkstone_health_context_unavailable'
 end
 assert(permanentApi and type(permanentApi.increaseMaxHp)=='function','missing permanent health API')
 local ok,why=permanentApi.increaseMaxHp(run,6)
 if not ok then return false,why end
 return true
end
function M.onObtainCard(run,card,definition,permanentApi)
 assert(type(card)=='table','invalid obtained card')
 for _,id in ipairs(run.relics or {})do
  if M.localId(id)=='ceramic_fish' then M.gainGold(run,9)
  elseif M.localId(id)=='darkstone_periapt' and (definition.type=='curse' or definition.type=='CURSE') then
   local ok,why=obtainCurseHealth(run,permanentApi)
   if not ok then return false,why end
  elseif eggTypes[M.localId(id)] then
   local before=require('abyss_card_origin').state(card)
   eggUpgrade(card,definition,eggTypes[M.localId(id)])
   if not before.upgraded and card.upgraded then
    require('abyss_card_origin').record(run,card,before,'obtained_upgraded',{kind='relic',relicId=M.localId(id)})
   end
  end
 end
 return true
end
end

return {boss=boss,uncommon=uncommon,rare=rare,shop=shop,common=common}
