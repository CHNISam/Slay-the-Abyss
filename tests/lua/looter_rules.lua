package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,R,A,D=require('abyss_combat'),require('abyss_run'),require('abyss_actor'),require('abyss_data')
local H=dofile('tests/lua/support/battle_action_fixture.lua');local test,finish=H.suite('LOOTER_RULES')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function battle(gold,enemies,seed) return C.new(D,{gold=gold,enemies=enemies or {'looter'},seed=seed or 42}) end
local function same(a,b) if type(a)~='table' then eq(a,b);return end;for k,v in pairs(a) do same(v,b[k]) end;for k in pairs(b) do assert(a[k]~=nil) end end
test('HP closed range and gold validation',function()
 local seen={};for seed=1,80 do local b=battle(99,nil,seed);local e=b.enemies[1];assert(e.hp>=44 and e.hp<=48);seen[e.hp]=true;eq(e.maxHp,e.hp);eq(b.player.gold,99);eq(e.statuses.thievery,15) end
 for n=44,48 do assert(seen[n]) end
 for _,n in ipairs({-1,0.5,math.huge,0/0,2147483648}) do eq(pcall(C.new,D,{gold=n}),false) end
end)
test('low gold and each-enemy ledger never overdraw',function()
 for _,gold in ipairs({0,8,20,99}) do local b=battle(gold,{'looter','looter'});assert(C.endTurn(b));local first=math.min(15,gold);local second=math.min(15,gold-first);eq(b.player.gold,gold-first-second);eq(b.enemies[1].stolenGold,first);eq(b.enemies[2].stolenGold,second) end
end)
test('fully blocked real starter Mug still steals',function()
 local r=R.new(D,3);r.floor=4;assert(R.startCombat(r,'looter_solo'));local plays=0
 for i=#r.combat.hand,1,-1 do local c=r.combat.hand[i];if c.cardId=='defend' and plays<2 then assert(R.play(r,c.uid));plays=plays+1 end end
 -- New HP/opening draw consumption may change the exact seed hand; this test requires a genuine two-Defend hand.
 eq(plays,2);assert(R.endTurn(r));eq(r.combat.player.hp,80);eq(r.gold,84)
end)
test('captured attack, exact thresholds, immediate and queued moves',function()
 local L=require('abyss_looter_ai')
 for _,sample in ipairs({32768,32769}) do local b=battle(99);local e=b.enemies[1];local ai=e.ai;e.looterSlashCount=1
  local old=e.intents[e.intentIndex];local calls=0;L.beforeAction(b,e,function(_,max) eq(max,65536);calls=calls+1;return sample end,old)
  eq(calls,1);eq(old.id,ai.mugIntent)
  if sample==32768 then eq(e.intents[e.intentIndex].id,ai.smokeIntent);eq(e.looterQueuedIntent,nil)
  else eq(e.intents[e.intentIndex].id,ai.mugIntent);eq(e.looterQueuedIntent,ai.lungeIntent);L.afterAction(b,e);eq(e.intents[e.intentIndex].id,ai.lungeIntent) end
 end
end)
test('RNG occurs before lethal attack and lethal retaliation; queued SetMove survives with companion',function()
 local b=battle(99,{'looter','cultist'});local e=b.enemies[1];A.addStatus(b.player,'thorns',100);local rnd=C.random;local seen=false
 C.random=function(s,max) if max==65536 then seen=true;eq(e.hp,e.maxHp);eq(s.player.hp,80) end;return rnd(s,max) end
 local ok,err=pcall(C.endTurn,b);C.random=rnd;assert(ok,err);assert(seen);eq(e.hp,0);eq(e.looterQueuedIntent,nil);eq(b.stolenGoldReward,15);eq(b.player.gold,84);eq(b.phase,'player')
 b=battle(99);b.player.hp=1;local before=b.seed;assert(C.endTurn(b));eq(b.phase,'defeat');assert(b.seed~=before);eq(b.player.gold,84)
end)
test('death registers once for ordinary damage, poison, retaliation and fixed bottle path',function()
 for _,kind in ipairs({'damage','poison','thorns','potion'}) do local r=R.new(D,42);r.floor=4;assert(R.startCombat(r,'looter_solo'));assert(R.endTurn(r));local b,e=r.combat,r.combat.enemies[1]
  if kind=='damage' then C.damage(b,b.player,e,100);assert(R.finishCombat(r))
  elseif kind=='poison' then A.addStatus(e,'poison',100);assert(R.endTurn(r))
  elseif kind=='thorns' then A.addStatus(b.player,'thorns',100);assert(R.endTurn(r))
  else C.damage(b,b.player,e,e.hp-1);assert(R.obtainPotion(r,'fire_potion'));assert(R.usePotion(r,1,1)) end
  local expected=kind=='thorns' and 30 or 15;eq(r.rewards.stolenGold.amount,expected);eq(b.stolenGoldReward,expected);eq(r.gold,114-expected);e=b.enemies[1];C.damage(b,b.player,e,100);eq(b.stolenGoldReward,expected);assert(R.claimStolenGoldReward(r));eq(r.gold,114)
 end
end)
test('escaped actor retains identity and HP but cannot be hit, selected, buffed or act',function()
 local b=battle(99,{'looter','cultist'});local e=b.enemies[1];for i,v in ipairs(e.intents) do if v.id==e.ai.escapeIntent then e.intentIndex=i end end -- explicit escape-state boundary fixture
 assert(C.escapeEnemy(b,e));eq(b.enemies[1],e);assert(e.hp>0);eq(C.outcome(b),nil);eq(C.intent(b,1),nil);eq(C.damage(b,b.player,e,100),0);eq(A.applyPower(b,e,'poison',2,b.player),false)
 for _,card in ipairs(b.hand) do if card.cardId=='strike' then eq(C.canPlay(b,card.uid,1),false) end end
 local gold=b.player.gold;assert(C.endTurn(b));eq(b.player.gold,gold);eq(e.stolenGold,0);eq(b.stolenGoldReward,0)
end)
test('failed card restores new fields RNG references and event journal',function()
 for _,command in ipairs({'play'}) do local b=battle(99);local e=b.enemies[1];local before=C.copy(b);local events=b.events;local hand=b.hand;local statuses=e.statuses;local old
  if command=='endTurn' then old=C.stealGold;C.stealGold=function(...) old(...);error('injected after steal') end
  else old=C.applyEffects;C.applyEffects=function(s,...) s.player.gold=0;s.stolenGoldReward=13;e.stolenGold=9;e.escaped=true;C.random(s,100);error('injected after mutation') end end
  local uid;for _,c in ipairs(b.hand) do if C.canPlay(b,c.uid,1) then uid=c.uid;break end end
  local ok=pcall(command=='play' and C.play or C.endTurn,b,uid,1)
  if command=='endTurn' then C.stealGold=old else C.applyEffects=old end
  eq(ok,false);same(b,before);eq(b.enemies[1],e);eq(b.events,events);eq(b.hand,hand);eq(e.statuses,statuses)
 end
end)
finish()
