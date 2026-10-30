-- N'loth at fixed STS319009d5: all owned relics are candidates, no filter.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local M={}
local function definition(run,id)
 for _,d in ipairs(run.data.relics.relics)do if d.id==id or d.sourceId==id then return d end end
end
local function owns(run,sourceId)
 for _,id in ipairs(run.relics)do local d=definition(run,id);if id==sourceId or d and d.sourceId==sourceId then return true end end
 return false
end
local function row(choice,title,description,relic)
 return {choice=choice,title=title,description=description,enabled=true,relicId=relic}
end
function M.prepare(run,event,rng)
 local relics={};for i,id in ipairs(run.relics)do relics[i]=id end
 assert(#relics>=2,"N'loth requires two relics")
 R.shuffle(rng or run.miscRng,relics)
 event.relicChoices={relics[1],relics[2]}
 event.stage,event.body='intro',"N'loth指着你随身的两件遗物，提出交换。"
end
function M.options(run,event)
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='intro'then return {}end
 local rows={}
 local repeated=owns(run,"Nloth's Gift")
 for i,id in ipairs(event.relicChoices)do
  local d=definition(run,id)
  local description=repeated and '已经持有礼物：获得圆环，不失去所示遗物。'or"交出所示遗物，获得N'loth的礼物。"
  rows[i]=row('trade_'..i,'选择'..(d and d.name or id),description,id)
 end
 rows[3]=row('leave','离开','拒绝交易。');return rows
end
local function trade(run,event,index)
 local selected=event.relicChoices[index]
 local d=selected and definition(run,selected)
 if not selected or not owns(run,d and d.sourceId or selected)then return false,'event_condition_unmet'end
 local gift="Nloth's Gift"
 if owns(run,gift)then
  -- Source deliberately DOES NOT remove the offered relic in this branch.
  gift='Circlet'
 else
  if type(Run.loseRelic)~='function'then return false,'relic_removal_content_unavailable'end
  local ok,why=Run.loseRelic(run,selected);if not ok then return false,why end
  event.removedRelicId=selected
 end
 local ok,id=Run.obtainRelic(run,gift);if not ok then return false,id end
 event.obtainedRelicId,event.obtainedSourceId=id,gift
 return true
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage~='intro'then return false,'invalid_event_choice'end
 if choice~='leave'then
  local index=choice=='trade_1'and 1 or choice=='trade_2'and 2
  if not index then return false,'invalid_event_choice'end
  local ok,why=trade(run,event,index);if not ok then return false,why end
 end
 event.choice,event.stage,event.body=choice,'result',"N'loth转过身去，交易结束了。"
 return true,'pending'
end
return M
