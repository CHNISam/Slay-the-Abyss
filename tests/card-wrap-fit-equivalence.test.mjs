import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
test('single-call token reuse retains the exact pre-optimization font and fit results',()=>{
 const prior=readFileSync('tests/fixtures/card-wrap-measurement-before.lua','utf8').replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(prior).digest('hex'),'e727c68178078006de49198449d21b5f7e70dc06a77e2d51c0d8628cd7e6b271');
 const result=runLua('tests/lua/card_wrap_fit_equivalence.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/CARD_WRAP_EQUIVALENCE_PASS 2992/);
});
