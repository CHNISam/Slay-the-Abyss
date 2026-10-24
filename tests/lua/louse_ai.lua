local F=dofile('tests/lua/support/louse_ai_fixture.lua')
local C,Run,Data,AI=F.C,F.Run,F.Data,F.AI
local eq,same,test,battle,observe=F.eq,F.same,F.test,F.battle,F.observe

test('constructors sample HP then Bite per actor before all opening rolls, shuffle and Curl',function()
 local old,calls=C.random,{};local values={1,1,7,3,26,26,1,1,1,1,5};local ranges={6,3,7,3,100,100,4,3,2,5,5}
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
F.finish('LOUSE_AI')
