import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync,symlinkSync} from 'node:fs';
import {join} from 'node:path';import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {colorlessCatalogBefore,preColorlessCatalogSource as project,colorlessCatalogReader, colorlessCatalogSourceProof as proof,prepareColorlessCatalogRetirement as retire} from './helpers/colorless-catalog-source-inverse.mjs';
import {preM7FinalSource,m7FinalReader} from './helpers/m7-core-final-source-inverse.mjs';
import {preRelicQuerySource,relicQueryReader} from './helpers/relic-query-source-inverse.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const owners=Object.keys(proof.files),originals=owners.filter(p=>Object.hasOwn(proof.files[p],'beforeSource'));
const leaf='src/lua/abyss_colorless_catalog.lua';
test('the independent archive authenticates all 333 complete source files and cannot authorize unknown history',()=>{
 assert.equal(Object.keys(colorlessCatalogBefore.files).length,333);
 assert.equal(colorlessCatalogBefore.revision,'2ad07111e3d5b5cb52b4229860b3b780941e29a9');
 for(const [name,row]of Object.entries(colorlessCatalogBefore.files)){assert.equal(row.path,'src/lua/'+name+'.lua');assert.equal(hash(row.source),row.sha256);assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(row.source)}\0`).update(row.source).digest('hex'),row.gitBlob);}
 assert.equal(colorlessCatalogBefore.files.abyss_colorless_catalog,undefined);
});
test('exact four-owner projection is fresh for every entry and every wrapped reader',()=>{
 for(const path of originals){
  for(const wrapper of [r=>r,colorlessCatalogReader,r=>colorlessCatalogReader(colorlessCatalogReader(r))]){
   const count=new Map(),reader=wrapper(p=>{count.set(p,(count.get(p)??0)+1);return read(p);});
   assert.equal(project(path,read(path),{readSource:reader}),proof.files[path].beforeSource);
   assert.deepEqual([...count.keys()].sort(),[...owners].sort());
  }
  for(const bad of owners)for(const kind of ['changed','missing','null','throw']){
   let broken=false;const raw=p=>{if(p===bad&&broken){if(kind==='throw')throw Error('sentinel');return kind==='changed'?read(p)+'\n':kind==='missing'?undefined:null;}return read(p);};
   const wrapped=colorlessCatalogReader(raw);
   assert.equal(project(path,read(path),{readSource:wrapped}),proof.files[path].beforeSource);broken=true;
   assert.throws(()=>project(path,read(path),{readSource:wrapped}),/Colorless catalog linked owner/);
  }
 }
});
test('old, foreign, partial and witness-only inputs never grant linked I/O',()=>{
 let reads=0;const readSource=()=>{reads++;throw Error('unexpected');};
 for(const path of originals)for(const source of [proof.files[path].beforeSource,read(path)+'\n-- foreign',null,'',read(path).slice(1)])assert.equal(project(path,source,{readSource}),source);
 assert.equal(project(leaf,read(leaf),{readSource}),read(leaf));assert.equal(project('foreign',read(originals[0]),{readSource}),read(originals[0]));assert.equal(reads,0);
});
test('CRLF and exact input-only JSON formatting retain prior strict token behavior',()=>{
 for(const path of originals)assert.equal(project(path,read(path).replaceAll('\n','\r\n')),proof.files[path].beforeSource);
 const path='config/architecture.json',formatted=JSON.stringify(JSON.parse(read(path)));
 assert.equal(project(path,formatted),proof.files[path].beforeSource);
 assert.throws(()=>project(path,formatted,{readSource:p=>p===path?formatted:read(p)}),/linked owner identity/);
 const duplicate=formatted.replace('{','{"schemaVersion":1,');assert.equal(project(path,duplicate),duplicate);
});
test('existing final M7 and relic lifecycle chains consume exact pre-extraction owners',()=>{
 for(const path of originals){assert.equal(preM7FinalSource(path,read(path)),proof.files[path].beforeSource);assert.equal(m7FinalReader(read)(path),proof.files[path].beforeSource);}
 const path='src/lua/abyss_colorless_cards.lua';const baseline=readFileSync('tests/helpers/relic-lifecycle-baseline-391306af.json.gz');assert(baseline.length>0);
 const projected=preRelicQuerySource(path,read(path));assert.notEqual(projected,read(path));assert.notEqual(projected,proof.files[path].beforeSource);
 assert.equal(relicQueryReader(read)(path),projected);
});
test('new catalog retirement checks bytes twice and cannot delete a live-file alias',t=>{
 assert.throws(()=>retire(process.cwd()),/separate historical destination/);
 const directory=mkdtempSync(join(tmpdir(),'colorless-retirement-')),target=join(directory,leaf);
 try{
  mkdirSync(join(directory,'src/lua'),{recursive:true});writeFileSync(target,read(leaf));
  const cleanup=retire(directory);assert(existsSync(target));writeFileSync(target,read(leaf)+'\n');assert.throws(cleanup,/unreviewed/);assert(existsSync(target));
  writeFileSync(target,read(leaf));retire(directory)();assert(!existsSync(target));assert(existsSync(leaf));
  try{symlinkSync(join(process.cwd(),leaf),target);}catch(error){if(['EPERM','EACCES','ENOTSUP'].includes(error.code)){t.skip('file symlink unavailable: '+error.code);return;}throw error;}
  assert.throws(()=>retire(directory),/aliases live source/);assert(existsSync(leaf));
 }finally{rmSync(directory,{recursive:true,force:true});}
});
