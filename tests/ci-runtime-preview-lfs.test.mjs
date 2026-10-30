import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import * as lfs from '../scripts/ci-reviewed-lfs.mjs';

const paths=['armaments','cleave','heavy_blade'].map(id=>`art/cards/traveler-geo/${id}/preview-native.png`).concat('art/characters/key-visual/traveler-geo/official-landscape-v1/preview-native.png');
const png=Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),Buffer.alloc(56,7)]);
const oid=createHash('sha256').update(png).digest('hex');
const pointer=`version https://git-lfs.github.com/spec/v1\noid sha256:${oid}\nsize ${png.length}\n`;
function git(root,...args){const r=spawnSync('git',['-c','core.hooksPath=',...args],{cwd:root,encoding:'utf8',env:{...process.env,GIT_LFS_SKIP_SMUDGE:'1',GIT_NO_LAZY_FETCH:'1'}});assert.equal(r.status,0,r.stderr);return r.stdout.trim();}
async function fixture(t){
 const root=mkdtempSync(join(tmpdir(),'runtime-lfs-'));t.after(()=>rmSync(root,{recursive:true,force:true}));git(root,'init');
 const source=readFileSync('scripts/ci-reviewed-lfs.mjs','utf8').replace(/export const runtimePreviewObjects = \[[\s\S]*?\n\];/,`export const runtimePreviewObjects = ${JSON.stringify(paths.map(()=>[oid,png.length]))};`);
 const module=join(root,'materializer.mjs');writeFileSync(module,source);
 for(const path of paths){mkdirSync(join(root,path,'..'),{recursive:true});writeFileSync(join(root,path),pointer);git(root,'add','--',path);writeFileSync(join(root,path),png);}
 return {root,api:await import(pathToFileURL(module).href)};
}

test('runtime selection is a separate frozen four-preview group, with no source image budget expansion',()=>{
 assert.deepEqual(lfs.runtimePreviewPaths,paths);
 assert.equal(lfs.maxRuntimePreviewBytes,181870);
 assert.deepEqual(lfs.runtimePreviewObjects,[["b7b2cd9c4fdfa3f1d893156405a51afc8b8bd1b65a776a9f704086c97685b2ff", 30121], ["271c49cc6248cf46ea029cc63387c682858b43c29288eb32b44d24175e662b39", 36567], ["aefb4d2ca114a8738029249fba8b1bdc4f6235be648684cbfe348ed496388936", 34027], ["e23d1daac5e7046f9119edbd6179fd16fa31abd245c24d395adfd1af31a91a43", 81155]]);
 assert.equal(lfs.runtimePreviewObjects.reduce((sum,row)=>sum+row[1],0),181870);
 assert.equal(lfs.maxReviewedPngBytes,5983528);assert.equal(lfs.reviewedPngPaths.length,6);
 assert.deepEqual(lfs.runtimePreviewArguments.slice(-6),['lfs','pull','--include',paths.join(','),'--exclude','']);
 assert.deepEqual(lfs.prepareRuntimePreviews({root:'/does-not-exist'}),{status:'not-needed'});
});
test('runtime PNG cache verifies pointer identities first and exact bytes after',async t=>{
 const {root,api}=await fixture(t);
 assert.deepEqual(api.prepareRuntimePreviews({root,needed:true}),{status:'cached',count:4,bytes:256});
 writeFileSync(join(root,paths[0]),pointer.replace(oid,'0'.repeat(64)));git(root,'add','--',paths[0]);writeFileSync(join(root,paths[0]),png);
 assert.throws(()=>api.prepareRuntimePreviews({root,needed:true}),/frozen runtime preview object/);
});
test('runtime pointer size, malformed pointer and corrupt PNG fail closed',async t=>{
 for(const replacement of [pointer.replace('size 64','size 999999'),pointer.replace('size 64','size 63'),'not a pointer']){
  const {root,api}=await fixture(t);writeFileSync(join(root,paths[0]),replacement);git(root,'add','--',paths[0]);writeFileSync(join(root,paths[0]),png);
  assert.throws(()=>api.prepareRuntimePreviews({root,needed:true}),/runtime preview|Runtime preview/);
 }
 const {root,api}=await fixture(t);writeFileSync(join(root,paths[0]),Buffer.alloc(64));
 assert.throws(()=>api.verifyRuntimePreviews(root),/not the frozen runtime preview PNG/);
 writeFileSync(join(root,paths[0]),pointer);assert.throws(()=>api.verifyRuntimePreviews(root),/not the frozen runtime preview PNG/);
});

