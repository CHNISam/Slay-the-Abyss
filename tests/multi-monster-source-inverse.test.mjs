import {preLegacyMultiSource} from './helpers/delivery-source-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {multiMonsterSourceLayer as layer,preMultiMonsterArtSource as pre} from './helpers/multi-monster-art-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('multi-monster outer layer recovers only exact complete parent source bytes',()=>{
 for(const [path,entry]of Object.entries(layer.files)){
  const live=preLegacyMultiSource(path,readFileSync(path,'utf8')).replaceAll('\r\n','\n');assert.equal(hash(live),entry.afterSha256);
  assert.equal(pre(path,live)===null?null:hash(pre(path,live)),entry.beforeSha256);assert.equal(pre(path,live.replaceAll('\n','\r\n')),entry.beforeSource);
  for(const bad of [live+'\n-- foreign drift',live.slice(1),live.replace(/MonsterArt|monster|pool/,'unknown')])if(bad!==live)assert.equal(pre(path,bad),bad);
  assert.equal(pre('wrong/'+path,live),live);assert.equal(pre(path,entry.beforeSource),entry.beforeSource);
 }
});
