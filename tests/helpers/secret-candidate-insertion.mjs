import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
export const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-secret-candidate-insertion.json'));
export function registerSecret(kind,upgraded,part){
 test(`source candidate insertion public ${kind} upgraded=${upgraded} ${part}`,()=>{
  const dir=mkdtempSync(join(tmpdir(),'secret-insert-'));
  try{
   const path=join(dir,'case.lua');writeFileSync(path,`dofile('tests/lua/support/secret_candidate_insertion.lua')(${toLua(kind)},${toLua(upgraded)},${toLua(fixture.cases.filter(c=>part==='small'?c.count<=2:c.count>=3))})`);
   const r=runLua(path);assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/SECRET_CANDIDATE_INSERTION_PASS/);
  }finally{rmSync(dir,{recursive:true,force:true});}
 });
}
