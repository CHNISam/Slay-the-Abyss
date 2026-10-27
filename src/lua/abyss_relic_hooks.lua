-- Narrow source-defined hooks: STS 319009d5 relic classes plus
-- ShowCardAndObtainEffect, AbstractPlayer and GameActionManager.
-- Run callers must invoke permanent hooks on their staged transaction.
local A=require('abyss_actor')
local E=require('abyss_events')
local S=require('abyss_sts_random')
local M={}
local aliases={['Darkstone Periapt']='darkstone_periapt',Omamori='omamori',CeramicFish='ceramic_fish',['Potion Belt']='potion_belt',
 MealTicket='meal_ticket',MawBank='maw_bank',['Blood Vial']='blood_vial',
 ['Bag of Marbles']='bag_of_marbles',Orichalcum='orichalcum',Ectoplasm='ectoplasm',
 Strawberry='strawberry',['Regal Pillow']='regal_pillow',['Toy Ornithopter']='toy_ornithopter',
 Whetstone='whetstone',['War Paint']='war_paint',['Happy Flower']='happy_flower',
 ['Ancient Tea Set']='ancient_tea_set',['Art of War']='art_of_war',
 Boot='boot',Akabeko='akabeko',['Pen Nib']='pen_nib',Nunchaku='nunchaku',
 PreservedInsect='preserved_insect',['Red Skull']='red_skull',['Centennial Puzzle']='centennial_puzzle',
 ['Tiny Chest']='tiny_chest',['Juzu Bracelet']='juzu_bracelet',['Dream Catcher']='dream_catcher',
 WarpedTongs='warped_tongs',['Spirit Poop']='spirit_poop',Circlet='circlet',TungstenRod='tungsten_rod',
 ['Red Mask']='red_mask',['Toxic Egg 2']='toxic_egg'}
function M.localId(id)return aliases[id] or id end
function M.owns(owner,id)
 for _,held in ipairs(owner.relics or {})do if M.localId(held)==id then return true end end
 return false
end
local function integer(n)return type(n)=='number' and n%1==0 and n>=0 and n<=2147483647 end
-- AbstractPlayer.damage dispatches this after onAttacked (including Static
-- Discharge), before Powers.onLoseHp and the actual HP/death notification.
-- Event owners use the same permanent relic list, never a historical battle.
function M.onLoseHpLast(owner,amount)
 assert(type(amount)=='number'and amount%1==0 and amount>=0 and amount<=9007199254740991,'invalid final HP loss')
 for _,id in ipairs(owner.relics or {})do
  if M.localId(id)=='tungsten_rod'and amount>0 then amount=amount-1 end
 end
 return amount
end
local function counters(owner)
 owner.relicCounters=owner.relicCounters or {};return owner.relicCounters
end
function M.gainGold(run,amount)
 assert(integer(amount) and integer(run.gold),'invalid gold')
 if M.owns(run,'ectoplasm')then return 0 end
 assert(run.gold+0.0+amount<=2147483647,'gold overflow')
 run.gold=run.gold+0.0+amount;return amount
