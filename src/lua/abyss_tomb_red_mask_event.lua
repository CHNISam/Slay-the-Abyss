-- Fixed319009 TombRedMask: named SPECIAL obtain, direct gold, no RNG.
-- Nodes owns the whole event command transaction and map completion.
local Run=require('abyss_run')
local Relics=require('abyss_relic_hooks')
local M={}
local function integer(n)return type(n)=='number'and n%1==0 and n>=0 and n<=2147483647 end
local function row(choice,title,text,enabled)return {choice=choice,title=title,description=text,enabled=enabled~=false}end
function M.prepare(run,event)
 assert(run.act==3 and event.id=='tomb_red_mask','Tomb requires the third act')
 assert(integer(run.gold),'invalid Tomb gold')
 event.hasMask=Relics.owns(run,'red_mask')
 event.stage,event.body='intro','红面具领主的陵墓要求你证明身份。'
end
function M.options(run,event)
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='intro'then return {}end
 if event.hasMask then return {
  row('wear','戴上红面具','保留红面具，获得222金币。'..(Relics.owns(run,'ectoplasm')and'当前遗物阻止获得金币。'or'')),
  row('leave','离开','不领取金币，继续前进。')}end
 return {row('wear','戴上红面具','需要红面具（未持有）。',false),
  row('pay','献出全部金币','失去当前全部'..string.format('%.0f',run.gold)..'金币，获得红面具；0金币也可以。'),
  row('leave','离开','保留金币，继续前进。')}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.id~='tomb_red_mask'or run.act~=3 or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'then
  if choice~='leave'then return false,'invalid_event_choice'end
  return true,'complete'
 end
 if event.stage~='intro'then return false,'invalid_event_choice'end
 if choice=='wear'then
  if not event.hasMask or not Relics.owns(run,'red_mask')then return false,'event_condition_unmet'end
  local gained=Run.gainGold(run,222);assert(integer(gained),'invalid Tomb gold gain')
  event.goldGained=gained;event.body='你保留了红面具，获得'..gained..'金币。'
 elseif choice=='pay'then
  if event.hasMask or Relics.owns(run,'red_mask')then return false,'event_condition_unmet'end
  if not integer(run.gold)then return false,'invalid_event_gold'end
  local paid=run.gold
  -- AbstractPlayer.loseGold dispatches onSpendGold only in ShopRoom. No
  -- fixed-source relic overrides onLoseGold; zero still obtains the mask.
  run.gold=0
  local ok,why=Run.obtainRelic(run,'red_mask');if not ok then return false,why end
  event.goldPaid,event.obtainedRelicId=paid,'red_mask'
  event.body='你献出了'..paid..'金币，获得红面具。'
 elseif choice=='leave'then
  event.stage,event.body='result','你没有取走陵墓中的东西。';return true,'complete'
 else return false,'invalid_event_choice'end
 event.stage='result';return true,'pending'
end
return M
