-- Pinned A0 method facts, not original seeds or full Curl Up/stream parity.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Data=require('abyss_combat'),require('abyss_run'),require('abyss_data')
local AI=require('abyss_enemy_ai')
local passed,failed=0,0
local function eq(a,b,n) assert(a==b,(n or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b) if type(a)~='table' then return eq(a,b) end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))end
local function battle(ids,deck,seed)return C.new(Data,{enemies=ids or {'red_louse'},deck=deck or {'defend'},seed=seed or 42})end
local function observe(roll,fn,bite)
 local old,calls=C.random,{};C.random=function(s,n)calls[#calls+1]=n;local v=old(s,n);if n==100 then return roll+1 elseif n==3 and bite then return bite-4 end;return v end
 local ok,why=pcall(fn,calls);C.random=old;assert(ok,why)
end
local function rolls(calls,start)local n=0;for i=(start or 0)+1,#calls do if calls[i]==100 then n=n+1 end end;return n end
local variants={{'red_louse',10,15},{'green_louse',11,17}}
for _,v in ipairs(variants)do local id,low,high=v[1],v[2],v[3]
 test(id..' HP and Bite are sampled once with independent endpoint coverage',function()
  local seenHp,seenBite={},{}
  for seed=0,127 do local s=battle({id},nil,seed);local e=s.enemies[1];local damage=e.intents[1].effects[1].value
   assert(e.hpRange,'HP range missing');assert(e.hp>=low and e.hp<=high);eq(e.hp,e.maxHp);assert(damage>=5 and damage<=7);seenHp[e.hp]=true;seenBite[damage]=true
  end
  for hp=low,high do assert(seenHp[hp],'missing HP '..hp)end;for damage=5,7 do assert(seenBite[damage],'missing Bite '..damage)end
 end)
 for _,row in ipairs({{0,2},{24,2},{25,1},{99,1}})do test(id..' opening boundary '..row[1],function()
  observe(row[1],function(calls)local s=battle({id});eq(C.intent(s,1).id,id..'_'..row[2]);eq(rolls(calls),1)end)
 end)end
 test(id..' A0 allows two support moves, but never three',function()
  observe(0,function(calls)local s=battle({id});for _,want in ipairs({2,1,2})do local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,id..'_'..want);eq(#calls-before,1);eq(rolls(calls,before),1)end
   if id=='red_louse' then eq(s.enemies[1].statuses.strength,6)else eq(s.player.statuses.weak,2)end
  end)
 end)
 test(id..' two Bites force support without resampling base damage',function()
  observe(99,function(calls)local s=battle({id});local e=s.enemies[1];local damage=e.intents[1].effects[1].value
   for _,want in ipairs({1,2,1})do local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,id..'_'..want);eq(#calls-before,1);eq(e.intents[1].effects[1].value,damage)end
   eq(s.player.hp,80-2*damage)
  end)
 end)
 test(id..' 800 controlled decisions honor each independent two-action history',function()
  local rows={{1,nil,2,1},{2,nil,2,1},{1,id..'_1',2,2},{2,id..'_2',1,1},{1,id..'_2',2,1},{2,id..'_1',2,1},{1,'other',2,1},{2,'other',2,1}}
  for _,row in ipairs(rows)do for roll=0,99 do local s=battle({id});local e=s.enemies[1];e.intentIndex=row[1];e.louseLast=row[2];local n=0
   AI.advance(s,e,function(_,max)eq(max,100);n=n+1;return roll+1 end);eq(n,1);eq(C.intent(s,1).id,id..'_'..(roll<25 and row[3] or row[4]));eq(e.lousePrevious,row[2]);eq(e.louseLast,id..'_'..row[1])
  end end
 end)
 test(id..' Bite uses sampled damage plus Strength, Weak and player Block',function()
  for _,row in ipairs({{5,0,0,0,5},{7,3,0,5,5},{7,3,1,0,7},{5,0,1,5,0}})do observe(99,function()
   local s=battle({id});local e=s.enemies[1];eq(C.intent(s,1).effects[1].value,row[1]);C.addStatus(e,'strength',row[2]);C.addStatus(e,'weak',row[3]);C.block(s,s.player,row[4],true)
   assert(C.endTurn(s));eq(s.player.hp,80-row[5]);eq(e.intents[1].effects[1].value,row[1])
  end,row[1])end
 end)
 test(id..' retaliation death consumes queued roll only with a living teammate',function()
  for _,solo in ipairs({false,true})do observe(99,function(calls)local s=battle(solo and {id} or {id,'shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local start=#calls
   assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(rolls(calls,start),solo and 0 or 1);eq(s.phase,solo and 'victory' or 'player')
  end)end
 end)
 test(id..' pre-turn poison death never takes a move or rolls',function()
  observe(99,function(calls)local s=battle({id,'shield_gremlin'});C.addStatus(s.enemies[1],'poison',99);local start=#calls;assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,80);eq(rolls(calls,start),0)end)
 end)
end

test('constructors sample HP then Bite per actor before all opening rolls and shuffle',function()
 local old,calls=C.random,{};local values={1,1,7,3,26,26,1,1,1};local ranges={6,3,7,3,100,100,4,3,2}
 C.random=function(s,n)calls[#calls+1]=n;eq(n,ranges[#calls],'request '..#calls);old(s,n);return values[#calls]end
 local ok,why=pcall(function()local s=battle({'red_louse','green_louse'},{'strike','defend','bash','anger'});eq(#calls,#ranges);eq(s.enemies[1].hp,10);eq(s.enemies[2].hp,17);eq(C.intent(s,1).effects[1].value,5);eq(C.intent(s,2).effects[1].value,7)end)
 C.random=old;assert(ok,why)
end)
test('two same-color actors own isolated sampled intents and detached previews',function()
 local old,calls=C.random,0;C.random=function(s,n)local v=old(s,n);if n==3 then calls=calls+1;return calls==1 and 1 or 3 elseif n==100 then return 100 end;return v end
 local ok,why=pcall(function()local s=battle({'red_louse','red_louse'});local first,second=s.enemies[1],s.enemies[2];eq(first.intents[1].effects[1].value,5);eq(second.intents[1].effects[1].value,7);eq(s.catalog.enemies.red_louse.intents[1].effects[1].value,6)
  local before=C.copy(s);C.intent(s,1).effects[1].value=99;same(s,before);AI.advance(s,first,C.random);eq(second.louseLast,nil);eq(second.intents[1].effects[1].value,7)
 end);C.random=old;assert(ok,why)
end)
test('real Run louse pair applies Red Strength3 and Green Weak2 before later Bites',function()
 observe(0,function()local r=Run.new(Data,42);assert(Run.startCombat(r,'louse_pair'));assert(Run.endTurn(r));local s=r.combat;eq(s.player.hp,80);eq(s.enemies[1].statuses.strength,3);eq(s.player.statuses.weak,2)
  s.enemies[1].intentIndex=1;s.enemies[2].intentIndex=1;local total=s.enemies[1].intents[1].effects[1].value+3+s.enemies[2].intents[1].effects[1].value
  assert(Run.endTurn(r));eq(s.player.hp,80-total);eq(s.player.statuses.weak,1)
 end)
end)
test('failed card restores actor histories and base values in place',function()
 observe(99,function()local s=battle();assert(C.endTurn(s));local e,intents=s.enemies[1],s.enemies[1].intents;s.catalog.cards.defend.effects={{op='draw',value=1},{op='gainStatus',status='missing',value=1}};local before=C.copy(s)
  eq(pcall(C.play,s,s.hand[1].uid,1),false);same(s,before);eq(s.enemies[1],e);eq(e.intents,intents)
 end)
end)
print('LOUSE_AI '..passed..' passed; '..failed..' failed');assert(failed==0)
