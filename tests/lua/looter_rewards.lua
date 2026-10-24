package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Combat,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local passed,failed=0,0
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function win(stolen)
 local r=Run.new(Data,42);assert(Run.startCombat(r,'cultist_solo'))
 -- Contract fixture only: a staged death ledger, not proof of real Looter stealing.
 if stolen then r.combat.stolenGoldReward=stolen end
 for _=1,30 do
  if r.phase~='combat' then break end
  for _=1,10 do
   if r.phase~='combat' then break end
   local c
   for _,x in ipairs(r.combat.hand) do if Combat.canPlay(r.combat,x.uid,1) then if not c or Combat.cardDefinition(r.combat,x).type=='attack' then c=x end end end
   if not c then break end; assert(Run.play(r,c.uid,1))
  end
  if r.phase=='combat' then assert(Run.endTurn(r)) end
 end
 eq(r.phase,'reward')
 assert(r.gold==99 and not r.rewards.goldClaimed);assert(Run.claimGoldReward(r))
 -- This prior contract suite isolates stolen gold/card ordering. Decline the
 -- newly available PR170 bottle explicitly; joint rewards have their own suite.
 if stolen and r.rewards.potion then assert(Run.skipPotionReward(r)) end
 return r
end
test('no-stolen real starter victory returns to map after an explicit bottle decision',function()
 local r=win();eq(r.gold,114);local seed=r.seed;assert(Run.claimCardReward(r,1))
 dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 eq(r.phase,'map');eq(r.seed,seed);eq(#r.deck,11)
end)
test('stolen contract creates separate unclaimed item, no immediate money',function()
 local r=win(30);eq(r.gold,114);assert(r.rewards.stolenGold,'missing separate stolen reward');eq(r.rewards.stolenGold.amount,30);eq(r.rewards.stolenGold.claimed,false);eq(r.rewards.manualContinue,true)
end)
test('card-first and stolen-first claims are independent and once-only',function()
 for _,first in ipairs({'card','gold'}) do local r=win(30);local seed=r.seed
  if first=='card' then assert(Run.claimCardReward(r,1));eq(r.phase,'reward');assert(Run.claimStolenGoldReward(r)) else assert(Run.claimStolenGoldReward(r));eq(r.phase,'reward');assert(Run.claimCardReward(r,1)) end
  eq(r.gold,144);eq(#r.deck,11);eq(r.seed,seed);eq(#Run.rewardOptions(r),0)
  eq(Run.claimCardReward(r,1),false);eq(Run.claimStolenGoldReward(r),false);eq(r.gold,144);assert(Run.leaveCombatRewards(r));eq(r.phase,'map');eq(Run.leaveCombatRewards(r),false)
 end
end)
test('skip does not forfeit stolen item; leave explicitly does',function()
 local r=win(30);assert(Run.claimCardReward(r,0));eq(r.phase,'reward');eq(r.gold,114);assert(Run.claimStolenGoldReward(r));eq(r.gold,144)
 r=win(30);assert(Run.leaveCombatRewards(r));eq(r.gold,114);eq(#r.deck,10);eq(r.rewards,nil)
end)
test('invalid and overflowing stolen claims reject before writes',function()
 for _,n in ipairs({-1,0,0.5,math.huge,0/0,2147483648}) do local r=win(30);r.rewards.stolenGold.amount=n;local item=r.rewards.stolenGold;local seed=r.seed;eq(Run.claimStolenGoldReward(r),false);eq(r.gold,114);eq(r.seed,seed);eq(item.claimed,false);eq(r.phase,'reward') end
 local r=win(30);r.gold=2147483640;eq(Run.claimStolenGoldReward(r),false);eq(r.gold,2147483640);eq(r.rewards.stolenGold.claimed,false)
end)
print('LOOTER_REWARDS '..passed..' passed '..failed..' failed');assert(failed==0)
