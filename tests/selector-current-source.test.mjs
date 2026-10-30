import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {createHash} from 'node:crypto';
import {selectorCurrentSourceProof as proof,preSelectorCurrentSource as project} from './helpers/selector-current-source.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
test('exact selector restores develop98 and preserves current selection bytes, CRLF and bidirectional proof',()=>{
 const live=read(proof.path),prior=project(proof.path,live);assert.equal(live.length,proof.afterUTF16Length);assert.equal(hash(live),proof.afterSha256);assert.equal(hash(prior),proof.beforeSha256);assert.equal(project(proof.path,live.replaceAll('\n','\r\n')),prior);assert.equal(project(proof.path,prior),prior);assert.equal(read(proof.path),live);
});
test('unknown partial same-length wrong-path and missing selector never acquire inverse permission',()=>{
 const live=read(proof.path),lines=live.split('\n'),h=proof.hunks.find(h=>h.after.length);lines.splice(h.at,h.after.length);
 for(const bad of [null,undefined,'',live.slice(1),live+'\n','!'+live.slice(1),lines.join('\n')])assert.equal(project(proof.path,bad),bad);
 for(const path of ['scripts/test-lua.mjs','src/lua/abyss_battle_ui.lua','./'+proof.path])assert.equal(project(path,live),live);
});
test('all four real imported owners are checked fresh through caller reads after warm success',()=>{
 const live=read(proof.path),owners=new Map(Object.keys(proof.owners).map(p=>[p,read(p)]));let reads=0;
 const readSource=p=>{reads++;assert(owners.has(p));return owners.get(p);};
 assert.equal(hash(project(proof.path,live,{readSource})),proof.beforeSha256);assert.equal(reads,4);
 for(const p of owners.keys()){
  const original=owners.get(p);
  for(const bad of [null,undefined,original+'\n','!'+original.slice(1)]){owners.set(p,bad);assert.throws(()=>project(proof.path,live,{readSource}),/selector linked source/);}
  owners.set(p,original);assert.equal(hash(project(proof.path,live,{readSource})),proof.beforeSha256);
  assert.throws(()=>project(proof.path,live,{readSource:q=>{if(q===p)throw Error('missing');return owners.get(q);}}),/selector linked source missing/);
 }
});
