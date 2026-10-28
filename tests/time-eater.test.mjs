import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {runLua} from '../scripts/test-lua.mjs';
const hash=path=>createHash('sha256').update(readFileSync(path)).digest('hex');
test('Time Eater source AI queue threshold Haste rollback public Run and Chinese display',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/time_eater.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/TIME_EATER 36 groups; 0 failed/);
});
test('Time Eater pinned source contract and independent vectors remain reproducible',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/time-eater-source-contract.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files.length,16);assert.equal(new Set(lock.files.map(x=>x.path)).size,16);
 for(const file of lock.files){assert.match(file.sha256,/^[a-f0-9]{64}$/);assert.match(file.gitBlobSha1,/^[a-f0-9]{40}$/);}
 assert.equal(hash(lock.independentModel.path),lock.independentModel.sha256);
 assert.equal(hash(lock.independentModel.fixture),lock.independentModel.fixtureSha256);
 const result=spawnSync(process.env.ABYSS_PYTHON||'python',['tools/oracles/sts1_time_eater.py','--lua'],{encoding:'utf8',timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.equal(result.stdout.replace(/\r\n/g,'\n'),readFileSync(lock.independentModel.fixture,'utf8').replace(/\r\n/g,'\n'));
 assert.equal(lock.contracts.timeWarpHook,'onAfterUseCard');
 assert.equal(lock.contracts.hasteInterruptsDamage,false);assert.equal(lock.contracts.hasteResetsPositiveStrength,false);
});
