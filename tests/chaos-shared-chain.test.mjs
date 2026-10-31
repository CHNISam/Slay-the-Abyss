import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync,mkdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {execFileSync,spawnSync} from 'node:child_process';
import {fixture} from './helpers/chaos-shared-chain.mjs';
test('independent Chaos shared-chain oracle regenerates exact pinned source vectors',()=>{
 execFileSync('python',['tools/oracles/sts1_chaos_shared_chain.py','--check']);
});
test('Chaos oracle source identities agree for Windows and POSIX path semantics',()=>{
 execFileSync('python',['-c',[
  'import sys','from pathlib import PureWindowsPath, PurePosixPath',"sys.path.insert(0,'tools/oracles')",
  'from sts1_chaos_shared_chain import source_identity',"key='data/reference/sts1-card-pools/pools.json'",
  "assert source_identity(PureWindowsPath('D:/repo')/key,PureWindowsPath('D:/repo'))==key",
  "assert source_identity(PurePosixPath('/repo')/key,PurePosixPath('/repo'))==key",
 ].join('\n')]);
});
test('real CRLF Git checkout preserves Chaos authenticated inputs and strict regeneration',()=>{
 const directory=mkdtempSync(join(tmpdir(),'chaos-source-checkout-'));
 const pinned=['tools/oracles/sts1_chaos_shared_chain.py',...Object.keys(fixture.inputSha256)];
 const git=(cwd,...args)=>{const result=spawnSync('git',args,{cwd,encoding:'utf8'});assert.equal(result.status,0,result.stderr||result.error?.message);};
 try{
  const source=join(directory,'source');mkdirSync(source);
  for(const path of [...pinned,'.gitattributes','tests/fixtures/sts1-chaos-shared-chain.json']){
   const target=join(source,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));
  }
  writeFileSync(join(source,'control.txt'),'first\nsecond\n');git(source,'init','--quiet','--initial-branch=fixture');
  git(source,'config','user.name','Fixture');git(source,'config','user.email','fixture@example.invalid');
  git(source,'-c','core.autocrlf=false','add','.');git(source,'commit','--quiet','-m','test: frozen model bytes');
  const checkout=join(directory,'crlf');git(directory,'clone','--quiet','--no-hardlinks','--config','core.autocrlf=true','--config','core.eol=crlf',source,checkout);
  assert.ok(readFileSync(join(checkout,'control.txt')).includes(Buffer.from('\r\n')));
  for(const path of pinned)assert.deepEqual(readFileSync(join(checkout,path)),readFileSync(path),path);
  execFileSync('python',['tools/oracles/sts1_chaos_shared_chain.py','--check'],{cwd:checkout,env:{...process.env,PYTHONUTF8:'1'},timeout:30000});
 }finally{rmSync(directory,{recursive:true,force:true});}
});
