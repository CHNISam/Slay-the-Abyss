import {preRelicViewUiSource} from './helpers/relic-view-ui-inverse.mjs';
import {preHeroVisualSource} from './helpers/hero-visual-source-inverse.mjs';
import {preEventProductionSource} from './helpers/event-production-source-inverse.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {playerDeathLayer,prePlayerDeathSource} from './helpers/player-death-transition-inverse.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import {preDeathSettlementGuardSource} from './helpers/death-settlement-guard-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const originalContext=JSON.parse(gunzipSync(readFileSync(new URL('./fixtures/pr323-historical-fixtures.json.gz',import.meta.url)))).historicalInputs.playerDeath;
assert.equal(originalContext.beforeCommit,playerDeathLayer.baseHead);
assert.deepEqual(Object.keys(originalContext.files),Object.keys(playerDeathLayer.files));
for(const [path,binding]of Object.entries(originalContext.files)){
 assert.equal(binding.beforeSha256,playerDeathLayer.files[path].beforeSha256);
 assert.equal(hash(binding.source),playerDeathLayer.files[path].afterSha256);
}
function useOriginalPlayerDeathInputs(){
 // This inverse owns its original eleven-file epoch, not later native-engine
 // fixtures. Every test reads real private files; no archive getter hides drift.
 assert.notEqual(resolve(process.cwd()),resolve(fileURLToPath(new URL('../',import.meta.url))));
 for(const [path,binding]of Object.entries(originalContext.files))writeFileSync(path,binding.source);
}
test('both original-budget death slices cover all ten registered cases exactly once',()=>{
  useOriginalPlayerDeathInputs();
  const read=path=>preEventProductionSource(path,preHeroVisualSource(path,preRelicViewUiSource(path,readFileSync(path,'utf8')))).replaceAll('\r\n','\n');
  assert.equal(read('tests/lua/player_death_transition.lua'),"dofile('tests/lua/support/player_death_cases.lua')(1, 5)\n");
  assert.equal(read('tests/lua/player_death_transition_slice_2.lua'),"dofile('tests/lua/support/player_death_cases.lua')(6, 10)\n");
  const cases=read('tests/lua/support/player_death_cases.lua');
  assert.equal((cases.match(/^test\('/gm)||[]).length,10);
  assert.match(cases,/assert\(registered == 10 and count == last - first \+ 1/);
});
test('death replay layer binds only this exact change and restores every complete prior source',()=>{
  useOriginalPlayerDeathInputs();
  assert.equal(playerDeathLayer.baseHead,'6795160ef93625f35ac61841f2a92d83524e8414');
  assert.equal(Object.keys(playerDeathLayer.files).length,11);
  for(const[path,binding]of Object.entries(playerDeathLayer.files)){
    const live=preDeathSettlementGuardSource(path,preEventProductionSource(path,preHeroVisualSource(path,preRelicViewUiSource(path,readFileSync(path,'utf8')))).replaceAll('\r\n','\n'));
    assert.equal(hash(live),binding.afterSha256,path);
    const prior=prePlayerDeathSource(path,live);
    assert.equal(hash(prior),binding.beforeSha256,path);
    assert.equal(prePlayerDeathSource(path,live.replaceAll('\n','\r\n')),prior);
    assert.equal(prePlayerDeathSource(path,prior),prior,'prior witnesses remain unchanged');
    assert.equal(prePlayerDeathSource('unrelated.lua',live),live);
    const drift=live+'\n-- unreviewed drift\n';
    assert.equal(prePlayerDeathSource(path,drift),drift,'unknown sources are never silently replaced');
  }
});
test('the unchanged upstream frozen guard still rejects partial or unrelated death-source mutations',()=>{
  useOriginalPlayerDeathInputs();
  for(const path of ['src/lua/abyss_feedback.lua','src/lua/abyss_game_ui.lua','data/presentation/ui_theme.json']){
    const live=preDeathSettlementGuardSource(path,preEventProductionSource(path,preHeroVisualSource(path,preRelicViewUiSource(path,readFileSync(path,'utf8')))).replaceAll('\r\n','\n'));
    assert.doesNotThrow(()=>preApprovedUiSource(path,live),'original unmodified input must be a legal upstream baseline: '+path);
    const binding=playerDeathLayer.files[path],hunk=binding.hunks.find(h=>h.after.length);
    const lines=live.split('\n');lines.splice(hunk.at,hunk.after.length);
    for(const mutant of [lines.join('\n'),live+'\n-- drift\n']){
      if(hash(mutant)===binding.beforeSha256){
        assert.equal(preApprovedUiSource(path,mutant),preApprovedUiSource(path,live),'exact whole prior source remains valid');
        continue;
      }
      assert.throws(()=>preApprovedUiSource(path,mutant),/unreviewed integrated/,path);
    }
  }
});
