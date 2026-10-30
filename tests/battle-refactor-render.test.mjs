import test from 'node:test';
import assert from 'node:assert/strict';
import {runHistoricalMonsterUi} from './helpers/historical-monster-ui-runner.mjs';
test('existing real battle preview preserves every resolved native scene across responsibility extraction',()=>{
 const result=runHistoricalMonsterUi('battle-refactor-render',{timeout:120000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 const scenes=result.stdout.split('\n').find(line=>line.startsWith('{"before":'));
 assert.ok(scenes,'both historical differential captures must be returned');
 const {before,after}=JSON.parse(scenes);assert.ok(before.length>=10);assert.deepEqual(after,before);
});
