import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync,mkdirSync} from 'node:fs';
import {execFileSync,spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {fixture,runSeed} from './helpers/deep-breath-vectors.mjs';
test('Deep Breath independent oracle regenerates exact byte-hashed source vectors',()=>{
 execFileSync('python',['tools/oracles/sts1_deep_breath.py','--check']);
});
test('Deep Breath source keys use identical Windows and POSIX path identities',()=>{
 execFileSync('python',['-c',[
  'import sys','from pathlib import PureWindowsPath,PurePosixPath',"sys.path.insert(0,'tools/oracles')",
  'from sts1_deep_breath import source_identity',"key='tools/oracles/sts1_combat_shuffle.py'",
  "assert source_identity(PureWindowsPath('D:/repo')/key,PureWindowsPath('D:/repo'))==key",
  "assert source_identity(PurePosixPath('/repo')/key,PurePosixPath('/repo'))==key",
 ].join('\n')]);
});
for(const mutation of [
 {name:'discard first long',before:"Random.shuffle(assert(state.shuffleRng,'Deep Breath needs shuffle stream'),state.discard)",after:'-- mutation omits first discard shuffle'},
 {name:'reversed Soul transfer',before:'for _,c in ipairs(state.discard)do state.draw[#state.draw+1]=c end;state.discard={}',after:'for i=#state.discard,1,-1 do state.draw[#state.draw+1]=state.discard[i]end;state.discard={}'},
])test(`Deep Breath independent UID/stream contract rejects ${mutation.name}`,()=>{
 const result=runSeed('7',mutation);assert.notEqual(result.status,0,result.stdout+result.stderr);assert.match(result.stderr,/Deep Breath independent shuffle sequence/);
});
test('real CRLF checkout preserves Deep Breath raw model bytes and strict regeneration',()=>{
 const directory=mkdtempSync(join(tmpdir(),'deep-breath-checkout-'));
 const pinned=['tools/oracles/sts1_deep_breath.py',...Object.keys(fixture.inputSha256)];
 const git=(cwd,...args)=>{const result=spawnSync('git',args,{cwd,encoding:'utf8'});assert.equal(result.status,0,result.stderr||result.error?.message);};
 try{
  const source=join(directory,'source');mkdirSync(source);
  for(const path of [...pinned,'.gitattributes','tests/fixtures/sts1-deep-breath.json']){
   const target=join(source,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));
  }
  writeFileSync(join(source,'control.txt'),'first\nsecond\n');git(source,'init','--quiet','--initial-branch=fixture');
  git(source,'config','user.name','Fixture');git(source,'config','user.email','fixture@example.invalid');
  git(source,'-c','core.autocrlf=false','add','.');git(source,'commit','--quiet','-m','test: frozen source bytes');
  const checkout=join(directory,'crlf');git(directory,'clone','--quiet','--no-hardlinks','--config','core.autocrlf=true','--config','core.eol=crlf',source,checkout);
  assert.ok(readFileSync(join(checkout,'control.txt')).includes(Buffer.from('\r\n')));
  for(const path of pinned)assert.deepEqual(readFileSync(join(checkout,path)),readFileSync(path),path);
  execFileSync('python',['tools/oracles/sts1_deep_breath.py','--check'],{cwd:checkout,env:{...process.env,PYTHONUTF8:'1'},timeout:30000});
 }finally{rmSync(directory,{recursive:true,force:true});}
});
