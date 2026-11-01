import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {fixture,execute,casesFor,registerSwordCases} from './helpers/sword-random-cases.mjs';
test('independent Sword random-target fixture regenerates with exact LF source hashes',()=>{
 execFileSync('python',['tools/oracles/sts1_sword_random.py','--check']);
 assert.equal(fixture.cases.length,24);
 const expected=['0','1','42','-1'].flatMap(seed=>['base','upgraded'].flatMap(mode=>['survive','kill_reselect','stop_after_last'].map(scenario=>`${seed}/${mode}/${scenario}`)));
 assert.deepEqual(fixture.cases.map(c=>c.caseId),expected);
 assert.equal(new Set(fixture.cases.map(c=>c.caseId)).size,24);
 for(const c of fixture.cases)assert.equal(c.caseId,`${c.seed}/${c.upgraded?'upgraded':'base'}/${c.scenario}`);
});
test('real random-attack UI drag and stale release cannot play the next card',()=>{
 const dir=mkdtempSync(join(tmpdir(),'sword-ui-'));
 try{
  const path=join(dir,'case.lua');writeFileSync(path,`dofile('tests/lua/support/sword_random_ui.lua')(${toLua(fixture.cases[0])})`);
  const r=runLua(path);assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/SWORD_RANDOM_UI_PASS/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
for(const [label,prelude,pattern] of [
 ['fixed first target',`local C=require('abyss_combat');C.cardRandom=function()return 1 end`,/per-hit target|exact wrapper draws/],
 ['skipping singleton draw',`local C=require('abyss_combat');local raw=C.cardRandom;C.cardRandom=function(s,n)if n==1 then return 1 end return raw(s,n)end`,/exact wrapper draws/],
 ['extra draw after final death',`local C=require('abyss_combat');local raw=C.damage;C.damage=function(s,source,target,...)local r=raw(s,source,target,...);local alive=false;for _,e in ipairs(s.enemies)do if e.hp>0 then alive=true end end;if not alive then require('abyss_sts_random').randomInt(s.cardRandomRng,0)end;return r end`,/unexpected extra selection draw/],
])test(`independent oracle rejects ${label}`,()=>{
 const sample=fixture.cases.find(c=>c.seed==='0'&&!c.upgraded&&c.scenario==='kill_reselect');
 const r=execute([sample],prelude);assert.notEqual(r.status,0,r.stdout+r.stderr);assert.match(r.stderr,pattern);
});
test('eight nonempty thin Sword entries partition all 24 exact case IDs without overlap',()=>{
 const entries=['0','1','42','-1'].flatMap(seed=>[false,true].map(upgraded=>({seed,upgraded,file:`sword-random-${seed==='-1'?'negative-one':seed}-${upgraded?'upgraded':'base'}.test.mjs`})));
 assert.deepEqual(readdirSync('tests').filter(f=>/^sword-random-.*\.test\.mjs$/.test(f)&&f!=='sword-random-oracle.test.mjs').sort(),entries.map(e=>e.file).sort());
 const ids=[];
 for(const {seed,upgraded,file} of entries){
  assert.equal(readFileSync(`tests/${file}`,'utf8'),`import {registerSwordCases} from './helpers/sword-random-cases.mjs';\nregisterSwordCases('${seed}',${upgraded});\n`,'thin wrapper must call the actual shared registration');
  const registered=[];registerSwordCases(seed,upgraded,(name,fn)=>registered.push({name,fn}));
  assert.deepEqual(registered.map(r=>r.name),casesFor(seed,upgraded).map(c=>`Sword case ${c.caseId}`));
  for(const r of registered)assert.equal(typeof r.fn,'function','case must register an executable callback');
  ids.push(...registered.map(r=>r.name.slice('Sword case '.length)));
 }
 assert.equal(new Set(ids).size,24);assert.deepEqual(ids,fixture.cases.map(c=>c.caseId));
});
