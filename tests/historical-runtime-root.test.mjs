import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync,existsSync,lstatSync,symlinkSync} from 'node:fs';
import {join,relative,isAbsolute} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {createHistoricalRuntimeRoots,writeHistoricalRuntimeSnapshot} from './helpers/historical-runtime-root.mjs';
import {materializeHistoricalMonsterUi} from './helpers/historical-monster-ui-materialize.mjs';
import {verifyOriginalRuntimeTarget,verifyOriginalBattleUiInputs,loadHistoricalRuntimeBundle} from './helpers/historical-baseline-inputs.mjs';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';

test('runtime replay roots contain independent original files outside the workspace and leave live source and art untouched',()=>{
 const path='src/lua/abyss_feedback.lua',livePath=fileURLToPath(new URL('../'+path,import.meta.url));
 const art=fileURLToPath(new URL('../art/performance/background-budget-v1.json',import.meta.url));
 const live=readFileSync(livePath),liveArt=readFileSync(art),previous=process.cwd();
 const roots=createHistoricalRuntimeRoots();
 try{
  assert.notEqual(roots.sourceRoot,roots.directory);
  for(const root of [roots.sourceRoot,roots.directory]){
   const inside=relative(tmpdir(),root);assert.ok(inside&&!isAbsolute(inside)&&!inside.startsWith('..'));
   assert.equal(lstatSync(join(root,'src')).isSymbolicLink(),false);
   assert.equal(lstatSync(join(root,'art')).isSymbolicLink(),false);
   assert.equal(lstatSync(join(root,'art/performance')).isSymbolicLink(),false);
   assert.deepEqual(readFileSync(join(root,path)),roots.inputs[path]);
  }
  writeFileSync(join(roots.directory,path),'-- actual target drift\n');
  assert.deepEqual(readFileSync(join(roots.sourceRoot,path)),roots.inputs[path]);
  assert.deepEqual(readFileSync(livePath),live);
  assert.deepEqual(readFileSync(art),liveArt);
  process.chdir(roots.directory);
 }finally{roots.close();}
 assert.equal(process.cwd(),previous);
 assert.equal(existsSync(roots.sourceRoot),false);assert.equal(existsSync(roots.directory),false);
});

test('runtime snapshots reject original writes through resource aliases and materialization rejects source aliases',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-historical-alias-test-'));
 try{
  const root=join(directory,'snapshot'),outside=join(directory,'outside');
  mkdirSync(root);mkdirSync(outside);writeFileSync(join(outside,'keep.txt'),'untouched');
  const alias=join(root,'alias');symlinkSync(outside,alias,process.platform==='win32'?'junction':'dir');
  assert.throws(()=>writeHistoricalRuntimeSnapshot(root,{'alias/keep.txt':Buffer.from('overwrite')}),/readonly resource alias/);
  assert.throws(()=>materializeHistoricalMonsterUi(alias,outside),/aliases its source root/);
  assert.equal(readFileSync(join(outside,'keep.txt'),'utf8'),'untouched');
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('single-root replay keeps an original private snapshot without allocating a second source root',()=>{
 const path='src/lua/abyss_feedback.lua',livePath=fileURLToPath(new URL('../'+path,import.meta.url));
 const live=readFileSync(livePath),previous=process.cwd(),roots=createHistoricalRuntimeRoots({source:false});
 try{
  assert.equal(roots.sourceRoot,undefined);
  assert.deepEqual(readFileSync(join(roots.directory,path)),roots.inputs[path]);
  writeFileSync(join(roots.directory,path),'-- private projected source\n');
  assert.deepEqual(readFileSync(livePath),live);
  process.chdir(roots.directory);
 }finally{roots.close();}
 assert.equal(process.cwd(),previous);assert.equal(existsSync(roots.directory),false);
});

test('an original target cannot refresh a non-formal source or absence by rewriting its own hashes',()=>{
 const archive=JSON.parse(gunzipSync(readFileSync(new URL('./fixtures/pr323-historical-fixtures.json.gz',import.meta.url))));
 verifyOriginalRuntimeTarget(archive.runtimeTargets.presentation);
 const changed=structuredClone(archive.runtimeTargets.presentation),binding=changed.files['src/lua/abyss_actor.lua'];
 assert.equal(typeof binding.source,'string');binding.source+='\n-- unrelated source replacement\n';
 binding.sourceSha256=createHash('sha256').update(binding.source).digest('hex');
 binding.gitBlob=createHash('sha1').update(`blob ${Buffer.byteLength(binding.source)}\0`).update(binding.source).digest('hex');
 assert.throws(()=>verifyOriginalRuntimeTarget(changed),/immutable original historical runtime target manifest/);
 const missing=structuredClone(archive.runtimeTargets.presentation),absent=Object.keys(missing.files).find(path=>missing.files[path].source===null);
 assert.ok(absent);delete missing.files[absent];
 assert.throws(()=>verifyOriginalRuntimeTarget(missing),/immutable original historical runtime target manifest/);
});

test('the original #372 battle input epoch retains complete fixtures and refuses a refreshed source or absence',()=>{
 const archive=JSON.parse(gunzipSync(readFileSync(new URL('./fixtures/pr323-historical-fixtures.json.gz',import.meta.url))));
 const target=archive.runtimeTargets.battleUi;verifyOriginalBattleUiInputs(target);
 const bundle=loadHistoricalRuntimeBundle('battleUi');
 assert.ok(bundle.target['src/lua/abyss_battle_actions.lua'].toString().includes('dependencies.notice("")'));
 const changed=structuredClone(target),binding=changed.files['src/lua/abyss_battle_actions.lua'];
 binding.source+='\n-- source refresh\n';
 binding.sourceSha256=createHash('sha256').update(binding.source).digest('hex');
 binding.gitBlob=createHash('sha1').update(`blob ${Buffer.byteLength(binding.source)}\0`).update(binding.source).digest('hex');
 changed.completeGitBlobs['src/lua/abyss_battle_actions.lua']=binding.gitBlob;
 assert.throws(()=>verifyOriginalBattleUiInputs(changed),/immutable original #372/);
 const missing=structuredClone(target),path=Object.keys(missing.files).find(path=>missing.files[path].source===null);
 assert.ok(path);delete missing.files[path];delete missing.completeGitBlobs[path];
 assert.throws(()=>verifyOriginalBattleUiInputs(missing),/immutable original #372/);
});
