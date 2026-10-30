-- MaskedBandits @ sts 319009d5. Constructor actors exist even when paying.
local R=require('abyss_sts_random')
local Hooks=require('abyss_relic_hooks')
local M={}
local function row(choice,title,description)return {choice=choice,title=title,description=description,enabled=true}end
function M.prepare(run,event)
 assert(run.act==2,'Masked Bandits requires act2')
 event.constructorEncounter='Masked Bandits';event.stage='intro'
 event.body='三名蒙面盗匪挡住了去路，索要你全部的金币。'
end
function M.options(run,event)
 if event.stage=='intro'then return {row('pay','交出金币','失去全部'..run.gold..'金币。'),row('fight','战斗','胜利后可领取25至35金币和红面具。')}end
 if event.stage=='paid_1'or event.stage=='paid_2'then return {row('continue','继续','盗匪们收起了金币。')}end
 if event.stage=='paid_3'then return {row('leave','离开','离开盗匪。')}end
 return {}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if run.act~=2 or event.id~='masked_bandits'or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='intro'then
  if choice=='pay'then
   event.goldPaid=run.gold;run.gold=0;event.stage,event.body='paid_1','盗匪们收走了你所有的金币。'
   -- Penny destinations use MathUtils, never the gameplay misc stream.
   return true,'pending'
  elseif choice=='fight'then
   event.combatRequest={sourceEncounter='Masked Bandits',roomClass='event',route='masked_bandits',
    gold=R.randomIntBetween(run.miscRng,25,35),fixedRelicId=Hooks.owns(run,'red_mask')and'circlet'or'red_mask'}
   event.stage='combat';return true,'event_combat'
  end
 elseif event.stage=='paid_1'and choice=='continue'then event.stage,event.body='paid_2','盗匪们对你冷嘲热讽。';return true,'pending'
 elseif event.stage=='paid_2'and choice=='continue'then event.stage,event.body='paid_3','盗匪们让开了道路。';return true,'pending'
 elseif event.stage=='paid_3'and choice=='leave'then event.stage='end';return true,'complete'end
 return false,'invalid_event_choice'
end
return M
