import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preClassChoiceSource as pre,classChoiceSourceProof as proof} from './helpers/class-choice-source.mjs';
const path='tests/lua/game_ui_class_choices.lua';
const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');
test('current actor access retreats exactly before frozen class-choice body checks',()=>{
 const prior=pre(path,live);assert.equal(createHash('sha256').update(prior).digest('hex'),proof.files[path].beforeSha256);
 assert.equal(pre(path,live.replaceAll('\n','\r\n')),prior);
 for(const mutant of [live+' ',live.slice(1),live.replace('local','Local'),live+'😀'])assert.equal(pre(path,mutant),mutant);
 assert.equal(pre('wrong/'+path,live),live);
});
test('class-choice owner is freshly read after warm recognition',()=>{
 let current=live,reads=0;const readSource=p=>{assert.equal(p,path);reads++;return current;};
 pre(path,live,{readSource});
 for(const mutant of [live+' ',live.replace('local','Local'),undefined]){current=mutant;assert.throws(()=>pre(path,live,{readSource}),/linked source/);}
 assert.equal(reads,4);current=live;pre(path,live,{readSource});
 assert.throws(()=>pre(path,live,{readSource:()=>{throw Error('missing');}}),/linked source/);
});
