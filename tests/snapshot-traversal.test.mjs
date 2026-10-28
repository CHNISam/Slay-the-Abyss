import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {luaString} from '../scripts/build-lua-data.mjs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=value=>createHash('sha256').update(value).digest('hex');
const bytes=read('tests/fixtures/snapshot-traversal-20261028.json');
assert.equal(sha(bytes),'b990616586d3997b67980f2af0caf316a7969264d573c5edc51ea85258981be6');
const proof=JSON.parse(bytes);
function original(source){assert.equal(source.split(proof.after).length,2);return source.replace(proof.after,proof.before);}
test('snapshot changes only the exact complete graph traversal, preserving all rollback and owner operations',()=>{
 assert.equal(proof.base,'9bab0cfd2c36a43c8f818fe121cdd79d082b683e');
 const legacy=read('tests/lua/support/snapshot_legacy_20261028.lua');
 assert.equal(sha(legacy),proof.sha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(legacy)+'\0').update(legacy).digest('hex'),proof.gitBlob);
 assert.equal(original(read(proof.path)),legacy);
 assert.throws(()=>original(read(proof.path).replace('pending[top]=nil','pending[top]=false')));
 assert.notEqual(sha(original(read(proof.path).replace('owners[owner]=nil','owners[owner]=target'))),proof.sha256);
 assert.equal(sha(read('tests/lua/silent_natural_build.lua')),'979708a7554d9d6467c34646e089f70dccdaee648f09893366ac5b7eccecf3e5','entire original same-instance double natural replay remains unchanged');
});
test('old and new snapshots both restore full cyclic aliased table-key graphs, deep chains and single-use owners',()=>{
 const result=runLua('tests/lua/snapshot_graph_equivalence.lua');assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SNAPSHOT_EQUIVALENCE_PASS 96/);
});

test('graph regressions reject omitted key-only nodes, false values and data/catalog exclusions',()=>{
 const source=read(proof.path);
 const changes=[
  ["if kind(k)=='table' and not saved[k] then", "if false and kind(k)=='table' and not saved[k] then"],
  ['values[k]=v', 'if v then values[k]=v end'],
  ["if kind(v)=='table' and not saved[v] then", "if k~='data' and k~='catalog' and kind(v)=='table' and not saved[v] then"],
 ];
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/snapshot-negative-'));
 try{
  for(const [index,[before,after]]of changes.entries()){
   assert.equal(source.split(before).length,2);
   const path=join(directory,`mutant-${index}.lua`);
   writeFileSync(path,`package.loaded.abyss_snapshot=assert(load(${luaString(source.replace(before,after))}))()\ndofile('tests/lua/snapshot_graph_equivalence.lua')\n`);
   const result=runLua(path);assert.notEqual(result.status,0,'the complete graph fixture must kill each omission');
   assert.match(result.stderr,/snapshot target is not captured|all original fields and identities must restore/);
  }
 }finally{rmSync(directory,{recursive:true,force:true});}
});
