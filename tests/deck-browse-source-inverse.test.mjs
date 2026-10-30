import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {deckBrowseSourceLayer as proof,preDeckBrowseSource} from './helpers/deck-browse-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('M4 deck controls recover only the seven complete pre-feature source identities',()=>{
 for(const [path,binding]of Object.entries(proof.files)){
  const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(live),binding.afterSha256,path);
  const before=preDeckBrowseSource(path,live);
  assert.equal(hash(before),binding.beforeSha256,path);
  assert.equal(preDeckBrowseSource(path,live.replaceAll('\n','\r\n')),before);
  assert.equal(preDeckBrowseSource(path,before),before);
  assert.equal(preDeckBrowseSource(path,null),null);
  for(const hunk of binding.hunks){
   assert.notEqual(hunk.after,hunk.before);
   for(const mutant of [live+'\n',live.slice(1),live.replace(hunk.after,hunk.before),live.replace(hunk.after,hunk.after+hunk.after),live.replace(hunk.after,hunk.after+'\n-- unknown')]){
    assert.notEqual(mutant,live);
    // An exact complete old source is also left untouched, not broadened.
    assert.equal(preDeckBrowseSource(path,mutant),mutant,path);
   }
  }
 }
 assert.equal(preDeckBrowseSource('unregistered','unknown'),'unknown');
});
