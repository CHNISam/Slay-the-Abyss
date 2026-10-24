-- Pinned A0 method facts, not original seeds or complete independent-stream parity.
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
-- Each color retains the full catalog, 128 seed samples and 800 decisions.
local function color(id,low,high)
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
local function finish(label)
 print(label..' '..passed..' passed; '..failed..' failed');assert(failed==0)
end
return {C=C,Run=Run,Data=Data,AI=AI,eq=eq,same=same,test=test,battle=battle,
 observe=observe,rolls=rolls,color=color,finish=finish}
