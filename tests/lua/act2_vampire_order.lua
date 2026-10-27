-- Candidate production Parasite action, not the historical staged enemy port.
-- Oracle: pinned319009 VampireDamageAction TOP Heal(lastDamageTaken), TOP Wait;
-- AbstractPlayer captures loss before Fairy; DeathScreen pauses later actions.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,E,D=require('abyss_combat'),require('abyss_actor'),require('abyss_events'),require('abyss_data')
local Profiles=require('abyss_original_v4_profiles')
local passed,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS 'or'FAIL ')..name..(ok and''or': '..tostring(why)))end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error('missing intent '..id)end
local function battle(mode,hp,sourceHp,extra)
 local data=mode=='V4'and Profiles.prepare(D,'AR')or D
 local s=C.new(data,{enemies=extra and {'shelled_parasite','cultist'}or{'shelled_parasite'},deck={},seed=42,hp=hp or 80,maxHp=80,enableStances=mode=='advanced'})
 local e=s.enemies[1];force(e,'life_suck');e.hp=sourceHp or 1;e.block=0;s.events={};return s,e
end
local function power(s,id,n)A.applyPower(s,s.player,id,n,s.player)end
local function hits(s,e)
 local result={}
 for _,v in ipairs(s.events)do
  if type(v.detail)=='table' and v.detail.target==e.id and(v.kind=='heal'or v.kind=='status_damage')then result[#result+1]=v end
 end
 return result
end
local function noHeal(s)for _,v in ipairs(s.events)do assert(v.kind~='heal','source schedules no HealAction when lastDamageTaken=0 or death screen is up')end end
for _,mode in ipairs({'native','advanced','V4'})do
 test(mode..' real Life Suck heals 1 to11 before Thorns5 and survives at6',function()
  local s,e=battle(mode);power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(e.hp,6);eq(s.player.hp,70);eq(s.phase,'player')
  local trace=hits(s,e);eq(#trace,2);eq(trace[1].kind,'heal');eq(trace[1].detail.amount,10);eq(trace[1].frame.enemies[1].hp,11)
  eq(trace[2].kind,'status_damage');eq(trace[2].detail.amount,5);eq(trace[2].frame.enemies[1].hp,6)
 end)
end
test('full-health source loses Thorns after its zero-actual HealAction, not heal back afterward',function()
 local s,e=battle();e.hp=e.maxHp;local max=e.maxHp;power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(e.hp,max-5)
 local trace=hits(s,e);eq(trace[1].kind,'heal');eq(trace[1].detail.amount,0);eq(trace[2].kind,'status_damage')
end)
test('fully blocked hit has no HealAction but still has Thorns',function()
 local s,e=battle(nil,80,10);s.player.block=10;power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(e.hp,5);eq(s.player.hp,80);noHeal(s)
end)
test('partial block caps healing to captured unblocked3 before Thorns2',function()
 local s,e=battle();s.player.block=7;power(s,'thorns',2);s.events={};assert(C.endTurn(s));eq(e.hp,2);eq(s.player.hp,77)
 local trace=hits(s,e);eq(trace[1].detail.amount,3);eq(trace[1].frame.enemies[1].hp,4)
end)
test('Intangible target captures1 and heals1 before retaliation5',function()
 local s,e=battle(nil,80,10);power(s,'intangible',1);power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(e.hp,6);eq(s.player.hp,79);eq(hits(s,e)[1].detail.amount,1)
end)
test('source Intangible still uses canonical retaliation cap after its heal',function()
 local s,e=battle();A.applyPower(s,e,'intangible',1,e);power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(e.hp,10);local trace=hits(s,e);eq(#trace,2);eq(trace[1].detail.amount,10);eq(trace[2].detail.amount,1)
end)
test('Weak and Vulnerable use existing NORMAL calculation before captured-loss heal',function()
 local s,e=battle();A.applyPower(s,e,'weak',1,e);power(s,'vulnerable',1);power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(e.hp,7);eq(s.player.hp,69);eq(hits(s,e)[1].detail.amount,11)
end)
test('overkill without Fairy opens death screen before queued heal and retaliation',function()
 local s,e=battle(nil,3,1);power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.hp,0);eq(e.hp,1);noHeal(s);eq(#hits(s,e),0)
end)
test('Fairy overkill heals captured pre-revive3, not net health delta, then retaliation',function()
 local s,e=battle(nil,3,10);s.potionInventory={[1]='fairy_in_a_bottle'};s.potionCapacity=3;power(s,'thorns',5);s.events={};assert(C.endTurn(s));eq(s.player.hp,24);eq(e.hp,8);eq(s.potionInventory[1],nil)
 local trace=hits(s,e);eq(trace[1].kind,'heal');eq(trace[1].detail.amount,3);eq(trace[1].frame.enemies[1].hp,13);eq(trace[2].kind,'status_damage')
end)
for _,order in ipairs({{'thorns','flame_barrier'},{'flame_barrier','thorns'}})do
 test('Heal precedes distinct reverse-TOP reactions acquired '..table.concat(order,','),function()
  local s,e=battle();for _,id in ipairs(order)do power(s,id,id=='thorns'and 5 or 2)end;s.events={};assert(C.endTurn(s));eq(e.hp,4)
  local trace=hits(s,e);eq(#trace,3);eq(trace[1].kind,'heal');eq(trace[1].frame.enemies[1].hp,11)
  eq(trace[2].detail.amount,order[2]=='thorns'and 5 or 2);eq(trace[3].detail.amount,order[1]=='thorns'and 5 or 2)
 end)
end
test('source killed after healing final foe clears Roll and keeps source death callback',function()
 local s,e=battle('V4');e.v4Directive={mature=true};power(s,'thorns',12);s.events={}
 local rng=s.aiRng and s.aiRng.counter;local intent=e.intentIndex;assert(C.endTurn(s));eq(e.hp,0);eq(s.phase,'victory');eq(e.intentIndex,intent);eq(s.aiRng and s.aiRng.counter,rng)
 eq(s.originalV4.bond,4);eq(e.v4Directive,nil);local trace=hits(s,e);eq(#trace,2);eq(trace[1].kind,'heal');eq(trace[2].detail.amount,11)
end)
test('dead source Roll survives while actual teammate remains and does not re-heal',function()
 local s,e=battle(nil,80,1,true);power(s,'thorns',12);s.events={};local old=C.random;local n=0
 C.random=function(state,max)n=n+1;return old(state,max)end
 local ok,why=pcall(C.endTurn,s);C.random=old;assert(ok,why);eq(e.hp,0);eq(s.phase,'player');assert(e.act2Last=='life_suck');eq(n,2);eq(#hits(s,e),2)
end)
local function unchanged(root)
 local saved={};local function visit(t)if type(t)~='table'or saved[t]then return end;local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;visit(k);visit(v)end end;visit(root)
 return function()for t,values in pairs(saved)do for k,v in pairs(values)do eq(t[k],v,'original key '..tostring(k))end;for k,v in pairs(t)do eq(v,values[k],'extra key '..tostring(k))end end end
end
for _,mode in ipairs({'advanced','V4'})do
 for _,stage in ipairs({'heal','status_damage'})do
  test(mode..' atomic endTurn restores all graph identities after '..stage..' failure',function()
   local s,e=battle(mode,3,10,true);s.potionInventory={[1]='fairy_in_a_bottle'};s.potionCapacity=3;power(s,'thorns',5);s.events={}
   local check=unchanged(s);local old=E.emit;local injected=false
   E.emit=function(state,kind,detail)local result=old(state,kind,detail);if kind==stage and detail.target==e.id then injected=true;error('vampire injected '..stage)end;return result end
   local ok,why=pcall(C.endTurn,s);E.emit=old;assert(injected);assert(not ok and tostring(why):find('vampire injected '..stage,1,true),tostring(why));check()
  end)
 end
end
print(passed..' Vampire source-order groups passed; '..failed..' failed');assert(failed==0)
