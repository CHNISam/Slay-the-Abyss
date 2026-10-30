import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
test('single-call token reuse retains the exact pre-optimization font and fit results',()=>{
 const prior=readFileSync('tests/fixtures/card-wrap-measurement-before.lua','utf8').replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(prior).digest('hex'),'e727c68178078006de49198449d21b5f7e70dc06a77e2d51c0d8628cd7e6b271');
 const cards=JSON.parse(readFileSync('data/presentation/traveler.zh-CN.json','utf8')).cards;
 const legacyIds=Object.keys(cards).filter(id=>id!=='necronomicurse').sort();
 assert.equal(legacyIds.length,90);
 assert.equal(createHash('sha256').update(legacyIds.join('\n')).digest('hex'),'35de5fd416bdb6df8dda6d9c27b9dd9726e751480ceacc6b7b5950e262291d4b');
 assert.equal(Object.keys(cards).length,91);assert.ok(cards.necronomicurse);
 const result=runLua('tests/lua/card_wrap_fit_equivalence.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/CARD_WRAP_EQUIVALENCE_PASS 3024/);
 assert.match(result.stdout,/CARD_WRAP_LEGACY_PASS 2992/);
 assert.match(result.stdout,/CARD_WRAP_NECRONOMICURSE_PASS 32/);
});
