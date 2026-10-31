import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
const pinned=['tools/oracles/sts1_card_random_chain.py',
 'data/reference/sts1-card-pools/pools.json','data/reference/sts1-card-pools/registration.json'];
const inputs=[...pinned,'tools/oracles/sts1_potion_pool.py','tests/fixtures/sts1-card-random-chain.json'];
function git(cwd,...args){
 const r=spawnSync('git',args,{cwd,encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.error?.message);return r;
}
test('real Windows autocrlf checkout retains shared card-random oracle byte identities and passes strict regeneration',()=>{
 const root=mkdtempSync(join(tmpdir(),'card-random-windows-checkout-'));
 try{
  const source=join(root,'source');mkdirSync(source);
  for(const path of [...inputs,'.gitattributes']){
   const target=join(source,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));
  }
  writeFileSync(join(source,'unrelated-control.txt'),'first line\nsecond line\n');
  git(source,'init','--quiet','--initial-branch=fixture');
  git(source,'config','user.name','Fixture');git(source,'config','user.email','fixture@example.invalid');
  git(source,'-c','core.autocrlf=false','add','.');git(source,'commit','--quiet','-m','test: source bytes');
  const checkout=join(root,'windows');
  git(root,'clone','--quiet','--no-hardlinks','--config','core.autocrlf=true','--config','core.eol=crlf',source,checkout);
  assert.ok(readFileSync(join(checkout,'unrelated-control.txt')).includes(Buffer.from('\r\n')),'control must prove Git really converted an unpinned path to CRLF');
  const r=spawnSync('python',['tools/oracles/sts1_card_random_chain.py','--check'],{
   cwd:checkout,encoding:'utf8',env:{...process.env,PYTHONUTF8:'1'},timeout:30000});
  assert.equal(r.status,0,r.stderr||r.stdout||r.error?.message);
  for(const path of pinned){
   const bytes=readFileSync(join(checkout,path));
   assert.ok(!bytes.includes(Buffer.from('\r\n')),`${path} must remain LF`);
   assert.deepEqual(bytes,readFileSync(path),`${path} must preserve authenticated bytes`);
  }
 }finally{rmSync(root,{recursive:true,force:true});}
});
