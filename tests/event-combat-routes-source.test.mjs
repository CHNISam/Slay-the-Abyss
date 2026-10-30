import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const modules=['abyss_dead_adventurer_event','abyss_colosseum_event','abyss_masked_bandits_event','abyss_event_combat_routes','abyss_event_combat_enemies'];
test('missing original combat events have dedicated reducers, bridge and constructors',()=>{
 for(const name of modules){const text=readFileSync(`src/lua/${name}.lua`,'utf8');assert.match(text,/return M/);}
});
const source=JSON.parse(readFileSync('tests/fixtures/event-combat-routes-source.json','utf8'));
test('new source witness pins original chances, constructor variants and two-fight reward order',()=>{
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 const expected={
  'events/exordium/DeadAdventurer.java':'8fee3cc721e2ae4e757f8d99e93d5a6a1eba9d4b',
  'events/city/Colosseum.java':'020f06f67113e90009e9a891828fe44f2e65f35b',
  'events/city/MaskedBandits.java':'4966a012aa1dd63c2a0d6835d6dbad0cba04f1eb',
  'monsters/exordium/Lagavulin.java':'57e7a86b61d31b9fba03000ae31e9ae433e1122d'};
 for(const [path,sha] of Object.entries(expected))assert.equal(source.sources.find(x=>x.path===path).sha,sha);
 assert.equal(source.contract.dead.chanceStart,25);assert.equal(source.contract.dead.chanceRamp,25);
 assert.deepEqual(source.contract.dead.sourceEncounters,['3 Sentries','Gremlin Nob','Lagavulin Event']);
 assert.deepEqual(source.contract.colosseum.second,['Colosseum Nobs','rare relic','uncommon relic','100 gold','eliteTrigger']);
 assert.equal(source.contract.colosseum.reseedBetweenBattles,false);
 assert.deepEqual(source.contract.awakeLagavulin.cycle,['siphon','attack','attack']);
 assert.equal(source.contract.awakeLagavulin.initialBlock,0);assert.equal(source.contract.awakeLagavulin.metallicize,0);
 assert.equal(source.acceptance.naturalPlay,'NOT_RUN');assert.equal(source.acceptance.nativeDevice,'NOT_RUN');
});

test('independent integer oracle reproduces new source witnesses without product imports',()=>{
 const result=spawnSync('python',['tests/helpers/event-combat-route-oracle.py'],{encoding:'utf8',timeout:15000,windowsHide:true});
 assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_ORACLE/);
});
test('Dead Adventurer merges raw gold before Golden Idol rounding, never sums separately rounded offers',()=>{
 const bridge=readFileSync('src/lua/abyss_event_combat_routes.lua','utf8');
 assert.match(bridge,/result\.gold=Gold\.offerAmount\(event\.encounterGold\+30,run\)/);
 assert.doesNotMatch(bridge,/result\.gold=result\.gold\+Gold\.offerAmount\(30,run\)/);
 // RewardItem.incrementGold example: 26 + 30 => 56 + round(14) = 70;
 // separately rounded offers would incorrectly produce 33 + 38 = 71.
 assert.equal(26+30+Math.floor((26+30)*.25+.5),70);
 assert.equal(26+Math.floor(26*.25+.5)+30+Math.floor(30*.25+.5),71);
});

test('Dead clue displays the already-selected source enemy without extra RNG or a new branch',()=>{
 const event=readFileSync('src/lua/abyss_dead_adventurer_event.lua','utf8');
 assert.match(event,/event\.encounterHint=sources\[event\.enemy\]/);
 assert.match(event,/clues\[event\.enemy\]/);
 assert.match(event,/三名符文哨卫/);assert.match(event,/怒焰巨魔/);assert.match(event,/苏醒的深渊潜伏者/);
});
