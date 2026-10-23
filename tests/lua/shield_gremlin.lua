-- Independent A0 Shield Gremlin expectations from the fixed source ledger.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C,Run,Data=require('abyss_combat'),require('abyss_run'),require('abyss_data')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b) if type(a)~='table' then return eq(a,b) end; for k,v in pairs(a) do same(v,b[k]) end;for k in pairs(b) do assert(a[k]~=nil) end end
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why))) end
local function battle(ids,deck,seed) return C.new(Data,{enemies=ids or {'shield_gremlin'},deck=deck or {'defend'},seed=seed or 42}) end
local function observe(fn,pick)
 local old,calls=C.random,{}; C.random=function(s,n) calls[#calls+1]=n;local v=old(s,n);if pick and n==2 then return pick end;return v end
 local ok,err=pcall(fn,calls);C.random=old;assert(ok,err)
end
local function ranges(a,b) eq(#a,#b,'draw count');for i,v in ipairs(b) do eq(a[i],v,'range '..i) end end
local function protect(s,index) local e=s.enemies[index];C.applyEffects(s,e.intents[1].effects,e,s.player) end

test('HP12-15 and one inherited opening main roll precede shuffle',function()
 observe(function(calls) local s=battle(nil,{'strike','defend','bash','anger'});ranges(calls,{4,100,4,3,2});eq(C.intent(s,1).id,'shield_gremlin_1') end)
 local seen={};for seed=1,32 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=12 and e.hp<=15);eq(e.maxHp,e.hp);seen[e.hp]=true end
 for hp=12,15 do assert(seen[hp],'missing HP '..hp) end
end)
test('alone opens Protect7 with zero target draws then permanently Bash6',function()
 observe(function(calls) local s=battle();local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].block,7);eq(s.player.hp,80);eq(#calls,before);eq(C.intent(s,1).id,'shield_gremlin_2')
 for turn=1,4 do assert(C.endTurn(s));eq(s.player.hp,80-6*turn);eq(s.enemies[1].block,0);eq(C.intent(s,1).id,'shield_gremlin_2');eq(#calls,before) end end)
end)
for _,order in ipairs({{'shield_gremlin','sneaky_gremlin'},{'sneaky_gremlin','shield_gremlin'}}) do
 test('Protect survives ally turn at slot '..(order[1]=='shield_gremlin' and '2' or '1'),function()
 observe(function(calls) local s=battle(order);local owner=order[1]=='shield_gremlin' and 1 or 2;local ally=3-owner;local before=#calls
 for turn=1,3 do assert(C.endTurn(s));eq(s.enemies[owner].block,0);eq(s.enemies[ally].block,7);eq(C.intent(s,owner).id,'shield_gremlin_1');eq(s.player.hp,80-9*turn);eq(#calls,before+turn);eq(calls[#calls],1) end end)
 end)
end
for _,pick in ipairs({1,2}) do test('random ally endpoint '..pick..' follows enemy list order and excludes owner',function()
 observe(function(calls) local s=battle({'sneaky_gremlin','shield_gremlin','mad_gremlin'});local before=#calls;protect(s,2);eq(#calls,before+1);eq(calls[#calls],2);eq(s.enemies[2].block,0);eq(s.enemies[pick==1 and 1 or 3].block,7);eq(s.enemies[pick==1 and 3 or 1].block,0) end,pick)
end) end
test('dead ally excluded without compacting enemy identity',function()
 observe(function(calls) local s=battle({'shield_gremlin','mad_gremlin','sneaky_gremlin'});s.enemies[2].hp=0;local before=#calls;protect(s,1);eq(#calls,before+1);eq(calls[#calls],1);eq(s.enemies[1].block,0);eq(s.enemies[2].block,0);eq(s.enemies[3].block,7) end)
end)
test('an escape intent is not a Protect target and empty list has no draw',function()
 observe(function(calls) local s=battle({'shield_gremlin','sneaky_gremlin'});s.enemies[2].intents[s.enemies[2].intentIndex].kind='escape';local before=#calls;protect(s,1);eq(#calls,before);eq(s.enemies[1].block,7);eq(s.enemies[2].block,0) end)
end)
test('last ally killed by actual Strike leaves current Protect before permanent Bash',function()
 local s=battle({'shield_gremlin','sneaky_gremlin'},{'strike'});s.enemies[2].hp=6;assert(C.play(s,s.hand[1].uid,2));eq(s.enemies[2].hp,0);eq(C.intent(s,1).id,'shield_gremlin_1');assert(C.endTurn(s));eq(s.enemies[1].block,7);eq(C.intent(s,1).id,'shield_gremlin_2');assert(C.endTurn(s));eq(s.player.hp,74);assert(C.endTurn(s));eq(s.player.hp,68)
end)
test('ally poison resolves before Shield targets or counts living allies',function()
 observe(function(calls) local s=battle({'shield_gremlin','sneaky_gremlin'});C.addStatus(s.enemies[2],'poison',99);local before=#calls;assert(C.endTurn(s));eq(s.enemies[2].hp,0);eq(s.enemies[1].block,7);eq(s.player.hp,80);eq(C.intent(s,1).id,'shield_gremlin_2');eq(#calls,before) end)
end)
test('an earlier ally killed by Thorns leaves self Protect without target draw',function()
 observe(function(calls) local s=battle({'sneaky_gremlin','shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.enemies[2].block,7);eq(C.intent(s,2).id,'shield_gremlin_2');eq(#calls,before) end)
end)
test('dead Shield never grants Block or draws a target',function()
 observe(function(calls) local s=battle({'shield_gremlin','sneaky_gremlin'});C.addStatus(s.enemies[1],'poison',99);local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.enemies[2].block,0);eq(#calls,before);eq(s.player.hp,71) end)
end)
test('Protect uses fixed seven and obeys shared 999 Block cap',function()
 local s=battle({'shield_gremlin','sneaky_gremlin'});local a=s.enemies[2];C.addStatus(a,'dexterity',20);C.addStatus(a,'frail',2);a.block=997;protect(s,1);eq(a.block,999);eq(s.enemies[1].block,0)
end)
test('two Shield instances protect each other without sharing decisions',function()
 observe(function(calls) local s=battle({'shield_gremlin','shield_gremlin'});local before=#calls;assert(C.endTurn(s));eq(s.enemies[1].block,7);eq(s.enemies[2].block,7);eq(#calls,before+2);eq(C.intent(s,1).id,'shield_gremlin_1');eq(C.intent(s,2).id,'shield_gremlin_1') end)
end)
test('Bash stays Bash if an ally appears after the solo transition',function()
 local s=battle();assert(C.endTurn(s));local ally=battle({'sneaky_gremlin'}).enemies[1];s.enemies[2]=ally;assert(C.endTurn(s));eq(C.intent(s,1).id,'shield_gremlin_2');eq(s.enemies[1].block,0);eq(ally.block,0);eq(s.player.hp,65)
end)
test('all enemy Block resets precede first poison presentation frame',function()
 local s=battle({'sneaky_gremlin','mad_gremlin'});for _,e in ipairs(s.enemies) do e.block=9 end;C.addStatus(s.enemies[1],'poison',1);local start=#s.events+1;assert(C.endTurn(s));local poison
 for i=start,#s.events do local e=s.events[i];if e.kind=='status_damage' and e.detail.status=='poison' then poison=e;break end end
 assert(poison,'poison frame');eq(poison.frame.enemies[1].block,0);eq(poison.frame.enemies[2].block,0)
end)
test('all poison resolves before any living enemy action',function()
 local s=battle({'sneaky_gremlin','mad_gremlin'});C.addStatus(s.enemies[2],'poison',1);local hp=s.enemies[2].hp;local start=#s.events+1;assert(C.endTurn(s));local first
 for i=start,#s.events do local e=s.events[i];if e.kind=='intent' then first=e;break end end
 assert(first);eq(first.frame.enemies[2].hp,hp-1)
end)
test('group preturn retains Barricade and stops entirely on poison victory',function()
 observe(function(calls) local s=battle({'sneaky_gremlin','mad_gremlin'});C.addStatus(s.enemies[1],'barricade',1);s.enemies[1].block=9;s.enemies[2].block=9
 for _,e in ipairs(s.enemies) do C.addStatus(e,'poison',99) end;local start=#s.events+1;local before=#calls;assert(C.endTurn(s));eq(s.phase,'victory');eq(s.enemies[1].block,9);eq(s.enemies[2].block,0);eq(#calls,before)
 for i=start,#s.events do assert(s.events[i].kind~='intent','action after all-enemy poison death') end end)
end)
test('later poison death makes Fat retaliation final and clears queued Weak and roll',function()
 observe(function(calls) local s=battle({'fat_gremlin','cultist'});s.enemies[1].hp=1;s.enemies[2].hp=1;C.addStatus(s.enemies[2],'poison',1);C.addStatus(s.player,'thorns',1);local before=#calls
 assert(C.endTurn(s));eq(s.phase,'victory');eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,0);eq(s.player.statuses.weak or 0,0);eq(#calls,before) end)
end)
test('first enemy lethal attack cannot suppress a later enemy preturn poison',function()
 local s=battle({'sneaky_gremlin','mad_gremlin'});s.player.hp=1;local hp=s.enemies[2].hp;C.addStatus(s.enemies[2],'poison',1);assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.enemies[2].hp,hp-1);eq(s.enemies[2].statuses.poison,0)
end)
test('Run gang uses Protect on one real teammate and no self shield',function()
 local r=Run.new(Data,42);r.floor=5;assert(Run.startCombat(r,'gremlin_gang'));assert(Run.endTurn(r));local s=r.combat;local total=0;for i=1,4 do total=total+s.enemies[i].block end;eq(total,7);eq(s.enemies[5].block,0);eq(C.intent(s,5).id,'shield_gremlin_1')
end)
test('failed player action restores Shield decision RNG and effects',function()
 local s=battle({'shield_gremlin','sneaky_gremlin'});s.catalog.cards.defend.effects={{op='draw',value=1},{op='gainStatus',status='missing',value=1}};local before=C.copy(s);assert(not pcall(C.play,s,s.hand[1].uid,1));same(s,before)
end)
print('SHIELD_GREMLIN '..passed..' passed; '..failed..' failed');assert(failed==0)
