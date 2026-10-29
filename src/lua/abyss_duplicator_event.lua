-- Duplicator behavior: pinned community mirror aeubanks/sts@319009d5.
-- Independent Lua implementation; Nodes owns the enclosing room transaction.
local Run=require('abyss_run')
local Copy=require('abyss_combat').copy
local M={}
local function row(choice,title,description,enabled)
 return {choice=choice,title=title,description=description,enabled=enabled~=false}
end
function M.prepare(_,event)
 event.stage,event.body='intro','石龛映出牌组的轮廓，一道微光正等待你留下拓印。'
end
function M.cards(run)return Copy(run.deck)end
function M.options(run,event)
 if event.stage=='intro'then
  return {row('copy','拓印',#run.deck>0 and '选择牌组中的一张牌，获得它的复制品。' or '牌组为空，没有可拓印的卡牌。',#run.deck>0),
   row('leave','离开','不留下拓印。')}
 end
 if event.stage=='choose_card'then
  return {row('select','选择卡牌','选择一张永久牌；复制品不继承瓶装绑定。',#run.deck>0)}
 end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 return {}
end
local function select(run,event,uid)
 local ok,obtained=Run.obtainCardCopy(run,uid)
 if not ok then return false,obtained end
 event.sourceCardUid=uid
 event.obtainedCardUid=type(obtained)=='number' and obtained or nil
 event.curseBlocked=obtained=='curse_blocked'
 event.stage='result'
 event.body=event.curseBlocked and '微光中的诅咒被御守挡下，牌组没有增加。' or '微光凝成了一张新的卡牌，原牌仍留在牌组中。'
 return true,'pending'
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.stage=='choose_card'then
  if choice~='select'then return false,'invalid_event_choice'end
  return select(run,event,uid)
 end
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result' and choice=='leave'then return true,'complete'end
 if event.stage~='intro'then return false,'invalid_event_choice'end
 if choice=='copy'then
  -- Defensive empty-input preflight, not a new source event outcome. Keep the
  -- existing intro Leave usable instead of opening an impossible mandatory grid.
  if #run.deck==0 then return false,'no_copyable_card'end
  event.stage,event.body='choose_card','请选择要拓印的卡牌。'
 elseif choice=='leave'then
  event.stage,event.body='result','你没有触碰微光，准备继续赶路。'
 else return false,'invalid_event_choice'end
 return true,'pending'
end
return M
