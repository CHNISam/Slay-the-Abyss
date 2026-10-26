-- PC A0 fixed319009 WindingHalls. All three outcomes are mandatory choices.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local M={}
local function rounded(maximum,ratio)return math.floor(R.float32(R.float32(maximum)*R.float32(ratio))+.5)end
local function row(choice,title,description,card)return {choice=choice,title=title,description=description,enabled=true,cardId=card}end
function M.prepare(run,event)
 assert(event.id=='winding_halls' and run.act==3,'Winding Halls requires act3')
 assert(type(run.maxHp)=='number' and run.maxHp%1==0 and run.maxHp>=1 and run.maxHp<=2147483647,'invalid Winding health')
 event.startMaxHp=run.maxHp
 event.hpDamage,event.healAmount,event.maxHpLoss=rounded(run.maxHp,.125),rounded(run.maxHp,.25),rounded(run.maxHp,.05)
 event.stage,event.body='intro','通道反复折返。你停下来，试图重新辨认方向。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','继续','寻找离开这片通道的方法。')}end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='choice'then return {}end
 return {
  row('madness','接受 Madness','受到'..event.hpDamage..'点普通伤害，获得2张Madness。','madness'),
  row('writhe','休息并获得 Writhe','回复'..event.healAmount..'点生命（受遗物限制），获得Writhe。','writhe'),
  row('max_hp','减少最大生命','失去'..event.maxHpLoss..'点最大生命（'..event.startMaxHp..' → '..math.max(1,event.startMaxHp-event.maxHpLoss)..'），不治疗。')}
end
local function obtain(run,event,id)
 local ok,uid=Run.obtainCard(run,id)
 if not ok then return false,uid end
 if uid=='curse_blocked'then event.curseBlocked=true
 else event.obtainedUids[#event.obtainedUids+1]=uid end
 return true
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.id~='winding_halls' or run.act~=3 or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='intro'then
  if choice~='continue'then return false,'invalid_event_choice'end
  event.stage,event.body='choice','继续前进需要付出代价。';return true,'pending'
 end
 if event.stage=='result'then
  if choice~='leave'then return false,'invalid_event_choice'end
  return true,'complete'
 end
 if event.stage~='choice'then return false,'invalid_event_choice'end
 if run.maxHp~=event.startMaxHp then return false,'stale_event_health'end
 if type(run.hp)~='number' or run.hp%1~=0 or run.hp<=0 or run.hp>run.maxHp then return false,'invalid_event_health'end
 -- Admission stays closed until the actual shared onObtainCard hooks exist.
 local missing=choice=='madness' and 'toxic_egg' or choice=='writhe' and 'darkstone_periapt'
 for _,id in ipairs(run.relics or {})do
  if id==missing then return false,'event_obtain_content_unavailable'end
 end
 event.obtainedUids={}
 if choice=='madness'then
  local ok,why=Run.eventNormalDamage(run,event.hpDamage);if not ok then return false,why end
  -- The source constructs both obtain effects after damage, even after death.
  for _=1,2 do ok,why=obtain(run,event,'madness');if not ok then return false,why end end
  event.body='你获得了2张Madness。'
 elseif choice=='writhe'then
  local healed=Run.heal(run,event.healAmount)
  if type(healed)~='number' or healed<0 or healed%1~=0 then return false,'event_heal_failed'end
  local ok,why=obtain(run,event,'writhe');if not ok then return false,why end
  event.healed=healed
  event.body='实际回复了'..healed..'点生命。'..(event.curseBlocked and'Omamori阻止了Writhe。'or'你获得了Writhe。')
 elseif choice=='max_hp'then
  -- AbstractCreature.decreaseMaxHealth clamps maximum BEFORE current health.
  run.maxHp=math.max(1,run.maxHp-event.maxHpLoss)
  run.hp=math.min(run.hp,run.maxHp)
  event.body='你失去了'..event.maxHpLoss..'点最大生命，没有获得治疗。'
 else return false,'invalid_event_choice'end
 event.stage='result';return true,'pending'
end
return M
