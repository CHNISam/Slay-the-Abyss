import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,mkdirSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
const read=path=>preFormalEntrySource(path,readFileSync(path,'utf8'));
const proofBytes=read('tests/fixtures/pr267-fixture-budget.json');
assert.equal(createHash('sha256').update(proofBytes).digest('hex'),'3883c358a3165e02ef1f7dc0d7cdcb42fdcbaa87c6e09b0c46cc6a56c56c46d7');
const proof=JSON.parse(proofBytes);
const sha=value=>createHash('sha256').update(value).digest('hex');
const blob=value=>createHash('sha1').update(`blob ${Buffer.byteLength(value)}\0`).update(value).digest('hex');
function inverse(source,before,after){assert.equal(source.split(after).length,2,'one complete reviewed edit');return source.replace(after,before);}
function verifyElite(source=read(proof.elite.path),parts=proof.elite.slices){
 const p=proof.elite;assert(source.startsWith(p.prefix));assert(source.endsWith(p.footer));
 const original=inverse(source.slice(p.prefix.length,-p.footer.length),p.before,p.after);
 assert.equal(sha(original),'e622c8b6338eaa7bc0c23e75504b5d65bddead802d2ba789382d45f137b0793d');
 assert.equal(blob(original),'9b5ad319c0002e83dc30a85db1e2a8d4f1660607');
 const covered=[];for(const part of parts)for(let n=part.first;n<=part.last;n++)covered.push(n);
 assert.deepEqual(covered,[1,2,3,4,5,6]);
 assert.deepEqual(parts,[{path:p.path,first:1,last:3},{path:'tests/lua/elite_relic_reward_ui_slice_2.lua',first:4,last:6}]);
 const files=readdirSync('tests/lua');for(const part of parts)assert(files.includes(part.path.slice('tests/lua/'.length)));
 assert.equal(read(parts[1].path),`assert(loadfile("${p.path}"))(4,6)\n`);
 return original;
}
test('PR267 elite partitions preserve every original byte and all six independent groups exactly once',()=>{
 assert.equal(proof.base,'9bab0cfd2c36a43c8f818fe121cdd79d082b683e');assert.equal(proof.timeoutMilliseconds,30000);
 assert.equal(proof.elite.prefix,'local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 3\nlocal sliceRegistered=0\n');
 assert.match(proof.elite.after,/sliceRegistered=sliceRegistered\+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end/);
 assert.match(proof.elite.footer,/assert\(sliceRegistered==6,/);assert.match(proof.elite.footer,/assert\(count==sliceLast-sliceFirst\+1,/);
 verifyElite();
});
test('elite partition proof rejects deleted assertions, skipped groups, overlap and changed wrappers',()=>{
 const source=read(proof.elite.path);const mutation=source.replace("assert(host:start())","assert(true)");assert.notEqual(mutation,source);assert.throws(()=>verifyElite(mutation));
 assert.throws(()=>verifyElite(source,proof.elite.slices.slice(0,1)));
 assert.throws(()=>verifyElite(source,[proof.elite.slices[0],{...proof.elite.slices[1],first:3}]));
 assert.throws(()=>verifyElite(source.replace('fn();count=count+1','count=count+1')));
});
test('Intent keeps the exact original coupled case, frame cadence and full checks outside the leaf-call optimization',()=>{
 assert.equal(sha(read(proof.intent.casePath)),'eec09d6aeb278997b82f0fbd05f8a0ed0448be4b1220101c13ac25ec5c004330');
 const original=inverse(read(proof.intent.path),proof.intent.before,proof.intent.after);
 assert.equal(sha(original),proof.intent.sha256);assert.equal(blob(original),proof.intent.gitBlob);
 assert.match(original,/for _ = 1, 400 do/);assert.match(original,/h:update\(0.05\)/);
});
test('optimized full-state comparison exactly matches the original for equal states and every nested mutation',()=>{
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/pr267-comparison-'));
 try{
  const source=`local old=assert(load(${luaString(proof.intent.before+'\nreturn difference')}))()\nlocal new=assert(load(${luaString(proof.intent.after+'\nreturn difference')}))()\n`+read('tests/lua/support/intent_comparison_equivalence.lua');
  const path=join(directory,'comparison.lua');writeFileSync(path,source);const result=runLua(path);
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/INTENT_COMPARISON_EQUIVALENCE_PASS/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
