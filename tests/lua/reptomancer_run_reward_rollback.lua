-- Requires the separately reviewed generic Run.play transaction fix be261338.
-- Real source room, starter card and elite reward path; lethal HP is explicit.
local Run,C,D,Q=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_encounter_queue')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
for _,failure in ipairs({'throw','refuse'})do
 local run=Run.new(D,'3',{experimental=true,campaign=true,character='ironclad'})
 run.act,run.floor,run.encounters=3,37,Q.new('3',3);eq(Q.peek(run.encounters,'elite'),'Reptomancer')
 assert(Run.startRoomCombat(run,'elite'));local s=run.combat;s.enemies[2].hp=1
 local uid;for _,c in ipairs(s.hand)do local d=C.cardDefinition(s,c)
  if d.type=='attack'and d.cost>=0 and d.cost<=s.energy then uid=c.uid;break end
 end;assert(uid)
 local before=C.copy(run);local leader,slots,hand,queue,cardRng=s.enemies[2],s.enemies[2].reptomancerSlots,s.hand,run.encounters,run.cardRng
 local finish=Run.finishCombat;local fired=false
 Run.finishCombat=function(r)
  local ok,why=finish(r);assert(ok,why);fired=true
  if failure=='throw'then error('LATE_REPTOMANCER_REWARD_THROW')end
  return false,'late_reptomancer_reward_refusal'
 end
 local called,ok,why=pcall(Run.play,run,uid,2);Run.finishCombat=finish
 assert(fired)
 if failure=='throw'then eq(called,false)else eq(called,true);eq(ok,false);eq(why,'late_reptomancer_reward_refusal')end
 same(run,before);eq(run.combat,s);eq(s.enemies[2],leader);eq(leader.reptomancerSlots,slots)
 eq(s.hand,hand);eq(run.encounters,queue);eq(run.cardRng,cardRng)
 assert(Run.play(run,uid,2));eq(run.phase,'reward');eq(run.victories,1)
end
print('REPTOMANCER_RUN_REWARD_ROLLBACK 2 failure/retry groups PASS')
