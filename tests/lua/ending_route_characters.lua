local F=dofile('tests/lua/support/ending_route_fixture.lua')
local Run,Nodes,C,R=F.Run,F.Nodes,F.C,F.R
local role=ABYSS_MUTATION_CASE or 'ironclad'
assert(role=='ironclad'or role=='silent'or role=='defect'or role=='watcher','select one bounded character route')
local run,map=F.eliteWon(role);local original={}
for i,card in ipairs(run.deck)do original[i]={uid=card.uid,cardId=card.cardId}end
assert(run.character==role)
assert(Run.finishCombat(run));assert(run.phase=='reward')
local reward=run.rewards;local gold=run.gold
assert(reward.gold>=25 and reward.gold<=35 and #reward.relics==1 and #reward.cards==3)
assert(not reward.emeraldKey)
assert(Run.claimGoldReward(run));assert(run.gold==gold+reward.gold)
assert(Run.claimRelicReward(run,1));assert(reward.relics[1].unavailable~=true)
assert(Run.claimCardReward(run,1));assert(#run.deck==#original+1)
if reward.potion then assert(Run.claimPotionReward(run))end
assert(Run.leaveCombatRewards(run));assert(Nodes.completeCombat(run,map))
F.enter(run,map,55)
assert(run.character==role and #run.combat.enemies==1 and run.encounterSource=='The Heart')
assert(run.combat.enemies[1].definitionId=='corrupt_heart'and run.combat.monsterHpRng.counter==1)
local hp=run.combat.enemies[1].hp;assert(hp==750)
assert(run.combat.roomSeed=='97') -- raw seed42 + destination55, not an Act3/legacy stream.
local expectedHp,expectedAi,expectedCards,expectedShuffle=R.fromSeed('97'),R.fromSeed('97'),R.fromSeed('97'),R.fromSeed('97')
R.randomInt(expectedHp,0);R.randomInt(expectedAi,99)
R.shuffle(expectedShuffle,{}) -- CardGroup.shuffle spends exactly one nextLong even on an empty group.
local initialDrawSize=#run.combat.draw
-- Three controlled NORMAL hits still traverse Invincible and two real enemy
-- rounds. No enemy HP write or hypothetical core victory substitutes for this.
for hit=1,3 do
 local battle=run.combat;C.damage(battle,battle.player,battle.enemies[1],999,false)
 if hit<3 then
  assert(battle.enemies[1].hp==750-300*hit)
  if role=='defect'then R.randomInt(expectedCards,0)end -- real CrackCore lightning targets the single Heart.
  if hit==1 then
   for inserted=0,4 do R.randomInt(expectedCards,initialDrawSize+inserted-1)end
  end
  R.randomInt(expectedAi,99);if hit==1 then R.randomBoolean(expectedAi)end
  assert(Run.endTurn(run))
 end
end
assert(C.outcome(run.combat)=='victory'and run.combat.player.hp>0)
F.same(R.snapshot(run.combat.monsterHpRng),R.snapshot(expectedHp))
F.same(R.snapshot(run.combat.aiRng),R.snapshot(expectedAi))
F.same(R.snapshot(run.combat.cardRandomRng),R.snapshot(expectedCards))
F.same(R.snapshot(run.combat.shuffleRng),R.snapshot(expectedShuffle))
local misc=R.cloneState(run.combat.miscRng);R.randomIntBetween(misc,-5,5)
local heldGold=run.gold;assert(Run.finishCombat(run))
assert(run.phase=='ending_proceed'and run.rewards==nil and run.gold==heldGold)
F.same(R.snapshot(run.miscRng),R.snapshot(misc))
local owner=run.endingProceed;assert(Run.proceedEnding(run,owner))
assert(run.phase=='victory'and run.ending=='true_victory'and run.character==role)
assert(run.nodeFlow.complete and run.nodeFlow.result=='true_victory'and map.floor==55 and #map.path==4)
for i,card in ipairs(original)do assert(run.deck[i].uid==card.uid and run.deck[i].cardId==card.cardId)end
print('ENDING_ROUTE_CHARACTER_PASS '..role..'; real 52 camp/53 shop/54 combat/claims/55 Heart/Proceed; controlled history/keys/damage, not natural play')
