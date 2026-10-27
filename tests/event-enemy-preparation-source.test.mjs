import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const sha=path=>createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex');
test('event enemy preparation retains fixed source HP versus init and preBattle boundaries',()=>{
 const lock=read('tests/fixtures/event-enemy-preparation-source.json');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files['events/beyond/MysteriousSphere.java'].sha256,'3e321b9e9424dac7113a3bcf705ff0f046ee8d8e443a70cafe1ad48b04029461');
 assert.equal(lock.files['monsters/beyond/OrbWalker.java'].sha256,'2ca7e87876547c47ca7dfcf92ce059681e8766676479e3496af3a3ada9121db8');
 assert.deepEqual(lock.contracts.positions,[[-250,32],[150,26]]);
 assert.equal(lock.contracts.sphereConstructionHpDraws,4);assert.equal(lock.contracts.initialAiDraws,2);
 assert.equal(lock.contracts.preBattleStrength,3);assert.equal(lock.contracts.preparedStoresMisc,false);
 for(const [path,hash]of Object.entries(lock.authoredInputs))assert.equal(sha(path),hash,path);
 const vectors=read('tests/fixtures/event-enemy-preparation-vectors.json');assert.equal(vectors.length,8);
 for(const vector of vectors){assert.equal(vector.after.counter,4);assert.equal(vector.hp.length,2);assert.equal(vector.discarded.length,2);}
});
