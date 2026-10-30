import test from 'node:test';
import assert from 'node:assert/strict';
import {buildNativeAudioGame} from '../scripts/build-native-audio-game.mjs';
test('audio entrypoint forwards requested native artwork into the real full build',async()=>{
 const marker=Error('stop before SDK'),art={registry:'reviewed-registry.json',hosts:['battlePanel/card1']};
 let called=false;
 await assert.rejects(buildNativeAudioGame({baseMap:'unused.gil',nativeCardArt:art,buildFull:async options=>{
  called=true;assert.deepEqual(options.nativeCardArt,art);throw marker;
 }}),e=>e===marker);
 assert.equal(called,true);
});

for(const [name,options] of [['normal',{}],['disabled',{readyCardArt:false}],['explicit zero',{nativeCardArt:{count:0}}]])
 test(`audio entrypoint preserves ${name} artwork selection before SDK startup`,async()=>{
  const marker=Error('stop before SDK');let called=false;
  await assert.rejects(buildNativeAudioGame({baseMap:'unused.gil',...options,buildFull:async full=>{
   called=true;assert.deepEqual(full.nativeCardArt,options.nativeCardArt);
   assert.equal(full.readyCardArt,options.readyCardArt);throw marker;
  }}),e=>e===marker);
  assert.equal(called,true);
 });
