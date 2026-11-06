-- STS1 319009d5 boss-relic rules. Call permanent operations on a staged Run.
-- Selection/reward continuation belongs to the caller; no filtered random pools.
local R=require('abyss_sts_random')

local Queries=require('abyss_relic_queries').boss
local Combat=require('abyss_relic_family_combat').boss
local queryFields={canPlay=true,cardRewardCount=true,drawBonus=true,energyBonus=true,hidesIntents=true,localId=true,retainsHand=true}
local combatFields={atTurnStart=true,battleStart=true,onPlayCard=true,onSpawnMonster=true,preBattle=true,wasHpLost=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
 if combatFields[key] then return Combat[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 elseif combatFields[key] then Combat[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
local owns=Queries.privateOwns

local function definition(run,id)
 for _,d in ipairs(run.data.cards.cards)do if d.id==id then return d end end
end
local function upgradeable(run,card)
 local d=definition(run,card.cardId)
 return d and d.upgrade and next(d.upgrade)and(not card.upgraded or d.repeatable)
end
local function upgrade(card)
 card.upgrades=(card.upgrades or(card.upgraded and 1 or 0))+1;card.upgraded=true
end
local function purge(run)return require('abyss_purge_candidates').purgeCards(run)end
local function selectTransform(run,card)
 local context=run.transformContext or require('abyss_event_transform_context').new(run)
 if not context or not context.cards[card.cardId]then return nil,'card_content_unavailable'end
 local from=context.cards[card.cardId]
 local offer,rng=require('abyss_transform_card').select(from.category,from.sourceId,context.pools,run.miscRng)
 if not offer then return nil,rng end
 local id=context.sourceToLocal[offer.cardId]
 if not require('abyss_card_capability').isImplemented(definition(run,id))then return nil,'card_content_unavailable'end
 run.miscRng=rng;return id
end
local function finishSelection(run,pending)
 local Run=require('abyss_run')
 for _,uid in ipairs(pending.selectedUids)do
  local card;for _,c in ipairs(run.deck)do if c.uid==uid then card=c;break end end
  if not card then return false,'invalid_card'end
  local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
  if pending.id=='astrolabe'then
   local id,reason=selectTransform(run,card);if not id then return false,reason end
   local d=definition(run,id)
   local upgraded=d.upgrade and next(d.upgrade)~=nil
   ok,why=Run.obtainCard(run,id,{upgraded=upgraded});if not ok then return false,why end
   for _,obtained in ipairs(run.deck)do if obtained.uid==why and obtained.upgraded then
    local Origin=require('abyss_card_origin')
    if not Origin.matches(obtained,obtained.lastUpgradeOrigin)then
     Origin.record(run,obtained,Origin.state({}),'obtained_upgraded',{kind='relic',relicId='astrolabe'})
    end
   end end
  end
 end
 run.pendingBossRelic=nil;return true
end
-- Public selection transaction: stale/duplicate/foreign UIDs refuse atomically.
function M.select(run,uid)
 return require('abyss_run').transaction(run,function(staged)
  local p=staged.pendingBossRelic
  if not p or p.kind~='cards'then return false,'no_pending_boss_selection'end
  local legal=false;for _,c in ipairs(purge(staged))do if c.uid==uid then legal=true;break end end
  if not legal or not p.selectionUids[uid]then return false,'invalid_card'end
  for _,old in ipairs(p.selectedUids)do if old==uid then return false,'invalid_card'end end
  p.selectedUids[#p.selectedUids+1]=uid
  if #p.selectedUids<p.total then return true,'choose_card'end
  return finishSelection(staged,p)
 end)
end
local function selection(run,id,total)
 local cards=purge(run)
 local p={id=id,kind='cards',total=math.min(total,#cards),selectedUids={},selectionUids={}}
 for _,c in ipairs(cards)do p.selectionUids[c.uid]=true end
 run.pendingBossRelic=p
 if #cards<=total then
  for _,c in ipairs(cards)do p.selectedUids[#p.selectedUids+1]=c.uid end
  return finishSelection(run,p)
 end
 return true,'choose_card'
end
local starterSources={Strike_R=true,Defend_R=true,Strike_G=true,Defend_G=true,Strike_B=true,Defend_B=true,Strike_P=true,Defend_P=true}
local function pandora(run)
 local context=run.transformContext or require('abyss_event_transform_context').new(run)
 if not context then return false,'card_content_unavailable'end
 local cards={};local count=0
 for _,c in ipairs(run.deck)do
  local source=context.cards[c.cardId]
  if source and starterSources[source.sourceId]then count=count+1 else cards[#cards+1]=c end
 end
 local pool={}
 for _,name in ipairs({'common','srcUncommon','srcRare'})do
  for _,source in ipairs(context.pools[name])do pool[#pool+1]=source end
 end
 if count>0 and #pool==0 then return false,'card_content_unavailable'end
 -- Source removes every starter directly before generating replacements. The
 -- selection uses cardRng (not misc), with replacement and without rarity rolls.
 run.deck=cards
 for _=1,count do
  local source=pool[R.randomInt(run.cardRng,#pool-1)+1]
  local id=context.sourceToLocal[source]
  if not id then return false,'card_content_unavailable'end
  local ok,why=require('abyss_run').obtainCard(run,id);if not ok then return false,why end
 end
 return true
end
local function bell(run)
 local Run=require('abyss_run')
 local curse
 for _,d in ipairs(run.data.cards.cards)do if d.sourceId=='CurseOfTheBell'or d.id=='curse_of_the_bell'then curse=d.id;break end end
 if not curse then return false,'card_content_unavailable'end
 local ok,why=Run.obtainCard(run,curse);if not ok then return false,why end
 local pending={id='calling_bell',kind='rewards',relics={}}
 for _,tier in ipairs({'common','uncommon','rare'})do
  local offer,pool=Run.prepareRelic(run,{tier=tier,screenless=true})
  if not offer then return false,pool end
  run.relicPool=pool;pending.relics[#pending.relics+1]=offer
 end
 run.pendingBossRelic=pending;return true,'rewards'
end
-- Rewards are independent claimable offers. Never grant all three implicitly.
function M.claimRelic(run,index)
 return require('abyss_run').transaction(run,function(staged)
  local p=staged.pendingBossRelic;local offer=p and p.kind=='rewards'and p.relics and p.relics[index]
  if not offer or offer.claimed then return false,'no_pending_relic_reward'end
  local ok,why=require('abyss_run').obtainRelic(staged,offer.id);if not ok then return false,why end
  staged.pendingBossRelic.relics[index].claimed=true;return true
 end)
end
function M.claim(run,kind,choice)
 if kind=='relic'then return M.claimRelic(run,choice)end
 return require('abyss_run').transaction(run,function(staged)
  local p=staged.pendingBossRelic
  if not p or p.kind~='rewards'then return false,'no_pending_boss_reward'end
  local Run=require('abyss_run')
  if kind=='gold'then
   if p.gold==nil or p.goldClaimed then return false,'no_pending_gold_reward'end
   Run.gainGold(staged,p.gold);p.goldClaimed=true
  elseif kind=='potion'then
   if not p.potion or p.potion.claimed then return false,'no_pending_potion_reward'end
   local ok,why=Run.obtainPotion(staged,p.potion.id);if not ok then return false,why end
   staged.pendingBossRelic.potion.claimed=true
  elseif kind=='card'then
   if choice=='bowl'then
    if not p.cards or p.cardResolved or not owns(staged,'singing_bowl')then return false,'no_pending_reward'end
    local ok,why=Run.increaseMaxHp(staged,2);if not ok then return false,why end
    staged.pendingBossRelic.cardResolved=true;return true
   end
   if not p.cards or p.cardResolved or type(choice)~='number'or choice%1~=0 or choice<0 or choice>#p.cards then
    return false,'invalid_reward_choice'
   end
   if choice>0 then
    local ok,why=Run.obtainCard(staged,p.cards[choice],{upgraded=p.cardUpgrades and p.cardUpgrades[choice]==true})
    if not ok then return false,why end
   end
   staged.pendingBossRelic.cardResolved=true
  elseif kind=='done'then staged.pendingBossRelic=nil
  else return false,'invalid_boss_reward'end
  return true
 end)
end
local function tinyHouse(run)
 local eligible={};for _,card in ipairs(run.deck)do if upgradeable(run,card)then eligible[#eligible+1]=card end end
 R.shuffle(run.miscRng,eligible);if #eligible>0 then
  local card=eligible[1];local before=require('abyss_card_origin').state(card)
  upgrade(card)
  require('abyss_card_origin').record(run,card,before,'permanent_upgrade',{kind='relic',relicId='tiny_house'})
 end
 local ok,why=require('abyss_run').increaseMaxHp(run,5);if not ok then return false,why end
 local Potions=require('abyss_potion_random')
 local pool=Potions.pool(Potions.character(run))
 local potion=pool[R.randomInt(run.miscRng,#pool-1)+1]
 local reward={id='tiny_house',kind='rewards',gold=50,goldClaimed=false,
  potion={id=potion.id,sourceId=potion.sourceId,claimed=false},relics={}}
 -- CombatRewardScreen.setupItemReward excludes TreasureRoom/RestRoom.
 -- BossTreasureRoom is a distinct room and does receive a normal card reward.
 local room=run.nodeFlow and run.nodeFlow.type
 if run.nodeFlow and run.nodeFlow.roomKind=='boss_treasure'then room='boss_treasure'end
 if room~='treasure'and room~='camp'then
  -- A historical boss encounter does not turn BossTreasureRoom's new card
  -- reward into the preceding MonsterRoomBoss rare-only reward.
  local owner={};for key,value in pairs(run)do owner[key]=value end
  if run.phase~='combat'then owner.encounterTier='normal'end
  local cards,rng,offset,upgrades=require('abyss_card_pool').prepareRewards(owner)
  run.cardRng,run.cardRarityOffset=rng,offset
  reward.cards,reward.cardUpgrades,reward.cardResolved=cards,upgrades,false
  require('abyss_relic_hooks').previewCardReward(run,reward,true)
 end
 run.pendingBossRelic=reward;return true,'rewards'
end
function M.onEquip(run,id)
 id=M.localId(id)
 local complex=id=='empty_cage'or id=='astrolabe'or id=='pandoras_box'or id=='calling_bell'or id=='tiny_house'
 if complex and run.pendingBossRelic then return false,'boss_relic_pending'end
 if id=='empty_cage'then return selection(run,id,2)
 elseif id=='astrolabe'then return selection(run,id,3)
 elseif id=='pandoras_box'then return pandora(run)
 elseif id=='calling_bell'then return bell(run)
 elseif id=='tiny_house'then return tinyHouse(run)
 end
 return true
end
return M
