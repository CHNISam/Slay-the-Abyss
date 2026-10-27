import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const lock=JSON.parse(readFileSync('tests/fixtures/mysterious-sphere-source.json','utf8'));

test('Sphere fixed source distinguishes constructor encounter, ordinary gold, rare queue and EventRoom rewards',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.archiveSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.equal(lock.files['events/beyond/MysteriousSphere.java'],'3e321b9e9424dac7113a3bcf705ff0f046ee8d8e443a70cafe1ad48b04029461');
 assert.equal(lock.files['monsters/beyond/OrbWalker.java'],'2ca7e87876547c47ca7dfcf92ce059681e8766676479e3496af3a3ada9121db8');
 assert.equal(Object.keys(lock.files).length,9);
 for(const value of Object.values(lock.files))assert.match(value,/^[a-f0-9]{64}$/);
 const c=lock.contract;
 assert.equal(c.sourceEncounter,'2 Orb Walkers');assert.equal(c.constructorHpRolls,4);
 assert.deepEqual(c.ordinaryGold,{stream:'miscRng',min:45,max:55,inclusive:true});
 assert.deepEqual(c.introChoices,['open','leave']);assert.equal(c.fightChoice,'fight');
 assert.deepEqual(c.preCombatOrder,['gold reward','screenless rare relic','enter combat']);
 assert.equal(c.relicTier,'rare');assert.equal(c.relicRarityRngRolls,0);assert.equal(c.rareEmptyFallback,'Circlet');
 assert.deepEqual(c.screenlessRejected,['Bottled Flame','Bottled Lightning','Bottled Tornado','Whetstone']);
 assert.equal(c.rewardRoomClass,'event');
 for(const key of ['extraMonsterGold','eliteRelicDrop','prayerWheelExtraCard','eventSpecificPostCombatCallback'])assert.equal(c[key],false);
 assert.equal(c.genericPotionReward,true);assert.equal(c.genericCardReward,true);
 assert.equal(lock.componentBoundary.nativeAcceptance,'NOT_RUN');assert.equal(lock.componentBoundary.deferredToSharedBridge.length,6);
});

test('Sphere gold endpoint vectors independently replay integer RandomXS128 and its full continuation',()=>{
 const script=`import json,runpy
Random=runpy.run_path('tools/sts1-card-rng-oracle.py')['Random']
rows=json.load(open('tests/fixtures/mysterious-sphere-source.json'))['goldVectors']
assert [r['gold'] for r in rows]==[45,50,55]
for row in rows:
 rng=Random(row['seed']);assert rng.snapshot()==row['before'];rng.counter+=1
 while True:
  bits=rng.raw()>>1;value=bits%11
  if bits-value+10<1<<63:break
 assert 45+value==row['gold'];assert rng.snapshot()==row['after']
print('SPHERE_GOLD_ORACLE 3 exact continuations')
`;
 const result=spawnSync('python',['-c',script],{encoding:'utf8',timeout:15000,windowsHide:true});
 assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SPHERE_GOLD_ORACLE 3 exact continuations/);
});
