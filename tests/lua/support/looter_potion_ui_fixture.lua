local H=dofile('tests/lua/support/battle_action_fixture.lua')
local Run,C,Theme=require('abyss_run'),require('abyss_combat'),require('abyss_theme')
local function reward(manual)
 local h,u,p,e,t,d=H.setup();h.run=Run.new(H.F.Data,42);h.battleUI.run=h.run
 assert(Run.startCombat(h.run,'cultist_solo'))
 -- Terminal/ledger fixture isolates the real generated controller.
 for _,enemy in ipairs(h.run.combat.enemies) do enemy.hp=0 end
 if manual then h.run.combat.stolenGoldReward=30 end
 assert(Run.finishCombat(h.run));h:refresh();assert(h.run.rewards.potion)
 return h,u,p,e,t,d
end
-- Each entry runs one half of the same 50-case Cartesian product. Every case
-- still creates its own full generated UI tree and seed-42 reward fixture.
local function changedRewardActions(released)
 for _,name in ipairs({'card1','skip','stolenGold','claimPotion','skipPotion'}) do
  for _,change in ipairs({'cards','choice','amount','type','mode'}) do
   local h,u,p,e=reward(true);local run=h.run;local gold,uid=run.gold,run.nextDeckUid
   e(name,'down',1);if released then e(name,'up',1) end
   if change=='cards' then run.rewards.cards=C.copy(run.rewards.cards)
   elseif change=='choice' then run.rewards.cards[2]='strike'
   elseif change=='amount' then run.rewards.stolenGold.amount=31
   elseif change=='type' then run.rewards.stolenGold.type='GOLD'
   else run.rewards.manualContinue=false end
   if not released then e(name,'up',1) end;e(name,'click',1)
   assert(run.phase=='reward' and run.gold==gold and run.nextDeckUid==uid and not run.rewards.cardResolved
    and not run.rewards.stolenGold.claimed and not run.rewards.potion.resolved,name..' '..change)
  end
 end
end
return {Run=Run,C=C,Theme=Theme,reward=reward,changedRewardActions=changedRewardActions}
