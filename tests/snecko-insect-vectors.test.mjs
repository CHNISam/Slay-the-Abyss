import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync,mkdirSync} from 'node:fs';
import {execFileSync,spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-snecko-insect.json'));
function run(body,marker){
 const directory=mkdtempSync(join(tmpdir(),'snecko-insect-'));
 try{
  const path=join(directory,'case.lua');writeFileSync(path,`local M=dofile('tests/lua/support/snecko_insect_vectors.lua');${body}`);
  const result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,new RegExp(marker));
 }finally{rmSync(directory,{recursive:true,force:true});}
}
test('independent pinned Snecko/Insect oracle regenerates without production imports',()=>{
 execFileSync('python',['tools/oracles/sts1_snecko_insect.py','--check']);
});
test('oracle source identities use POSIX keys for real Windows and POSIX path semantics',()=>{
 execFileSync('python',['-c',[
  'import sys',
  'from pathlib import PureWindowsPath, PurePosixPath',
  "sys.path.insert(0, 'tools/oracles')",
  'from sts1_snecko_insect import source_identity',
  "expected = 'data/reference/sts1-card-pools/registration.json'",
  "assert source_identity(PureWindowsPath('D:/checkout') / expected, PureWindowsPath('D:/checkout')) == expected",
  "assert source_identity(PurePosixPath('/checkout') / expected, PurePosixPath('/checkout')) == expected",
 ].join('\n')]);
});
test('real CRLF checkout preserves every authenticated Snecko/Insect model and input byte',()=>{
 const directory=mkdtempSync(join(tmpdir(),'snecko-insect-checkout-'));
 const pinned=['tools/oracles/sts1_snecko_insect.py',...Object.keys(vectors.inputSha256)];
 const git=(cwd,...args)=>{const result=spawnSync('git',args,{cwd,encoding:'utf8'});assert.equal(result.status,0,result.stderr||result.error?.message);};
 try{
  const source=join(directory,'source');mkdirSync(source);
  for(const path of [...pinned,'.gitattributes','tests/fixtures/sts1-snecko-insect.json']){
   const target=join(source,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));
  }
  writeFileSync(join(source,'control.txt'),'first\nsecond\n');
  git(source,'init','--quiet','--initial-branch=fixture');
  git(source,'config','user.name','Fixture');git(source,'config','user.email','fixture@example.invalid');
  git(source,'-c','core.autocrlf=false','add','.');git(source,'commit','--quiet','-m','test: frozen input bytes');
  const checkout=join(directory,'crlf');git(directory,'clone','--quiet','--no-hardlinks','--config','core.autocrlf=true','--config','core.eol=crlf',source,checkout);
  assert.ok(readFileSync(join(checkout,'control.txt')).includes(Buffer.from('\r\n')));
  for(const path of pinned)assert.deepEqual(readFileSync(join(checkout,path)),readFileSync(path),path);
  execFileSync('python',['tools/oracles/sts1_snecko_insect.py','--check'],{cwd:checkout,env:{...process.env,PYTHONUTF8:'1'},timeout:30000});
 }finally{rmSync(directory,{recursive:true,force:true});}
});
for(const sample of vectors.snecko)test(`Snecko public opening and later draw exact source costs/RNG seed ${sample.seed}`,()=>{
 run(`M.snecko(${toLua(sample)},${toLua(vectors.deck)})`,'SNECKO_INDEPENDENT_PASS');
});
for(const maximum of [...new Set(vectors.insect.map(row=>row.maximum))])test(`Insect public opening binary32 source HP ${maximum} and room eligibility`,()=>{
 run(`M.insect(${toLua(vectors.insect.filter(row=>row.maximum===maximum))})`,'INSECT_INDEPENDENT_PASS');
});
