-- Independent A0 reducer derived from DeadAdventurer @ sts 319009d5.
-- Nodes owns each command: rejected rewards/constructors roll back its RNG too.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Gold=require('abyss_gold_rewards')
local M={}
local sources={'3 Sentries','Gremlin Nob','Lagavulin Event'}
local clues={'三名符文哨卫','怒焰巨魔','苏醒的深渊潜伏者'}
local function row(choice,title,description)return {choice=choice,title=title,description=description,enabled=true}end
function M.prepare(run,event,misc,floor)
 floor=floor or run.floor
 assert((run.act or 1)==1 and floor>6,'Dead Adventurer requires floor > 6 in act1')
 event.rewardOrder={'GOLD','NOTHING','RELIC'};R.shuffle(misc or run.miscRng,event.rewardOrder)
 event.enemy=R.randomIntBetween(misc or run.miscRng,0,2)+1
 event.encounterChance,event.numRewards=25,0
 event.encounterHint=sources[event.enemy]
 event.stage,event.body='intro','一位冒险者倒在通道旁。现场的痕迹指向'..clues[event.enemy]..'；搜寻可能惊动它们。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('search','搜寻','发现敌人的概率为'..event.encounterChance..'%。'),row('leave','离开','停止搜寻。')}end
 if event.stage=='fail'then return {row('fight','战斗','敌人出现了，无法继续搜寻。')}end
 if event.stage=='success'or event.stage=='escape'then return {row('leave','离开','返回路线。')}end
 return {}
end
local function search(run,event)
 if R.randomIntBetween(run.miscRng,0,99)<event.encounterChance then
  event.encounterGold=R.randomIntBetween(run.miscRng,25,35)
  event.encounterGoldOffer=Gold.offerAmount(event.encounterGold,run)
  local prepared,why=Run.prepareEventEncounter(run,sources[event.enemy],run.floor)
  if not prepared then return false,why end
  event.preparedCombat=prepared;event.stage,event.body='fail','搜寻声惊动了附近的敌人。'
  return true,'pending'
 end
 local reward=table.remove(event.rewardOrder,1)
 event.numRewards=event.numRewards+1;event.encounterChance=event.encounterChance+25
 if reward=='GOLD'then Run.gainGold(run,30);event.body='你找到了30金币。'
 elseif reward=='RELIC'then
  local offer,pool=Run.prepareRelic(run,{channel='event',screenless=true,room='event'})
  if not offer then return false,pool end
  local ok,why=Run.obtainRelic(run,offer.id);if not ok then return false,why end
  run.relicPool=pool;event.obtainedRelicId=offer.id;event.body='你找到并获得了一件遗物。'
 elseif reward=='NOTHING'then event.body='这次搜寻没有发现物品。'
 else return false,'event_reward_mismatch'end
 if event.numRewards==3 then event.stage,event.body='success','你已搜完所有物品。'end
 return true,'pending'
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.id~='dead_adventurer'or (run.act or 1)~=1 or run.floor<=6 or uid~=nil then return false,'invalid_event_choice'end
 if (event.stage=='escape'or event.stage=='success')and choice=='leave'then return true,'complete'end
 if event.stage=='intro'then
  if choice=='leave'then event.stage,event.body='escape','你停止搜寻，准备离开。';return true,'pending'end
  if choice=='search'then return search(run,event)end
 elseif event.stage=='fail'and choice=='fight'then
  event.combatRequest={sourceEncounter=sources[event.enemy],roomClass='event',route='dead_adventurer'}
  event.stage='combat';return true,'event_combat'
 end
 return false,'invalid_event_choice'
end
return M
