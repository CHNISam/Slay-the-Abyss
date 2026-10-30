import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync,readdirSync,symlinkSync,existsSync,statSync,copyFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preMonsterInventorySource as pre,monsterInventorySourceProof as proof} from './helpers/monster-inventory-source.mjs';
import {preDeliveryTargetSource} from './helpers/delivery-source-composition.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import {preNativeMonsterArtSource,prepareNativeMonsterRetirement} from './helpers/native-monster-art-source-inverse.mjs';
import {preMultiMonsterArtSource} from './helpers/multi-monster-art-source-inverse.mjs';
const path='scripts/monster-art.mjs',normalize=s=>s.replaceAll('\r\n','\n');
const live=normalize(readFileSync(path,'utf8'));
const read=p=>readFileSync(p,'utf8');
const projections=[(s,o)=>pre(path,s,o),(s,o)=>preDeliveryTargetSource(path,s,'legacyM3',o),(s,o)=>preIntegrationSource(path,s,'monster',o),(s,o)=>preNativeMonsterArtSource(path,s,o),(s,o)=>preMultiMonsterArtSource(path,s,o)];
test('inventory optimization retreats exactly and preserves all historical projection targets',()=>{
 const previous=pre(path,live);
 assert.equal(createHash('sha256').update(previous).digest('hex'),proof.files[path].beforeSha256);
 assert.equal(pre(path,live.replaceAll('\n','\r\n')),previous);
 for(const project of projections)assert.equal(project(live,{readSource:read}),project(previous,{readSource:read}));
 for(const mutant of [live+' ',live.slice(1),live.replace('import','Import'),live+'😀'])assert.equal(pre(path,mutant),mutant);
 assert.equal(pre('foreign/'+path,live),live);
});
test('all public source bridges re-read caller-owned inventory source after warm success',()=>{
 for(const project of projections){
  let current=live,reads=0;
  const readSource=p=>{if(p===path){reads++;return current;}return read(p);};
  project(live,{readSource});const warm=reads;assert(warm>0);
  for(const mutation of [live+' ',live.replace('import','Import'),undefined]){current=mutation;assert.throws(()=>project(live,{readSource}),/linked source/);}
  assert(reads>warm);current=live;project(live,{readSource});
  assert.throws(()=>project(live,{readSource:p=>{if(p===path)throw Error('missing');return read(p);}}),/linked source/);
 }
});
test('native retirement validates isolated sourceRoot rather than falling back to global checkout',()=>{
 const root=mkdtempSync(join(tmpdir(),'inventory-owner-')),destination=mkdtempSync(join(tmpdir(),'inventory-retire-'));
 try{
  for(const name of readdirSync(process.cwd()))if(name!=='.git'&&name!=='scripts'){if(statSync(name).isDirectory())symlinkSync(resolve(name),join(root,name),'junction');else copyFileSync(name,join(root,name));}
  mkdirSync(join(root,'scripts'));for(const name of readdirSync('scripts'))if(name!=='monster-art.mjs'){const from=resolve('scripts',name),to=join(root,'scripts',name);if(statSync(from).isDirectory())symlinkSync(from,to,'junction');else copyFileSync(from,to);}
  mkdirSync(join(destination,'scripts'));const target=join(destination,path);writeFileSync(target,live);
  assert.throws(()=>prepareNativeMonsterRetirement(destination,{sourceRoot:root}),/linked source/);assert(existsSync(target));
  writeFileSync(join(root,path),live.replace('import','Import'));
  assert.throws(()=>prepareNativeMonsterRetirement(destination,{sourceRoot:root}),/linked source/);assert(existsSync(target));
  writeFileSync(join(root,path),live);const retire=prepareNativeMonsterRetirement(destination,{sourceRoot:root});assert(existsSync(target));retire();assert(!existsSync(target));
 }finally{rmSync(root,{recursive:true,force:true});rmSync(destination,{recursive:true,force:true});}
});
