-- Combat relic callbacks. The caller owns state, queue execution and commit.
local A=require('abyss_actor')
local E=require('abyss_events')
local S=require('abyss_sts_random')
local Queries=require('abyss_relic_queries').hooks
local function queryIndex(_,key)
 if key=='localId' or key=='owns' then return Queries[key] end
end
local function queryNewIndex(self,key,value)
 if key=='localId' or key=='owns' then Queries[key]=value else rawset(self,key,value)end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})

local function integer(n)return type(n)=='number' and n%1==0 and n>=0 and n<=2147483647 end

local function energy(state,id,amount)
 assert(integer(state.energy) and state.energy+amount<=2147483647,'relic energy overflow')
 state.energy=state.energy+amount
 E.emit(state,'relic_energy',{relic=id,amount=amount})
end

function M.enqueuePostDraw(state)
 for _,held in ipairs(state.relics or {})do
  require('abyss_relic_family_combat').rare.postDraw(state,held)
  if M.localId(held)=='warped_tongs'then
   require('abyss_combat_reactions').enqueueReaction(state,{op='relicUpgradeRandomHand'},false)
  end
 end
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

function M.onVictory(state)
 require('abyss_relic_family_combat').uncommon.onVictory(state)
 require('abyss_relic_family_combat').rare.onVictory(state)
end

function M.bindBattle(state,owned,persistentCounters)
 state.relics={};for i,id in ipairs(owned)do state.relics[i]=M.localId(id)end
 state.relicCounters={};for k,v in pairs(persistentCounters or {})do state.relicCounters[k]=v end
 require('abyss_lizard_tail').bind(state)
 state.relicCombat={attackPlayed=false}
 require('abyss_relic_family_combat').rare.bindBattle(state)
end

local function neowOpening(state)
 -- NeowsLament.atBattleStart directly sets current health, before queued
 -- opening actions; this is neither damage nor an HP-loss/death callback.
 if M.owns(state,'neows_lament')then
  local left=state.relicCounters.neows_lament
  assert(type(left)=='number' and left%1==0 and (left==-2 or left>=1 and left<=3),'invalid Neow counter')
  if left>0 then
   state.relicCounters.neows_lament=left==1 and -2 or left-1
   for _,enemy in ipairs(state.enemies)do
    enemy.hp=1;E.emit(state,'relic_hp_set',{relic='neows_lament',target=enemy.id,hp=1})
   end
  end
 end
end

local function insectOpening(state,context)
 if M.owns(state,'preserved_insect') and (context.eliteTrigger==true or (context.tier=='elite' and context.eliteTrigger~=false))then
  for _,enemy in ipairs(state.enemies)do
   local maximum=math.floor(S.float32(S.float32(enemy.maxHp)*S.float32(.75)))
   if enemy.hp>maximum then
    enemy.hp=maximum;E.emit(state,'relic_hp_set',{relic='preserved_insect',target=enemy.id,hp=enemy.hp})
   end
  end
 end
end

function M.preBattle(state,context)
 context=context or {}
 if M.owns(state,'philosophers_stone')then require('abyss_relic_family_combat').boss.battleStart(state,'philosophers_stone')end
 neowOpening(state)
 insectOpening(state,context)
end

local function redSkullHealth(state,actor,before,queuedFatal,c)
 if M.owns(state,'red_skull')then
  local bloodied=actor.hp<=actor.maxHp/2.0
  local wasBloodied=before<=actor.maxHp/2.0
  if bloodied and not wasBloodied and not c.redSkullActive then
   c.redSkullActive=true
   if queuedFatal then require('abyss_combat_reactions').enqueueReaction(state,{op='gainStatus',status='strength',value=3},true)
   else A.applyPower(state,actor,'strength',3,actor)end
  elseif not bloodied and wasBloodied and c.redSkullActive then
   c.redSkullActive=false
   if queuedFatal then require('abyss_combat_reactions').enqueueReaction(state,{op='gainStatus',status='strength',value=-3},true)
   else A.applyPower(state,actor,'strength',-3,actor)end
  end
 end
end

function M.hpChanged(state,actor,before,queuedFatal)
 if actor~=state.player or not queuedFatal and not A.isActive(actor)then return end
 local inCombat=false
 for _,enemy in ipairs(state.enemies or {})do if A.isPresent(enemy)then inCombat=true;break end end
 if not inCombat and not queuedFatal then return end
 local c=state.relicCombat
 if not c then return end
 redSkullHealth(state,actor,before,queuedFatal,c)
end

function M.wasHpLost(state,actor,amount)
 if actor~=state.player or amount<=0 then return end
 local inCombat=false
 for _,enemy in ipairs(state.enemies or {})do if A.isPresent(enemy)then inCombat=true;break end end
 local c=state.relicCombat
 if not inCombat or not c then return end
 require('abyss_relic_family_combat').boss.wasHpLost(state,actor,amount)
 for _,effect in ipairs(require('abyss_relic_family_combat').uncommon.wasHpLost(state,actor,amount))do
  require('abyss_combat_reactions').enqueueReaction(state,effect,true)
 end
 if M.owns(state,'centennial_puzzle') and not c.centennialUsed then
  c.centennialUsed=true
  -- wasHPLost queues a TOP DrawCardAction; it must not draw while the HP
  -- action is still executing. This is the existing CardActions item ABI.
  -- The outer action owner drains it, including draw-triggered actions.
  require('abyss_combat_reactions').enqueueReaction(state,{op='draw',value=3},true)
 end
end

