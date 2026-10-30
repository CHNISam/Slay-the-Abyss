import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {syncBuiltinESMExports} from 'node:module';
import {readFileSync} from 'node:fs';
import {preDeliveryTargetSource} from './helpers/delivery-source-composition.mjs';
import {prePostBetaRuntimeSource} from './helpers/post-beta-runtime-source.mjs';
import {preDeckDeliverySource} from './helpers/deck-delivery-source-composition.mjs';

test('delivery inverse reuses verified pure raw-string projections without repeating Git-blob hashes',()=>{
 const path='config/architecture.json';
 const source=preDeckDeliverySource(path,prePostBetaRuntimeSource(path,readFileSync(path,'utf8')));
 let hashes=0;const original=crypto.createHash;
 crypto.createHash=(algorithm,...args)=>{if(algorithm==='sha1')hashes++;return original(algorithm,...args);};
 syncBuiltinESMExports();
 try{
  const prior=preDeliveryTargetSource(path,source,'legacyMulti');
  assert.notEqual(prior,source);assert.ok(hashes>0,'cold recognition verifies Git blobs');
  const cold=hashes;
  assert.equal(preDeliveryTargetSource(path,source,'legacyMulti'),prior);
  assert.equal(hashes,cold,'warm pure inverse does not repeat Git-blob hashing');
  assert.equal(preDeliveryTargetSource(path,source.replaceAll('\n','\r\n'),'legacyMulti'),prior);
  assert.ok(hashes>cold,'CRLF input has its own raw-string cache key');
 }finally{crypto.createHash=original;syncBuiltinESMExports();}
});
