-- Controlled combined-owner fixtures, NOT natural source formations/routes.
local C,A,D,R,Actions=require('abyss_combat'),require('abyss_actor'),require('abyss_data'),
 require('abyss_sts_random'),require('abyss_card_actions')
local Schedule=require('abyss_power_schedule')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,'[ACT3_COMPLETION '..(label or 'value')..'] '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function battle(mode,enemies,deck)
 local streams={seed='42'};for _,id in ipairs({'monsterHpRng','aiRng','shuffleRng','cardRandomRng'})do streams[id]=R.fromSeed('42')end
 return C.new(D,{enemies=enemies,deck=deck or {'defend'},roomSeed='42',roomStreams=streams,
  maxHp=1000,hp=1000,enableStances=mode=='advanced'})
end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error(id)end
local function actor(s,id)for _,e in ipairs(s.enemies)do if e.definitionId==id then return e end end;error(id)end
local function capture(s,fn)
 local original=Actions.enqueueReaction;local trace={}
 Actions.enqueueReaction=function(state,e,...)
  if state==s and(e.op=='giantHeadSlow'or e.op=='timeEater')then
   trace[#trace+1]=e.op=='giantHeadSlow'and 'slow'or e.kind
  end
  return original(state,e,...)
 end
 local ok,why=pcall(fn);Actions.enqueueReaction=original;assert(ok,why);return trace
end
for _,mode in ipairs({'native','advanced'})do
 for _,reverse in ipairs({false,true})do
  test(mode..' controlled mixed group callbacks preserve '..(reverse and 'TimeWarp-first'or 'Slow-first')..' monster order',function()
   local s=battle(mode,reverse and {'time_eater','giant_head'}or {'giant_head','time_eater'})
   actor(s,'time_eater').statuses.time_warp=11
   local trace=capture(s,function()assert(C.play(s,held(s,'defend').uid))end)
   eq(table.concat(trace,','),reverse and 'strength,strength,slow'or 'slow,strength,strength','group order')
   eq(actor(s,'time_eater').statuses.strength,2);eq(actor(s,'giant_head').statuses.strength,2)
   eq(actor(s,'giant_head').statuses.slow,0,'source round reset');eq(s.turn,2)
  end)
  test(mode..' controlled same-owner Powers preserve '..(reverse and 'Slow-first'or 'TimeWarp-first')..' acquisition order',function()
   local s=battle(mode,{'time_eater'});local e=s.enemies[1]
   if reverse then
    Schedule.remove(s,e,'time_warp');e.statuses.time_warp=nil;e.powerOrder={}
    A.applyPower(s,e,'slow',0,e);A.applyPower(s,e,'time_warp',0,e)
   else A.applyPower(s,e,'slow',0,e)end
   local order=Schedule.list(e,{slow=true,time_warp=true})
   eq(order[1].id,reverse and 'slow'or 'time_warp');eq(order[2].id,reverse and 'time_warp'or 'slow')
   e.statuses.time_warp=11
   local trace=capture(s,function()assert(C.play(s,held(s,'defend').uid))end)
   eq(table.concat(trace,','),reverse and 'slow,strength'or 'strength,slow','Power acquisition order')
   eq(e.statuses.time_warp,0);eq(e.statuses.slow,0)
   local retained=Schedule.list(e,{slow=true,time_warp=true});eq(retained[1].id,order[1].id);eq(retained[2].id,order[2].id)
  end)
 end
 test(mode..' physical flag suppresses both owners then resets on ordinary disposal',function()
  local s=battle(mode,{'giant_head','time_eater'});local c=held(s,'defend');c.dontTriggerOnUseCard=true
  local clone=Actions.sameInstance(C,s,c);eq(clone.dontTriggerOnUseCard,nil,'copy starts fresh')
  local trace=capture(s,function()assert(C.play(s,c.uid))end)
  eq(#trace,0);eq(actor(s,'giant_head').statuses.slow,0);eq(actor(s,'time_eater').statuses.time_warp,0)
  eq(c.dontTriggerOnUseCard,false,'physical reset');eq(s.turn,1)
 end)
 test(mode..' cancelled Sentinel TOP precedes all Strength while FNP and Embrace BOT follow',function()
  local s=battle(mode,{'giant_head','time_eater'},{'anger'});local e=actor(s,'time_eater');e.statuses.time_warp=11
  local sentinel=Actions.fresh(C,s,'sentinel');local drawn=Actions.fresh(C,s,'defend');s.draw[#s.draw+1]=drawn
  for _,id in ipairs({'feel_no_pain','dark_embrace'})do
   A.applyPower(s,s.player,id,id=='feel_no_pain'and 3 or 1,s.player);require('abyss_exhaust').rememberPower(s,id)
  end
  C.queueCard(s,sentinel,{targetIndex=1,exhaustCards=true,append=true})
  local start=#s.events+1;assert(C.play(s,held(s,'anger').uid,1));local strengths=0
  for i=start,#s.events do local event=s.events[i]
   if event.kind=='status'and event.detail.status=='strength'and event.detail.amount==2 then
    strengths=strengths+1;eq(event.frame.energy,5,'Sentinel energy TOP')
    eq(event.frame.player.block,0,'FNP block BOT');eq(#event.frame.hand,0,'Embrace draw BOT')
    eq(event.frame.draw[1].uid,drawn.uid);eq(event.frame.exhaust[1].uid,sentinel.uid)
   end
  end
  eq(strengths,2);eq(sentinel.dontTriggerOnUseCard,false);eq(s.cardInUse,nil)
 end)
end
test('TimeWarp zero membership preserves acquisition identity across stacks and reset',function()
 local s=battle('native',{'time_eater'});local e=s.enemies[1]
 eq(e.statuses.time_warp,0);eq(e.powerOrder[1],'time_warp');local serial=e.powerScheduleSerial
 A.applyPower(s,e,'time_warp',0,e);eq(e.powerOrder[1],'time_warp');eq(e.powerScheduleSerial,serial)
 eq(Schedule.list(e,{time_warp=true})[1].id,'time_warp')
end)
print('ACT3_COMPLETION_SEAMS '..count..' groups; '..failed..' failed');assert(failed==0)
