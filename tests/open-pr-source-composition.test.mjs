import {preTitleMenuSource} from './helpers/title-menu-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {openPrSourceComposition as proof,projectOpenPrSource as project} from './helpers/open-pr-source-composition.mjs';
import {preBattleLifeSource} from './helpers/battle-life-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');

test('combined source projection binds complete live sources and all reviewed slice targets',()=>{
 assert.equal(proof.schemaVersion,1);
 assert.deepEqual(Object.keys(proof.heads),['hero','relic','event']);
 for(const[path,binding]of Object.entries(proof.files)){
  const source=preBattleLifeSource(path,preTitleMenuSource(path,readFileSync(path,'utf8'))).replaceAll('\r\n','\n');
  assert.equal(source,binding.current,path+' exact live composition');
  assert.equal(hash(source),binding.currentHash,path);
  for(const[target,witness]of Object.entries(binding.targets)){
   assert.equal(project(path,source,target),witness.source,path+' '+target);
   assert.equal(project(path,source.replaceAll('\n','\r\n'),target),witness.source,path+' CRLF '+target);
   assert.equal(hash(witness.source),witness.hash);
  }
 }
});

test('composition projection refuses missing partial duplicated reordered cross-path and unrelated bytes',()=>{
 const entries=Object.entries(proof.files);
 for(const[path,binding]of entries){
  const lines=binding.current.split('\n'),at=lines.findIndex((line,i)=>line&&lines[i+1]&&line!==lines[i+1]);
  assert.ok(at>=0,path);
  const duplicated=[...lines];duplicated.splice(at,0,lines[at]);
  const reordered=[...lines];[reordered[at],reordered[at+1]]=[reordered[at+1],reordered[at]];
  for(const mutant of [null,undefined,'',binding.current.slice(1),binding.current+'\n-- drift\n',duplicated.join('\n'),reordered.join('\n')])
   for(const target of Object.keys(proof.heads))assert.equal(project(path,mutant,target),mutant,path+' unknown stays exposed');
  const foreign=entries.find(([other,value])=>other!==path&&value.currentHash!==binding.currentHash);
  assert.ok(foreign);
  for(const target of Object.keys(proof.heads))assert.equal(project(path,foreign[1].current,target),foreign[1].current);
  assert.equal(project(path,binding.current,'unregistered'),binding.current);
 }
 assert.equal(project('unregistered.lua','return {}','event'),'return {}');
});
