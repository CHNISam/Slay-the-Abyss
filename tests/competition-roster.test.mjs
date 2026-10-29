import {preRosterConfigSource} from './helpers/competition-roster-config-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preRosterSource,rosterSourceBindings as proof} from './helpers/competition-roster-source-inverse.mjs';
import {preRetirementSource} from './helpers/presentation-announcement-retirement.mjs';
import {preAcceptedPresentation} from './helpers/p0-presentation-inverse.mjs';
test('roster source inverse preserves the complete accepted sources and rejects current admission drift',()=>{
  assert.equal(proof.base,'cec690c1701af121e370facde5c1ca2ad9beb99e');
  assert.deepEqual(Object.keys(proof.files),['src/lua/abyss_game_ui.lua','src/lua/abyss_character_select_view.lua','config/architecture.json']);
  for(const [path,binding]of Object.entries(proof.files)){
  const project=path.endsWith('abyss_game_ui.lua')?preRetirementSource:preAcceptedPresentation;
  const source=preRosterConfigSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n'),'roster');
  const before=preRosterSource(path,source);
  assert.notEqual(source,before);
  assert.equal(createHash('sha256').update(before).digest('hex'),binding.beforeSha256);
  assert.equal(project(path,source),project(path,before));
  for(const hunk of binding.hunks){
    const lines=source.split('\n');
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after);
    const duplicate=hunk.after.length?[...hunk.after,...hunk.after]:[...hunk.before,...hunk.before];
    for(const replacement of [hunk.before,duplicate]){
      const changedLines=[...lines];changedLines.splice(hunk.at,hunk.after.length,...replacement);
      const changed=changedLines.join('\n');assert.notEqual(changed,source);
      if(changed===before)assert.equal(project(path,changed),project(path,before),'an exact whole accepted source remains a usable prior witness');
      else assert.throws(()=>project(path,changed),/unreviewed integrated retirement source drift/);
    }
  }
  assert.throws(()=>project(path,source+'\n-- unrelated drift\n'),/unreviewed integrated retirement source drift/);
  }
});
for (const [name, marker] of [
  ['run', 'COMPETITION_ROSTER_RUN_PASS 4'],
  ['ui', 'COMPETITION_ROSTER_UI_PASS'],
]) test(`competition roster ${name} permits Geo/frozen Raiden and rejects other effective identities`, () => {
  const result=runLua(`tests/lua/competition_roster_${name}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.ok(result.stdout.includes(marker),result.stdout);
});
test('native startup failure lifecycle covers competition Geo and retained full-source Watcher',()=>{
  const result=runLua('tests/lua/game_ui_classes_failure.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/GAME_UI_CLASSES_FAILURE_PASS 7/);
});
