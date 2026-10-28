import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {currentSourceLayers as layers,preCurrentSource} from './helpers/task77-current-source-layers.mjs';
import {formalEntryInverses,preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import {preRetirementSource} from './helpers/presentation-announcement-retirement.mjs';
import {controlsGuide} from '../scripts/controls-guide-layout.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
function invert(source,binding){
 assert.equal(hash(source),binding.afterSha256);
 for(const edit of binding.edits){assert.equal(source.split(edit.after).length,2);source=source.replace(edit.after,edit.before);}
 assert.equal(hash(source),binding.beforeSha256);return source;
}
function acceptedSource(path){const source=preApprovedUiSource(path,read(path));return layers.competition[path]?invert(source,layers.competition[path]):source;}

test('current Task77 source reverses only its owned edits and preserves the complete accepted confirmation/UI base',()=>{
 assert.equal(layers.acceptedBase,'77c2d5e6850f1758b821e5e2d45be60e8b5ed8a4');
 assert.equal(layers.canonicalBindingSha256,hash(read('docs/reviews/formal-entry-source-inverses-20261028.json')));
 assert.deepEqual(Object.keys(layers.competition),['src/lua/abyss_game_ui.lua','src/lua/abyss_ui.lua']);
 for(const [path,binding]of Object.entries(layers.competition)){
  const live=read(path),accepted=invert(live,binding);
  assert.equal(hash(accepted),binding.beforeSha256);
  assert.equal(preFormalEntrySource(path,live),preFormalEntrySource(path,accepted));
  for(const edit of binding.edits){
   for(const mutation of [live.replace(edit.after,edit.before),live.replace(edit.after,edit.after+edit.after)])
    assert.throws(()=>preRetirementSource(path,mutation),/unreviewed integrated retirement source drift/);
  }
 }
 assert.match(read('src/lua/abyss_game_ui.lua'),/CharacterSelect\.options\(character\)[\s\S]*selection\.campaignProfile=platform\.campaignProfile[\s\S]*Run\.new/);
});

test('accepted UI source layers recover the original immutable formal bindings and reject incomplete or duplicated changes',()=>{
 assert.deepEqual(Object.keys(layers.acceptedUi),['data/presentation/ui_theme.json','scripts/character-ui-layout.mjs','scripts/game-ui-layout.mjs','src/lua/abyss_game_ui.lua']);
 for(const [path,binding]of Object.entries(layers.acceptedUi)){
  const accepted=acceptedSource(path),canonical=invert(accepted,binding);
  assert.equal(hash(canonical),formalEntryInverses[path].afterSha256,'original formal golden retained');
  assert.equal(preCurrentSource(path,accepted),canonical);
  assert.equal(hash(preFormalEntrySource(path,accepted)),formalEntryInverses[path].beforeSha256);
  for(const edit of binding.edits){
   for(const mutation of [accepted.replace(edit.after,edit.before),accepted.replace(edit.after,edit.after+edit.after)])
    assert.throws(()=>preFormalEntrySource(path,mutation),/unreviewed integrated retirement source drift/);
  }
  assert.throws(()=>preFormalEntrySource(path,accepted+'\n-- unrelated drift\n'),/unreviewed integrated retirement source drift/);
 }
});

test('new controls guide offers same-run controls only, not later acts, keys or persistent continuation',()=>{
 assert.doesNotMatch(JSON.stringify(controlsGuide()),/第三幕|第四幕|真结局|钥匙|存档|续玩|保留进度/);
});
