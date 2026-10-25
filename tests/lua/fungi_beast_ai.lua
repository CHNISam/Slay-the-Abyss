-- FungiBeast A0 HP/decisions only; the source ledger keeps Spore Cloud separate.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Data=require('abyss_combat'),require('abyss_run'),require('abyss_data')
local AI=require('abyss_enemy_ai')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b) if type(a)~='table' then return eq(a,b) end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why))) end
local function battle(ids,deck,seed) return C.new(Data,{enemies=ids or {'fungi_beast'},deck=deck or {'defend'},seed=seed or 42}) end
local function observe(roll,fn,hp)
 local old,calls=C.random,{};C.random=function(s,n) calls[#calls+1]=n;local v=old(s,n);if n==100 then return roll+1 elseif n==7 and hp then return hp end;return v end
 local ok,why=pcall(fn,calls);C.random=old;assert(ok,why)
end
local function rolls(calls,start) local n=0;for i=start+1,#calls do if calls[i]==100 then n=n+1 end end;return n end

test('HP22-28 sampling precedes opening AI draw and shuffle',function()
 for _,edge in ipairs({1,7})do observe(0,function(calls)
  local s=battle(nil,{'strike','defend','bash','anger'});eq(s.enemies[1].hp,21+edge);eq(s.enemies[1].maxHp,21+edge)
  eq(#calls,5);for i,v in ipairs({7,100,4,3,2})do eq(calls[i],v,'request '..i)end
 end,edge)end
 local seen={};for seed=1,64 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=22 and e.hp<=28);eq(e.hp,e.maxHp);seen[e.hp]=true end
 for hp=22,28 do assert(seen[hp],'missing HP '..hp)end
end)
for _,row in ipairs({{0,'fungi_beast_1'},{59,'fungi_beast_1'},{60,'fungi_beast_2'},{99,'fungi_beast_2'}})do test('opening boundary '..row[1],function()
 observe(row[1],function(calls)local s=battle();eq(C.intent(s,1).id,row[2]);eq(rolls(calls,0),1)end)
end)end
test('Bite deals six and two Bites force Grow, each action consumes one roll',function()
 observe(0,function(calls)local s=battle()
  for turn,want in ipairs({'fungi_beast_1','fungi_beast_2','fungi_beast_1'})do local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,want);eq(rolls(calls,before),1)end
  eq(s.player.hp,68);eq(s.enemies[1].statuses.strength,3)
 end)
end)
test('Grow grants three Strength and cannot repeat despite a second high roll',function()
 observe(99,function(calls)local s=battle();local before=#calls;assert(C.endTurn(s));eq(rolls(calls,before),1);eq(C.intent(s,1).id,'fungi_beast_1');eq(s.player.hp,80);eq(s.enemies[1].statuses.strength,3)
  before=#calls;assert(C.endTurn(s));eq(rolls(calls,before),1);eq(s.player.hp,71);eq(C.intent(s,1).id,'fungi_beast_2')
 end)
end)
test('Bite observes existing Block, Weak and Strength through real damage resolution',function()
 for _,row in ipairs({{5,0,0,1},{6,0,0,0},{0,1,0,4},{5,0,3,4}})do
  observe(0,function()local s=battle();C.block(s,s.player,row[1],true);C.addStatus(s.enemies[1],'weak',row[2]);C.addStatus(s.enemies[1],'strength',row[3]);local start=#s.events+1
   assert(C.endTurn(s));eq(s.player.hp,80-row[4]);local damage
   for i=start,#s.events do local event=s.events[i];if event.kind=='damage' and event.detail.source==s.enemies[1].id then damage=event;eq(event.detail.amount,row[4]);eq(event.detail.target,'player')end end
   assert(damage,'missing real damage event')
  end)
 end
end)
test('900 controlled post-action rolls use independent history-specific outcomes',function()
 local cases={{1,nil,'a','g'},{2,nil,'a','a'},{1,'fungi_beast_1','g','g'},{2,'fungi_beast_2','a','a'},{1,'fungi_beast_2','a','g'},{2,'fungi_beast_1','a','a'},{1,'other','a','g'},{2,'other','a','a'},{1,'','a','g'}}
 local s=battle();local original=C.copy(s.enemies[1]);local seed=s.seed
 for _,row in ipairs(cases)do for roll=0,99 do
  local e=C.copy(original);s.enemies={e};s.events={};e.intentIndex=row[1];e.fungiLast=row[2];local calls=0
  AI.advance(s,e,function(_,n)eq(n,100);calls=calls+1;return roll+1 end)
  local want=roll<60 and row[3] or row[4];eq(C.intent(s,1).id,want=='a' and 'fungi_beast_1' or 'fungi_beast_2');eq(calls,1)
  eq(e.fungiLast,row[1]==1 and 'fungi_beast_1' or 'fungi_beast_2');eq(e.fungiPrevious,row[2])
  eq(s.seed,seed);eq(s.player.hp,80);eq(next(s.player.statuses),nil)
 end end
end)
test('two actual fungi independently retain their own action histories',function()
 observe(0,function(calls)local s=battle({'fungi_beast','fungi_beast'});eq(rolls(calls,0),2);local e=s.enemies[1]
  AI.advance(s,e,C.random);AI.advance(s,e,C.random);eq(C.intent(s,1).id,'fungi_beast_2');eq(C.intent(s,2).id,'fungi_beast_1');eq(s.enemies[2].fungiLast,nil)
  local before=#calls;assert(C.endTurn(s));eq(rolls(calls,before),2);eq(s.player.hp,74);eq(e.statuses.strength,3);eq(s.enemies[2].statuses.strength or 0,0)
 end)
end)
test('queued roll survives lethal retaliation only while a teammate remains',function()
 for _,solo in ipairs({false,true})do observe(0,function(calls)
  local s=battle(solo and {'fungi_beast'} or {'fungi_beast','shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls
  assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.phase,solo and 'victory' or 'player');eq(rolls(calls,before),solo and 0 or 1)
 end)end
end)
test('pre-turn poison death never acts or consumes a queued roll',function()
 observe(0,function(calls)local s=battle({'fungi_beast','shield_gremlin'});C.addStatus(s.enemies[1],'poison',99);local before=#calls
  assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,80);eq(rolls(calls,before),0)
 end)
end)
test('real Run fungi encounter starts with two independently sampled Grow intents',function()
 observe(99,function(calls)local r=Run.new(Data,42);r.floor=5;assert(Run.startCombat(r,'fungi_pair'));eq(#r.combat.enemies,2)
  for _,e in ipairs(r.combat.enemies)do assert(e.hp>=22 and e.hp<=28)end;eq(C.intent(r.combat,1).id,'fungi_beast_2');eq(C.intent(r.combat,2).id,'fungi_beast_2')
  local before=#calls;assert(Run.endTurn(r));eq(r.combat.player.hp,80);eq(rolls(calls,before),2);for _,e in ipairs(r.combat.enemies)do eq(e.statuses.strength,3)end
 end)
end)
test('failed card action restores existing fungi histories and shared random state',function()
 observe(0,function()local s=battle();assert(C.endTurn(s));s.catalog.cards.defend.effects={{op='draw',value=1},{op='gainStatus',status='missing',value=1}}
  local before=C.copy(s);assert(not pcall(C.play,s,s.hand[1].uid,1));same(s,before)
 end)
end)
print('FUNGI_BEAST_AI '..passed..' passed; '..failed..' failed');assert(failed==0)
