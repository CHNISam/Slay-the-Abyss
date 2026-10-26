-- Fixed319009 MoaiHead: direct max-health edit, then ordinary outside healing.
-- GoldenIdol has no onUnequip override. This slice does not implement its obtain.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Relics=require('abyss_relic_hooks')
local M={}
local function integer(n)return type(n)=='number' and n%1==0 and n>=0 and n<=2147483647 end
local function idol(run)
 local position
 for i,id in ipairs(run.relics)do if id=='golden_idol'then assert(not position,'duplicate Golden Idol');position=i end end
 return position
end
local function blockedHealing(run)
 for _,id in ipairs(run.relics)do if id=='mark_of_bloom' or id=='Mark of the Bloom'then return true end end
 return false
end
local function row(choice,title,description,enabled)return {choice=choice,title=title,description=description,enabled=enabled~=false}end
function M.prepare(run,event)
 assert(event.id=='moai_head' and run.act==3,'Moai requires the third act')
 assert(integer(run.maxHp) and run.maxHp>=1 and integer(run.hp) and run.hp>0 and run.hp<=run.maxHp,'invalid Moai health')
 event.startMaxHp=run.maxHp
 event.hpLoss=math.floor(R.float32(R.float32(run.maxHp)*R.float32(.125))+.5)
 event.hasIdol=idol(run)~=nil
 event.stage,event.body='intro','一尊巨大的石像挡在路边，要求你作出献祭。'
end
function M.options(run,event)
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='intro'then return {}end
 local healing=blockedHealing(run)and'当前遗物禁止治疗；仍会降低生命上限。'or'然后回复生命至新的上限。'
 local gold=Relics.owns(run,'ectoplasm')and'当前遗物禁止获得金币。'or'获得333金币。'
 return {
  row('heal','触碰石像','失去'..event.hpLoss..'点最大生命（'..event.startMaxHp..' → '..math.max(1,event.startMaxHp-event.hpLoss)..'）。'..healing),
  row('give_idol','献上金神像',event.hasIdol and'失去金神像。'..gold or'需要金神像（未持有）。',event.hasIdol),
  row('leave','离开','不作献祭，继续前进。')}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.id~='moai_head' or run.act~=3 or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'then
  if choice~='leave'then return false,'invalid_event_choice'end
  return true,'complete'
 end
 if event.stage~='intro'then return false,'invalid_event_choice'end
 if choice=='heal'then
  if run.maxHp~=event.startMaxHp then return false,'stale_event_health'end
  if not integer(run.hp) or run.hp<=0 or run.hp>run.maxHp then return false,'invalid_event_health'end
  -- MoaiHead edits maxHealth itself, not damage/decreaseMaxHealth. No Fairy.
  run.maxHp=run.maxHp-event.hpLoss
  if run.hp>run.maxHp then run.hp=run.maxHp end
  if run.maxHp<1 then run.maxHp=1 end
  local healed=Run.heal(run,run.maxHp)
  if not integer(healed)then return false,'event_heal_failed'end
  event.healed=healed
  event.body='生命上限降低了'..event.hpLoss..'点。'..(blockedHealing(run)and'遗物阻止了治疗。'or'你恢复了生命。')
 elseif choice=='give_idol'then
  local position=idol(run)
  if not event.hasIdol or not position then return false,'event_condition_unmet'end
  -- Exact canonical owner removal; unrelated relics and permanent card UIDs stay.
  table.remove(run.relics,position)
  local gained=Run.gainGold(run,333)
  if not integer(gained)then return false,'event_gold_failed'end
  event.lostRelicId,event.goldGained='golden_idol',gained
  event.body='你献出了金神像，获得'..gained..'金币。'
 elseif choice=='leave'then event.body='你没有献祭，石像身后的道路依然畅通。'
 else return false,'invalid_event_choice'end
 event.stage='result';return true,'pending'
end
return M
