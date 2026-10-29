import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {playerDeathLayer,prePlayerDeathSource} from './helpers/player-death-transition-inverse.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('both original-budget death slices cover all ten registered cases exactly once',()=>{
  const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(read('tests/lua/player_death_transition.lua'),"dofile('tests/lua/support/player_death_cases.lua')(1, 5)\n");
  assert.equal(read('tests/lua/player_death_transition_slice_2.lua'),"dofile('tests/lua/support/player_death_cases.lua')(6, 10)\n");
  const cases=read('tests/lua/support/player_death_cases.lua');
  assert.equal((cases.match(/^test\('/gm)||[]).length,10);
  assert.match(cases,/assert\(registered == 10 and count == last - first \+ 1/);
});
test('death replay layer binds only this exact change and restores every complete prior source',()=>{
  assert.equal(playerDeathLayer.baseHead,'6795160ef93625f35ac61841f2a92d83524e8414');
  assert.equal(Object.keys(playerDeathLayer.files).length,11);
  for(const[path,binding]of Object.entries(playerDeathLayer.files)){
    const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');
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
  for(const path of ['src/lua/abyss_feedback.lua','src/lua/abyss_game_ui.lua','data/presentation/ui_theme.json']){
    const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');
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
test('committed-defeat guard is the only host delta from accepted PR330 and wrong guards remain exposed',()=>{
  const path='src/lua/abyss_game_ui.lua';
  const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  const guarded='if self.motion.deathReveal or self.run and self.run.phase == "defeat" and self.battleUI.busy then return false,"result_revealing" end';
  const revealOnly='if self.motion.deathReveal then return false,"result_revealing" end';
  const allBusy='if self.motion.deathReveal or self.battleUI.busy then return false,"result_revealing" end';
  assert.equal(live.split(guarded).length,2,'one shared committed-defeat guard');
  assert.equal(hash(live),'6a4ea31117d9e23c1c7498859b965496d2b6672af837b220e91ad9fb874a1499');
  const accepted=live.replace(guarded,revealOnly);
  assert.equal(hash(accepted),'400375891c34b7c52c06227570263f9f83d4cc177e8ca3d60f8e8f7bc5c55520','exact host at accepted PR330 merge 1dc33fe');
  for(const unknown of [accepted,live.replace(guarded,allBusy),live+'\n-- drift\n']){
    assert.equal(prePlayerDeathSource(path,unknown),unknown,'wrong or unregistered current sources must not be silently rewritten');
    assert.throws(()=>preApprovedUiSource(path,unknown),/unreviewed integrated/);
  }
});
