import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {playerDeathLayer,prePlayerDeathSource} from './helpers/player-death-transition-inverse.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('death replay layer binds only this exact change and restores every complete prior source',()=>{
  assert.equal(playerDeathLayer.baseHead,'20a74da73ff5379a748e6b9687b258e2c9a22bf8');
  assert.equal(Object.keys(playerDeathLayer.files).length,10);
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
