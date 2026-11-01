-- Fixed-source A0 Large Spike pre-split contract; TASK-15.12.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data,Run=require('abyss_combat'),require('abyss_data'),require('abyss_run')
local first,last,historyFirst,historyLast=...
first,last=first or 1,last or 5
assert(first>=1 and last<=17 and first<=last,'invalid budget slice')
historyFirst,historyLast=historyFirst or 1,historyLast or 6
assert(historyFirst>=1 and historyLast<=6 and historyFirst<=historyLast,'invalid history slice')
local passed,failed,registered=0,0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b) if type(a)~='table' then return eq(a,b) end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(name,fn)
 registered=registered+1;if registered<first or registered>last then return end
 local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
 print('SPIKE_SLIME_L_CASE '..registered)
end
local function battle(ids,deck,seed) return C.new(Data,{enemies=ids or {'spike_slime_l'},deck=deck or {'defend'},seed=seed or 42}) end
local function force(e,id) for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error('missing '..id)end
local function count(s,id) local n=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do if c.cardId==id then n=n+1 end end end;return n end
local function observe(roll,fn)
 local old,calls=C.random,{};C.random=function(s,n)calls[#calls+1]=n;local value=old(s,n);return n==100 and roll+1 or value end
 local ok,why=pcall(fn,calls);C.random=old;assert(ok,why)
end
local function primary(calls,start) local n=0;for i=(start or 0)+1,#calls do if calls[i]==100 then n=n+1 end end;return n end

test('ordinary HP64-70 sample precedes opening roll and deck shuffle',function()
 observe(0,function(calls)local s=battle(nil,{'strike','defend','bash','anger'});eq(#calls,5);for i,n in ipairs({7,100,4,3,2})do eq(calls[i],n)end;eq(C.intent(s,1).id,'spike_slime_l_1')end)
 local seen={};for seed=1,128 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=64 and e.hp<=70);eq(e.maxHp,e.hp);seen[e.hp]=true end
 for hp=64,70 do assert(seen[hp],'missing endpoint/value '..hp)end
end)
for _,r in ipairs({0,29,30,99})do test('opening boundary '..r,function()
 observe(r,function(calls)local s=battle();eq(C.intent(s,1).id,r<30 and 'spike_slime_l_1' or 'spike_slime_l_2');eq(primary(calls),1)end)
end)end
test('runtime dispatcher covers all 600 controlled action histories and rolls',function()
 local histories={{1,0},{2,0},{1,1},{2,2},{1,2},{2,1}}
 local historyCases=0
 for history,h in ipairs(histories)do if history>=historyFirst and history<=historyLast then for r=0,99 do observe(r,function(calls)
  historyCases=historyCases+1
  local s=battle();local e=s.enemies[1];force(e,'spike_slime_l_'..h[1]);e.spikeLast=h[2]>0 and 'spike_slime_l_'..h[2] or nil
  local before=#calls;assert(C.endTurn(s));local want=r<30 and 1 or 2;if h[1]==h[2] then want=3-h[1] end
  eq(C.intent(s,1).id,'spike_slime_l_'..want);eq(primary(calls,before),1);eq(e.spikePrevious,h[2]>0 and 'spike_slime_l_'..h[2] or nil);eq(e.spikeLast,'spike_slime_l_'..h[1])
 end)end end end
 eq(historyCases,(historyLast-historyFirst+1)*100)
 print('SPIKE_SLIME_L_HISTORIES '..historyFirst..' '..historyLast..' '..historyCases)
end)
test('two attacks produce four Slimed then force Frail before another attack',function()
 observe(0,function(calls)local s=battle();for _,want in ipairs({1,2,1})do local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,'spike_slime_l_'..want);eq(primary(calls,before),1)end
 eq(s.player.hp,48);eq(count(s,'slimed'),4);eq(s.player.statuses.frail,2)
 end)
end)
test('Frail2 cannot occur three times and stacked duration follows shared round boundary',function()
 observe(99,function()local s=battle();assert(C.endTurn(s));eq(s.player.statuses.frail,2);eq(C.intent(s,1).id,'spike_slime_l_2')
 assert(C.endTurn(s));eq(s.player.statuses.frail,3);eq(C.intent(s,1).id,'spike_slime_l_1');eq(s.player.hp,80)
 assert(C.endTurn(s));eq(s.player.hp,64);eq(s.player.statuses.frail,2);eq(count(s,'slimed'),2)end)
end)
test('Tackle16 precedes two distinct temporary Slimed and the next actor',function()
 observe(0,function()local s=battle({'spike_slime_l','sneaky_gremlin'});s.events={};assert(C.endTurn(s));local damage,created,nextAttack
 for i,event in ipairs(s.events)do
  if event.kind=='damage' and event.detail.source==s.enemies[1].id then damage=i;eq(event.detail.amount,16)
  elseif event.kind=='cards_created' then created=i;eq(event.detail.cardId,'slimed');eq(event.detail.amount,2);eq(event.frame.player.hp,64)
  elseif event.kind=='damage' and event.detail.source==s.enemies[2].id then nextAttack=i end
 end
 assert(damage and created and nextAttack and damage<created and created<nextAttack);eq(count(s,'slimed'),2);eq(s.player.hp,55)
 local uids={};for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.cardId=='slimed' then assert(not uids[c.uid]);uids[c.uid]=true end end end
 end)
end)
test('fully blocked Tackle still generates two Slimed',function()
 observe(0,function()local s=battle();C.block(s,s.player,16,true);assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),2)end)
