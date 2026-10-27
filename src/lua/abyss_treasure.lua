-- Independently implemented chest contracts from the pinned STS1 319009d5
-- AbstractDungeon / AbstractChest / BossChest / AbstractRoom and relic hooks.
-- Preparation never mutates its Run. Publish all owners in one node transaction.
local R=require('abyss_sts_random')
local Pool=require('abyss_relic_pool')
local M={}
local chestRules={small={common=75,uncommon=100,goldChance=50,goldAmount=25},
 medium={common=35,uncommon=85,goldChance=35,goldAmount=50},
 large={common=0,uncommon=75,goldChance=50,goldAmount=75}}
local sourceAliases={burning_blood='Burning Blood',anchor='Anchor',vajra='Vajra',
 bag_of_preparation='Bag of Preparation',lantern='Lantern',oddly_smooth_stone='Oddly Smooth Stone',
 bronze_scales='Bronze Scales',membership_card='Membership Card',courier='The Courier',
 smiling_mask='Smiling Mask',black_blood='Black Blood',slavers_collar='SlaversCollar',sozu='Sozu',
 matryoshka='Matryoshka',nloths_mask='NlothsMask',cursed_key='Cursed Key'}
local curseOrder={'Regret','Injury','Shame','Parasite','Normality','Doubt','Writhe','Pain','Decay','Clumsy'}
local function copy(value)
 if type(value)~='table' then return value end
 local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
end
local function definition(run,id)
 for _,entry in ipairs(run.data.relics.relics)do
  if entry.id==id or entry.sourceId==id or sourceAliases[entry.id]==id then return entry end
 end
end
local function sourceId(run,id)
 local entry=definition(run,id)
 return entry and (entry.sourceId or sourceAliases[entry.id] or entry.id) or sourceAliases[id] or id
end
local function validRoll(roll)
 assert(type(roll)=='number' and roll%1==0 and roll>=0 and roll<=99,'invalid chest roll')
end
function M.kind(roll,act)
 validRoll(roll);assert(act==1 or act==2 or act==3 or act==4,'invalid chest act')
 if act==4 then return 'medium' end
 return roll<50 and 'small' or roll<83 and 'medium' or 'large'
end
function M.rewardRule(kind,roll)
 validRoll(roll);local rule=assert(chestRules[kind],'invalid chest kind')
 return roll<rule.common and 'common' or roll<rule.uncommon and 'uncommon' or 'rare',
  roll<rule.goldChance,rule.goldAmount
