-- Independent PC A0 mechanism from aeubanks/sts@319009d5 KnowingSkull.
-- Each Nodes command owns cost, RNG, permanent obtain and fatal settlement.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
local P=require('abyss_potion_random')
local Hooks=require('abyss_relic_hooks')
local Capability=require('abyss_card_capability')
local M={}
local function row(choice,title,description)
 return {choice=choice,title=title,description=description,enabled=true}
end
function M.prepare(_,event)
 event.stage,event.body='intro','石隙中传来回声，邀请你以生命换取馈赠。'
 event.potionCost,event.goldCost,event.cardCost,event.leaveCost=6,6,6,6
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','倾听','听清回声提出的交易。')}end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='ask'then return {}end
 return {row('potion','索取药水','失去'..event.potionCost..'点生命，获得随机药水；满槽时药水丢失。'),
  row('gold','索取金币','失去'..event.goldCost..'点生命，获得90金币。'),
  row('card','索取卡牌','失去'..event.cardCost..'点生命，获得随机罕见无色牌。'),
  row('leave','请求离开','失去'..event.leaveCost..'点生命，结束交易。')}
end
local function potion(run,event)
 event.lastPotionId,event.potionLost,event.potionBlocked=nil,false,false
 if Hooks.owns(run,'sozu')then event.potionBlocked=true;return true end
 local pool=P.pool(P.character(run))
 -- PotionHelper.getRandomPotion() uses the persistent uniform class stream.
 local rng=run.shopRng and R.cloneState(run.shopRng.potion)or R.fromSeed(run.eventSeed)
 local selected=pool[R.randomIntBetween(rng,0,#pool-1)+1]
 local ok,why=Run.obtainPotion(run,selected.id)
 -- Source ignores only a full inventory. Unknown content/other failures abort.
 if not ok and why~='potion_slots_full'then return false,why end
 run.shopRng=run.shopRng or {merchant=R.fromSeed(run.eventSeed)}
 run.shopRng.potion=rng
 event.lastPotionId,event.potionLost=selected.id,not ok
 return true
end
local function colorlessPool(run)
 local source=run.data.cards.sourcePools
 if not source or type(source.colorlessRaw)~='table'or #source.colorlessRaw~=35
  or type(source.cardSourceMetadata)~='table'then return nil,'skull_source_pool_unavailable'end
 local owner=run.colorlessCardPool
 if not owner or owner.act~=(run.act or 1)then
  owner={act=run.act or 1,cards=Copy(source.colorlessRaw)};run.colorlessCardPool=owner
 end
 if type(owner.cards)~='table'or #owner.cards~=35 then return nil,'skull_source_pool_unavailable'end
 local seen={}
 for _,id in ipairs(owner.cards)do
  local fact=source.cardSourceMetadata[id]
  if seen[id]or not fact or(fact.rarity~='uncommon'and fact.rarity~='rare')then return nil,'skull_source_pool_unavailable'end
  seen[id]=true
 end
 for _,id in ipairs(source.colorlessRaw)do if not seen[id]then return nil,'skull_source_pool_unavailable'end end
 return owner.cards,source.cardSourceMetadata
end
local function card(run,event)
 local pool,metadata=colorlessPool(run);if not pool then return false,metadata end
 event.shuffleRng=event.shuffleRng or Run.roomStreams(run,run.floor).shuffleRng
 R.shuffle(event.shuffleRng,pool)
 local selected
 for _,id in ipairs(pool)do if metadata[id].rarity=='uncommon'then selected=id;break end end
 if not selected then return false,'skull_source_pool_unavailable'end
 local definition
 for _,d in ipairs(run.data.cards.cards)do if d.id==selected then definition=d;break end end
 if not Capability.isImplemented(definition)or definition.color~='colorless'or definition.rarity~='uncommon'
  or(definition.sourceId or definition.sts_name or definition.id)~=metadata[selected].sourceId then
  return false,'card_content_unavailable'
 end
 local ok,uid=Run.obtainCard(run,selected);if not ok then return false,uid end
 event.obtainedCardUid=uid
 return true
end
local function reward(run,event,choice)
 if choice=='potion'then return potion(run,event)end
 if choice=='card'then return card(run,event)end
 event.goldGained=Run.gainGold(run,90);return true
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if uid~=nil or type(choice)~='string'then return false,'invalid_event_choice'end
 if event.stage=='intro'and choice=='continue'then
  event.stage,event.body='ask','每项馈赠都要付出生命；重复索取同项，代价将逐次增加。'
  return true,'pending'
 end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage~='ask'or(choice~='potion'and choice~='gold'and choice~='card'and choice~='leave')then
  return false,'invalid_event_choice'
 end
 local key=choice..'Cost';local cost=event[key]
 if type(cost)~='number'or cost%1~=0 or cost<6 or cost>=2147483647 then return false,'invalid_skull_cost'end
 local ok,lost=Run.eventDamage(run,cost);if not ok then return false,lost end
 event.hpLost=lost
 if choice=='leave'then
  event.stage,event.body='result','回声渐渐消散。你可以继续前行。'
 else
  event[key]=cost+1
  -- Reward still resolves after lethal damage, including consumed Fairy reserve.
  local why;ok,why=reward(run,event,choice);if not ok then return false,why end
  event.body='回声回应了你的请求。你还要继续交换吗？'
 end
 return true,'pending'
end
return M
