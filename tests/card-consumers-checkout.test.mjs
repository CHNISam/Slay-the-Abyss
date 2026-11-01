import test from'node:test';import assert from'node:assert/strict';
import{mkdirSync,mkdtempSync,readFileSync,rmSync,writeFileSync}from'node:fs';
import{spawnSync}from'node:child_process';import{dirname,join}from'node:path';import{tmpdir}from'node:os';
const pinned=['tools/oracles/sts1_card_consumers.py','tools/sts1-card-rng-oracle.py',
 'data/reference/sts1-card-pools/pools.json','data/reference/sts1-card-pools/registration.json','tests/fixtures/sts1-card-consumers.json'];
function git(cwd,...args){const r=spawnSync('git',args,{cwd,encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.error?.message);}
test('card consumer raw hashes and POSIX provenance keys survive a real Git CRLF checkout',()=>{
 const root=mkdtempSync(join(tmpdir(),'card-consumers-checkout-'));try{
  const source=join(root,'source');mkdirSync(source);
  for(const path of [...pinned,'.gitattributes']){const target=join(source,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));}
  writeFileSync(join(source,'unrelated-control.txt'),'first\nsecond\n');
  git(source,'init','--quiet','--initial-branch=fixture');git(source,'config','user.name','Fixture');git(source,'config','user.email','fixture@example.invalid');
  git(source,'-c','core.autocrlf=false','add','.');git(source,'commit','--quiet','-m','test: card source checkout');
  const checkout=join(root,'windows');git(root,'clone','--quiet','--no-hardlinks','--config','core.autocrlf=true','--config','core.eol=crlf',source,checkout);
  assert.ok(readFileSync(join(checkout,'unrelated-control.txt')).includes(Buffer.from('\r\n')),'unrelated checkout must really convert');
  for(const path of pinned){const bytes=readFileSync(join(checkout,path));assert.ok(!bytes.includes(Buffer.from('\r\n')),path);assert.deepEqual(bytes,readFileSync(path),path);}
  const r=spawnSync('python',['tools/oracles/sts1_card_consumers.py','--check'],{cwd:checkout,encoding:'utf8',env:{...process.env,PYTHONUTF8:'1'},timeout:10000});
  assert.equal(r.status,0,r.stderr||r.stdout||r.error?.message);
  const fixture=JSON.parse(readFileSync(join(checkout,'tests/fixtures/sts1-card-consumers.json')));
  for(const path of [...Object.keys(fixture.inputSha256),...Object.keys(fixture.sourceFilesSha256)])assert.ok(!path.includes('\\'),'provenance key must be POSIX');
 }finally{rmSync(root,{recursive:true,force:true});}
});
