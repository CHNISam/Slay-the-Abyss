-- FaceTrader at fixed STS319009d5. No normal relic-pool draw or tier roll.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local M={}
local faces={'CultistMask','FaceOfCleric','GremlinMask','NlothsMask','SsserpentHead'}
local function owns(run,sourceId)
 for _,id in ipairs(run.relics)do
  if id==sourceId then return true end
  for _,d in ipairs(run.data.relics.relics)do if d.id==id and d.sourceId==sourceId then return true end end
 end
 return false
end
local function row(choice,title,description)return {choice=choice,title=title,description=description,enabled=true}end
function M.prepare(run,event)
 event.damage=math.max(1,math.floor(run.maxHp/10))
 event.goldReward,event.stage,event.body=75,'intro','一位没有面孔的商人向你招手。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','接近','听听商人的提议。')}end
 if event.stage=='choice'then return {
  row('touch','触摸','获得75金币，然后受到'..event.damage..'点伤害。'),
  row('trade','交易','随机获得一张未持有的面孔遗物；全部持有时获得圆环。'),row('leave','离开','拒绝商人的提议。')}end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 return {}
end
local function trade(run,event)
 local ids={}
 for _,id in ipairs(faces)do if not owns(run,id)then ids[#ids+1]=id end end
 if #ids==0 then ids[1]='Circlet'end
 -- Collections.shuffle(..., new Random(miscRng.randomLong())) consumes
 -- one misc draw even for the singleton Circlet list. Never capability-filter.
 R.shuffle(run.miscRng,ids)
 local ok,id=Run.obtainRelic(run,ids[1]);if not ok then return false,id end
 event.obtainedRelicId,event.obtainedSourceId=id,ids[1]
 return true
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage=='intro'and choice=='continue'then event.stage,event.body='choice','商人提出了两笔交易。';return true,'pending'end
 if event.stage~='choice'then return false,'invalid_event_choice'end
 if choice=='touch'then
  -- Gain gold precedes NORMAL damage, including Ectoplasm/Tungsten/Fairy.
  event.goldGained=Run.gainGold(run,event.goldReward)
  local ok,lost=Run.eventNormalDamage(run,event.damage);if not ok then return false,lost end
  event.hpLost=lost
 elseif choice=='trade'then local ok,why=trade(run,event);if not ok then return false,why end
 elseif choice~='leave'then return false,'invalid_event_choice'end
 event.choice,event.stage,event.body=choice,'result','商人收回了双手，交易结束了。'
 return true,'pending'
end
return M
