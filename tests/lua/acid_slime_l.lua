-- Fixed-source AcidSlime_L A0 non-split contract; TASK-15.14.
-- Split is deliberately outside this slice; see its evidence ledger.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data,Run=require('abyss_combat'),require('abyss_data'),require('abyss_run')
local passed,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
local function test(name,f)local ok,why=pcall(f);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS 'or'FAIL ')..name..(ok and ''or': '..tostring(why)))end
local function battle(ids,deck,seed)return C.new(Data,{enemies=ids or {'acid_slime_l'},deck=deck or {'defend'},seed=seed or 42})end
local function observe(roll,boolean,unit,f)local old,calls=C.random,{};C.random=function(s,n)calls[#calls+1]=n;local v=old(s,n);if n==100 then return roll+1 elseif n==2 then return boolean and 2 or 1 elseif n==65536 then return unit+1 end;return v end;local ok,why=pcall(f,calls);C.random=old;assert(ok,why)end
local function count(s,id)local n=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do if c.cardId==id then n=n+1 end end end;return n end
local function primary(calls,start)local n=0;for i=(start or 0)+1,#calls do if calls[i]==100 then n=n+1 end end;return n end

test('HP65-69 actual Combat sampling and maxHp',function()local seen={};for seed=1,64 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=65 and e.hp<=69);eq(e.maxHp,e.hp);seen[e.hp]=true end;for hp=65,69 do assert(seen[hp],'missing HP '..hp)end end)
test('HP sample then primary roll before shuffle',function()observe(0,false,0,function(calls)battle(nil,{'strike','defend','bash','anger'});for i,n in ipairs({5,100,4,3,2})do eq(calls[i],n,'draw '..i)end;eq(#calls,5)end)end)
for _,case in ipairs({{0,'acid_slime_l_1'},{29,'acid_slime_l_1'},{30,'acid_slime_l_3'},{69,'acid_slime_l_3'},{70,'acid_slime_l_2'},{99,'acid_slime_l_2'}})do test('opening roll '..case[1]..' branch and draw count',function()observe(case[1],false,0,function(calls)local s=battle();eq(C.intent(s,1).id,case[2]);eq(primary(calls),1)end)end)end
test('Spit11 then Slimed2 before next enemy',function()observe(0,false,0,function()local s=battle({'acid_slime_l','sneaky_gremlin'});s.events={};assert(C.endTurn(s));eq(s.player.hp,60);eq(count(s,'slimed'),2);local damage,cards,nextHit;for i,e in ipairs(s.events)do if e.kind=='damage' and e.detail.source==s.enemies[1].id then damage=i elseif e.kind=='cards_created' then cards=i;eq(e.detail.cardId,'slimed');eq(e.detail.amount,2);eq(e.frame.player.hp,69) elseif e.kind=='damage' and e.detail.source==s.enemies[2].id then nextHit=i end end;assert(damage<cards and cards<nextHit)end)end)
test('fully blocked Spit11 still adds Slimed2',function()observe(0,false,0,function()local s=battle();C.block(s,s.player,11,true);assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),2)end)end)
test('Tackle16 no contamination then cannot repeat',function()observe(30,false,65535,function(calls)local s=battle();local before=#calls;assert(C.endTurn(s));eq(s.player.hp,64);eq(count(s,'slimed'),0);eq(C.intent(s,1).id,'acid_slime_l_2');eq(primary(calls,before),1);eq(calls[before+2],65536)end)end)
test('Weak2 runtime application with no damage',function()observe(70,false,0,function()local s=battle();assert(C.endTurn(s));eq(s.player.hp,80);eq(s.player.statuses.weak,2)end)end)
for _,flag in ipairs({false,true})do test('two Spits fallback unweighted Boolean '..tostring(flag),function()observe(0,flag,0,function(calls)local s=battle();assert(C.endTurn(s));local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,flag and 'acid_slime_l_3' or 'acid_slime_l_2');eq(calls[before+1],100);eq(calls[before+2],2)end)end)end
for _,case in ipairs({{26214,'acid_slime_l_1'},{26215,'acid_slime_l_2'}})do test('repeat Tackle 0.4f adapter threshold '..case[1],function()observe(30,false,case[1],function()local s=battle();eq(C.intent(s,1).id,'acid_slime_l_3');assert(C.endTurn(s));eq(C.intent(s,1).id,case[2])end)end)end
for _,case in ipairs({{26214,'acid_slime_l_1'},{26215,'acid_slime_l_3'}})do test('two Weak 0.4f adapter threshold '..case[1],function()observe(70,false,case[1],function()local s=battle();eq(C.intent(s,1).id,'acid_slime_l_2');assert(C.endTurn(s));assert(C.endTurn(s));eq(C.intent(s,1).id,case[2])end)end)end
test('dead source queued contamination and roll with live ally only',function()observe(0,false,0,function(calls)local s=battle({'acid_slime_l','shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(count(s,'slimed'),2);eq(primary(calls,before),1)end)end)
test('last-enemy death clears queued effects (negative control)',function()observe(0,false,0,function(calls)local s=battle();s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls;assert(C.endTurn(s));eq(s.phase,'victory');eq(count(s,'slimed'),0);eq(primary(calls,before),0)end)end)
test('pre-action poison death never damages or rolls (negative control)',function()observe(0,false,0,function(calls)local s=battle({'acid_slime_l','shield_gremlin'});C.addStatus(s.enemies[1],'poison',99);local before=#calls;assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),0);eq(primary(calls,before),0)end)end)
test('player death clears queued effects (negative control)',function()observe(0,false,0,function(calls)local s=battle();s.player.hp=1;local before=#calls;assert(C.endTurn(s));eq(s.phase,'defeat');eq(count(s,'slimed'),0);eq(primary(calls,before),0)end)end)
test('real Run large_acid encounter produces Slimed2',function()observe(0,false,0,function()local r=Run.new(Data,42);r.floor=4;assert(Run.startCombat(r,'large_acid'));assert(Run.endTurn(r));eq(count(r.combat,'slimed'),2)end)end)

local function force(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('missing intent '..id)
end
local function same(a,b)
 if type(a)~='table' then return eq(a,b)end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected field '..tostring(k))end
end

test('all 13 source histories and 100 rolls through runtime request only required fallbacks',function()
 -- Literal source oracle: low/middle/high branch; b is nextBoolean, p is nextFloat.
 local cases={{nil,nil,'s','t','w'},{'s',nil,'s','t','w'},{'t',nil,'s','p','w'},{'w',nil,'s','t','w'},
 {'s','s','b','t','w'},{'s','t','s','t','w'},{'s','w','s','t','w'},
 {'t','s','s','p','w'},{'t','t','s','p','w'},{'t','w','s','p','w'},
 {'w','s','s','t','w'},{'w','t','s','t','w'},{'w','w','s','t','p'}}
 local ids={s='acid_slime_l_1',t='acid_slime_l_3',w='acid_slime_l_2'}
 for _,h in ipairs(cases)do for roll=0,99 do for _,flag in ipairs({false,true})do
  observe(roll,flag,flag and 0 or 65535,function(calls)
   -- Keep five cards in the draw pile so the next owner turn does not shuffle
   -- newly generated Slimed; this matrix isolates only enemy AI requests.
   local deck=h[1] and {'defend','defend','defend','defend','defend','defend','defend','defend','defend','defend'} or nil
   local s=battle(nil,deck);local e=s.enemies[1];local start=0
   if h[1]then force(e,ids[h[1]]);e.acidLast=ids[h[2]];start=#calls;assert(C.endTurn(s))else start=1 end
   local mode=h[roll<30 and 3 or(roll<70 and 4 or 5)]
   local want=mode
   if mode=='b'then want=flag and't'or'w'elseif mode=='p'then want=flag and's'or(roll<70 and'w'or't')end
   eq(C.intent(s,1).id,ids[want]);eq(primary(calls,start),1)
   eq(calls[start+1],100)
   local extra=(mode=='b'or mode=='p')and 1 or 0
   eq(#calls-start,1+extra)
   if extra==1 then eq(calls[start+2],mode=='b'and 2 or 65536)end
   if h[1]then eq(e.acidLast,ids[h[1]]);eq(e.acidPrevious,ids[h[2]])end
  end)
 end end end
end)

test('Artifact blocks Weak2 without canceling next-move roll',function()
 observe(70,false,0,function(calls)local s=battle();C.addStatus(s.player,'artifact',1);local before=#calls
  assert(C.endTurn(s));eq(s.player.statuses.artifact,0);eq(s.player.statuses.weak or 0,0);eq(primary(calls,before),1)
 end)
end)

test('Weak2 applies then stacks and uses the established owner-round duration',function()
 observe(70,false,0,function()local s=battle();assert(C.endTurn(s));eq(s.player.statuses.weak,2)
  assert(C.endTurn(s));eq(s.player.statuses.weak,3);eq(C.intent(s,1).id,'acid_slime_l_1');eq(s.player.hp,80)
 end)
end)

test('large and medium histories and contamination counts remain per actor',function()
 observe(0,true,0,function()local s=battle({'acid_slime_l','acid_slime_m'});s.enemies[1].acidLast='acid_slime_l_1'
  assert(C.endTurn(s));eq(s.player.hp,62);eq(count(s,'slimed'),3)
  eq(C.intent(s,1).id,'acid_slime_l_3');eq(C.intent(s,2).id,'acid_slime_m_1')
  eq(s.enemies[1].acidPrevious,'acid_slime_l_1');eq(s.enemies[2].acidPrevious,nil)
 end)
end)

test('failed card preserves actor identity history random state and piles in place',function()
 observe(0,false,0,function()local s=battle();assert(C.endTurn(s));local uid
  for _,card in ipairs(s.hand)do if card.cardId=='defend'then uid=card.uid end end;assert(uid)
  local before=C.copy(s);local actor,hand,events=s.enemies[1],s.hand,s.events
  local old=C.block;C.block=function()error('ACID_L_INJECTED_FAILURE')end
  local ok,why=pcall(C.play,s,uid);C.block=old
  eq(ok,false);assert(tostring(why):find('ACID_L_INJECTED_FAILURE',1,true));same(s,before)
  eq(s.enemies[1],actor);eq(s.hand,hand);eq(s.events,events)
 end)
end)

test('Run temporary Slimed cards do not alter permanent deck and remain playable',function()
 observe(0,false,0,function()local r=Run.new(Data,42);r.floor=4;assert(Run.startCombat(r,'large_acid'))
  local deck=C.copy(r.deck);assert(Run.endTurn(r));same(r.deck,deck);eq(count(r.combat,'slimed'),2)
  local s=battle();assert(C.endTurn(s));local target
  for _,card in ipairs(s.hand)do if card.cardId=='slimed'then target=card;break end end;assert(target)
  assert(C.play(s,target.uid));eq(s.energy,2);eq(s.exhaust[1],target)
 end)
end)

print('ACID_SLIME_L '..passed..' passed; '..failed..' failed');assert(failed==0)

