-- Colosseum @ sts 319009d5: mandatory first battle, then flee or fight again.
local Run=require('abyss_run')
local Routes=require('abyss_event_combat_routes')
local M={}
local function row(choice,title,description)return {choice=choice,title=title,description=description,enabled=true}end
function M.prepare(run,event)
 assert(run.act==2,'Colosseum requires act2')
 event.stage,event.body='intro','你被带入了一座喧闹的竞技场。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','继续','进入竞技场。')}end
 if event.stage=='fight'then return {row('fight','战斗','与两名奴隶贩子战斗；本场没有可领取奖励。')}end
 if event.stage=='post_combat'then return {row('leave','离开','不参加第二场。'),row('fight','再战','与监军和丘丘暴徒战斗，胜利后可领取100金币、稀有和罕见遗物各一件。')}end
 return {}
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if run.act~=2 or event.id~='colosseum'or uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='intro'and choice=='continue'then event.stage,event.body='fight','两名奴隶贩子走入了场地。';return true,'pending'end
 if event.stage=='post_combat'and choice=='leave'then event.stage='leave';return true,'complete'end
 if (event.stage~='fight'and event.stage~='post_combat')or choice~='fight'then return false,'invalid_event_choice'end
 local second=event.stage=='post_combat'
 local source=second and'Colosseum Nobs'or'Colosseum Slavers'
 local prepared,why=Routes.prepare(run,source,run.floor,Run.roomStreams,run.miscRng,event.roomContinuation)
 if not prepared then return false,why end
 event.preparedCombat=prepared
 event.combatRequest={sourceEncounter=source,roomClass='event',route='colosseum',round=second and 2 or 1}
 event.stage=second and'combat_second'or'combat_first';return true,'event_combat'
end
return M