end
local function context(run,options)
 local owned,deck={},{}
 for _,id in ipairs(run.relics)do owned[#owned+1]=sourceId(run,id)end
 for _,card in ipairs(run.deck)do
  for _,entry in ipairs(run.data.cards.cards)do
   if entry.id==card.cardId then deck[#deck+1]={type=entry.type:upper(),rarity=entry.rarity:upper()};break end
  end
 end
 return {act=run.act or 1,floor=options.floor or run.floor,room='treasure',owned=owned,deck=deck,endless=false}
end
local function addItem(prepared,item)
 prepared.nextSlot=prepared.nextSlot+1;item.slot=prepared.nextSlot
 prepared.reward.items[#prepared.reward.items+1]=item;return item
end
local function addRelic(run,prepared,tier,where)
 local id,trace,requested=Pool.draw(prepared.relicPool,tier,prepared.context)
 local entry=definition(run,id)
 return addItem(prepared,{kind='relic',id=entry and entry.id or id,sourceId=id,
  requestedId=requested,tier=tier,available=entry~=nil,trace=trace,origin=where})
end
local function counter(prepared,localId,source,initial)
 local value=prepared.relicCounters[localId]
 if value==nil then value=prepared.relicCounters[source] end
 if value==nil then value=initial end
 assert(type(value)=='number' and value%1==0 and value>=-2 and value<=initial,'invalid chest relic counter')
 return value
end
local function curse(prepared,source)
 local index=R.randomIntBetween(prepared.cardRng,0,#curseOrder-1)+1
 prepared.curseSourceIds[#prepared.curseSourceIds+1]=curseOrder[index]
 prepared.hookTrace[#prepared.hookTrace+1]={hook='onChestOpen',sourceId=source,curse=curseOrder[index]}
end
local function beforeOpen(run,prepared,boss)
 for _,held in ipairs(run.relics)do
  local id=sourceId(run,held)
  if id=='Matryoshka' and not boss then
   local remaining=counter(prepared,held,id,2)
   if remaining>0 then
    remaining=remaining-1;prepared.relicCounters[held]=remaining==0 and -2 or remaining
    local tier=R.randomBooleanChance(prepared.relicPool.rng,.75) and 'common' or 'uncommon'
    prepared.hookTrace[#prepared.hookTrace+1]={hook='onChestOpen',sourceId=id,tier=tier}
    addRelic(run,prepared,tier,'matryoshka')
   end
  elseif id=='Cursed Key' and not boss then curse(prepared,id) end
 end
end
local function afterOpen(run,prepared)
 for _,held in ipairs(run.relics)do
  local id=sourceId(run,held)
  if id=='NlothsMask' then
   local remaining=counter(prepared,held,id,1)
   if remaining>0 then
    prepared.relicCounters[held]=-2
    for index,item in ipairs(prepared.reward.items)do
     if item.kind=='relic' then
      table.remove(prepared.reward.items,index)
      local following=prepared.reward.items[index]
      if following and following.slot==item.linkedSlot then table.remove(prepared.reward.items,index) end
      prepared.hookTrace[#prepared.hookTrace+1]={hook='onChestOpenAfter',sourceId=id,removedSlot=item.slot}
      break
     end
    end
   end
  end
 end
end
local function summaries(prepared)
 local reward={items=prepared.reward.items};prepared.reward=reward
 for _,item in ipairs(reward.items)do
  if item.kind=='gold' then reward.gold=item.amount
  elseif item.kind=='relic' then
   if item.origin=='base' then
    reward.relicId,reward.relicSourceId,reward.relicUnavailable=item.id,item.sourceId,not item.available
   elseif item.origin=='boss' then
    reward.relics=reward.relics or {};reward.relics[#reward.relics+1]=item.id
   else reward.extraRelics=reward.extraRelics or {};reward.extraRelics[#reward.extraRelics+1]=item end
  elseif item.kind=='sapphire' then
   reward.sapphireKey={relicId=item.relicId,linkedSlot=item.linkedSlot,slot=item.slot}
  end
 end
end
local function owners(run,options)
 options=options or {};assert(type(options)=='table','invalid chest options')
 assert(options.boss==nil or type(options.boss)=='boolean','invalid boss chest option')
 if not run.relicPool then return nil,'relic_pool_unavailable' end
 return {treasureRng=R.cloneState(run.treasureRng),
  relicPool=Pool.restore(Pool.snapshot(run.relicPool),run.relicPool.catalog),
  cardRng=R.cloneState(run.cardRng),relicCounters=copy(run.relicCounters or {}),
  curseSourceIds={},hookTrace={},reward={items={}},nextSlot=0,context=context(run,options)}
end
local function finished(prepared)
 summaries(prepared);prepared.context,prepared.nextSlot=nil,nil
 prepared.curseObtainCount=#prepared.curseSourceIds
 return prepared
end
-- Entering TreasureRoom constructs the chest but does not open it. The player
-- can leave here, avoiding Cursed Key and spending no opening/gold/relic draw.
function M.create(run,options)
 options=options or {};local prepared,reason=owners(run,options);if not prepared then return nil,reason end
 if options.boss then
  prepared.chest={kind='boss',opened=false}
  for _=1,3 do addRelic(run,prepared,'boss','boss')end
 else
  local kindRoll=R.randomIntBetween(prepared.treasureRng,0,99)
  local kind=M.kind(kindRoll,run.act or 1)
  local rewardRoll=R.randomIntBetween(prepared.treasureRng,0,99)
  local tier,hasGold=M.rewardRule(kind,rewardRoll)
  prepared.chest={kind=kind,kindRoll=kindRoll,rewardRoll=rewardRoll,relicTier=tier,goldReward=hasGold,opened=false}
 end
 return finished(prepared)
end
-- Normal PC A0, no Daily/Endless/custom modifiers. Missing definitions retain
-- unavailable SOURCE identities; never filter/retry them. Apply curseSourceIds
-- with the permanent-card API before committing any prepared owner.
function M.open(run,chest,reward)
 assert(type(chest)=='table' and getmetatable(chest)==nil,'invalid chest')
 if chest.opened~=false then return nil,'chest_already_open' end
 local prepared,reason=owners(run,{});if not prepared then return nil,reason end
 prepared.chest=copy(chest);prepared.chest.opened=true
 if chest.kind=='boss' then
  assert(type(reward)=='table' and type(reward.items)=='table' and #reward.items==3,'invalid boss rewards')
  prepared.reward=copy(reward)
  beforeOpen(run,prepared,true) -- BossChest excludes Matryoshka and has no after-hook.
 else
  local tier,hasGold,goldAmount=M.rewardRule(chest.kind,chest.rewardRoll)
  assert(tier==chest.relicTier and hasGold==chest.goldReward,'invalid chest reward rule')
  beforeOpen(run,prepared,false)
  if hasGold then
   local gold=R.randomFloatBetween(prepared.treasureRng,R.float32(goldAmount*R.float32(.9)),R.float32(goldAmount*R.float32(1.1)))
   addItem(prepared,{kind='gold',amount=math.floor(gold+.5)})
  end
  local base=addRelic(run,prepared,tier,'base')
  if run.campaign==true and run.endingUnlocked==true then
   assert(type(run.keys)=='table' and type(run.keys.ruby)=='boolean' and type(run.keys.emerald)=='boolean'
    and type(run.keys.sapphire)=='boolean','invalid ending keys')
  end
  if run.campaign==true and run.endingUnlocked==true and run.keys.sapphire==false then
   local key=addItem(prepared,{kind='sapphire',relicId=base.id,linkedSlot=base.slot})
   base.linkedSlot=key.slot
  end
  afterOpen(run,prepared)
 end
 return finished(prepared)
end
-- Combined helper for source-vector comparisons. The normal node/UI must call
-- create at entry and open only after the explicit opening command.
function M.prepare(run,options)
 local created,reason=M.create(run,options);if not created then return nil,reason end
 local staged={};for key,value in pairs(run)do staged[key]=value end
 for _,key in ipairs({'treasureRng','relicPool','cardRng','relicCounters'})do staged[key]=created[key]end
 return M.open(staged,created.chest,created.reward)
end
-- Stage removal before the caller applies obtain/gold/key effects in its Run
-- transaction. Slots survive other claims/removals; equal IDs are not owners.
function M.take(reward,slot)
 if type(reward)~='table' or type(reward.items)~='table' or type(slot)~='number'
  or slot%1~=0 or slot<1 then return nil,'invalid_treasure_reward' end
 local item
 for _,candidate in ipairs(reward.items)do if candidate.slot==slot then item=candidate;break end end
 if not item then return nil,'treasure_reward_unavailable' end
 if item.kind=='relic' and item.available~=true then return nil,'relic_content_unavailable' end
 if item.kind~='relic' and item.kind~='gold' and item.kind~='sapphire' then return nil,'invalid_treasure_reward' end
 local linked
 if item.linkedSlot then
  for _,candidate in ipairs(reward.items)do if candidate.slot==item.linkedSlot then linked=candidate;break end end
  if not linked or linked.linkedSlot~=slot or (item.kind=='sapphire' and linked.kind~='relic')
   or (item.kind=='relic' and linked.kind~='sapphire') then return nil,'invalid_treasure_link' end
 end
 local prepared={reward={items={}}}
 for _,candidate in ipairs(reward.items)do
  if candidate.slot~=slot and candidate~=linked then prepared.reward.items[#prepared.reward.items+1]=copy(candidate) end
 end
 summaries(prepared)
 return {item=copy(item),reward=prepared.reward}
end
return M
