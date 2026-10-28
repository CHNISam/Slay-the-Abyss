-- Nest PC A0 behavior, pinned community mirror aeubanks/sts@319009d5.
-- Nodes owns the enclosing transaction and the final fatal-health transition.
local Run=require('abyss_run')
local M={}
local function row(choice,title,description,card)
 return {choice=choice,title=title,description=description,enabled=true,cardId=card}
end
function M.prepare(_,event)
 event.stage,event.body='intro','你来到一处隐秘的巢穴，里面传来低声吟唱。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','继续','走近查看。')}end
 if event.stage=='choice'then
  return {row('gold','拿走金币','获得99金币。'),
   row('dagger','加入仪式','受到6点普通伤害，获得「仪式匕首」。','ritual_dagger')}
 end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 return {}
end
local function dagger(run,event)
 -- Construct the fresh card before damage, but defer every permanent obtain
 -- callback and UID allocation until after damage and possible Fairy revival.
 local offer,why=Run.prepareCard(run,'ritual_dagger')
 if not offer then return false,why end
 local ok,lost=Run.eventNormalDamage(run,6)
 if not ok then return false,lost end
 -- Source creates the obtain effect even after fatal damage; no early return.
 local uid;ok,uid=Run.commitCard(run,offer)
 if not ok then return false,uid end
 if type(uid)~='number'then return false,'invalid_ritual_dagger_obtain'end
 event.hpLost,event.obtainedCardUid=lost,uid
 event.body='仪式结束，你获得了一把「仪式匕首」。'
 return true
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='intro' and choice=='continue'then
  event.stage,event.body='choice','你看见祭坛旁的金币，也收到加入仪式的邀请。'
  return true,'pending'
 end
 if event.stage=='result' and choice=='leave'then return true,'complete'end
 if event.stage~='choice'then return false,'invalid_event_choice'end
 if choice=='gold'then
  event.goldGained=Run.gainGold(run,99)
  event.body='你拿走了'..event.goldGained..'枚金币，准备离开。'
 elseif choice=='dagger'then
  local ok,why=dagger(run,event);if not ok then return false,why end
 else return false,'invalid_event_choice'end
 event.choice,event.stage=choice,'result'
 return true,'pending'
end
return M
