-- AI policies receive the host's Power command; no Actor module back-reference.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data,Actors=require('abyss_combat'),require('abyss_data'),require('abyss_actor')
local cases={
 {module='abyss_fungi_beast_ai',enemy='fungi_beast',method='initialize',status='spore_cloud',amount=2,random=true},
 {module='abyss_louse_ai',enemy='red_louse',method='preBattle',status='curl_up',amount=3,random=true},
 {module='abyss_sentry_ai',enemy='sentry',method='initialize',status='artifact',amount=1,random=true},
 {module='abyss_looter_ai',enemy='looter',method='preBattle',status='thievery',amount=15},
}
local function loadPolicy(name)
 package.loaded[name]=nil
 local original=require
 require=function(target)
  assert(target~='abyss_actor','AI policy must not import the Actor host')
  return original(target)
 end
 local ok,policy=pcall(original,name)
 require=original
 assert(ok,policy)
 return policy
end
local function exercise(row,policy,omitPower)
 local s=C.new(Data,{enemies={row.enemy},deck={'defend'},seed=42})
 local enemy=s.enemies[1]
 enemy.statuses={};enemy.powerScheduleOrder=nil;enemy.powerScheduleSerial=nil;s.events={}
 local order={};local seed=s.seed
 local function random(state,range)
  assert(state==s and (range==100 or range==5),'wrong RNG boundary')
  order[#order+1]='random'
  return range==100 and 1 or row.amount-enemy.ai.curlUpRange.min+1
 end
 local function applyPower(state,target,id,amount,source)
  assert(state==s and target==enemy and source==enemy,'wrong Power owner/source')
  order[#order+1]='power'
  if not omitPower then return Actors.applyPower(state,target,id,amount,source) end
 end
 if row.random then policy[row.method](s,enemy,random,applyPower)
 else policy[row.method](s,enemy,applyPower) end
 assert(enemy.statuses[row.status]==row.amount,'missing real '..row.status..' Power')
 assert(#s.events==1 and s.events[1].kind=='status','missing real Power event')
 local event=s.events[1]
 assert(event.detail.status==row.status and event.detail.amount==row.amount,'wrong Power event')
 assert(event.frame.enemies[1].statuses[row.status]==row.amount,'Power event precedes mutation')
 assert(table.concat(order,',')==(row.random and 'random,power' or 'power'),'RNG/Power order changed')
 assert(s.seed==seed,'policy bypassed supplied RNG')
end
local function hostEntry(row)
 -- Combat enters through EnemyAI.initialize/preBattle. Observe the real host
 -- command so a swapped/missing forwarded argument cannot pass leaf tests.
 local original,calls=Actors.applyPower,{}
 Actors.applyPower=function(state,target,id,amount,source)
  if id==row.status then calls[#calls+1]={state=state,target=target,source=source,amount=amount}end
  return original(state,target,id,amount,source)
 end
 local ok,s=pcall(C.new,Data,{enemies={row.enemy},deck={'defend'},seed=42})
 Actors.applyPower=original
 assert(ok,s)
 assert(#calls==1,'EnemyAI must forward the current host Power command once')
 local call=calls[1];local enemy=s.enemies[1]
 assert(call.state==s and call.target==enemy and call.source==enemy,'EnemyAI forwarded wrong Power arguments')
 assert(call.amount==enemy.statuses[row.status],'EnemyAI lost actual Power application')
end
for _,row in ipairs(cases)do
 local policy=loadPolicy(row.module)
 hostEntry(row)
 exercise(row,policy,false)
 local ok,why=pcall(exercise,row,policy,true)
 assert(not ok and tostring(why):find('missing real '..row.status..' Power',1,true),'negative control missed omitted Power')
 print('PASS host Power boundary '..row.module..' and omitted-Power negative control')
end
