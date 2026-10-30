import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {preRelicRound3CompositionSource} from './helpers/relic-round3-composition.mjs';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync,symlinkSync,renameSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {projectArtPerfSource,artPerfSourceComposition} from './helpers/art-perf-source-composition.mjs';
import {round3CatalogProof as proof,preRound3CatalogSource as prior,prepareRound3CatalogModuleRetirement as retire} from './helpers/round3-catalog-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const current=path=>preRelicRound3CompositionSource(path,preNativeMonsterArtSource(path,readFileSync(path,'utf8')),'round3').replaceAll('\r\n','\n');
const added='src/lua/abyss_combat_catalog.lua';
for(const path of ['config/architecture.json','src/lua/abyss_combat.lua']){
 test('exact catalog delta recovers complete rebased 1bfca626 identity: '+path,()=>{
  const source=current(path),binding=proof.files[path];
  assert.equal(hash(source),binding.afterSha256);
  const original=prior(path,source);
  assert.equal(hash(original),binding.beforeSha256);
  assert.equal(prior(path,original),original);
  assert.equal(prior(path,source.replaceAll('\n','\r\n')),original);
 });
 test('catalog inverse exposes partial, extra and duplicate drift: '+path,()=>{
  const source=current(path),binding=proof.files[path];
  const hunk=binding.hunks.find(h=>h.after.length),text=hunk.after.join('\n');
  for(const drift of [source+'\n-- extra\n',source.slice(1),source.replace(text,hunk.before.join('\n')),source.replace(text,text+'\n'+text)]){
   assert.notEqual(drift,source);assert.equal(prior(path,drift),drift);
  }
  assert.equal(prior('src/lua/unknown.lua',source),source);
  assert.equal(prior(path,null),null);
 });
 test('catalog inverse binds complete extracted responsibility: '+path,()=>{
  const source=current(path);
  for(const readSource of [()=>{throw new Error('missing');},()=>null,()=>current(added)+'\n-- drift\n',()=>current(added).replace('Colorless.withCards','Other.withCards')]){
   assert.throws(()=>prior(path,source,{readSource}),/catalog linked/);
  }
 });
}

test('rebased config retains the exact original 9293405d performance identity through the unchanged art proof',()=>{
 const path='config/architecture.json';
 assert.equal(hash(prior(path,current(path))),artPerfSourceComposition.files[path].currentSha256);
 assert.equal(hash(projectArtPerfSource(path,current(path),'perf')),
  '2a067420c4503b0efdf16ebe22eb7177a69759e4d41e50a15161422f6dcc41ed');
 assert.equal(hash(projectArtPerfSource(path,current(path),'art')),artPerfSourceComposition.files[path].targets.art.sha256);
});
test('only exact catalog module has no historical identity',()=>{
 const source=current(added);
 assert.equal(prior(added,source),null);
 assert.equal(prior(added,source+'\n'),source+'\n');
 assert.equal(prior('src/lua/renamed_catalog.lua',source),source);
});
test('retirement validates the exact copied module before deferred cleanup and refuses the live tree',()=>{
 assert.throws(()=>retire(process.cwd()),/separate historical destination/);
 const directory=mkdtempSync(join(tmpdir(),'abyss-catalog-inverse-'));
 try{
  mkdirSync(join(directory,'src/lua'),{recursive:true});
  const target=join(directory,added);writeFileSync(target,current(added)+'\n-- unknown\n');
  assert.throws(()=>retire(directory),/unreviewed catalog module destination/);
  assert.ok(existsSync(target),'rejected source stays intact');
  writeFileSync(target,current(added));const cleanup=retire(directory);
  assert.ok(existsSync(target),'validation itself never removes files');
  cleanup();assert.equal(existsSync(target),false);
  retire(directory)();assert.ok(existsSync(added),'live source remains intact');
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('retirement refuses content changed after preparation and preserves the file',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-catalog-drift-'));
 try{
  mkdirSync(join(directory,'src/lua'),{recursive:true});
  const target=join(directory,added);writeFileSync(target,current(added));
  const cleanup=retire(directory),changed=current(added)+'\n-- changed after preparation\n';
  writeFileSync(target,changed);
  assert.throws(cleanup,/unreviewed catalog module destination/);
  assert.equal(readFileSync(target,'utf8'),changed);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

function linkDirectory(t,target,path){
 try{symlinkSync(target,path,process.platform==='win32'?'junction':'dir');return true;}
 catch(error){
  if(!['EPERM','EACCES','ENOTSUP'].includes(error.code))throw error;
  t.skip('directory links unavailable: '+error.code);return false;
 }
}
test('retirement rejects a directory alias for the source module',t=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-catalog-alias-'));
 try{
  const sourceRoot=join(directory,'source'),alias=join(directory,'alias');
  mkdirSync(join(sourceRoot,'src/lua'),{recursive:true});
  writeFileSync(join(sourceRoot,added),current(added));
  if(!linkDirectory(t,sourceRoot,alias))return;
  assert.throws(()=>retire(alias,{sourceRoot}),/separate historical module/);
  assert.ok(existsSync(join(sourceRoot,added)));
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('retirement rejects a destination retargeted after preparation',t=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-catalog-retarget-'));
 try{
  const sourceRoot=join(directory,'source'),historical=join(directory,'historical');
  for(const root of [sourceRoot,historical]){
   mkdirSync(join(root,'src/lua'),{recursive:true});writeFileSync(join(root,added),current(added));
  }
  const cleanup=retire(historical,{sourceRoot});
  renameSync(join(historical,'src/lua'),join(historical,'src/saved-lua'));
  if(!linkDirectory(t,join(sourceRoot,'src/lua'),join(historical,'src/lua')))return;
  assert.throws(cleanup,/catalog module destination changed/);
  assert.ok(existsSync(join(sourceRoot,added)));
  assert.ok(existsSync(join(historical,'src/saved-lua/abyss_combat_catalog.lua')));
 }finally{rmSync(directory,{recursive:true,force:true});}
});
