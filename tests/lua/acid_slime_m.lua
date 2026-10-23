-- Source oracle: fixed AcidSlime_M.java, PC A0 branch; see TASK-15.7 ledger.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, Data, AI = require('abyss_combat'), require('abyss_data'), require('abyss_enemy_ai')
local passed, failed = 0, 0
local function eq(a,b,label) assert(a == b, (label or 'value') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
local function test(name, fn) local ok, why = pcall(fn); if ok then passed=passed+1 else failed=failed+1 end; print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': '..tostring(why))) end
local function battle(ids,deck,seed) return C.new(Data,{enemies=ids or {'acid_slime_m'},deck=deck or {'defend'},seed=seed or 42}) end
local function observe(roll,boolean,unit,fn)
 local old,calls=C.random,{}; C.random=function(s,n) calls[#calls+1]=n; local v=old(s,n); if n==100 then return roll+1 elseif n==2 then return boolean and 2 or 1 elseif n==65536 then return unit+1 end; return v end
 local ok,why=pcall(fn,calls); C.random=old; assert(ok,why)
end
local function count(s,id) local n=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,card in ipairs(pile)do if card.cardId==id then n=n+1 end end end;return n end
local function rolls(calls,start) local n=0;for i=start+1,#calls do if calls[i]==100 then n=n+1 end end;return n end

test('HP28-32 consumes its sample before opening roll and shuffle',function()
 observe(0,false,0,function(calls) local s=battle(nil,{'strike','defend','bash','anger'});eq(#calls,5);for i,v in ipairs({5,100,4,3,2})do eq(calls[i],v)end;eq(C.intent(s,1).id,'acid_slime_m_1') end)
 local seen={};for seed=1,64 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=28 and e.hp<=32);eq(e.maxHp,e.hp);seen[e.hp]=true end;for hp=28,32 do assert(seen[hp],'missing '..hp)end
end)
for _,case in ipairs({{0,'acid_slime_m_1'},{29,'acid_slime_m_1'},{30,'acid_slime_m_3'},{69,'acid_slime_m_3'},{70,'acid_slime_m_2'},{99,'acid_slime_m_2'}})do test('opening main roll '..case[1],function()
 observe(case[1],false,0,function(calls)local s=battle();eq(C.intent(s,1).id,case[2]);eq(#calls,2)end)
end)end

test('corrosive hit damages7 then creates Slimed1 before the next enemy',function()
 observe(0,false,0,function() local s=battle({'acid_slime_m','sneaky_gremlin'});local start=#s.events+1;assert(C.endTurn(s));eq(s.player.hp,64);eq(count(s,'slimed'),1)
 local hit,card,nextHit;for i=start,#s.events do local e=s.events[i];if e.kind=='damage' and e.detail.source==s.enemies[1].id then hit=i elseif e.kind=='cards_created' then card=i;eq(e.detail.cardId,'slimed');eq(e.detail.amount,1);eq(e.frame.player.hp,73) elseif e.kind=='damage' and e.detail.source==s.enemies[2].id then nextHit=i end end;assert(hit and card and nextHit and hit<card and card<nextHit)
 end)
end)
test('blocked corrosive hit still adds Slimed',function()observe(0,false,0,function()local s=battle();C.block(s,s.player,7,true);assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),1)end)end)
test('ordinary tackle hits10 without Slimed and cannot repeat',function()observe(30,false,65535,function(calls)local s=battle();local before=#calls;assert(C.endTurn(s));eq(s.player.hp,70);eq(count(s,'slimed'),0);eq(C.intent(s,1).id,'acid_slime_m_2');eq(rolls(calls,before),1);eq(calls[before+2],65536)end)end)
test('Weak1 survives its application round and stacks without refresh',function()observe(70,false,0,function()local s=battle();assert(C.endTurn(s));eq(s.player.hp,80);eq(s.player.statuses.weak,1);assert(C.endTurn(s));eq(s.player.statuses.weak,1);eq(C.intent(s,1).id,'acid_slime_m_1')end)end)
for _,boolean in ipairs({false,true})do test('two corrosive hits use unweighted Boolean '..tostring(boolean),function()observe(0,boolean,0,function(calls)local s=battle();assert(C.endTurn(s));local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,boolean and 'acid_slime_m_3' or 'acid_slime_m_2');eq(calls[before+1],100);eq(calls[before+2],2);eq(rolls(calls,before),1)end)end)end
for _,case in ipairs({{26214,'acid_slime_m_1'},{26215,'acid_slime_m_2'}})do test('repeat tackle uses 0.4f threshold at adapter value '..case[1],function()observe(30,false,case[1],function()local s=battle();assert(C.endTurn(s));eq(C.intent(s,1).id,case[2])end)end)end
for _,case in ipairs({{26214,'acid_slime_m_1'},{26215,'acid_slime_m_3'}})do test('two Weak moves use 0.4f threshold at adapter value '..case[1],function()observe(70,false,case[1],function()local s=battle();assert(C.endTurn(s));assert(C.endTurn(s));eq(C.intent(s,1).id,case[2])end)end)end

test('queued Slimed and roll survive retaliation only while another enemy lives',function()
 for _,solo in ipairs({false,true})do observe(0,false,0,function(calls)local s=battle(solo and {'acid_slime_m'} or {'acid_slime_m','shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(count(s,'slimed'),solo and 0 or 1);eq(rolls(calls,before),solo and 0 or 1);eq(s.phase,solo and 'victory' or 'player')end)end
end)
test('pre-turn poison death never attacks creates or rolls',function()observe(0,false,0,function(calls)local s=battle({'acid_slime_m','shield_gremlin'});C.addStatus(s.enemies[1],'poison',99);local before=#calls;assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),0);eq(#calls,before)end)end)
test('separate medium acid instances never share action history',function()observe(0,true,0,function()local s=battle({'acid_slime_m','acid_slime_m'});AI.advance(s,s.enemies[1],C.random);AI.advance(s,s.enemies[1],C.random);eq(C.intent(s,1).id,'acid_slime_m_3');eq(C.intent(s,2).id,'acid_slime_m_1');eq(s.enemies[2].acidLast,nil)end)end)
test('all primary rolls and 13 histories use only the required fallback kind',function()
 local Policy=require('abyss_acid_slime_m_ai')
 local ai={spitIntent='s',tackleIntent='t',weakIntent='w',spitCutoff=30,tackleCutoff=70,spitChance=0.4000000059604645}
 -- Each row gives literal low/mid/high outcomes. b: unweighted Boolean;
 -- p: probability fallback. Neither may be consumed on the ordinary branches.
 local cases={{nil,nil,'s','t','w'},{'s',nil,'s','t','w'},{'t',nil,'s','p','w'},{'w',nil,'s','t','w'},
 {'s','s','b','t','w'},{'s','t','s','t','w'},{'s','w','s','t','w'},
 {'t','s','s','p','w'},{'t','t','s','p','w'},{'t','w','s','p','w'},
 {'w','s','s','t','w'},{'w','t','s','t','w'},{'w','w','s','t','p'}}
 for _,h in ipairs(cases)do for r=0,99 do for _,flag in ipairs({false,true})do
  local mode=h[r<30 and 3 or (r<70 and 4 or 5)];local b,p=0,0
  local want=mode;if mode=='b' then want=flag and 't' or 'w' elseif mode=='p' then want=flag and 's' or (r<70 and 'w' or 't')end
  eq(Policy.choose(ai,h[1],h[2],r,function()b=b+1;return flag end,function()p=p+1;return flag and 0.4 or 0.4000000059604645 end),want)
  eq(b,mode=='b' and 1 or 0);eq(p,mode=='p' and 1 or 0)
 end end end
end)
print('ACID_SLIME_M '..passed..' passed; '..failed..' failed');assert(failed==0)
