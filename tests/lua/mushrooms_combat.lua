local F=dofile('tests/lua/support/mushrooms_fixture.lua');local Run,N,C,R=F.Run,F.N,F.C,F.R
local r,m=F.enter();local hp=C.copy(r);local queues=C.copy(r.relicPool);local q=C.copy(r.encounters)
assert(not r.nodeFlow.event.preparedCombat);local misc=R.snapshot(r.miscRng)
assert(N.chooseEvent(r,'fight'));F.eq(r.nodeFlow.event.stage,'pre_combat');assert(not r.combat)
local pre=r.nodeFlow.event.preparedCombat;F.eq(pre.source,'The Mushroom Lair');F.eq(#pre.prepared.actors,3);F.eq(pre.prepared.monsterHpRng.counter,3)
F.same(R.snapshot(r.miscRng),misc);F.same(r.relicPool,queues);F.same(r.encounters,q)
for _,e in ipairs(pre.prepared.actors)do assert(e.intentRoll==nil)end
local nextRng=R.cloneState(r.miscRng);local gold=R.randomIntBetween(nextRng,20,30)
assert(N.chooseEvent(r,'fight'));F.eq(r.phase,'combat');F.eq(#r.combat.enemies,3);F.eq(r.encounterSource,'The Mushroom Lair');F.eq(r.encounterTier,'normal')
F.eq(r.eventCombat.gold,gold);F.same(R.snapshot(r.miscRng),R.snapshot(nextRng));F.same(r.relicPool,queues);F.same(r.encounters,q)
for _,e in ipairs(r.combat.enemies)do F.eq(e.definitionId,'fungi_beast')end
local before=C.copy(r);assert(not N.chooseEvent(r,'fight'));F.same(r,before)
-- Controlled combat boundary proves reward plumbing, not a natural winning build.
for _,e in ipairs(r.combat.enemies)do e.hp=0 end
local Potion,Cards=require('abyss_potion_rewards'),require('abyss_card_pool');local oldP,oldC=Potion.prepare,Cards.prepareRewards;local order={}
Potion.prepare=function(...)order[#order+1]='potion';return oldP(...)end
Cards.prepareRewards=function(...)order[#order+1]='cards';return oldC(...)end
assert(Run.finishCombat(r));Potion.prepare,Cards.prepareRewards=oldP,oldC
F.eq(table.concat(order,','),'potion,cards');F.eq(r.phase,'reward');F.eq(r.rewards.gold,gold);F.eq(r.rewards.relics[1].id,'odd_mushroom')
assert(not F.owned(r,'odd_mushroom'));assert(Run.claimRelicReward(r,1));assert(F.owned(r,'odd_mushroom'));assert(not Run.claimRelicReward(r,1))
assert(Run.claimGoldReward(r));assert(Run.claimCardReward(r,0));assert(Run.leaveCombatRewards(r));assert(N.completeCombat(r,m));F.eq(r.phase,'map')
-- Public next battle publishes actual held SPECIAL into the Actor modifier.
assert(Run.startCombat(r,'cultist_solo'));local A=require('abyss_actor');r.combat.player.statuses.vulnerable=2
F.eq(A.attackAmount(r.combat,r.combat.enemies[1],r.combat.player,10,false),12)
F.eq(A.attackAmount(r.combat,r.combat.enemies[1],r.combat.player,10,true),10)
r.combat.enemies[1].statuses.vulnerable=2;F.eq(A.attackAmount(r.combat,r.combat.player,r.combat.enemies[1],10,false),15)
local detail=require('abyss_battle_status_view').statusDetail({id='vulnerable',amount=2},r.combat.rules,r.combat.player,r.combat);assert(detail:find('+25%%'))
print('MUSHROOMS_COMBAT_PASS 3 groups; two-stage timing/independent fixed reward/next-battle real modifier')
