import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {runLua} from '../scripts/test-lua.mjs';
for (const [fixture,groups] of [['ai',5],['runtime',9],['ui',1]]) test(`Nemesis fixed-source ${fixture} boundaries`,()=>{
 const result=runLua(`tests/lua/nemesis_${fixture}.lua`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`NEMESIS_${fixture.toUpperCase()} ${groups} groups; 0 failed`));
});
test('Nemesis exact source identities and independent oracle remain reproducible',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/nemesis-source-lock.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files.length,25);assert.equal(new Set(lock.files.map(file=>file.path)).size,25);
 const hash=path=>createHash('sha256').update(readFileSync(path,'utf8').replace(/\r\n/g,'\n')).digest('hex');
 assert.equal(hash(lock.independentModel.generator),lock.independentModel.generatorSha256LF);
 assert.equal(hash(lock.independentModel.fixture),lock.independentModel.sha256LF);
 for(const file of lock.independentModel.dependencies)assert.equal(hash(file.path),file.sha256LF);
 const result=spawnSync(process.env.ABYSS_PYTHON||'python',['tools/oracles/sts1_nemesis.py','--lua'],{encoding:'utf8',timeout:30000});
 assert.equal(result.status,0,result.stderr);
 assert.equal(result.stdout.replace(/\r\n/g,'\n'),readFileSync(lock.independentModel.fixture,'utf8').replace(/\r\n/g,'\n'));
 assert.equal(lock.contracts.hpDraws,1);assert.equal(lock.contracts.monsterPowerSourceId,'Intangible');
 assert.equal(lock.contracts.playerPowerSourceId,'IntangiblePlayer');
});
