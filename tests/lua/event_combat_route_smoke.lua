-- Public inventory commands are explicit component inputs, not natural drops.
-- No stat/deck/RNG writes, invented escape choice, damage or forced outcome.
local F=dofile('tests/lua/support/event_combat_route_fixture.lua')
local Run,N,C,R=F.Run,F.N,F.C,F.R
local run,map=F.event('42','colosseum')
local ok,slot=Run.obtainPotion(run,'smoke_bomb');assert(ok,slot)
assert(N.chooseEvent(run,'continue'));assert(N.chooseEvent(run,'fight'))
local card=R.snapshot(run.cardRng);local queue=C.copy(run.encounters)
assert(Run.usePotion(run,slot))
assert(run.phase=='node'and run.nodeFlow.event.stage=='post_combat')
assert(not run.rewards and not run.eventCombat and not run.nodeFlow.eventCombat and not run.potions[slot])
assert(run.lastResult.outcome=='escaped'and run.victories==0)
F.same(R.snapshot(run.cardRng),card);F.same(run.encounters,queue)
assert(run.nodeFlow.event.roomContinuation.monsterHpRng.counter==2)
assert(run.nodeFlow.event.roomContinuation.shuffleRng.counter==2)
assert(not N.completeCombat(run,map));assert(N.chooseEvent(run,'leave'));assert(run.phase=='map'and run.nodeFlow.complete)
local B=require('abyss_masked_bandits_event')
for _,held in ipairs({false,true})do
 local r=Run.new(F.D,'42',{experimental=true,campaign=true});r.act,r.floor,r.phase=2,18,'node'
 r.nodeFlow={type='event',event={id='masked_bandits'}};B.prepare(r,r.nodeFlow.event)
 r.nodeFlow.event.preparedCombat=assert(Run.prepareEventEncounter(r,'Masked Bandits',18))
 -- Explicit permanent acquisition command tests the already-held-mask branch;
 -- it is not described as a natural Red Mask obtain or a won Bandits battle.
 if held then assert(Run.obtainRelic(r,'red_mask'))end
 local relics=C.copy(r.relics);local pool=require('abyss_relic_pool').snapshot(r.relicPool)
 local expected=R.cloneState(r.miscRng);local gold=R.randomIntBetween(expected,25,35)
 assert(Run.transaction(r,function(s)
  local accepted,status=B.choose(s,s.nodeFlow,'fight');if not accepted then return false,status end
  return Run.startEventCombat(s)
 end))
 assert(r.eventCombat.relics[1].id==(held and'circlet'or'red_mask')and r.eventCombat.relics[1].rarity=='special')
 assert(r.eventCombat.gold==gold and r.encounterTier=='normal')
 F.same(r.relics,relics);F.same(require('abyss_relic_pool').snapshot(r.relicPool),pool);F.same(R.snapshot(r.miscRng),R.snapshot(expected))
 assert(not r.rewards,'fixed relic is an unclaimed battle offer, not a free grant')
end
print('EVENT_COMBAT_ROUTE_SMOKE_PASS actual Smoke reopens source first fight; fixed mask/Circlet offers retain real inventory owners')
