-- GoldenIdolEvent PC A0 fixed319009. Actual obtain precedes the trap choice.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local M={}
local function owned(run,id)for _,held in ipairs(run.relics)do if held==id then return true end end;return false end
local function row(choice,title,text,card)return {choice=choice,title=title,description=text,cardId=card,enabled=true}end
function M.prepare(run,event)
 assert((run.act or 1)==1,'Golden Idol event requires act1')
 assert(type(run.maxHp)=='number' and run.maxHp%1==0 and run.maxHp>=1 and run.maxHp<=2147483647,'invalid Golden Idol health')
 event.damage=math.floor(R.float32(R.float32(run.maxHp)*R.float32(.25)))
 event.maxHpLoss=math.max(1,math.floor(R.float32(R.float32(run.maxHp)*R.float32(.08))))
 event.stage,event.body='intro','石台上的Golden Idol似乎可以拿走。'
end
function M.options(run,event)
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage=='intro'then return {
  row('take','拿取 Golden Idol',owned(run,'golden_idol')and'已持有时获得Circlet；随后必须选择陷阱代价。'or'获得Golden Idol；随后必须选择陷阱代价。'),
  row('leave','离开','不拿取遗物。')}end
 if event.stage~='trap'then return {}end
 return {row('injury','承受 Injury','获得Injury。','injury'),
  row('damage','承受伤害','受到'..event.damage..'点普通伤害。'),
  row('max_hp','牺牲最大生命','失去'..event.maxHpLoss..'点最大生命（'..string.format('%.0f',run.maxHp)..' → '..string.format('%.0f',math.max(1,run.maxHp-event.maxHpLoss))..'），不治疗。')}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if uid~=nil or (run.act or 1)~=1 then return false,'invalid_event_choice'end
 if event.stage=='result'then
  if choice~='leave'then return false,'invalid_event_choice'end
  return true,'complete'
 end
 if event.stage=='intro'then
  if choice=='leave'then event.stage,event.body='result','你没有拿走遗物。';return true,'pending'end
  if choice~='take'then return false,'invalid_event_choice'end
  local id=owned(run,'golden_idol')and'circlet'or'golden_idol'
  local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
  event.obtainedRelicId,event.stage,event.body=id,'trap','遗物已经到手；巨石滚来，必须选择代价。'
  return true,'pending'
 end
 if event.stage~='trap'then return false,'invalid_event_choice'end
 if type(run.maxHp)~='number' or run.maxHp%1~=0 or run.maxHp<1 or run.maxHp>2147483647
  or type(run.hp)~='number' or run.hp%1~=0 or run.hp<=0 or run.hp>run.maxHp then return false,'invalid_event_health'end
 if choice=='injury'then
  if owned(run,'darkstone_periapt')then return false,'event_obtain_content_unavailable'end
  local ok,obtained=Run.obtainCard(run,'injury');if not ok then return false,obtained end
  event.obtainedCardUid=type(obtained)=='number' and obtained or nil;event.curseBlocked=obtained=='curse_blocked'
  event.body=event.curseBlocked and'Omamori阻止了Injury。'or'你获得了Injury。'
 elseif choice=='damage'then
  local ok,why=Run.eventNormalDamage(run,event.damage);if not ok then return false,why end
  event.body='你承受了陷阱的伤害。'
 elseif choice=='max_hp'then
  run.maxHp=math.max(1,run.maxHp-event.maxHpLoss);run.hp=math.min(run.hp,run.maxHp)
  event.body='你失去了'..event.maxHpLoss..'点最大生命，没有获得治疗。'
 else return false,'invalid_event_choice'end
 event.stage='result';return true,'pending'
end
return M
