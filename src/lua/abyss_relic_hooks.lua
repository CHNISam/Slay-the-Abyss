-- Session relic commands and lifecycle bridges; delegated APIs share fixed slots.
local Potion=require('abyss_relic_potion_hooks')
local S=require('abyss_sts_random')
local Queries=require('abyss_relic_queries').hooks
local Combat=require('abyss_relic_combat_hooks')
local Rules=require('abyss_relic_family_combat').common
local queryFields={localId=true,owns=true,onLoseHpLast=true,scoreAdjustment=true,campHealAmount=true}
local combatFields={enqueuePostDraw=true,upgradeRandomHand=true,onVictory=true,bindBattle=true,preBattle=true,hpChanged=true,wasHpLost=true,atTurnStart=true,prepareTurnStart=true,onUseCard=true,afterCard=true,battleStart=true,endTurnBlock=true,onPlayerEndTurn=true}
local ruleFields={gainGold=true,beforeObtainCard=true,onPreviewObtainCard=true,previewCardReward=true,onObtainCard=true}
local function queryIndex(_,key)
 if queryFields[key]then return Queries[key]
 elseif combatFields[key]then return Combat[key]
 elseif ruleFields[key]then return Rules[key]
 elseif key=='onUsePotion'then return Potion[key]end
end
local function queryNewIndex(self,key,value)
 if queryFields[key]then Queries[key]=value
 elseif combatFields[key]then Combat[key]=value
 elseif ruleFields[key]then Rules[key]=value
 elseif key=='onUsePotion'then Potion[key]=value
 else rawset(self,key,value)end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})

local function integer(n)return type(n)=='number' and n%1==0 and n>=0 and n<=2147483647 end

local function counters(owner)
 owner.relicCounters=owner.relicCounters or {};return owner.relicCounters
end

local function healRun(run,amount)if not require('abyss_potion_health').blocked(run.relics)then run.hp=math.min(run.maxHp,run.hp+amount)end end

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
   local ok,reason=api.upgrade(eligible[i],id);assert(ok~=false,reason or 'permanent upgrade rejected')
  else eligible[i].upgraded=true end
 end
end

function M.onEquip(run,id,upgradeApi)
 id=M.localId(id)
 require('abyss_uncommon_relics').onEquip(run,id)
 local bottled=(id=='bottled_flame' or id=='bottled_lightning' or id=='bottled_tornado') and require('abyss_uncommon_relics').bottleCandidates(run,id)
 if bottled and #bottled>0 then
  if run.pendingBottledRelic then return false,'bottled_relic_pending' end
  run.pendingBottledRelic={id=id,uids=bottled}
 end
 require('abyss_rare_relics').onEquip(run,id)
 local ok,why=require('abyss_boss_relics').onEquip(run,id)
 if not ok then return false,why end
 ok,why=require('abyss_shop_relics').onEquip(run,id)
 if ok==false then return false,why end
 if id=='nloths_mask' then counters(run).nloths_mask=1
 elseif id=='necronomicon'then return require('abyss_act2_event_relics').onEquip(run,id,upgradeApi)
 elseif id=='lizard_tail' then require('abyss_lizard_tail').onObtain(run)
 elseif id=='neows_lament' then counters(run).neows_lament=3
 elseif id=='omamori' then counters(run).omamori=2
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
 elseif id=='strawberry' or id=='pear' or id=='mango' or id=='lees_waffle' then
  require('abyss_max_hp_relics').equip(run,id,M.hpChanged)
 elseif id=='old_coin' then M.gainGold(run,300)
 elseif id=='whetstone' or id=='war_paint' then equipmentUpgrade(run,id,upgradeApi)
 elseif id=='toxic_egg' or id=='molten_egg' or id=='frozen_egg' then
  -- ToxicEgg2/MoltenEgg2.onEquip visit CombatRewardScreen.rewards only. Dream Catcher
  -- opens CardRewardScreen directly; neither it nor old shop shelves belongs here.
  if run.phase=='reward' and run.rewards and not run.rewards.cardResolved then M.previewCardReward(run,run.rewards)end
  local event=run.nodeFlow and run.nodeFlow.event
  if event and event.id=='sensory_stone' and event.rewardScreenOpen then
   for _,reward in ipairs(event.rewards or {})do if not reward.claimed then M.previewCardReward(run,reward)end end
  end
 end
 return true
end

function M.onUnequip(run,id)
 id=M.localId(id)
 if id=='necronomicon'then return require('abyss_act2_event_relics').onUnequip(run,id)end
 return require('abyss_relic_loss').onUnequip(run,id)
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

function M.onRest(run,createCardReward)
 if not M.owns(run,'dream_catcher')then return nil end
 assert(type(createCardReward)=='function','Dream Catcher requires ordinary card reward adapter')
 return createCardReward(run)
end

function M.onEnterRoom(run,kind,phase)
 require('abyss_uncommon_relics').onEnterRoom(run,kind,phase)
 -- onEnterRoom runs before justEnteredRoom; preserve those distinct phases.
 if phase~='entered' then
  for _,id in ipairs(run.relics or {})do
   if M.localId(id)=='maw_bank' and (counters(run).maw_bank or 0)~=-2 then M.gainGold(run,12)end
   if M.localId(id)=='ssserpent_head'and kind=='event'then M.gainGold(run,50)end
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
return M