end)
test('Artifact blocks Frail2 but not later contamination',function()
 observe(99,function()local s=battle();C.addStatus(s.player,'artifact',1);assert(C.endTurn(s));eq(s.player.statuses.artifact,0);eq(s.player.statuses.frail or 0,0);force(s.enemies[1],'spike_slime_l_1');assert(C.endTurn(s));eq(count(s,'slimed'),2)end)
end)
test('lethal retaliation retains queued Slimed and roll only while a teammate lives',function()
 for _,solo in ipairs({false,true})do observe(0,function(calls)
  local s=battle(solo and {'spike_slime_l'} or {'spike_slime_l','shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls
  assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(count(s,'slimed'),solo and 0 or 2);eq(primary(calls,before),solo and 0 or 1);eq(s.phase,solo and 'victory' or 'player')
 end)end
end)
test('pre-action lethal poison generates no card and consumes no action roll',function()
 observe(0,function(calls)local s=battle({'spike_slime_l','shield_gremlin'});C.addStatus(s.enemies[1],'poison',99);local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,80);eq(count(s,'slimed'),0);eq(primary(calls,before),0)end)
end)
test('player death stops queued contamination and roll',function()
 observe(0,function(calls)local s=battle();s.player.hp=1;local before=#calls;assert(C.endTurn(s));eq(s.phase,'defeat');eq(count(s,'slimed'),0);eq(primary(calls,before),0)end)
end)
test('shared medium policy keeps per-actor histories and payload counts independent',function()
 observe(0,function()local s=battle({'spike_slime_l','spike_slime_m'});s.enemies[1].spikeLast='spike_slime_l_1';assert(C.endTurn(s));eq(C.intent(s,1).id,'spike_slime_l_2');eq(C.intent(s,2).id,'spike_slime_m_1');eq(s.player.hp,56);eq(count(s,'slimed'),3)
 eq(s.enemies[1].spikePrevious,'spike_slime_l_1');eq(s.enemies[2].spikePrevious,nil)end)
end)
test('real Run large-spike encounter produces payable temporary cards without permanent deck changes',function()
 observe(0,function()local r=Run.new(Data,42);r.floor=4;assert(Run.startCombat(r,'large_spike'));local deck=C.copy(r.deck);assert(Run.endTurn(r));eq(count(r.combat,'slimed'),2);same(r.deck,deck)
 local s=battle(nil,{'defend'});assert(C.endTurn(s));local target;for _,c in ipairs(s.hand)do if c.cardId=='slimed' then target=c;break end end;assert(target);assert(C.play(s,target.uid));eq(s.energy,2);eq(s.exhaust[1],target)
 end)
end)
test('failed card action rolls back actor identity history and random state in place',function()
 observe(0,function()local s=battle(nil,{'defend'});assert(C.endTurn(s));local before=C.copy(s);local enemy,hand,events=s.enemies[1],s.hand,s.events
 local id;for _,c in ipairs(s.hand)do if c.cardId=='defend' then id=c.uid end end;assert(id)
 local old=C.block;C.block=function()error('SPIKE_L_FAILURE')end;local ok,why=pcall(C.play,s,id);C.block=old
 eq(ok,false);assert(tostring(why):find('SPIKE_L_FAILURE',1,true));same(s,before);eq(s.enemies[1],enemy);eq(s.hand,hand);eq(s.events,events)
 end)
end)
assert(registered==17,'all original cases must remain registered')
assert(passed+failed==last-first+1,'each selected case must execute')
print(passed..' Large Spike groups passed; '..failed..' failed');assert(failed==0)
