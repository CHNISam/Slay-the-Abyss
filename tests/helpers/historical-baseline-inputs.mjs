// Complete original inputs for historical source contracts, never current game
// acceptance. Real helpers run unchanged against an isolated source directory.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync,symlinkSync,existsSync} from 'node:fs';
import {dirname,join,resolve,relative,isAbsolute} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {gunzipSync} from 'node:zlib';

const sourceRoot=fileURLToPath(new URL('../..',import.meta.url));
const archiveUrl=new URL('../fixtures/pr323-historical-fixtures.json.gz',import.meta.url);
const hash=(algorithm,source)=>createHash(algorithm).update(source).digest('hex');
export function historicalInputPath(directory,path){
 assert.ok(typeof path==='string'&&!isAbsolute(path)&&!/^[A-Za-z]:/.test(path)&&!path.includes('\\')&&!path.split('/').some(part=>!part||part==='.'||part==='..'),'relative original input: '+path);
 const target=resolve(directory,path),within=relative(resolve(directory),target);
 assert.ok(within&&!isAbsolute(within)&&!within.startsWith('..'),'isolated historical input: '+path);
 return target;
}
function sourceArchive(){
 const archive=JSON.parse(gunzipSync(readFileSync(archiveUrl)));
 assert.equal(archive.sourceCommit,'98fef95d047652aa6a8880241ddff28ef320a484');
 return archive;
}
function baselineInputs(archive){
 const groups=[archive.files,archive.maintainedSources,archive.baselineInputs],inputs={};
 for(const group of groups){
  assert.ok(group&&typeof group==='object');
  for(const [path,binding]of Object.entries(group)){
   assert.ok(!Object.hasOwn(inputs,path),'unique original input: '+path);
   historicalInputPath(sourceRoot,path);
   assert.ok(binding.encoding===undefined||['utf8','base64'].includes(binding.encoding),'original input encoding');
   const bytes=Buffer.from(binding.source,binding.encoding||'utf8');
   assert.equal(hash('sha256',bytes),binding.sourceSha256,'original complete source: '+path);
   assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),binding.gitBlob,'original Git blob: '+path);
   inputs[path]=bytes;
  }
 }
 return inputs;
}
export function loadHistoricalBaselineInputs(){return baselineInputs(sourceArchive());}
export function verifyOriginalRuntimeTarget(target){
 // Fixed original executable inputs, not a digest read from the same archive.
 // Changes require review against the original source proofs and Git inputs.
 assert.equal(hash('sha256',JSON.stringify(target)),'29ac235c54dbc163291ddda3d3cb3940a8e3302c324b8146154f2ac67a1e3e38','immutable original historical runtime target manifest');
}
export function verifyOriginalBattleUiInputs(target){
 assert.equal(hash('sha256',JSON.stringify(target)),'f35e6549b2ec2e0dc5a3581da9a3e14a09694de3834d68ed1d7cfca335bf0189','immutable original #372 battle UI input manifest');
}
export function loadHistoricalRuntimeBundle(name){
 const archive=sourceArchive(),inputs=baselineInputs(archive);
 if(name===undefined)return {inputs};
 assert.ok(['presentation','battleUi'].includes(name),'declared original runtime source target');
 const target=archive.runtimeTargets?.[name];assert.ok(target,'complete original runtime source target');
 if(name==='presentation')verifyOriginalRuntimeTarget(target);else verifyOriginalBattleUiInputs(target);
 assert.equal(target.inputCommit,archive.sourceCommit);
 const files={};
 for(const [path,binding]of Object.entries(target.files)){
  historicalInputPath(sourceRoot,path);
  if(binding.source===null){assert.equal(binding.sourceSha256,null);assert.equal(binding.gitBlob,null);files[path]=null;continue;}
  const bytes=Buffer.from(binding.source);
  assert.equal(hash('sha256',bytes),binding.sourceSha256,'complete original runtime source: '+path);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),binding.gitBlob,'original runtime Git blob: '+path);
  files[path]=bytes;
 }
 if(name==='battleUi'){
  assert.equal(target.historicalHead,'38f4dd8aea7fa77370146e616700c68fd1bea911');
  // Bind the complete original epoch, including unchanged 98 input files and
  // declared absences. Sparse storage never permits a mixed source closure.
  for(const [path,blob]of Object.entries(target.completeGitBlobs)){
   historicalInputPath(sourceRoot,path);
   const bytes=Object.hasOwn(files,path)?files[path]:inputs[path];
   assert.equal(bytes==null?null:createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),blob,'complete original #372 Git input: '+path);
  }
  for(const path of Object.keys(files))assert.ok(Object.hasOwn(target.completeGitBlobs,path),'declared complete #372 input: '+path);
  // These pre-existing complete fixture/support witnesses remain independent
  // of the new original-input archive and retain all their existing bytes.
  for(const path of ['tests/lua/battle_ui.lua',...Array.from({length:6},(_,i)=>`tests/lua/battle_ui_slice_${i+2}.lua`),'tests/lua/support/battle_ui_cases.lua']){
   const bytes=Object.hasOwn(files,path)?files[path]:inputs[path];assert.deepEqual(bytes,inputs[path],'unchanged full frozen battle UI fixture: '+path);
  }
  const supportBytes=readFileSync(new URL('../fixtures/historical-monster-ui-support.json',import.meta.url));
  assert.equal(hash('sha256',supportBytes.toString('utf8').replaceAll('\r\n','\n')),'f536f06de7bea3052a7303db34ec37cc68b631704f337ae3efba2d39515821ed');
  for(const [path,binding]of Object.entries(JSON.parse(supportBytes).files)){
   const bytes=Object.hasOwn(files,path)?files[path]:inputs[path];assert.equal(hash('sha256',bytes),binding.beforeSha256,'existing original battle support: '+path);
  }
  return {inputs,target:files};
 }
 // Critical final sources are independently bound by the existing unchanged
 // source records. Their actual Git bytes matched all 26 formal beforeSha.
 const p0Bytes=readFileSync(new URL('../fixtures/p0-accepted-presentation-inverses.json.gz',import.meta.url));
 assert.equal(hash('sha256',p0Bytes),'6f74bc575b24e5c830119e0309b0311017cbeba5ad5cc6d1fdcc44f69a27e164');
 const p0=JSON.parse(gunzipSync(p0Bytes));
 const uiBytes=readFileSync(new URL('../fixtures/approved-ui-latest-to-53fa.json',import.meta.url));
 assert.equal(hash('sha256',uiBytes),'39f651e8ec7a3037947d1a76123c2d03a521dd4a05168565f80f7222590ec89a');
 const approved=JSON.parse(uiBytes);assert.equal(target.historicalHead,p0.historicalHead);
 for(const path of new Set([...Object.keys(p0.files),...Object.keys(approved.files)])){
  const binding=Object.hasOwn(p0.files,path)?p0.files[path]:approved.files[path];
  const bytes=Object.hasOwn(files,path)?files[path]:inputs[path];
  assert.equal(bytes===null||bytes===undefined?null:hash('sha256',bytes),binding.beforeSha256,'unchanged original runtime beforeSha: '+path);
 }
 return {inputs,target:files};
}
export function readHistoricalBaselineSource(path){
 const inputs=loadHistoricalBaselineInputs();assert.ok(Object.hasOwn(inputs,path),'registered original input: '+path);
 return inputs[path].toString('utf8');
}
export function withHistoricalBaseline(callback){
 assert.equal(typeof callback,'function','historical cwd callback');
 assert.notEqual(callback.constructor.name,'AsyncFunction','historical cwd callbacks must be synchronous');
 const previous=process.cwd(),directory=mkdtempSync(join(tmpdir(),'abyss-source-contract-'));
 try{
  // Every call gets real new files. Mutations in another case or working tree
  // can never be reused as a historical source or linked-owner validation.
  for(const [path,source]of Object.entries(loadHistoricalBaselineInputs())){
   const target=historicalInputPath(directory,path);
   mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source);
  }
  // Immutable oracle records stay at their real location. No source directory
  // is aliased, and historical helpers never write into these oracle folders.
  for(const path of ['tests/fixtures','node_modules']){
   const original=join(sourceRoot,path);if(!existsSync(original))continue;
   const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});
   symlinkSync(original,target,process.platform==='win32'?'junction':'dir');
  }
  process.chdir(directory);
  const result=callback();
  assert.ok(!result||typeof result.then!=='function','historical cwd callbacks must be synchronous');
  return result;
 }finally{
  process.chdir(previous);rmSync(directory,{recursive:true,force:true});
 }
}
export function historicalTest(name,callback){
 assert.equal(typeof callback,'function','historical cwd callback');
 assert.notEqual(callback.constructor.name,'AsyncFunction','historical cwd callbacks must be synchronous');
 return test('[historical 98fef source contract] '+name,context=>withHistoricalBaseline(()=>callback(context)));
}
