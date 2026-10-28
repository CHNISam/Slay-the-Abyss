-- Mushrooms.buttonEffect @319009d5. Actors are constructed on the first
-- Fight, fixed GOLD/SPECIAL on the second; Heal precedes permanent Parasite.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local M={}
local function row(choice,title,text)return {choice=choice,title=title,description=text,enabled=true}end
local function healAmount(run)return math.floor(R.float32(R.float32(run.maxHp)*R.float32(.25)))end
function M.prepare(run,event)
 assert((run.act or 1)==1,'Mushrooms requires act1')
 event.stage,event.body='intro','发光的蘑菇覆盖了通道。'
end
function M.options(run,event)
 if event.stage=='intro'then return {row('fight','战斗','与三只真菌兽战斗，胜利后领取20至30金币和奇怪蘑菇。'),
  row('heal','食用蘑菇','回复'..healAmount(run)..'点生命，获得寄生诅咒。')}end
 if event.stage=='pre_combat'then return {row('fight','战斗','真菌兽已经苏醒。')}end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 return {}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if (run.act or 1)~=1 or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage=='intro'then
  if choice=='heal'then
   local healed=Run.heal(run,healAmount(run))
   local ok,value=Run.obtainCard(run,'Parasite');if not ok then return false,value end
   event.obtainedCardUid=type(value)=='number'and value or nil;event.curseBlocked=value=='curse_blocked'
   event.stage,event.body='result','回复'..healed..'点生命。'..(event.curseBlocked and'御守阻止了寄生。'or'寄生诅咒已加入牌组。')
   return true,'pending'
  end
  if choice~='fight'then return false,'invalid_event_choice'end
  local prepared,why=Run.prepareEventEncounter(run,'The Mushroom Lair',run.floor)
  if not prepared then return false,why end
  event.preparedCombat=prepared;event.stage,event.body='pre_combat','三只真菌兽挡住了去路。'
  return true,'pending'
 end
 if event.stage~='pre_combat'or choice~='fight'then return false,'invalid_event_choice'end
 local id='odd_mushroom'
 for _,held in ipairs(run.relics)do if held=='odd_mushroom'or held=='Odd Mushroom'then id='circlet'end end
 event.combatRequest={sourceEncounter='The Mushroom Lair',roomClass='event',gold=R.randomIntBetween(run.miscRng,20,30),fixedRelicId=id}
 event.stage='combat';return true,'event_combat'
end
return M
