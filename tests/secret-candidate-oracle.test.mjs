import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync,spawnSync} from 'node:child_process';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {fixture} from './helpers/secret-candidate-insertion.mjs';
test('Secret action independent vectors regenerate exact hashes and POSIX source keys',()=>{
 for(const kind of ['skill','attack'])for(const version of ['base','upgraded'])for(const part of ['small','large']){
  assert.equal(readFileSync(`tests/secret-candidate-${kind}-${version}-${part}.test.mjs`,'utf8'),`import {registerSecret} from './helpers/secret-candidate-insertion.mjs';\nregisterSecret('${kind}',${version==='upgraded'},'${part}');\n`);
 }
 assert.equal(fixture.cases.length,5);assert.deepEqual(fixture.cases.map(r=>r.count),[0,1,2,3,4]);
 assert.ok(Object.keys(fixture.sourceFilesSha256).every(k=>!k.includes('\\')));
 execFileSync('python',['tools/oracles/sts1_secret_candidate_insertion.py','--check']);
});
test('Secret authenticated bytes survive an actual Git CRLF checkout',()=>{
 const dir=mkdtempSync(join(tmpdir(),'secret-crlf-'));
 const pinned=['tools/oracles/sts1_secret_candidate_insertion.py',...Object.keys(fixture.inputSha256)];
 const git=(cwd,...args)=>{const r=spawnSync('git',args,{cwd,encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.error?.message);};
 try{
  const source=join(dir,'source');mkdirSync(source);
  for(const file of [...pinned,'.gitattributes','tests/fixtures/sts1-secret-candidate-insertion.json']){
   const path=join(source,file);mkdirSync(dirname(path),{recursive:true});writeFileSync(path,readFileSync(file));
  }
  writeFileSync(join(source,'control.txt'),'first\nsecond\n');git(source,'init','--quiet','--initial-branch=fixture');
  git(source,'config','user.name','Fixture');git(source,'config','user.email','fixture@example.invalid');
  git(source,'-c','core.autocrlf=false','add','.');git(source,'commit','--quiet','-m','test: source bytes');
  const checkout=join(dir,'crlf');git(dir,'clone','--quiet','--no-hardlinks','--config','core.autocrlf=true','--config','core.eol=crlf',source,checkout);
  assert.ok(readFileSync(join(checkout,'control.txt')).includes(Buffer.from('\r\n')));
  for(const file of pinned)assert.deepEqual(readFileSync(join(checkout,file)),readFileSync(file));
  execFileSync('python',['tools/oracles/sts1_secret_candidate_insertion.py','--check'],{cwd:checkout,env:{...process.env,PYTHONUTF8:'1'},timeout:30000});
 }finally{rmSync(dir,{recursive:true,force:true});}
});
