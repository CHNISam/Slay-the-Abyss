-- Fixed-source A0 Curl Up: ordered bottom tail, not a top damage reaction.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Run,Data=require('abyss_combat'),require('abyss_actor'),require('abyss_run'),require('abyss_data')
local passed,failed=0,0
local function eq(a,b,n)assert(a==b,(n or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
local function same(a,b)if type(a)~='table'then return eq(a,b)end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(n,f)local ok,why=pcall(f);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..n..(ok and '' or ': '..tostring(why)))end
local function battle(ids,deck)
 local s=C.new(Data,{enemies=ids or {'red_louse'},deck=deck or {'strike'},seed=42})
 for _,e in ipairs(s.enemies)do if e.ai and e.ai.kind=='louse'then e.statuses.curl_up=5 end;e.hp=30;e.maxHp=30 end
 s.events={};return s
end
local function play(s,id,target)for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid,target));return end end;error('missing '..id)end
local function sequence(s)
 local out={};for _,e in ipairs(s.events)do
  if e.kind=='damage'then out[#out+1]='hit:'..e.detail.target
  elseif e.kind=='block'then out[#out+1]='block:'..e.detail.target
  elseif e.kind=='status'then out[#out+1]=e.detail.status..':'..e.detail.target
  elseif e.kind=='status_damage'then out[#out+1]=e.detail.status..':'..e.detail.target end
 end;return table.concat(out,',')
end
for _,id in ipairs({'red_louse','green_louse'})do
 test(id..' receives visible actor-local 3-7 Curl in real Combat',function()
  local seen={};for seed=0,127 do local s=C.new(Data,{enemies={id},deck={'defend'},seed=seed});local e=s.enemies[1];local n=e.statuses.curl_up
   assert(n and n>=3 and n<=7);seen[n]=true;eq(e.block,0);local found=false;for _,v in ipairs(C.statusView(e))do if v.id=='curl_up'then found=true;eq(v.amount,n);eq(v.decay,'none');assert(v.description:find('格挡',1,true))end end;assert(found)
  end;for n=3,7 do assert(seen[n],'missing amount '..n)end
 end)
 test(id..' first nonlethal ordinary attack gains once then removes',function()
  local s=battle({id});local e=s.enemies[1];eq(C.damage(s,s.player,e,6),6);eq(e.hp,24);eq(e.block,5);eq(e.statuses.curl_up,0)
  eq(sequence(s),'hit:'..e.id..',block:'..e.id..',curl_up:'..e.id);e.block=0;C.damage(s,s.player,e,1);eq(e.block,0)
 end)
end
test('all constructors and opening rolls precede shuffle then both pre-battle draws',function()
 local old,calls=C.random,{};local ranges={6,3,7,3,100,100,4,3,2,5,5};local values={1,1,7,3,26,26,1,1,1,1,5}
 C.random=function(s,n)calls[#calls+1]=n;eq(n,ranges[#calls],'request '..#calls);old(s,n);return values[#calls]end
 local ok,why=pcall(function()local s=C.new(Data,{enemies={'red_louse','green_louse'},deck={'strike','defend','bash','anger'}});eq(#calls,#ranges);eq(s.enemies[1].hp,10);eq(s.enemies[2].hp,17);eq(s.enemies[1].statuses.curl_up,3);eq(s.enemies[2].statuses.curl_up,7)end)
 C.random=old;assert(ok,why)
end)
test('real Run pair has independent amounts and no opening Block',function()
 local r=Run.new(Data,42);assert(Run.startCombat(r,'louse_pair'));for _,e in ipairs(r.combat.enemies)do assert(e.statuses.curl_up>=3 and e.statuses.curl_up<=7);eq(e.block,0)end
 local s=r.combat;local second=s.enemies[2].statuses.curl_up;play(s,'strike',1);eq(s.enemies[1].statuses.curl_up,0);eq(s.enemies[2].statuses.curl_up,second)
end)
test('Curl is installed before the one-shot opening hook without resampling later',function()
 local called=0;local s=C.new(Data,{enemies={'red_louse'},deck={'defend'},beforeOpeningDraw=function(state)
  called=called+1;assert(state.enemies[1].statuses.curl_up>=3);eq(#state.hand,0);return true
 end});eq(called,1);local seed=s.seed;local amount=s.enemies[1].statuses.curl_up;C.intent(s,1);C.statusView(s.enemies[1]);eq(s.seed,seed);eq(s.enemies[1].statuses.curl_up,amount)
end)
for _,row in ipairs({{'zero',0,0,false,30},{'blocked',3,3,false,30},{'lethal',30,0,false,0},{'overkill',99,0,false,0},{'fixed',6,0,true,24}})do
 test(row[1]..' does not trigger or remove Curl',function()local s=battle();local e=s.enemies[1];e.block=row[3];C.damage(s,s.player,e,row[2],row[4]);eq(e.hp,row[5]);eq(e.statuses.curl_up,5);eq(e.block,0);eq(e.curlUpTriggered,nil)end)
end
test('partially blocked damage tests actual HP loss rather than attack base',function()local s=battle();local e=s.enemies[1];e.hp=4;e.block=10;C.damage(s,s.player,e,12);eq(e.hp,2);eq(e.block,5);eq(e.statuses.curl_up,0)end)
test('retaliation and poison cannot trigger Curl',function()
 local s=battle();local e=s.enemies[1];C.retaliate(s,s.player,e,1);eq(e.statuses.curl_up,5);eq(e.block,0);C.addStatus(e,'poison',1);A.startTurnEffects(s,e);eq(e.statuses.curl_up,5);eq(e.block,0)
end)
test('dead normal source cannot trigger Curl or damage the target',function()local s=battle();local e=s.enemies[1];s.player.hp=0;eq(C.damage(s,s.player,e,1),0);eq(e.hp,30);eq(e.block,0);eq(e.statuses.curl_up,5);eq(e.curlUpTriggered,nil)end)
test('two damage actions finish before one Curl Block',function()
 local s=battle(nil,{'twin_strike'});local e=s.enemies[1];play(s,'twin_strike',1);eq(e.hp,20);eq(e.block,5);eq(e.statuses.curl_up,0);eq(sequence(s),'hit:'..e.id..',hit:'..e.id..',block:'..e.id..',curl_up:'..e.id)
end)
test('later lethal hit cancels gain and removal without undoing one-shot latch',function()
 local s=battle({'red_louse','shield_gremlin'},{'twin_strike'});local e=s.enemies[1];e.hp=10;play(s,'twin_strike',1);eq(e.hp,0);eq(e.block,0);eq(e.statuses.curl_up,5);eq(e.curlUpTriggered,true);assert(not sequence(s):find('block:',1,true))
end)
test('last-enemy lethal second hit cannot gain postcombat Block',function()
 local s=battle(nil,{'twin_strike'});local e=s.enemies[1];e.hp=10;play(s,'twin_strike',1);eq(s.phase,'victory');eq(e.block,0);eq(e.statuses.curl_up,5);eq(e.curlUpTriggered,true)
end)
test('later card effects and card disposal precede Curl tail',function()
 local s=battle(nil,{'bash'});local e=s.enemies[1];play(s,'bash',1);eq(e.statuses.vulnerable,2);eq(e.block,5)
 eq(sequence(s),'hit:'..e.id..',vulnerable:'..e.id..',block:'..e.id..',curl_up:'..e.id)
 for _,event in ipairs(s.events)do if event.kind=='block'then eq(#event.frame.discard,1)end end
end)
test('standalone effect batches also defer until every queued effect',function()
 local s=battle();local e=s.enemies[1];C.applyEffects(s,{{op='damage',value=1},{op='damage',value=1},{op='block',value=3}},s.player,e)
 eq(e.hp,28);eq(e.block,5);eq(s.player.block,3);eq(sequence(s),'hit:'..e.id..',hit:'..e.id..',block:player,block:'..e.id..',curl_up:'..e.id)
end)
test('AoE Curl tails are FIFO while Angry and Thorns are TOP',function()
 local s=battle({'red_louse','green_louse'},{'cleave'});local a,b=s.enemies[1],s.enemies[2];C.addStatus(a,'angry',2);C.addStatus(b,'thorns',1);play(s,'cleave')
 eq(a.hp,22);eq(b.hp,22);eq(a.block,5);eq(b.block,5);eq(a.statuses.strength,2);eq(s.player.hp,79)
 eq(sequence(s),'hit:'..a.id..',hit:'..b.id..',thorns:player,strength:'..a.id..',block:'..a.id..',curl_up:'..a.id..',block:'..b.id..',curl_up:'..b.id)
end)
test('Spore TOP reaction and later AoE effects precede Curl tail',function()
 local s=battle({'red_louse','fungi_beast'},{'cleave'});local a,b=s.enemies[1],s.enemies[2];b.hp=8;play(s,'cleave');eq(s.player.statuses.vulnerable,2);eq(a.block,5)
 eq(sequence(s),'hit:'..a.id..',hit:'..b.id..',vulnerable:player,block:'..a.id..',curl_up:'..a.id)
end)
test('Sharp Hide queued at card use precedes Curl gain',function()
 local s=battle(nil,{'iron_wave'});local e=s.enemies[1];C.addStatus(e,'sharp_hide',4);play(s,'iron_wave',1);eq(s.player.hp,80);eq(s.player.block,1);eq(e.block,5)
 eq(sequence(s),'block:player,hit:'..e.id..',sharp_hide:player,block:'..e.id..',curl_up:'..e.id)
end)
test('power gain ignores Dexterity and Frail and respects 999 Block cap',function()
 local s=battle();local e=s.enemies[1];C.addStatus(e,'dexterity',99);C.addStatus(e,'frail',1);C.applyEffects(s,{{op='damage',value=1},{op='gainStatus',status='strength',value=1}},s.player,e);eq(e.block,5)
 local t=battle();local f=t.enemies[1];C.applyEffects(t,{{op='damage',value=1},{op='block',value=998}},f,f);eq(f.block,999)
end)
for _,status in ipairs({'thorns','sharp_hide'})do test('lethal '..status..' stops the pending Curl tail',function()
 local s=battle();local e=s.enemies[1];s.player.hp=1;C.addStatus(e,status,1);play(s,'strike',1);eq(s.phase,'defeat');eq(e.block,0);eq(e.statuses.curl_up,5);eq(e.curlUpTriggered,true)
end)end
test('failed card rolls back latch, pending tail, events, state and aliases',function()
 local s=battle();local e,statuses=s.enemies[1],s.enemies[1].statuses;s.catalog.cards.strike.effects={{op='damage',value=1},{op='gainStatus',status='missing',value=1}};local before=C.copy(s)
 eq(pcall(C.play,s,s.hand[1].uid,1),false);same(s,before);eq(s.enemies[1],e);eq(e.statuses,statuses)
 s.catalog.cards.strike.effects={{op='damage',value=1}};play(s,'strike',1);eq(e.block,5);eq(e.statuses.curl_up,0)
end)
test('power never reappears at later turn boundaries',function()local s=battle();local e=s.enemies[1];play(s,'strike',1);assert(C.endTurn(s));eq(e.block,0);eq(e.statuses.curl_up,0);C.damage(s,s.player,e,1);eq(e.block,0)end)
print('CURL_UP '..passed..' passed; '..failed..' failed');assert(failed==0)
