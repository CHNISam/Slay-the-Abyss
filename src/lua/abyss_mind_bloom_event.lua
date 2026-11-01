-- Fixed319009 MindBloom. Nodes owns the whole event transaction/combat bridge.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local M={}
local function rich(run)return run.floor%50<=40 end
local function row(choice,title,description)
 return {choice=choice,title=title,description=description,enabled=true}
end
function M.prepare(run,event)
 assert(run.act==3 and event.id=='mind_bloom','Mind Bloom requires the third act')
 assert(type(run.floor)=='number'and run.floor%1==0 and run.floor>=0,'invalid Mind Bloom floor')
 event.stage,event.body='intro','意识在高塔深处展开。你可以选择战争、觉醒，或改变眼前的处境。'
end
function M.options(run,event)
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='intro'then return {}end
 local rows={row('fight','挑战首领','挑战随机一名第一幕首领，获得50金币和一件稀有遗物，另有普通事件战后奖励。'),
  row('awake','全部升级','每张可升级卡牌升级一次，获得绽放印记；此后无法回复生命。')}
 rows[3]=rich(run)and row('rich','获得财富','获得999金币，并尝试获得两张平庸诅咒。')
  or row('healthy','恢复健康','回复至最大生命，并尝试获得一张疑惧诅咒。')
 return rows
end
local function fight(run,event)
 local bosses={'The Guardian','Hexaghost','Slime Boss'}
 Random.shuffle(run.miscRng,bosses)
 event.combatRequest={sourceEncounter=bosses[1],roomClass='event',gold=50,relicTier='rare',metric='Mind Bloom Boss Battle'}
 event.stage,event.body='fight','意识中的首领现身了。'
 return true,'event_combat'
end
local function awake(run,event)
 if type(Run.canUpgradeCard)~='function'or type(Run.upgradeCard)~='function'then return false,'event_upgrade_content_unavailable'end
 local upgraded={}
 for _,card in ipairs(run.deck)do
  local can,reason=Run.canUpgradeCard(run,card.uid)
  if can then
   local ok,why=Run.upgradeCard(run,card.uid);if not ok then return false,why end
   upgraded[#upgraded+1]=card.uid
  elseif reason and reason~='card_not_upgradeable'then return false,reason end
 end
 local ok,why=Run.obtainRelic(run,'mark_of_bloom');if not ok then return false,why end
 event.upgradedUids,event.obtainedRelicId=upgraded,'mark_of_bloom'
 event.body='所有可升级的卡牌已各升级一次。绽放印记封住了此后的生命回复。'
 return true,'pending'
end
local function fortune(run,event)
 event.goldGained=Run.gainGold(run,999)
 for _=1,2 do
  local ok,why=Run.obtainCard(run,'normality');if not ok then return false,why end
 end
 event.body='你获得'..event.goldGained..'金币，并分别尝试获得两张平庸诅咒。'
 return true,'pending'
end
local function healthy(run,event)
 event.healed=Run.heal(run,run.maxHp)
 local ok,why=Run.obtainCard(run,'doubt');if not ok then return false,why end
 event.body='你回复'..event.healed..'点生命，并尝试获得一张疑惧诅咒。'
 return true,'pending'
end
local choices={awake=awake,rich=fortune,healthy=healthy}
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.id~='mind_bloom'or run.act~=3 or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage~='intro'then return false,'invalid_event_choice'end
 if choice=='fight'then return fight(run,event)end
 if choice=='rich'and not rich(run)or choice=='healthy'and rich(run)then return false,'event_condition_unmet'end
 local apply=choices[choice];if not apply then return false,'invalid_event_choice'end
 local ok,why=apply(run,event);if not ok then return false,why end
 event.stage='result';return true,why
end
return M
