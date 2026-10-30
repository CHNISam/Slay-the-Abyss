local C=require('abyss_combat')
local Data=require('abyss_data')
local A=require('abyss_actor')
local E=require('abyss_events')
local P=require('abyss_combat_effect_powers')
local Focus=require('abyss_focus')
local Stances=require('abyss_stances')
local tests=0
local function test(name,fn)fn();tests=tests+1;print('ok SOURCE_INTENT_POWER '..tests..' - '..name)end
local function battle()
 local s=C.new(Data,{enemies={'acid_slime_m','acid_slime_m'},deck={'strike'},seed=42})
 s.events={};return s
end
local function callback(entry,origin,timing)
 local marker=assert(entry.sourceIntentPowers,'missing explicit callback provenance')
 assert(marker.origin==origin and marker.scope=='all-monsters')
 assert(marker.timing==(timing or 'action-boundary'))
 assert(#entry.frame.enemies==2 and entry.frame.player and entry.frame.hand,'complete all-monster frame')
end
local function reduce(s,target,id,amount,op)
 return P.removeStatus({state=s,effect={targetId=target.id,status=id,value=amount,op=op or 'reduceStatus'},helpers={event=E.emit}})
end
test('accepted new and zero-delta stack annotate original status events',function()
 local s=battle();local e=s.enemies[1]
 assert(A.applyPower(s,e,'strength',2,e));assert(#s.events==1 and s.events[1].kind=='status')
 callback(s.events[1],'ApplyPowerAction')
 local original=s.events[1]
 assert(A.applyPower(s,e,'strength',0,e));assert(#s.events==2 and s.events[2].detail.amount==0)
 callback(s.events[2],'ApplyPowerAction');assert(original.frame.enemies[1].statuses.strength==2)
 assert(A.applyPower(s,e,'strength',1,e));assert(original.frame.enemies[1].statuses.strength==2,'prior frame was mutated')
 assert(#original.frame.enemies[1].powerOrder==1 and original.frame.enemies[1].powerOrder[1]=='strength')
end)
test('raw constructor/direct status paths never claim action callbacks',function()
 local s=battle();local e=s.enemies[1]
 A.addStatus(e,'strength',2);assert(#s.events==0)
 A.status(s,e,'weak',2,s.player);assert(#s.events==1 and not s.events[1].sourceIntentPowers)
 e.hp=0;local before=#s.events;assert(not A.applyPower(s,e,'strength',1,e));assert(#s.events==before)
 assert(not s.events[1].sourceIntentPowers,'failed action annotated stale tail')
end)
test('new zero is one callback; existing zero-stack compression is explicit',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'strength',0,e);callback(s.events[1],'ApplyPowerAction');assert(#s.events==1)
 A.applyPower(s,e,'strength',2,e);A.applyPower(s,e,'strength',-2,e)
 callback(s.events[3],'ApplyPowerAction');assert(#s.events==3,'do not fabricate a queued removal event absent from this engine')
end)
test('successful NoDraw has a boundary; duplicate and dead-target do not',function()
 local s=battle();assert(A.applyNoDraw(s,s.player));assert(#s.events==1 and s.events[1].kind=='source_intent_powers')
 callback(s.events[1],'ApplyPowerAction.NoDraw');assert(s.events[1].frame.player.noDraw)
 assert(not A.applyNoDraw(s,s.player));assert(#s.events==1)
 s.player.noDraw=false;s.player.hp=0;assert(not A.applyNoDraw(s,s.player));assert(#s.events==1)
end)
test('Artifact callback belongs to compressed reduction not failed incoming Apply',function()
 for _,count in ipairs({1,2})do
  local s=battle();local e=s.enemies[1];A.applyPower(s,e,'artifact',count,e);s.events={}
  assert(not A.applyPower(s,e,'weak',2,s.player));assert(#s.events==1)
  callback(s.events[1],'ArtifactPower.queuedReduction','compressed-existing-reduction')
  assert(s.events[1].detail.status=='artifact' and s.events[1].detail.blockedStatus=='weak')
  assert(not e.statuses.weak and e.statuses.artifact==count-1)
 end
end)
test('NoDraw interception also attributes only Artifact reduction',function()
 local s=battle();A.applyPower(s,s.player,'artifact',1,s.player);s.events={}
 assert(not A.applyNoDraw(s,s.player));assert(not s.player.noDraw and #s.events==1)
 callback(s.events[1],'ArtifactPower.queuedReduction','compressed-existing-reduction')
end)
test('positive reduction now has its exact detached action boundary',function()
 local s=battle();local e=s.enemies[2];A.applyPower(s,e,'weak',3,s.player);s.events={}
 assert(reduce(s,e,'weak',1));assert(e.statuses.weak==2 and #s.events==1)
 assert(s.events[1].kind=='source_intent_powers');callback(s.events[1],'ReducePowerAction')
 local f=s.events[1].frame;assert(f.enemies[2].statuses.weak==2 and f.enemies[1].id==s.enemies[1].id)
 e.statuses.weak=9;assert(f.enemies[2].statuses.weak==2)
end)
test('full reduction annotates actual removal, missing owner does not',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'weak',2,s.player);s.events={}
 assert(reduce(s,e,'weak',2));assert(e.statuses.weak==nil and #s.events==1 and s.events[1].kind=='status_removed')
 callback(s.events[1],'RemoveSpecificPowerAction')
 assert(reduce(s,e,'weak',1));assert(#s.events==1)
end)
test('positive Reduce has no life guard; real Remove keeps its source live guard',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'weak',2,s.player);s.events={};e.hp=0
 reduce(s,e,'weak',1);assert(#s.events==1);callback(s.events[1],'ReducePowerAction')
 reduce(s,e,'weak',1);assert(#s.events==2 and not s.events[2].sourceIntentPowers)
end)
test('Focus special apply and actual zero-removal each retain their source boundary',function()
 local s=battle();Focus.apply(s,s.player,2,s.player);callback(s.events[1],'ApplyPowerAction.Focus')
 Focus.apply(s,s.player,-2,s.player);assert(#s.events==3)
 callback(s.events[2],'ApplyPowerAction.Focus');callback(s.events[3],'RemoveSpecificPowerAction.Focus')
 assert(s.events[2].frame.player.statuses.focus==0 and s.events[3].frame.player.statuses.focus==nil)
 assert(not Focus.remove(s));assert(#s.events==3)
end)
test('same-stance action refreshes without changing its prior return/rules result',function()
 local s=battle();local energy=s.energy
 assert(Stances.change(s,'Neutral')==false);assert(#s.events==1 and s.events[1].kind=='source_intent_powers')
 callback(s.events[1],'ChangeStanceAction');assert(s.energy==energy and s.player.stance==nil and not s.stanceQueue)
end)
test('real changed stance annotates original event; blocked stance has no callback',function()
 local s=battle();assert(Stances.change(s,'Wrath'));assert(#s.events==1 and s.events[1].kind=='stance')
 callback(s.events[1],'ChangeStanceAction');assert(s.events[1].frame.player.stance=='Wrath')
 assert(not Stances.change(s,'Neutral',{cannotChange=true}));assert(#s.events==1)
 assert(not Stances.change(s,'Wrath',{cannotChange=true}));assert(#s.events==1)
end)
test('callback helper refuses stale/duplicate boundary attribution',function()
 local s=battle();A.status(s,s.player,'strength',1,s.player)
 assert(not pcall(E.onModifyPower,s,'ApplyPowerAction',-1))
 assert(not pcall(E.onModifyPower,s,'ApplyPowerAction',#s.events+1))
 E.onModifyPower(s,'ApplyPowerAction',0)
 assert(not pcall(E.onModifyPower,s,'ApplyPowerAction',0))
end)
test('Plated queued Reduce then actual Remove have distinct exact producers',function()
 local s=battle();local e=s.enemies[1];local Plated=require('abyss_plated_armor');local q={}
 local function queue(_,effect)q[#q+1]=effect end
 A.applyPower(s,e,'plated_armor',2,e);s.events={}
 Plated.apply(C,s,{op='platedReduce',targetId=e.id,value=1},queue)
 callback(s.events[1],'ReducePowerAction.PlatedArmor')
 Plated.apply(C,s,{op='platedReduce',targetId=e.id,value=1},queue)
 assert(#s.events==1 and #q==1,'terminal Reduce only queues Remove')
 Plated.apply(C,s,q[1],queue);callback(s.events[2],'RemoveSpecificPowerAction.PlatedArmor')
 assert(e.statuses.plated_armor==nil and #q==2 and q[2].op=='monsterChangeState')
end)
test('CurlUp callback is on actual removal after block, not original hit',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'curl_up',2,e);s.events={}
 A.resolveCurlUp(s,e,2);assert(s.events[1].kind=='block' and not s.events[1].sourceIntentPowers)
 assert(s.events[2].kind=='status');callback(s.events[2],'RemoveSpecificPowerAction.CurlUp')
end)
test('verified round debuffs refresh while source Poison direct decay does not',function()
 for _,id in ipairs({'weak','frail','vulnerable'})do
  local s=battle();local e=s.enemies[1];A.applyPower(s,e,id,2,s.player);s.events={}
  A.endRound(s,e);assert(#s.events==1);callback(s.events[1],'ReducePowerAction.RoundDebuff','compressed-existing-decay')
  A.endRound(s,e);assert(#s.events==2);callback(s.events[2],'RemoveSpecificPowerAction.RoundDebuff','compressed-existing-decay')
 end
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'poison',2,s.player);s.events={}
 A.startTurn(s,e);assert(#s.events>0)
 for _,entry in ipairs(s.events)do assert(not entry.sourceIntentPowers,'Poison direct decrement invented an onModifyPower')end
end)
print('SOURCE_INTENT_POWER_CALLBACKS_PASS '..tests)