local function teaSetTurnStart(state)
 for _,id in ipairs(state.relics or {})do
  if id=='ancient_tea_set' and state.turn==1 and state.relicCounters.ancient_tea_set==-2 then
   state.relicCounters.ancient_tea_set=-1;energy(state,id,2)
  end
 end
end

local function flowerAndWarTurnStart(state)
 for _,id in ipairs(state.relics or {})do
  if id=='happy_flower' then
   local old=state.relicCounters.happy_flower or 0
   assert(old==-1 or (integer(old) and old<=2),'invalid Happy Flower counter')
   local nextCount=old==-1 and 1 or old+1
   state.relicCounters.happy_flower=nextCount==3 and 0 or nextCount
   if nextCount==3 then energy(state,id,1)end
  elseif id=='art_of_war' and state.turn>1 and not state.relicCombat.attackPlayed then energy(state,id,1)end
 end
end

function M.atTurnStart(state)
 require('abyss_act2_event_relics').turnStart(state)
 teaSetTurnStart(state)
 flowerAndWarTurnStart(state)
 if state.relicCombat then state.relicCombat.attackPlayed=false end
end

function M.prepareTurnStart(state)
 local actions={}
 require('abyss_relic_family_combat').boss.atTurnStart(state)
 for _,id in ipairs(state.relics or {})do
  require('abyss_relic_family_combat').rare.atTurnStart(state,id,function(_,effect,top)
   local action={kind='effect',effect=effect}
   if top then table.insert(actions,1,action)else actions[#actions+1]=action end
  end)
  for _,effect in ipairs(require('abyss_relic_family_combat').uncommon.atTurnStart(state,id))do actions[#actions+1]={kind='effect',effect=effect}end
  local topIndex=1
  for _,effect in ipairs(require('abyss_relic_family_combat').shop.turnStartActions(state,id))do
   local action={kind='effect',effect=effect}
   if effect.top then table.insert(actions,topIndex,action);topIndex=topIndex+1 else actions[#actions+1]=action end
  end
  if M.localId(id)=='damaru' then
   local effect=require('abyss_mantra').prepareGain(state,1)
   effect.nullSource=true
   actions[#actions+1]={kind='effect',effect=effect}
  end
 end
 return actions
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

local function openingHeal(state,id,value)
  local amount=require('abyss_potion_health').modifyHealing(value,state.relics,true)
  if state.originalV4 then require('abyss_original_v4_health').heal(state,state.player,amount,nil,id)
  else
   local before=state.player.hp;state.player.hp=math.min(state.player.maxHp,before+amount)
   E.emit(state,'heal',{target=state.player.id,amount=state.player.hp-before,relic=id})
   M.hpChanged(state,state.player,before)
  end
end

local function redMaskOpening(state)
  for _,enemy in ipairs(state.enemies)do
   if A.isActive(enemy)then A.applyPower(state,enemy,'weak',1,state.player,false)end
  end
end

local function marblesOpening(state)
  for _,enemy in ipairs(state.enemies)do
   if A.isActive(enemy)then A.applyPower(state,enemy,'vulnerable',1,state.player)end
  end
end

local function redSkullOpening(state)
  if state.player.hp<=state.player.maxHp/2.0 and not state.relicCombat.redSkullActive then
   state.relicCombat.redSkullActive=true;A.addStatus(state.player,'strength',3)
   E.emit(state,'status',{source=state.player.id,target=state.player.id,status='strength',amount=3})
  end
end

local function openingPower(state,id)
 if id=='cultist_mask'then E.emit(state,'relic_flavor',{relic=id,text='CAW! CAAAW!'})
 elseif id=='fossilized_helix' then A.applyPower(state,state.player,'buffer',1,state.player)
 elseif id=='data_disk' then A.applyPower(state,state.player,'focus',1,state.player)
 elseif id=='red_mask'then redMaskOpening(state)
 elseif id=='bag_of_marbles' then marblesOpening(state)
 elseif id=='akabeko' then A.applyPower(state,state.player,'vigor',8,state.player)
 elseif id=='pen_nib' then
  if state.relicCounters.pen_nib==9 then A.applyPower(state,state.player,'pen_nib',1,state.player)end
 elseif id=='red_skull' then redSkullOpening(state)
 elseif id=='philosophers_stone' or id=='mark_of_pain' then require('abyss_relic_family_combat').boss.battleStart(state,id)
 elseif id=='thread_and_needle' or id=='girya' or id=='du_vu_doll' then require('abyss_relic_family_combat').rare.battleStart(state,id,true)
 else error('unsupported battle hook '..tostring(id))end
end

function M.battleStart(state,id)
 if id=='mutagenic_strength'then return require('abyss_act2_event_relics').battleStart(state,id)end
 id=M.localId(id)
 if id=='pantograph' then openingHeal(state,id,25)
 elseif id=='blood_vial' then openingHeal(state,id,2)
 else openingPower(state,id)end
end

function M.endTurnBlock(state)
 if state.relicEndTurnResolved==state.turn then return end
 if not A.isActive(state.player)then return end
 -- Fixed GainBlockAction bypasses Dexterity/Frail. Eligibility is observed at
 -- hook dispatch, before end-turn cards/powers, not after their queued effects.
 if M.owns(state,'orichalcum') and state.player.block==0 then return 6 end
end

function M.onPlayerEndTurn(state)
 require('abyss_relic_family_combat').rare.onPlayerEndTurn(state)
 local amount=M.endTurnBlock(state)
 if amount then A.block(state,state.player,amount,true)end
end
return M
