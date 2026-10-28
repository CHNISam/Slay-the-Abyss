import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {loadContent,validateContent,contentFiles} from '../scripts/validate-data.mjs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
const read=path=>readFileSync(path,'utf8');
const vectors=JSON.parse(read('tests/fixtures/sts1-class-relic-pool-vectors.json'));
const catalogs=JSON.parse(read('data/catalogs/sts1-class-relic-queues.json'));
const sha=path=>createHash('sha256').update(read(path).replaceAll('\r\n','\n')).digest('hex');
test('all three chosen-class relic catalogs retain complete source registrations and stable shared order',()=>{
 const old=JSON.parse(read('data/catalogs/sts1-relic-queues.json'));
 const registrationText=read('tests/fixtures/sts1-relic-library-registration.tsv').replaceAll('\r\n','\n');
 assert.equal(sha(vectors.generator),vectors.generatorSha256);
 assert.equal(sha(vectors.jdkGenerator),vectors.jdkGeneratorSha256);
 assert.equal(sha(vectors.seedInput),vectors.seedInputSha256);
 assert.equal(sha(vectors.luaFixture),vectors.luaSha256);
 // Windows checkout CRLF must not become part of a source relic identity.
 for (const text of [registrationText,registrationText.replaceAll('\n','\r\n')]) {
 const registration=text.trim().split(/\r?\n/).map(line=>line.split('\t'));
 const red=new Set(registration.filter(row=>row[0]==='red').map(row=>row[2]));
 assert.ok(red.has('Red Skull'),'exact Ironclad source identity survives LF and CRLF');
 for (const [character,library] of [['silent','green'],['defect','blue'],['watcher','purple']]) {
  const source=catalogs[character];assert.equal(source.character,character);assert.equal(source.sourceCommit,vectors.sourceCommit);
  for (const [tier,ids] of Object.entries(source.queues)) {
   const extra=vectors.registration.filter(row=>row.library===library&&row.tier===tier).map(row=>row.id);
   assert.deepEqual(ids.filter(id=>!extra.includes(id)),old.queues[tier].filter(id=>!red.has(id)));
   assert.deepEqual(ids.filter(id=>extra.includes(id)).sort(),extra.sort());
   assert.ok(ids.every(id=>!red.has(id)));
  }
 }
 }
});
test('content loader and validation require each complete chosen-class source',()=>{
 const data=loadContent('data');assert.deepEqual(validateContent(data),[]);
 for (const mutate of [d=>{delete d.classRelicSources.defect;},d=>d.classRelicSources.watcher.queues.boss.pop(),
  d=>{d.classRelicSources.silent.character='ironclad';}]) {
  const changed=structuredClone(data);mutate(changed);
  assert.ok(validateContent(changed).some(error=>error.includes('classRelicSources')));
 }
});
test('new class catalog remains a protected build input',()=>{
 const root=mkdtempSync(join(tmpdir(),'class-relic-input-'));
 try {
  const data=loadContent('data');for (const file of contentFiles) writeFileSync(join(root,`${file}.json`),JSON.stringify(data[file]));
  mkdirSync(join(root,'catalogs'));const input=join(root,'catalogs/sts1-class-relic-queues.json');
  const source=JSON.stringify(data.classRelicSources);writeFileSync(input,source);
  writeFileSync(join(root,'catalogs/sts1-relic-queues.json'),JSON.stringify(data.relicSource));
  assert.throws(()=>buildLuaData(root,input),/must not overwrite an input/);assert.equal(read(input),source);
 } finally { rmSync(root,{recursive:true,force:true}); }
});
test('default Ironclad vectors and all original V4 historical source contracts stay unchanged',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/class_relic_pool_default.lua');assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/CLASS_RELIC_POOL default 10 JVM vectors and four original roles passed/);
});
for (const character of ['silent','defect','watcher']) test(`${character} Run and all shared source channels use their own full queues`,()=>{
 const result=runLua(`tests/fixtures/js-owned/tests/lua/class_relic_pool_${character}.lua`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`CLASS_RELIC_POOL ${character} 10 JVM vectors`));
});
