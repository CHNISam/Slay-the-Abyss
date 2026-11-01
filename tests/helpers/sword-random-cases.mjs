import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
export const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-sword-random.json'));
export function execute(cases,prelude=''){
 const dir=mkdtempSync(join(tmpdir(),'sword-random-'));
 try{const path=join(dir,'case.lua');writeFileSync(path,`${prelude}\ndofile('tests/lua/support/sword_random_oracle.lua')(${toLua(cases)})`);return runLua(path);}
 finally{rmSync(dir,{recursive:true,force:true});}
}
export function casesFor(seed,upgraded){
 assert.equal(typeof seed,'string');assert.equal(typeof upgraded,'boolean');
 const cases=fixture.cases.filter(c=>c.seed===seed&&c.upgraded===upgraded);
 assert.equal(cases.length,3,'thin entry must register exactly three nonempty cases');
 return cases;
}
export function registerSwordCases(seed,upgraded,register=test){
 assert.equal(typeof register,'function');
for(const sample of casesFor(seed,upgraded))register(`Sword case ${sample.caseId}`,()=>{
 const r=execute([sample]);assert.equal(r.status,0,r.stdout+r.stderr);
 assert.ok(r.stdout.includes(`SWORD_CASE_PASS ${sample.caseId}`),r.stdout);
 assert.match(r.stdout,/SWORD_RANDOM_ORACLE_PASS 1/);
});
}
