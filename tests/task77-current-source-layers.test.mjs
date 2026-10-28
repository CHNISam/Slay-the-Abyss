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
function acceptedSource(path){
 let source=read(path);
 if(layers.noticeFix[path])source=invert(source,layers.noticeFix[path]);
 return layers.competition[path]?invert(source,layers.competition[path]):source;
}

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

// Current geometry has its own strict identity; the old geometry remains a historical input only.
test('reviewed battle notice is the only new theme delta and current identity cannot downgrade or hide drift',()=>{
 const path='data/presentation/ui_theme.json',live=read(path),binding=layers.noticeFix[path];
 assert.deepEqual(Object.keys(layers.noticeFix),[path]);
 assert.equal(binding.afterSha256,'68fac59a6200dd5cf43070851bd0ef4323b73134ede1dea97107939b0dc8fdd2');
 assert.equal(binding.beforeSha256,layers.acceptedUi[path].afterSha256);
 assert.equal(binding.edits.length,1);
 const current=JSON.parse(live),old=invert(live,binding);
 assert.deepEqual(current.layout.battleNotice,{position:[-330,206],size:[520,80]});
 const restored=structuredClone(current);restored.layout.battleNotice={position:[0,228],size:[1080,32]};
 assert.deepEqual(restored,JSON.parse(old),'every unrelated live theme field remains byte-bound and value-identical');
 assert.equal(preFormalEntrySource(path,live),preFormalEntrySource(path,old),'old formal/archive identity is retained');
 assert.equal(preRetirementSource(path,live),preRetirementSource(path,old));
 const edit=binding.edits[0];
 for(const mutant of [old,live.replace(edit.after,edit.after+edit.after),live+'\n',
  live.replace('        -330,\n        206','        -329,\n        206'),
  live.replace('        520,\n        80','        520,\n        79'),
  live.replace('"body": 18','"body": 19')]){
  assert.notEqual(mutant,live);
  assert.throws(()=>invert(mutant,binding),'direct current identity rejects old geometry and all unreviewed bytes');
  if(mutant!==old)assert.throws(()=>preFormalEntrySource(path,mutant),/unreviewed integrated retirement source drift/);
 }
});
