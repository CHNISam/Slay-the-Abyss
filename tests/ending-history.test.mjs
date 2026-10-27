import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
test('ending history names remain compatible with the native sandbox forbidden-call scanner',()=>{
 // The native setClientScript scanner rejects this token even for a local
 // function. Keep provider reading distinct from unavailable dynamic loading.
 assert.doesNotMatch(readFileSync('src/lua/abyss_ending_history.lua','utf8'),/(?<![.:\w])(?:loadfile|dofile|load)\s*\(/);
});
test('ending history has distinct fixed-source WIN and standard-run rules',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/ending-history-source-lock.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.deepEqual(lock.requiredWins,['IRONCLAD','THE_SILENT','DEFECT']);
 assert.equal(lock.standardRun,'!isDailyRun && !isTrial && !seedSet');
 assert.equal(lock.seededRunsMayUseExistingFinalActQualification,true);
 assert.equal(lock.neowSpiritsAreVictoryHistory,false);
 for(const source of lock.sources){assert.match(source.sha256,/^[0-9a-f]{64}$/);assert.match(source.gitBlobSha,/^[0-9a-f]{40}$/);assert.ok(source.size>0);}
});
for(const [file,marker]of [['ending_history.lua','ENDING_HISTORY 8 passed'],['ending_history_host.lua','ENDING_HISTORY_HOST 3 passed']]){
 test(`separate ending history: ${file}`,()=>{
  const result=runLua(`tests/lua/${file}`);
  assert.equal(result.status,0,result.stdout+result.stderr);assert.ok(result.stdout.includes(marker),result.stdout);
 });
}
