import {preHeroVisualSource} from './helpers/hero-visual-source-inverse.mjs';
import {historicalTest as test,readHistoricalSourceData,readHistoricalPlayerDeathInput} from './helpers/historical-baseline-inputs.mjs';
import {preRelicViewUiSource} from './helpers/relic-view-ui-inverse.mjs';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {playerDeathLayer,prePlayerDeathSource} from './helpers/player-death-transition-inverse.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import {preAcceptedPr323Source,preOriginalPr323Source,requirePr323Source,readAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import {deathSettlementGuardLayer,preDeathSettlementGuardSource} from './helpers/death-settlement-guard-inverse.mjs';
import {preRosterConfigSource} from './helpers/competition-roster-config-composition.mjs';
import {preRosterSource,rosterSourceBindings} from './helpers/competition-roster-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
// TASK-4.7 relic view UI is the outermost exact layer above this guard.
const read=path=>{
 if(path==='tests/helpers/player-death-transition-inverse.mjs')return readHistoricalSourceData(path);
 const source=path==='tests/lua/support/battle_gesture_fixture.lua'?readHistoricalPlayerDeathInput(path):readFileSync(path,'utf8');
 return preRelicViewUiSource(path,preHeroVisualSource(path,preRelicViewUiSource(path,source)).replaceAll('\r\n','\n'));
};
test('one exact settlement guard precedes the frozen accepted330 death and PR323 layers',()=>{
  const path='src/lua/abyss_game_ui.lua',live=read(path),binding=deathSettlementGuardLayer.files[path];
  assert.equal(deathSettlementGuardLayer.acceptedBase,'1dc33fe790a5f82be4f1bf2f0d09e339dcb943dd');
  assert.deepEqual(Object.keys(deathSettlementGuardLayer.files),[path]);
  assert.equal(hash(read('tests/fixtures/player-death-transition-inverse.json')),'864bef1d366836036fc8d7cefd6c9fb18d0c90877628f1030a310ac780148dd7','accepted330 eleven-input witness remains byte-exact');
  assert.equal(hash(read('tests/helpers/player-death-transition-inverse.mjs')),'8739d0142bc2a2ad8a451e3c1c66696639ffbc983f3f52c69e23419ba4477a15','accepted330 death helper remains byte-exact');
  assert.equal(existsSync('tests/helpers/player-death-transition-inverse.mjs'),false,'original helper source evidence is not an executable historical input');
  assert.equal(hash(live),binding.afterSha256);
  assert.equal(binding.hunks.length,1);assert.equal(binding.hunks[0].before.length,1);assert.equal(binding.hunks[0].after.length,1);
  const accepted=preDeathSettlementGuardSource(path,live);
  assert.equal(hash(accepted),binding.beforeSha256);
  assert.equal(binding.beforeSha256,playerDeathLayer.files[path].afterSha256,'outer guard recovers the exact already-accepted death host');
  assert.equal(preDeathSettlementGuardSource(path,live.replaceAll('\n','\r\n')),accepted);
  assert.equal(preDeathSettlementGuardSource(path,accepted),accepted);
  assert.equal(preDeathSettlementGuardSource(path,null),null);
  assert.equal(hash(prePlayerDeathSource(path,accepted)),playerDeathLayer.files[path].beforeSha256);
  for(const project of [preAcceptedPr323Source,preOriginalPr323Source])assert.equal(project(path,live),project(path,accepted),'all source routes invert guard before accepted death');
  assert.equal(readAcceptedPr323Source(path),preAcceptedPr323Source(path,live),'disk reads use the same exact order');
  assert.equal(requirePr323Source(path,live),requirePr323Source(path,accepted),'explicit source validators use the same exact order');
  assert.equal(preApprovedUiSource(path,live),preApprovedUiSource(path,accepted));
  for(const changed of [live+'\n-- drift\n',live.slice(1),live.replace('self.run.phase == "defeat" and self.battleUI.busy','self.run.phase == "defeat" or self.battleUI.busy')]){
    assert.notEqual(changed,live);assert.equal(preDeathSettlementGuardSource(path,changed),changed,'partial or unrelated sources never acquire guard permission');
    assert.throws(()=>requirePr323Source(path,changed),/unreviewed integrated/);
    assert.throws(()=>preApprovedUiSource(path,changed),/unreviewed integrated/);
  }
  assert.equal(preDeathSettlementGuardSource('unregistered.lua',live),live,'a matching body under the wrong path is not authorized');
});
function originalDeathCases(source){
  const prefix='return function(first, last)\n';
  const registration='    registered = registered + 1\n    if registered < first or registered > last then return end\n';
  const footer="assert(registered == 10 and count == last - first + 1, 'all death cases must register and the entire selected slice must run')\nprint('LUA_PLAYER_DEATH_TRANSITION_PASS ' .. first .. ' ' .. last .. ' ' .. count)\nend\n";
  assert.ok(source.startsWith(prefix) && source.endsWith(footer),'exact death partition wrapper and complete execution guard');
  assert.equal(hash(source),'27c94f4e438319d12c32abeefd0605ca0683b4c6fbb157973de61e607c8ef2bc','complete original330 death case fixture input');
  let original=source.slice(prefix.length,-footer.length);
  assert.equal(original.split('local count, registered = 0, 0\n').length,2);
  assert.equal(original.split(registration).length,2);
  original=original.replace('local count, registered = 0, 0\n','local count = 0\n').replace(registration,'')+"print('LUA_PLAYER_DEATH_TRANSITION_PASS ' .. count)\n";
  assert.equal(hash(original),'a8c6ff9fede30b619d63d5f142f066dd33cd894f3c34e96930f99374bb5b3159','all original328/331 assertions, helpers, timing and seeds remain byte-identical');
  return original;
}
test('both original-budget death slices cover exactly the unchanged ten complete cases',()=>{
  const wrappers=['player_death_transition.lua','player_death_transition_slice_2.lua'];
  assert.deepEqual(readdirSync('tests/lua').filter(path=>/^player_death_transition(?:_slice_\d+)?\.lua$/.test(path)).sort(),wrappers);
  assert.equal(read('tests/lua/'+wrappers[0]),"dofile('tests/lua/support/player_death_cases.lua')(1, 5)\n");
  assert.equal(read('tests/lua/'+wrappers[1]),"dofile('tests/lua/support/player_death_cases.lua')(6, 10)\n");
  assert.deepEqual([[1,5],[6,10]].flatMap(([first,last])=>Array.from({length:last-first+1},(_,i)=>first+i)),Array.from({length:10},(_,i)=>i+1));
  const cases=read('tests/lua/support/player_death_cases.lua');
  assert.equal((cases.match(/^test\('/gm)||[]).length,10);
  originalDeathCases(cases);
  for(const changed of [cases+'\n-- drift\n',cases.replace('assert(ui.run.phase','assert(true or ui.run.phase'),cases.replace('value = 12','value = 13')]){
    assert.notEqual(changed,cases);assert.throws(()=>originalDeathCases(changed),/exact death partition|complete original330/);
  }
  assert.equal(hash(read('scripts/test-lua.mjs')),'977f7dde00e9c4d2a8b93de7abaf702e5b4595f7cd8c3fdeb8623e47553dc2d6','the complete accepted runner and original30s fixture budgets are unchanged');
});
test('the shared gesture wait has one exact input binding before all unchanged historical guards',()=>{
  const path='tests/lua/support/battle_gesture_fixture.lua',source=read(path),binding=playerDeathLayer.files[path];
  assert.equal(binding.beforeSha256,'64407f8ea32f7591ce65cb25a675acee5e499581155942ee448ca4c300691715');
  assert.equal(binding.afterSha256,'134616d268298a4d3337ca5e65af2af3568a06c3cb3382e4e0fb8e0fcf3a9868');
  assert.equal(binding.hunks.length,1);assert.equal(binding.hunks[0].at,29);
  assert.equal(hash(preFormalEntrySource(path,source)),'b92b90973b271f2a5789f9b59942263ecda7b6fb1922b1b6780b4ae8f892140e','original PR262 shared fixture input recovered');
  const prior=prePlayerDeathSource(path,source);
  assert.equal(preFormalEntrySource(path,prior),preFormalEntrySource(path,source));
  for(const changed of [source+'\n-- drift\n',source.replace('not ui.busy and not host.motion.deathReveal','not ui.busy'),source.replace('for _=1,400','for _=1,800')]){
    assert.notEqual(changed,source);assert.equal(prePlayerDeathSource(path,changed),changed,'partial or unrelated input is never silently authorized');
    assert.throws(()=>preFormalEntrySource(path,changed),/unreviewed integrated/);
  }
});
test('final328 roster projection is already equivalent through the death-first central entry',()=>{
  for(const path of Object.keys(rosterSourceBindings.files)){
    const raw=read(path),central=preAcceptedPr323Source(path,raw),explicit=preAcceptedPr323Source(path,prePlayerDeathSource(path,preDeathSettlementGuardSource(path,raw)));
    assert.equal(central,explicit,'central entry already inverts death exactly once: '+path);
    const source=preRosterConfigSource(path,central,'roster'),before=preRosterSource(path,source);
    assert.equal(hash(before),rosterSourceBindings.files[path].beforeSha256,'final328 roster witness remains exact: '+path);
  }
});
test('gesture drain projection preserves the complete prior fixture and exposes every partial change',()=>{
  const path='tests/lua/support/battle_gesture_fixture.lua';
  const binding=playerDeathLayer.files[path];
  assert.ok(binding,'the shared gesture fixture must join the exact death layer');
  assert.equal(binding.beforeSha256,'64407f8ea32f7591ce65cb25a675acee5e499581155942ee448ca4c300691715');
  assert.equal(binding.afterSha256,'134616d268298a4d3337ca5e65af2af3568a06c3cb3382e4e0fb8e0fcf3a9868');
  const live=read(path);
  const prior=prePlayerDeathSource(path,live);
  assert.equal(hash(live),binding.afterSha256);
  assert.equal(hash(prior),binding.beforeSha256);
  assert.equal(prePlayerDeathSource(path,prior),prior,'the entire accepted fixture is already valid');
  assert.equal(preApprovedUiSource(path,live),preApprovedUiSource(path,prior),'the complete outer layer recovers the same historical input');
  const partials=binding.hunks[0].after.map((line,index)=>live.replace(line,binding.hunks[0].before[index]));
  for(const unknown of [...partials,live+'\n-- drift\n',prior+'\n-- drift\n',live.slice(1)]){
    assert.notEqual(hash(unknown),binding.beforeSha256);
    assert.notEqual(hash(unknown),binding.afterSha256);
    assert.equal(prePlayerDeathSource(path,unknown),unknown,'partial or unrelated bytes must remain visible, never silently replaced');
    assert.equal(preApprovedUiSource(path,unknown),unknown,'composition must not turn unknown fixture bytes into an accepted witness');
  }
  assert.equal(prePlayerDeathSource('tests/lua/support/unregistered_fixture.lua',live),live,'a matching body under a different path is not authorized');
});
