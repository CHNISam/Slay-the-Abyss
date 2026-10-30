-- Constructor/AI components use unmodified starter values and source streams.
-- No enemy/player HP mutation, injected RNG words, fake kill or pool rewriting.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local Routes,Bandits=require('abyss_event_combat_routes'),require('abyss_masked_bandits_event')
local V=require('event_combat_routes_vectors')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for key,value in pairs(a)do same(value,b[key])end;for key in pairs(b)do assert(a[key]~=nil)end
end
for _,vector in ipairs(V.bandits)do
 local run=Run.new(D,vector.runSeed,{experimental=true,campaign=true});run.act=2
 local misc=R.snapshot(run.miscRng);local queue=C.copy(run.encounters)
 local prepared,why=Run.prepareEventEncounter(run,'Masked Bandits',vector.floor)
 assert(prepared,why);assert(prepared.roomSeed==vector.roomSeed)
 same(prepared.prepared.monsterHpRng,vector.after);same(R.snapshot(run.miscRng),misc);same(run.encounters,queue)
 for i,actor in ipairs(prepared.prepared.actors)do
  assert(actor.hp==vector.hp[i]and actor.hp==actor.maxHp and actor.block==0 and next(actor.statuses)==nil)
  assert(actor.definitionId==({'bandit_pointy','bandit_leader','bandit_bear'})[i])
  assert(actor.intentIndex==1 and actor.eventAttacks==nil)
 end
end
do
 local run=Run.new(D,'42',{experimental=true,campaign=true});run.act,run.phase,run.floor=2,'node',18
 run.nodeFlow={type='event',event={id='masked_bandits'}}
 Bandits.prepare(run,run.nodeFlow.event)
 run.nodeFlow.event.preparedCombat=assert(Run.prepareEventEncounter(run,'Masked Bandits',18))
 assert(Run.transaction(run,function(staged)return Bandits.choose(staged,staged.nodeFlow,'fight')end))
 local queue=C.copy(run.encounters);local deck=C.copy(run.deck);local gold=run.gold
 assert(Run.startEventCombat(run));assert(run.phase=='combat'and run.encounterTier=='normal')
 same(run.encounters,queue);same(run.deck,deck);assert(run.gold==gold)
 assert(run.combat.aiRng.counter==3 and run.combat.monsterHpRng.counter==3)
 local hp=run.hp;assert(Run.endTurn(run));assert(run.phase=='combat')
 assert(run.combat.player.hp==hp-10 and run.combat.player.statuses.dexterity==-2)
 assert(run.combat.enemies[2].intents[run.combat.enemies[2].intentIndex].id=='agonizing_slash')
 assert(run.combat.enemies[3].intents[run.combat.enemies[3].intentIndex].id=='lunge')
 assert(Run.endTurn(run));assert(run.phase=='combat')
 assert(run.combat.aiRng.counter==3)
 assert(run.combat.enemies[2].intents[run.combat.enemies[2].intentIndex].id=='cross_slash')
 assert(run.combat.enemies[3].intents[run.combat.enemies[3].intentIndex].id=='maul')
 assert(Run.endTurn(run));assert(run.phase=='defeat'and run.hp==0)
 assert(not run.rewards,'real defeat may not grant mask or gold')
end
do
 local run=Run.new(D,'13',{experimental=true,campaign=true});run.floor=7
 local prepared=assert(Routes.prepare(run,'Lagavulin Event',7,Run.roomStreams))
 local room=Run.roomStreams(run,7);room.monsterHpRng=R.restore(prepared.prepared.monsterHpRng)
 local battle=assert(C.new(run.data,{roomSeed=room.seed,roomStreams=room,preparedEncounter=prepared.prepared,
  seed=run.seed,hp=run.hp,maxHp=run.maxHp,gold=run.gold,deck=run.deck,masterDeck=run.deck,nextMasterDeckUid=run.nextDeckUid}))
 local enemy=battle.enemies[1]
 assert(enemy.definitionId=='lagavulin_awake'and enemy.block==0 and not enemy.statuses.metallicize)
 assert(enemy.intents[enemy.intentIndex].id=='siphon'and battle.aiRng.counter==1)
 assert(C.endTurn(battle));assert(battle.player.hp==run.hp)
 assert(battle.player.statuses.dexterity==-1 and battle.player.statuses.strength==-1)
 assert(enemy.intents[enemy.intentIndex].id=='attack'and battle.aiRng.counter==2)
 assert(C.endTurn(battle));assert(battle.player.hp==run.hp-18)
 assert(enemy.intents[enemy.intentIndex].id=='attack'and battle.aiRng.counter==3)
 assert(C.endTurn(battle));assert(battle.player.hp==run.hp-36)
 assert(enemy.intents[enemy.intentIndex].id=='siphon'and battle.aiRng.counter==4)
end
print('EVENT_COMBAT_ROUTE_ENEMIES_PASS exact HP, awake constructor and legal-turn source AI')
