import fs from 'node:fs';
import {syncBuiltinESMExports} from 'node:module';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync,copyFileSync,rmSync,unlinkSync,linkSync,symlinkSync} from 'node:fs';
import {join,dirname,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {prepareMonsterArt,monsterArtInputPaths} from '../scripts/monster-art.mjs';
const registryPath='data/presentation/native-monster-art.json';
const original=JSON.parse(readFileSync(registryPath,'utf8'));
const paths=prepareMonsterArt().inputPaths;
function fixture(fn){
 const home=process.cwd(),root=mkdtempSync(join(tmpdir(),'monster-input-inventory-'));
 try{
  for(const path of [registryPath,...paths]){mkdirSync(dirname(join(root,path)),{recursive:true});copyFileSync(resolve(path),join(root,path));}
  process.chdir(root);return fn(root);
 }finally{process.chdir(home);rmSync(root,{recursive:true,force:true});}
}
function failure(fn){try{fn();return null;}catch(e){return {name:e.name,message:e.message,code:e.code};}}
function equalFailure(){const normal=failure(()=>prepareMonsterArt()),inventory=failure(()=>monsterArtInputPaths());assert(normal,'invalid input must fail the original producer');assert.deepEqual(inventory,normal,'same validation order and error');}
test('inventory reads the same ordered source paths but owns a fresh unpolluted result on every call',()=>fixture(()=>{
 assert.deepEqual(monsterArtInputPaths(),prepareMonsterArt().inputPaths);
 const first=monsterArtInputPaths();first[0]='polluted';first.push('extra');
 assert.deepEqual(monsterArtInputPaths(),paths,'a prior result must never pollute another inventory');
 const art=prepareMonsterArt();art.assets[art.asset.enemyId].slots[0].image=-1;art.inputPaths.length=0;
 assert.deepEqual(monsterArtInputPaths(),paths,'unconsumed mutable output cannot affect input inventory');
}));
const changes={
 'schema':r=>r.schemaVersion=2,
 'enabled type':r=>r.enabled='yes',
 'pool budget':r=>r.poolCount=2,
 'source record count':r=>r.sourceInputs.pop(),
 'source traversal':r=>r.sourceInputs[0].path='art/monsters/acid_slime_m/native-art-r02/../native-art.lua',
 'source identity':r=>r.sourceInputs[0].sha256='0'.repeat(64),
 'canvas':r=>r.canvas=[0,64],
 'asset identity':r=>r.asset.enemyId='wrong',
 'slot budget':r=>r.asset.slots=Array(601).fill(r.asset.slots[0]),
 'slot image':r=>r.asset.slots[0].image=99,
 'slot mature type':r=>r.asset.slots[0].kind='unsupported',
 'binding type':r=>r.bindings=[],
 'binding unknown asset':r=>r.bindings.acid_slime_m='missing',
 'unbound asset':r=>{const id=Object.keys(r.additionalAssets)[0];for(const enemy of Object.keys(r.bindings))if(r.bindings[enemy]===id)delete r.bindings[enemy];},
 'additional identity':r=>r.additionalAssets[Object.keys(r.additionalAssets)[0]].enemyId='wrong',
 'additional provenance count':r=>r.additionalAssets[Object.keys(r.additionalAssets)[0]].sourceInputs.pop(),
 'additional provenance hash':r=>r.additionalAssets[Object.keys(r.additionalAssets)[0]].sourceInputs[0].sha256='f'.repeat(64),
 'multiple-invalid precedence':r=>{r.schemaVersion=-1;r.sourceInputs=[];},
};
for(const [name,change]of Object.entries(changes))test('inventory preserves original rejection: '+name,()=>fixture(()=>{
 const r=structuredClone(original);change(r);writeFileSync(registryPath,JSON.stringify(r));equalFailure();
}));
test('inventory preserves disabled-registry early return and malformed JSON failure',()=>fixture(()=>{
 writeFileSync(registryPath,JSON.stringify({schemaVersion:1,enabled:false}));assert.equal(prepareMonsterArt(),null);assert.equal(monsterArtInputPaths(),null);
 writeFileSync(registryPath,'{bad JSON');equalFailure();
}));
for(const target of [0,paths.length-1])for(const mutation of ['missing','corrupt'])test(`every call rereads ${mutation} source ${target}`,()=>fixture(()=>{
 assert.deepEqual(monsterArtInputPaths(),paths);
 if(mutation==='missing')unlinkSync(paths[target]);else writeFileSync(paths[target],'changed after successful inventory');
 equalFailure();
}));
for(const mode of ['hardlink','symlink'])test('inventory preserves '+mode+' input identity and detects subsequent backing mutation',t=>fixture(root=>{
 const input=paths[0],backing=join(root,'backing.lua');copyFileSync(input,backing);unlinkSync(input);
 try{if(mode==='hardlink')linkSync(backing,input);else symlinkSync(backing,input,'file');}catch(e){if(mode==='symlink'&&['EPERM','EACCES','ENOSYS'].includes(e.code)){t.skip(e.code);return;}throw e;}
 assert.deepEqual(monsterArtInputPaths(),prepareMonsterArt().inputPaths);
 writeFileSync(backing,'aliased source changed');equalFailure();
}));
test('normal prepare API still clones output graphs and rejects noncloneable custom extensions',()=>{
 const input=structuredClone(original),prepared=prepareMonsterArt(input);
 assert.notEqual(prepared.asset.slots,input.asset.slots);assert.notEqual(prepared.additionalAssets,input.additionalAssets);
 assert.equal(prepared.bindings,input.bindings,'normal API retains its original binding-reference contract');
 prepared.asset.slots[0].image=-1;assert.notEqual(input.asset.slots[0].image,-1);
 const bad=structuredClone(original);bad.asset.unusedCallback=()=>{};
 assert.throws(()=>prepareMonsterArt(bad),{name:'DataCloneError'});
});

test('inventory performs the identical registry and every source read in original order',()=>fixture(()=>{
 const originalRead=fs.readFileSync;let reads=[];
 try{
  fs.readFileSync=function(path,...args){reads.push(String(path));return originalRead.call(this,path,...args);};syncBuiltinESMExports();
  prepareMonsterArt();const normal=reads;reads=[];monsterArtInputPaths();
  assert.deepEqual(reads,normal);assert.deepEqual(reads,[registryPath,...paths]);
 }finally{fs.readFileSync=originalRead;syncBuiltinESMExports();}
}));