test('empty and Lua-only plans skip runtime input reads; any selected JS consumer opts in',()=>{
 assert.equal(lfs.needsRuntimePreviews([]),false);
 assert.equal(lfs.needsRuntimePreviews(['tests/lua/default.lua']),false);
 assert.equal(lfs.needsRuntimePreviews(['tests/official-background-build.test.mjs']),true);
 assert.equal(lfs.needsRuntimePreviews(['tests/future-subprocess-consumer.test.mjs']),true);
 for(const file of ['scripts/ci-fast.mjs','scripts/ci-shards.mjs']){
  const source=readFileSync(file,'utf8');
  assert.match(source,/prepareRuntimePreviews\(\{ needed: needsRuntimePreviews\(plan\.(?:js|files)\) \}\)/);
 }
 assert.throws(()=>lfs.prepareRuntimePreviews({needed:'true',root:'/does-not-exist'}),/selection must be boolean/);
});

function offlineLfs(root) {
 // Copy only an existing commit object, not its tree or LFS cache; no new commit.
 const commit=spawnSync('git',['cat-file','commit','HEAD']);assert.equal(commit.status,0);
 const object=spawnSync('git',['hash-object','-t','commit','-w','--stdin'],{cwd:root,input:commit.stdout,encoding:'utf8'});assert.equal(object.status,0);
 git(root,'update-ref','refs/heads/fixture',object.stdout.trim());git(root,'symbolic-ref','HEAD','refs/heads/fixture');
 git(root,'config','lfs.url',pathToFileURL(join(root,'absent-server')).href);
 writeFileSync(join(root,'.gitattributes'),paths.map(p=>`${p} filter=lfs diff=lfs merge=lfs -text`).join('\n')+'\n');git(root,'add','.gitattributes');
 const cache=join(root,'.git/lfs/objects',oid.slice(0,2),oid.slice(2,4),oid);mkdirSync(join(cache,'..'),{recursive:true});writeFileSync(cache,png);
 for(const path of paths)writeFileSync(join(root,path),pointer);
 return cache;
}
test('real offline LFS pull materializes only four previews and reuses verified cache',async t=>{
 const {root,api}=await fixture(t);offlineLfs(root);
 const extra=join(root,'unselected.png');writeFileSync(extra,'untouched');
 assert.deepEqual(api.prepareRuntimePreviews({root,needed:true}),{status:'materialized',count:4,bytes:256});
 assert.equal(readFileSync(extra,'utf8'),'untouched');
 assert.deepEqual(api.prepareRuntimePreviews({root,needed:true}),{status:'cached',count:4,bytes:256});
 // Zero-exit pull does not overwrite corrupt existing materialized files.
 writeFileSync(join(root,paths[0]),Buffer.alloc(64));
 assert.throws(()=>api.prepareRuntimePreviews({root,needed:true}),/not the frozen runtime preview PNG/);
});
test('missing local payload fails closed without leaking token or transport diagnostics',async t=>{
 const {root,api}=await fixture(t);const cache=offlineLfs(root);rmSync(cache);
 assert.throws(()=>api.prepareRuntimePreviews({root,needed:true,env:{...process.env,CI_LFS_TOKEN:'never-echo-this'}}),error=>{
  assert.match(error.message,/Runtime preview LFS materialization failed/);
  assert.doesNotMatch(error.message,/never-echo-this|AUTHORIZATION|absent-server/);return true;
 });
});

