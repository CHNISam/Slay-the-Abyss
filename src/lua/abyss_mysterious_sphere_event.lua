-- Fixed319009 MysteriousSphere stages only. Nodes owns constructor combat,
-- shared rare relic queues, admission, rewards and the enclosing transaction.
local R=require('abyss_sts_random')
local M={}
local function row(choice,title,description)
 return {choice=choice,title=title,description=description,enabled=true}
end
function M.prepare(run,event)
 assert(run.act==3 and event.id=='mysterious_sphere','Mysterious Sphere requires act3')
 event.constructorEncounter='2 Orb Walkers'
 event.stage,event.body='intro','密闭的球形容器中传来机关运转的声音。'
end
function M.options(_,event)
 if event.stage=='intro'then return {
  row('open','打开容器','准备与两台雷核步行机关战斗，胜利后可领取45至55金币和一件稀有遗物。'),
  row('leave','离开','不打开容器。')}end
 if event.stage=='pre_combat'then return {row('fight','战斗','容器已经打开，两台雷核步行机关正在苏醒。')}end
 if event.stage=='end'then return {row('leave','离开','返回路线。')}end
 return {}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if run.act~=3 or event.id~='mysterious_sphere' or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='intro'then
  if choice=='open'then
   event.stage,event.body='pre_combat','容器缓缓开启，机关的核心亮了起来。'
  elseif choice=='leave'then
   event.stage,event.body='end','你决定让容器保持原样。'
  else return false,'invalid_event_choice'end
  return true,'pending'
 end
 if event.stage=='end' and choice=='leave'then return true,'complete'end
 if event.stage~='pre_combat' or choice~='fight'then return false,'invalid_event_choice'end
 local gold=R.randomIntBetween(run.miscRng,45,55)
 event.combatRequest={sourceEncounter='2 Orb Walkers',roomClass='event',gold=gold,relicTier='rare'}
 event.stage='combat'
 return true,'event_combat'
end
return M
