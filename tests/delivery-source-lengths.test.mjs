import {prePostBetaRuntimeSource} from './helpers/post-beta-runtime-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preDeckDeliverySource} from './helpers/deck-delivery-source-composition.mjs';
import {deliverySourceProof as proof,deliverySourceLengths as lengths,preDeliveryTargetSource as project,preDeliverySource} from './helpers/delivery-source-composition.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s,'utf8').digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s,'utf8')+'\0').update(s,'utf8').digest('hex');
const read=p=>normalize(preDeckDeliverySource(p,prePostBetaRuntimeSource(p,readFileSync(p,'utf8'))));
const current=(p,t)=>t==='develop'?project(p,read(p),'developEvents'):t==='pre379'?preDeliverySource(p,read(p)):read(p);
test('every length derives from the exact full Git blob and canonical UTF16 code-unit spelling',()=>{
 let total=0,unicode=0;
 for(const[t,{files}]of Object.entries(proof.targets))for(const[p,b]of Object.entries(files)){
  const s=current(p,t),l=lengths.targets[t][p];total++;
  assert.equal(s.length,l.utf16Length,p+' '+t);assert.equal(hash(s),l.afterSha256);assert.equal(blob(s),l.afterGitBlob);
  assert.equal(normalize(s.replaceAll('\n','\r\n')).length,l.utf16Length);
  if(Buffer.byteLength(s,'utf8')!==s.length)unicode++;
  const previous=project(p,s,t);assert.equal(project(p,s.replaceAll('\n','\r\n'),t),previous);
 }
 assert.equal(total,365);assert.ok(unicode>0,'actual non-ASCII sources are included');
 assert.ok(Object.isFrozen(lengths));assert.throws(()=>{lengths.targets.developEvents['config/architecture.json'].utf16Length++;},TypeError);
});
test('length inequality only rejects; same-length ASCII Unicode surrogate and NUL mutations still require original complete hashes',()=>{
 for(const[t,{files}]of Object.entries(proof.targets))for(const p of Object.keys(files)){
  const s=current(p,t);assert.ok(s.length>2);
  const mutants=[s+'\n',s.slice(1),(s[0]==='X'?'Y':'X')+s.slice(1),'界'+s.slice(1),'🙂'+s.slice(2),'\0'+s.slice(1)];
  for(const bad of mutants){assert.notEqual(bad,s);assert.equal(project(p,bad,t),bad,p+' '+t);}
 }
});
