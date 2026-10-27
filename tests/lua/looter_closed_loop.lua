package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,A,D=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
-- Genuine Run, unmodified HP/damage/deck/relics/random. Floor is only the
-- existing encounter's legal entry prerequisite, not a claim of map traversal.
local function win()
 local r=R.new(D,1);r.floor=4;assert(R.startCombat(r,'looter_solo'))
 for _=1,100 do
  if r.phase~='combat' then break end
  local chosen
  for _,c in ipairs(r.combat.hand) do
   if C.canPlay(r.combat,c.uid,1) and (not chosen or C.cardDefinition(r.combat,c).type=='attack') then chosen=c end
  end
  if chosen then assert(R.play(r,chosen.uid,1)) else assert(R.endTurn(r)) end
 end
 eq(r.phase,'reward');eq(r.combat.enemies[1].hp,0);eq(r.combat.enemies[1].escaped,false)
 -- The complete ordinary catalog initializes the same seed's draw stream;
 -- this real starter replay now wins after two Mug actions, not three.
 eq(r.combat.turn,3);eq(r.rewards.stolenGold.amount,30);eq(r.gold,69);eq(r.combat.player.gold,69)
 eq(r.rewards.gold,15);assert(R.claimGoldReward(r));eq(r.gold,84)
 return r
end
for _,first in ipairs({'gold','card','skip','leave'}) do
 local r=win();local seed=r.seed;local old=r.combat;local uid=r.nextDeckUid
 if first=='leave' then assert(R.leaveCombatRewards(r));eq(r.gold,84)
 else
  if first=='gold' then assert(R.claimStolenGoldReward(r));assert(R.claimCardReward(r,1))
  else assert(R.claimCardReward(r,first=='skip' and 0 or 1));eq(r.phase,'reward');eq(r.gold,84);assert(R.claimStolenGoldReward(r)) end
  eq(r.gold,114);eq(r.phase,'reward');eq(R.claimStolenGoldReward(r),false);eq(R.claimCardReward(r,1),false)
  eq(r.nextDeckUid,uid+(first=='skip' and 0 or 1));assert(R.leaveCombatRewards(r))
 end
 eq(r.phase,'map');eq(r.seed,seed);eq(R.claimStolenGoldReward(r),false)
 local gold=r.gold;assert(R.startCombat(r,'looter_solo'));assert(r.combat~=old);eq(r.combat.player.gold,gold)
 eq(r.combat.enemies[1].stolenGold,0);eq(r.combat.stolenGoldReward,0);eq(r.combat.mugged,false)
 assert(R.endTurn(r));eq(r.gold,gold-15)
end
print('LOOTER_REAL_KILL_CLAIM_CROSS_NODE_PASS 4 orders')
-- Boundary fixtures below are explicit, not natural starter wins.
local r=R.new(D,42);r.floor=4;assert(R.startCombat(r,'looter_solo'));r.combat.player.hp=1;A.addStatus(r.combat.player,'thorns',100)
assert(R.endTurn(r));eq(r.phase,'defeat');eq(r.hp,0);eq(r.rewards,nil);eq(r.gold,84);eq(r.combat.stolenGoldReward,15);eq(r.victories,0)
print('LOOTER_SIMULTANEOUS_DEFEAT_PASS')
