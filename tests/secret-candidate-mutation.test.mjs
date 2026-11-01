import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {fixture} from './helpers/secret-candidate-insertion.mjs';
test('Secret independent trace kills omission of one second-candidate insertion draw',()=>{
 const dir=mkdtempSync(join(tmpdir(),'secret-mutant-'));
 try{
  const src=readFileSync('src/lua/abyss_colorless_cards.lua','utf8');
  const before='Random.randomInt(state.cardRandomRng,#ordered-1)+1';
  assert.equal(src.split(before).length,2);
  const mutant=join(dir,'colorless.lua');writeFileSync(mutant,src.replace(before,'(#ordered==1 and 1 or Random.randomInt(state.cardRandomRng,#ordered-1)+1)'));
  const entry=join(dir,'case.lua');const samples=fixture.cases.filter(s=>s.count===2);
  writeFileSync(entry,`package.loaded.abyss_colorless_cards=dofile(${toLua(mutant)});dofile('tests/lua/support/secret_candidate_insertion.lua')('skill',false,${toLua(samples)})`);
  const r=runLua(entry);assert.notEqual(r.status,0,r.stdout+r.stderr);assert.match(r.stderr,/secret candidate construction draws/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
