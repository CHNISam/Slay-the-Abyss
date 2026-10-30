import {projectOpenPrSource} from './helpers/open-pr-source-composition.mjs';
import {projectEventSnapshotSource} from './helpers/event-snapshot-composition.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {existsSync,readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync,readdirSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';

const helperPath='./helpers/event-production-source-inverse.mjs';
const helper=existsSync(new URL(helperPath,import.meta.url))?await import(helperPath):null;
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const blob=source=>createHash('sha1').update(`blob ${Buffer.byteLength(source)}\0`).update(source).digest('hex');
const read=path=>normalize(projectEventSnapshotSource(path,projectOpenPrSource(path,readFileSync(path,'utf8'),'event'),'event'));
const put=(root,path,source)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),source);};
const temporary=()=>{mkdirSync('build',{recursive:true});return mkdtempSync(resolve('build/event-source-proof-'));};

test('the event layer binds complete Git1dc sources and the complete current source inventory',()=>{
 assert.ok(helper,'the explicit event source inverse must exist');
 const {eventProductionInverse:proof,preEventProductionSource:project,requireEventProductionSource:requireSource}=helper;
 assert.equal(proof.schemaVersion,1);
 assert.ok(proof.files['data/release/launch-content.json'],'event content mapping belongs to the complete source inventory');
 assert.equal(proof.baseHead,'1dc33fe790a5f82be4f1bf2f0d09e339dcb943dd');
 assert.equal(proof.baseTree,'b25f04658942be82ac9b5044ebf62e0862c0c2a5','actual complete Git1dc tree');
 assert.deepEqual(Object.keys(proof.files),[...Object.keys(proof.files)].sort(),'canonical complete source path order');
 assert.ok(Object.keys(proof.files).length>0);
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path);requireSource(path,current);
  assert.equal(current,binding.afterSource,path+' full final source, not a hunk or hash-only permission');
  assert.equal(hash(current),binding.afterSha256,path);
  if(binding.beforeSource===null){
   assert.equal(binding.beforeSha256,null,path+' genuinely added');
   assert.equal(binding.beforeGitBlob,null,path+' absent on Git1dc');
  }else{
   assert.equal(hash(binding.beforeSource),binding.beforeSha256,path+' complete before source');
   assert.equal(blob(binding.beforeSource),binding.beforeGitBlob,path+' original Git blob identity');
  }
  assert.notEqual(binding.beforeSource,current,path+' only changed inputs belong to this layer');
  assert.equal(project(path,current),binding.beforeSource,path);
  assert.equal(project(path,current.replaceAll('\n','\r\n')),binding.beforeSource,path+' CRLF');
  assert.equal(project(path,binding.beforeSource),binding.beforeSource,path+' original complete witness remains unchanged');
  assert.equal(project(path,null),null,path+' absent historical witness');
 }
});

test('partial duplicated reordered missing and cross-path event sources cannot acquire projection permission',()=>{
 assert.ok(helper,'the explicit event source inverse must exist');
 const {eventProductionInverse:proof,preEventProductionSource:project,requireEventProductionSource:requireSource}=helper;
 const entries=Object.entries(proof.files);
 for(const [path,binding]of entries){
  const current=binding.afterSource,lines=current.split('\n'),index=lines.findIndex((line,i)=>line&&lines[i+1]&&line!==lines[i+1]);
  assert.ok(index>=0,path+' meaningful source lines for order controls');
  const missing=[...lines];missing.splice(index,1);
  const duplicated=[...lines];duplicated.splice(index,0,lines[index]);
  const reordered=[...lines];[reordered[index],reordered[index+1]]=[reordered[index+1],reordered[index]];
  for(const mutant of [current+'\n-- unrelated drift\n',current.slice(1),missing.join('\n'),duplicated.join('\n'),reordered.join('\n')]){
   assert.notEqual(mutant,current,path);
   assert.throws(()=>requireSource(path,mutant),/unreviewed integrated event production/);
   assert.equal(project(path,mutant),mutant,'unknown complete bytes stay exposed: '+path);
  }
  for(const absent of [null,undefined,''])assert.throws(()=>requireSource(path,absent),/event production/);
  const foreign=entries.find(([other,value])=>other!==path&&value.afterSha256!==binding.afterSha256);
  assert.ok(foreign,path+' cross-path control');
  assert.throws(()=>requireSource(path,foreign[1].afterSource),/unreviewed integrated event production/);
 }
 const unknown='src/lua/unregistered_event_source.lua',source='return {}\n';
 assert.throws(()=>requireSource(unknown,source),/registered event production/);
 assert.equal(project(unknown,source),source);
});

