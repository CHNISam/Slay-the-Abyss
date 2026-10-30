import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preCharacterLayoutSource,characterLayoutProof} from './helpers/character-layout-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('character layout projection preserves every complete historical owner and exposes mutations',()=>{
 for(const [path,b] of Object.entries(characterLayoutProof.files)){
  const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');assert.equal(hash(live),b.afterSha256);
  const prior=preCharacterLayoutSource(path,live);assert.equal(hash(prior),b.beforeSha256);
  for(const drift of [live+'\n',live.replace(/./,'!')])assert.equal(preCharacterLayoutSource(path,drift),drift);
  assert.equal(preCharacterLayoutSource(path,prior),prior);
 }
});
