import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('fixed-source Spire pair component owns AI, frozen actions and surrounded callbacks',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/spire_pair_component.lua',{timeout:30_000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SPIRE_PAIR_COMPONENT_PASS 10/);
});

test('Spire pair source lock binds the independent oracle and component inputs',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/spire-pair-source.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files['monsters/ending/SpireShield.java'].sha256,'bd2048d80bf6f6b270997ec50ccec83fd1e7ce5c90b046e91a9bb4b71ff9bd7c');
 assert.equal(lock.files['monsters/ending/SpireSpear.java'].sha256,'4e7ea2ab3451d2bcd7b2842a50dee2b48388407e8815057260dcc7d396cfc8e0');
 assert.equal(lock.files['characters/AbstractPlayer.java'].sha256,'2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95');
 for(const [path,hash]of Object.entries(lock.authoredInputs)){
  assert.equal(createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex'),hash,path);
 }
 const vectors=JSON.parse(readFileSync('tests/fixtures/spire-pair-vectors.json','utf8'));
 assert.equal(vectors.length,8);
 assert.ok(vectors.some(row=>row.orbSlots===0));assert.ok(vectors.some(row=>row.orbSlots===3));
 assert.ok(vectors.every(row=>row.steps.length===6 && row.after.counter>0));
});