test('historical event materialization restores every complete1dc source and removes only exact added inputs',()=>{
 assert.ok(helper,'the explicit event source inverse must exist');
 const {eventProductionInverse:proof,materializeBeforeEventProduction:materialize}=helper;
 const directory=temporary();
 try{
  for(const [path,binding]of Object.entries(proof.files))put(directory,path,binding.afterSource.replaceAll('\n','\r\n'));
  put(directory,'keep.txt','unrelated file stays untouched\n');
  materialize(directory);
  for(const [path,binding]of Object.entries(proof.files)){
   const target=join(directory,path);
   if(binding.beforeSource===null)assert.equal(existsSync(target),false,path);
   else assert.equal(readFileSync(target,'utf8'),binding.beforeSource,path);
  }
  assert.equal(readFileSync(join(directory,'keep.txt'),'utf8'),'unrelated file stays untouched\n');
  materialize(directory); // Exact prior sources and already-absent additions are idempotent.
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('event materialization validates the entire live inventory before any destination write or deletion',()=>{
 assert.ok(helper,'the explicit event source inverse must exist');
 const {eventProductionInverse:proof,materializeBeforeEventProduction:materialize}=helper;
 const root=temporary(),sourceRoot=join(root,'live'),target=join(root,'historical');
 const entries=Object.entries(proof.files);
 try{
  mkdirSync(target);put(target,'keep.txt','untouched');
  for(const [path,binding]of entries)put(sourceRoot,path,binding.afterSource);
  for(const [path,binding]of entries){
   for(const mutant of [binding.afterSource+'\n-- unknown live bytes\n',null]){
    if(mutant===null)rmSync(join(sourceRoot,path));else put(sourceRoot,path,mutant);
    assert.throws(()=>materialize(target,{sourceRoot}),/event production/);
    assert.deepEqual(readdirSync(target),['keep.txt']);
    assert.equal(readFileSync(join(target,'keep.txt'),'utf8'),'untouched');
    put(sourceRoot,path,binding.afterSource);
   }
  }
 }finally{rmSync(root,{recursive:true,force:true});}
});

test('unknown destination content is never overwritten or deleted by the event materializer',()=>{
 assert.ok(helper,'the explicit event source inverse must exist');
 const {eventProductionInverse:proof,materializeBeforeEventProduction:materialize}=helper;
 const root=temporary(),target=join(root,'historical');
 try{
  mkdirSync(target);
  for(const [path,binding]of Object.entries(proof.files)){
   const source=binding.afterSource+'\n-- destination does not belong to this proof\n';
   put(target,path,source);put(target,'keep.txt','untouched');
   assert.throws(()=>materialize(target),/unreviewed event production destination/);
   assert.equal(readFileSync(join(target,path),'utf8'),source,path+' no destructive fallback');
   assert.equal(readFileSync(join(target,'keep.txt'),'utf8'),'untouched');
   rmSync(target,{recursive:true});mkdirSync(target);
  }
 }finally{rmSync(root,{recursive:true,force:true});}
});


test('event materialization cannot target the live source root or waive ownership of an added module',()=>{
 assert.ok(helper,'the explicit event source inverse must exist');
 const {eventProductionInverse:proof,materializeBeforeEventProduction:materialize}=helper;
 const added=Object.entries(proof.files).find(([,binding])=>binding.beforeSource===null);
 assert.ok(added,'new event modules must be represented as genuinely absent on1dc');
 assert.throws(()=>materialize(process.cwd()),/separate temporary historical destination/);
 const directory=temporary();
 try{
  assert.throws(()=>materialize(directory,{historicalPaths:[added[0]]}),/only pre-existing event production paths/);
  assert.deepEqual(readdirSync(directory),[]);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