test('real fast and shard entrypoints dispatch bounded preparation only for selected JS',t=>{
 const root=mkdtempSync(join(tmpdir(),'runtime-routing-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 mkdirSync(join(root,'scripts'));mkdirSync(join(root,'tests'));mkdirSync(join(root,'tests/lua'));
 // Replace only external preparation/build side effects; execute the actual CI entrypoints.
 for(const file of ['ci-fast.mjs','ci-shards.mjs','ci-test-timings.json'])writeFileSync(join(root,'scripts',file),readFileSync('scripts/'+file));
 writeFileSync(join(root,'scripts/ci-reviewed-lfs.mjs'),`import {appendFileSync} from 'node:fs';
 export function needsRuntimePreviews(files){return files.some(p=>/^tests\\/[^/]+\\.test\\.mjs$/.test(p));}
 export function prepareRuntimePreviews(options){appendFileSync('calls.jsonl',JSON.stringify(options)+'\\n');return options;}
 export function prepareReviewedAssets(){appendFileSync('calls.jsonl','"reviewed"\\n');return {};}`);
 for(const name of ['build-lua-data','build-ui','map-ui-layout','test-lua'])writeFileSync(join(root,'scripts',name+'.mjs'),'');
 const selected='tests/reviewed-traveler-geo-assets.test.mjs';writeFileSync(join(root,selected),'');
 const env={...process.env,GITHUB_SHA:'exact'};delete env.NODE_TEST_CONTEXT;
 for(const [js,lua,expected] of [[[],[],false],[[],['tests/lua/default.lua'],false],[[selected],[],true]]){
  writeFileSync(join(root,'ci-impact.json'),JSON.stringify({mode:'fast',sha:'exact',js,lua}));writeFileSync(join(root,'calls.jsonl'),'');
  const result=spawnSync(process.execPath,['scripts/ci-fast.mjs'],{cwd:root,env,encoding:'utf8'});assert.equal(result.status,0,result.stderr);
  const calls=readFileSync(join(root,'calls.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  assert.deepEqual(calls,expected?['reviewed',{needed:true}]:[{needed:false}]);
 }
 writeFileSync(join(root,'calls.jsonl'),'');
 const result=spawnSync(process.execPath,['scripts/ci-shards.mjs','--prepare=1/1'],{cwd:root,env,encoding:'utf8'});assert.equal(result.status,0,result.stderr);
 assert.deepEqual(readFileSync(join(root,'calls.jsonl'),'utf8').trim().split('\n').map(JSON.parse),['reviewed',{needed:true}]);
});

test('already materialized shared card previews do not require their missing LFS cache again',async t=>{
 const {root}=await fixture(t);const sharedCache=offlineLfs(root);
 for(const path of paths.slice(0,3))writeFileSync(join(root,path),png);
 rmSync(sharedCache); // A redundant attempt to download shared previews would fail offline.
 const background=Buffer.from(png);background[20]=99;
 const backgroundOid=createHash('sha256').update(background).digest('hex');
 const backgroundPointer=pointer.replace(oid,backgroundOid);
 writeFileSync(join(root,paths[3]),backgroundPointer);
 const object=spawnSync('git',['hash-object','-w','--stdin'],{cwd:root,input:backgroundPointer,encoding:'utf8'});assert.equal(object.status,0);
 git(root,'update-index','--cacheinfo','100644',object.stdout.trim(),paths[3]);
 const cache=join(root,'.git/lfs/objects',backgroundOid.slice(0,2),backgroundOid.slice(2,4),backgroundOid);mkdirSync(join(cache,'..'),{recursive:true});writeFileSync(cache,background);
 const module=join(root,'deduplicated.mjs');
 writeFileSync(module,readFileSync(join(root,'materializer.mjs'),'utf8').replace(/export const runtimePreviewObjects = \[[^;]+;/,
  `export const runtimePreviewObjects = ${JSON.stringify(paths.map((_,i)=>[i===3?backgroundOid:oid,64]))};`));
 const api=await import(pathToFileURL(module).href);
 assert.deepEqual(api.prepareRuntimePreviews({root,needed:true}),{status:'materialized',count:4,bytes:256});
 for(const path of paths.slice(0,3))assert.deepEqual(readFileSync(join(root,path)),png);
 assert.deepEqual(readFileSync(join(root,paths[3])),background);
});
