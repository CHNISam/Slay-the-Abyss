import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync,mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {dirname,join} from 'node:path';
import {tmpdir} from 'node:os';

const pinned=['tools/oracles/library-event-oracle.py','tools/sts1-card-rng-oracle.py',
 'tests/fixtures/library-event-vectors.json','tests/fixtures/library-event-vectors.lua',
 'tools/oracles/sts1_writhing_mass.py','tools/oracles/sts1_combat_gold.py',
 'tests/fixtures/act3-writhing-mass-vectors.lua'];
const facts=['data/reference/sts1-card-pools/registration.json','data/reference/sts1-card-pools/pools.json',
 'tests/fixtures/act3-writhing-mass-source-lock.json'];
const inputs=[...pinned,...facts];
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const json=path=>JSON.parse(readFileSync(path,'utf8'));
const pythonEnv={...process.env,PYTHONUTF8:'1'};
function git(cwd,...args){
 const result=spawnSync('git',['-c','core.hooksPath=.no-test-hooks','-c','commit.gpgSign=false',...args],
  {cwd,encoding:'utf8',timeout:15000});
 assert.equal(result.status,0,result.stderr||result.error?.message||result.stdout);return result.stdout;
}
function library(directory,accepted=true){
 const result=spawnSync('python',[join(directory,pinned[0]),'--check'],{encoding:'utf8',timeout:15000,env:pythonEnv});
 if(accepted)assert.equal(result.status,0,result.stderr||result.error?.message||result.stdout);
 else {assert.equal(result.status,1,result.stderr||result.error?.message||result.stdout);assert.match(result.stderr,/Library oracle fixture changed/);}
}
function writhing(directory){
 const script=join(directory,'tools/oracles/sts1_writhing_mass.py');
 const result=spawnSync('python',['-X','utf8','-c',
  'import os,runpy,sys; script=sys.argv[1]; sys.path.insert(0,os.path.dirname(script)); sys.argv=[script,"--lua"]; sys.stdout.reconfigure(newline="\\n"); runpy.run_path(script,run_name="__main__")',
  script],{encoding:'utf8',timeout:15000});
 assert.equal(result.status,0,result.stderr||result.error?.message);
 assert.equal(result.stdout,readFileSync(join(directory,'tests/fixtures/act3-writhing-mass-vectors.lua'),'utf8'));
 for(const row of json(join(directory,facts[2])).authoredInputs)
  assert.equal(sha(readFileSync(join(directory,row.path))),row.sha256,row.path);
}

test('Git LF and Windows autocrlf checkouts preserve authenticated Library and Writhing bytes and strict sensitivity',()=>{
 const root=mkdtempSync(join(tmpdir(),'abyss-oracle-checkout-'));
 const attributes=readFileSync('.gitattributes','utf8');
 for(const path of pinned)assert.ok(attributes.split(/\r?\n/).includes(`${path} text eol=lf`),path);
 const seed=(name,policy)=>{
  const directory=join(root,name);mkdirSync(directory,{recursive:true});
  for(const path of inputs){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});
   writeFileSync(target,readFileSync(path,'utf8').replaceAll('\r\n','\n'),'utf8');}
  writeFileSync(join(directory,'.gitattributes'),policy,'utf8');
  writeFileSync(join(directory,'unrelated-control.txt'),'not byte-authenticated\nsecond line\n','utf8');
  git(directory,'init','--quiet','--initial-branch=fixture');
  git(directory,'config','user.name','Fixture');git(directory,'config','user.email','fixture@example.invalid');
  git(directory,'-c','core.autocrlf=false','add','.');git(directory,'commit','--quiet','-m','test: independent input checkout');
  return directory;
 };
 const checkout=(source,name,autocrlf)=>{
  const directory=join(root,name);
  git(root,'clone','--quiet','--no-hardlinks','--config',`core.autocrlf=${autocrlf}`,
   '--config',`core.eol=${autocrlf?'crlf':'lf'}`,source,directory);return directory;
 };
 const copy=(source,name)=>{
  const directory=join(root,name);
  for(const path of inputs){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});
   writeFileSync(target,readFileSync(join(source,path)));}return directory;
 };
 try{
  const source=seed('seed',attributes),lf=checkout(source,'lf',false),crlf=checkout(source,'windows-crlf',true);
  assert.ok(!readFileSync(join(lf,'unrelated-control.txt'),'utf8').includes('\r\n'));
  assert.ok(readFileSync(join(crlf,'unrelated-control.txt'),'utf8').includes('\r\n'),'Windows checkout conversion must really run');
  for(const directory of [lf,crlf]){
   for(const path of pinned){const actual=readFileSync(join(directory,path));
    assert.deepEqual(actual,readFileSync(path),`${path} remains exact`);assert.ok(!actual.includes(Buffer.from('\r\n')),path);}
   library(directory);writhing(directory);
  }
  // Raw UTF-8 and ASCII JSON escapes are equivalent input encodings. Explicit
  // Python UTF-8 mode avoids depending on the host's legacy default locale.
  for(const escaped of [false,true]){
   const directory=copy(lf,escaped?'escaped-json':'utf8-json');
   for(const path of facts.slice(0,2)){
    const value=json(join(directory,path));value.encodingProbe='源码';
    let text=JSON.stringify(value,null,2)+'\n';
    if(escaped)text=text.replace(/[^\x00-\x7f]/g,char=>'\\u'+char.charCodeAt(0).toString(16).padStart(4,'0'));
    writeFileSync(join(directory,path),text,'utf8');
   }
   library(directory);
  }
  const semantic=copy(lf,'semantic-drift'),poolPath=join(semantic,facts[1]);
  const pools=json(poolPath),traversal=pools.pools.libraryHashMapTraversal;
  const canonical=json(join(lf,'tests/fixtures/library-event-vectors.json')).pools.ironclad.common;
  const a=traversal.indexOf(canonical[0]),b=traversal.indexOf(canonical[1]);assert.ok(a>=0&&b>=0);
  [traversal[a],traversal[b]]=[traversal[b],traversal[a]];
  writeFileSync(poolPath,JSON.stringify(pools,null,2)+'\n','utf8');library(semantic,false);
  const drift=copy(lf,'source-drift'),driftPath=join(drift,'tools/sts1-card-rng-oracle.py');
  writeFileSync(driftPath,readFileSync(driftPath,'utf8')+'\n# unexpected source identity drift\n','utf8');library(drift,false);
  const whitespace=copy(lf,'fixture-whitespace'),fixturePath=join(whitespace,'tests/fixtures/library-event-vectors.json');
  writeFileSync(fixturePath,readFileSync(fixturePath,'utf8').replace('{\n','{ \n'),'utf8');library(whitespace,false);
  // Removing only the seven policies reproduces both actual CI failures;
  // arbitrary CRLF source bytes are not silently accepted as authenticated.
  const without=attributes.split(/\r?\n/).filter(line=>!pinned.includes(line.split(' ')[0])).join('\n');
  const unpinned=checkout(seed('unpinned-seed',without),'unpinned-windows',true);
  library(unpinned,false);
  const lock=json(join(unpinned,facts[2]));
  for(const row of lock.authoredInputs)assert.notEqual(sha(readFileSync(join(unpinned,row.path))),row.sha256,row.path);
 }finally{rmSync(root,{recursive:true,force:true});}
});