end
local function healRun(run,amount)run.hp=math.min(run.maxHp,run.hp+amount)end
local function equipmentUpgrade(run,id,api)
 local kind=id=='whetstone' and 'attack' or 'skill'
 local function definition(card)
  for _,d in ipairs(run.data.cards.cards)do if d.id==card.cardId then return d end end
  error('unknown permanent card')
 end
 local eligible={}
 for _,card in ipairs(run.deck)do
  local d=definition(card)
  local can=api and api.canUpgrade and api.canUpgrade(card)
  if not api or not api.canUpgrade then can=not card.upgraded and d.upgrade and next(d.upgrade)~=nil end
  if d.type==kind and can then eligible[#eligible+1]=card end
 end
 -- Source shuffles even zero/one candidate using exactly one misc randomLong.
 S.shuffle(run.miscRng,eligible)
 for i=1,math.min(2,#eligible)do
  if api and api.upgrade then
   local ok,reason=api.upgrade(eligible[i]);assert(ok~=false,reason or 'permanent upgrade rejected')
  else eligible[i].upgraded=true end
 end
end
function M.onEquip(run,id,upgradeApi)
 id=M.localId(id)
 if id=='omamori' then counters(run).omamori=2
 elseif id=='maw_bank' then counters(run).maw_bank=0
 elseif id=='happy_flower' then counters(run).happy_flower=0
 elseif id=='pen_nib' or id=='nunchaku' then counters(run)[id]=0
 elseif id=='ancient_tea_set' then counters(run).ancient_tea_set=-1
 elseif id=='tiny_chest' then
  assert(run.unknown and run.unknown.chances,'missing unknown-room state')
  run.unknown.chances.tinyChestCount=0
 elseif id=='circlet' then
  -- Source constructor starts at one. The owner handles repeat obtains rather
  -- than calling onEquip twice; preserve its already incremented count.
  local c=counters(run);if c.circlet==nil then c.circlet=1 end
 elseif id=='potion_belt' then
  local slots=run.potionSlots or (run.data and run.data.rules.player.potionSlots)
  assert(integer(slots) and slots+2<=2147483647,'invalid potion capacity')
  run.potionSlots=slots+2
 elseif id=='strawberry' then
  assert(integer(run.maxHp) and run.maxHp+7<=2147483647,'invalid max health')
  run.maxHp=run.maxHp+7;healRun(run,7)
 elseif id=='whetstone' or id=='war_paint' then equipmentUpgrade(run,id,upgradeApi)
 elseif id=='toxic_egg' then
  -- ToxicEgg2.onEquip visits CombatRewardScreen.rewards only. Dream Catcher
  -- opens CardRewardScreen directly; neither it nor old shop shelves belongs here.
  if run.phase=='reward' and run.rewards and not run.rewards.cardResolved then M.previewCardReward(run,run.rewards)end
  local event=run.nodeFlow and run.nodeFlow.event
  if event and event.id=='sensory_stone' and event.rewardScreenOpen then
   for _,reward in ipairs(event.rewards or {})do if not reward.claimed then M.previewCardReward(run,reward)end end
  end
 end
end
function M.obtainCirclet(run)
 local c=counters(run)
 if M.owns(run,'circlet')then
  local old=c.circlet or 1;assert(integer(old) and old>=1 and old<2147483647,'invalid Circlet count')
  c.circlet=old+1
 else
  run.relics=run.relics or {};run.relics[#run.relics+1]='circlet';c.circlet=1
 end
 return true,c.circlet
end
function M.scoreAdjustment(run)return M.owns(run,'spirit_poop') and -1 or 0 end
-- atTurnStartPostDraw dispatches before the ordinary draw has executed: append
-- its action behind DrawCardAction, rather than inspecting the old hand now.
function M.enqueuePostDraw(state)
 if not M.owns(state,'warped_tongs')then return end
 state.cardActions=state.cardActions or {}
 state.cardActions[#state.cardActions+1]={effect={op='relicUpgradeRandomHand'},source=state.player}
end
function M.upgradeRandomHand(combat,state)
 local eligible={}
 for _,card in ipairs(state.hand)do
  if combat.cardDefinition(state,card).type~='status' and combat.canUpgrade(state,card)then
   eligible[#eligible+1]=card -- CardGroup.addToTop is append; preserve hand order
  end
 end
 if #eligible==0 then return end
 assert(state.shuffleRng,'Warped Tongs requires the source shuffleRng')
 -- UpgradeRandomCardAction calls CardGroup.shuffle(), whose no-argument
 -- overload uses shuffleRng.randomLong, even for one candidate.
 S.shuffle(state.shuffleRng,eligible)
 local card=eligible[1];assert(combat.upgrade(state,card)~=false,'combat upgrade refused')
 E.emit(state,'card_upgraded',{uid=card.uid,cardId=card.cardId,relic='warped_tongs'})
end
function M.campHealAmount(run,base)
 assert(integer(base),'invalid camp healing')
 local total=base+(M.owns(run,'regal_pillow') and 15 or 0)
 assert(total<=2147483647,'camp healing overflow');return total
end
function M.onUsePotion(run,combat)
 if not M.owns(run,'toy_ornithopter')then return end
 if combat then
  if not A.isActive(combat.player)then return end
  require('abyss_card_actions').enqueue(combat,{op='heal',value=5,relic='toy_ornithopter'},combat.player)
 else healRun(run,5)end
end
function M.onRest(run,createCardReward)
 if not M.owns(run,'dream_catcher')then return nil end
 assert(type(createCardReward)=='function','Dream Catcher requires ordinary card reward adapter')
 return createCardReward(run)
end
-- Must precede UID allocation, insertion and every onObtainCard hook. A blocked
-- curse is a resolved obtain attempt, not an error or a reason to reroll.
function M.beforeObtainCard(run,definition)
 assert(type(definition)=='table' and type(definition.type)=='string','invalid card definition')
 if (definition.type=='curse' or definition.type=='CURSE') and M.owns(run,'omamori')then
  local c=counters(run);local remaining=c.omamori
  assert(integer(remaining) and remaining<=2,'missing/invalid Omamori counter')
  if remaining>0 then c.omamori=remaining-1;return false,'curse_prevented' end
 end
 return true
end
local function eggUpgrade(card,definition)
 assert(type(definition)=='table','missing permanent card definition')
 if definition.type=='skill' and not card.upgraded and type(definition.upgrade)=='table' and next(definition.upgrade)then
  card.upgrades=(card.upgrades or 0)+1;card.upgraded=true
 end
end
-- Preview is deliberately separate from obtaining: no gold, UID, curse charge,
-- master-deck callback or random consumption. Mutate only the private offer.
function M.onPreviewObtainCard(run,card,definition)
 for _,id in ipairs(run.relics or {})do
  if M.localId(id)=='toxic_egg' then eggUpgrade(card,definition)end
 end
end
function M.previewCardReward(run,reward,skipUpgraded)
 if not M.owns(run,'toxic_egg')then return end
 for i,value in ipairs(reward.cards or {})do
  local card=type(value)=='table' and value or {cardId=value,upgraded=reward.cardUpgrades and reward.cardUpgrades[i]==true}
  local definition
  for _,d in ipairs(run.data.cards.cards)do if d.id==card.cardId then definition=d;break end end
  -- getRewardCards continues after a successful random upgrade. onEquip and
  -- RewardItem(COLORLESS) instead dispatch every card, even already upgraded.
  if not skipUpgraded or not card.upgraded then M.onPreviewObtainCard(run,card,definition)end
  if type(value)=='string' and card.upgraded then
   reward.cardUpgrades=reward.cardUpgrades or {};reward.cardUpgrades[i]=true
  end
 end
end
-- Called on the private card entity immediately before permanent insertion,
-- never on combat generation, upgrade or removal. One dispatch per obtain.
function M.onObtainCard(run,card,definition,permanentApi)
 assert(type(card)=='table','invalid obtained card')
 for _,id in ipairs(run.relics or {})do
  if M.localId(id)=='ceramic_fish' then M.gainGold(run,9)
  elseif M.localId(id)=='darkstone_periapt' and (definition.type=='curse' or definition.type=='CURSE') then
   -- The source tests CURSE color, not STATUS type. No onEquip retroactivity.
   -- Active/retained combat contexts lack source heal modifiers/health sync.
   if run.phase=='combat' or run.combat or run.pendingCombatRewards then return false,'darkstone_health_context_unavailable' end
   assert(permanentApi and type(permanentApi.increaseMaxHp)=='function','missing permanent health API')
   local ok,why=permanentApi.increaseMaxHp(run,6)
   if not ok then return false,why end
  elseif M.localId(id)=='toxic_egg' then eggUpgrade(card,definition)
  end
 end
 return true
end
function M.onEnterRoom(run,kind,phase)
 -- onEnterRoom runs before justEnteredRoom; preserve those distinct phases.
 if phase~='entered' then
  for _,id in ipairs(run.relics or {})do
   if M.localId(id)=='maw_bank' and (counters(run).maw_bank or 0)~=-2 then M.gainGold(run,12)end
  end
 end
 if phase~='enter' and kind=='shop' then
  for _,id in ipairs(run.relics or {})do if M.localId(id)=='meal_ticket' then healRun(run,15)end end
 end
 if phase~='enter' and kind=='camp' and M.owns(run,'ancient_tea_set')then counters(run).ancient_tea_set=-2 end
end
function M.onSpendGold(run,roomKind)
 -- AbstractPlayer.loseGold calls onSpendGold only in ShopRoom, even if the
 -- quoted price is zero. Event payments must not disable Maw Bank.
 if roomKind~='shop' then return end
 if M.owns(run,'maw_bank')then counters(run).maw_bank=-2 end
end
function M.bindBattle(state,owned,persistentCounters)
 state.relics={};for i,id in ipairs(owned)do state.relics[i]=M.localId(id)end
 state.relicCounters={};for k,v in pairs(persistentCounters or {})do state.relicCounters[k]=v end
 state.relicCombat={attackPlayed=false}
end
function M.preBattle(state,context)
 context=context or {}
 if M.owns(state,'preserved_insect') and (context.eliteTrigger==true or (context.tier=='elite' and context.eliteTrigger~=false))then
  for _,enemy in ipairs(state.enemies)do
   local maximum=math.floor(S.float32(enemy.maxHp*S.float32(.75)))
   if enemy.hp>maximum then
    enemy.hp=maximum;E.emit(state,'relic_hp_set',{relic='preserved_insect',target=enemy.id,hp=enemy.hp})
   end
  end
 end
end
function M.hpChanged(state,actor,before)
 if actor~=state.player or not A.isActive(actor)then return end
 local inCombat=false
 for _,enemy in ipairs(state.enemies or {})do if A.isActive(enemy)then inCombat=true;break end end
 if not inCombat then return end
 local c=state.relicCombat
 if not c then return end
 if M.owns(state,'red_skull')then
  local bloodied=actor.hp<=actor.maxHp/2.0
  local wasBloodied=before<=actor.maxHp/2.0
  if bloodied and not wasBloodied and not c.redSkullActive then
   c.redSkullActive=true;A.applyPower(state,actor,'strength',3,actor)
  elseif not bloodied and wasBloodied and c.redSkullActive then
   c.redSkullActive=false;A.applyPower(state,actor,'strength',-3,actor)
  end
 end
 if before>actor.hp and M.owns(state,'centennial_puzzle') and not c.centennialUsed then
  c.centennialUsed=true
  -- wasHPLost queues a TOP DrawCardAction; it must not draw while the HP
  -- action is still executing. This is the existing CardActions item ABI.
  -- The outer action owner drains it, including draw-triggered actions.
  require('abyss_card_actions').enqueueReaction(state,{op='draw',value=3},true)
 end
end
local function energy(state,id,amount)
 assert(integer(state.energy) and state.energy+amount<=2147483647,'relic energy overflow')
 state.energy=state.energy+amount
 E.emit(state,'relic_energy',{relic=id,amount=amount})
end
function M.atTurnStart(state)
 for _,id in ipairs(state.relics or {})do
  if id=='ancient_tea_set' and state.turn==1 and state.relicCounters.ancient_tea_set==-2 then
   state.relicCounters.ancient_tea_set=-1;energy(state,id,2)
  end
 end
 for _,id in ipairs(state.relics or {})do
  if id=='happy_flower' then
   local old=state.relicCounters.happy_flower or 0
   assert(old==-1 or (integer(old) and old<=2),'invalid Happy Flower counter')
   local nextCount=old==-1 and 1 or old+1
   state.relicCounters.happy_flower=nextCount==3 and 0 or nextCount
   if nextCount==3 then energy(state,id,1)end
  elseif id=='art_of_war' and state.turn>1 and not state.relicCombat.attackPlayed then energy(state,id,1)end
 end
 if state.relicCombat then state.relicCombat.attackPlayed=false end
end
function M.onUseCard(state,definition)
 if definition.type=='attack' and M.owns(state,'art_of_war')then state.relicCombat.attackPlayed=true end
 if definition.type~='attack' then return end
 local c=state.relicCombat or {};state.relicCombat=c
 c.consumeVigor=(state.player.statuses.vigor or 0)>0
 c.consumePenNib=(state.player.statuses.pen_nib or 0)>0
 for _,id in ipairs({'pen_nib','nunchaku'})do
  if M.owns(state,id)then
   local old=state.relicCounters[id] or 0;assert(integer(old) and old<=9,'invalid attack relic counter')
   state.relicCounters[id]=(old+1)%10
   if id=='nunchaku' and old==9 then c.nunchakuEnergy=true end
  end
 end
end
function M.afterCard(state)
 local c=state.relicCombat;if not c then return end
 for _,row in ipairs({{'consumeVigor','vigor'},{'consumePenNib','pen_nib'}})do
  if c[row[1]] then
   local old=state.player.statuses[row[2]] or 0;state.player.statuses[row[2]]=0
   E.emit(state,'status',{source=state.player.id,target=state.player.id,status=row[2],amount=-old})
   c[row[1]]=nil
  end
 end
 if M.owns(state,'pen_nib') and state.relicCounters.pen_nib==9 and (state.player.statuses.pen_nib or 0)==0 then
  A.applyPower(state,state.player,'pen_nib',1,state.player)
 end
 if c.nunchakuEnergy then c.nunchakuEnergy=nil;if A.isActive(state.player)then energy(state,'nunchaku',1)end end
end
function M.battleStart(state,id)
 id=M.localId(id)
 if id=='blood_vial' then
  if state.originalV4 then require('abyss_original_v4_health').heal(state,state.player,2,nil,id);return end
  local before=state.player.hp;state.player.hp=math.min(state.player.maxHp,before+2)
  E.emit(state,'heal',{target=state.player.id,amount=state.player.hp-before,relic=id})
  M.hpChanged(state,state.player,before)
 elseif id=='red_mask'then
  for _,enemy in ipairs(state.enemies)do
   if A.isActive(enemy)then A.applyPower(state,enemy,'weak',1,state.player,false)end
  end
 elseif id=='bag_of_marbles' then
  for _,enemy in ipairs(state.enemies)do
   if A.isActive(enemy)then A.applyPower(state,enemy,'vulnerable',1,state.player)end
  end
 elseif id=='akabeko' then A.applyPower(state,state.player,'vigor',8,state.player)
 elseif id=='pen_nib' then
  if state.relicCounters.pen_nib==9 then A.applyPower(state,state.player,'pen_nib',1,state.player)end
 elseif id=='red_skull' then
  if state.player.hp<=state.player.maxHp/2.0 and not state.relicCombat.redSkullActive then
   state.relicCombat.redSkullActive=true;A.addStatus(state.player,'strength',3)
   E.emit(state,'status',{source=state.player.id,target=state.player.id,status='strength',amount=3})
  end
 else error('unsupported battle hook '..tostring(id))end
end
function M.endTurnBlock(state)
 if not A.isActive(state.player)then return end
 -- Fixed GainBlockAction bypasses Dexterity/Frail. Eligibility is observed at
 -- hook dispatch, before end-turn cards/powers, not after their queued effects.
 if M.owns(state,'orichalcum') and state.player.block==0 then return 6 end
end
function M.onPlayerEndTurn(state)
 local amount=M.endTurnBlock(state)
 if amount then A.block(state,state.player,amount,true)end
end
return M
