import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {runLua} from '../scripts/test-lua.mjs';

for (const [file,marker,count] of [
  ['act3_writhing_mass','ACT3_WRITHING_MASS',10],
  ['act3_writhing_parasite','ACT3_WRITHING_PARASITE',9],
]) test(`source Writhing Mass ${file}`,()=>{
  const result=runLua(`tests/lua/${file}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`${marker} ${count} passed; 0 failed`));
});

test('Writhing independent integer/float trace vectors reproduce byte-exactly',()=>{
  const result=spawnSync('python',['tools/oracles/sts1_writhing_mass.py','--lua'],{encoding:'utf8'});
  assert.equal(result.status,0,result.stderr);
  assert.equal(result.stdout,readFileSync('tests/fixtures/act3-writhing-mass-vectors.lua','utf8'));
  const lock=JSON.parse(readFileSync('tests/fixtures/act3-writhing-mass-source-lock.json','utf8'));
  assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.equal(lock.contracts.hp,160);
  assert.equal(lock.contracts.reactivePriority,50);
  assert.equal(lock.contracts.parasitePermanentOnly,true);
  for (const file of lock.authoredInputs) {
    const bytes=readFileSync(file.path);
    assert.equal(createHash('sha256').update(bytes).digest('hex'),file.sha256,file.path);
  }
});
