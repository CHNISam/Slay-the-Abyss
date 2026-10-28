-- Frozen decision trace: history, threshold edges, typed draws and mutable AI counters.
local AI=require('abyss_act2_ai')
local Data=require('abyss_act2_enemies')
local copy=require('abyss_copy').copy
local policies={}
for _,definition in ipairs(Data.enemies)do
 if definition.ai and definition.ai.kind=='act2' and not policies[definition.ai.policy]then policies[definition.ai.policy]=definition end
end
local names={};for name in pairs(policies)do names[#names+1]=name end;table.sort(names)
local edges={0,14,15,19,20,24,25,29,30,39,40,49,50,54,55,59,60,64,65,69,70,74,75,79,80,99}
local total=0
for _,name in ipairs(names)do for scenario=0,3 do for _,edge in ipairs(edges)do
 local e=copy(policies[name]);e.hp,e.maxHp=scenario==0 and 40 or 100,100;e.statuses={flight=scenario==0 and 0 or 3}
 local s,draws={enemies={e}},{}
 for i=1,math.min(scenario,2)do s.enemies[#s.enemies+1]={id='ally'..i,hp=i==2 and scenario==3 and 0 or 1,maxHp=30,statuses={}}end
 e.act2TorchSlots={'ally1','ally2'}
 local function random(_,maximum)
  local n=maximum==100 and edge+1 or (edge*997+#draws*73)%maximum+1
  draws[#draws+1]=maximum..':'..n;return n
 end
 AI.initialize(s,e,random)
 local trace={name,scenario,edge}
 for turn=1,12 do
  trace[#trace+1]=table.concat({e.intents[e.intentIndex].id,e.act2Stabs,e.act2Turns,e.act2Forges,
   tostring(e.act2Enraged),tostring(e.act2HexUsed),e.act2AutoTurns,tostring(e.act2StasisUsed)},':')
  AI.afterAction(s,e,random,e.intents[e.intentIndex])
 end
 trace[#trace+1]=table.concat(draws,',')
 for i,v in ipairs(trace)do trace[i]=tostring(v)end
 print(table.concat(trace,'|'));total=total+1
end end end
assert(#names==15,'missing Act2 policy coverage')
print('CORE_AI_TRACE '..total)
