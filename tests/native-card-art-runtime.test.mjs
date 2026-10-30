import test, {before, after} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
// Each required lifecycle phase must be registered and reported after its Lua
// assertions. Splitting slow contexts must not silently drop an original phase.
const contexts={
 battle:['battle-hand','battle-reward'],
 'deck-capacity':['deck-capacity-refill','deck-close'],
 'deck-scroll':['deck-ready-reuse','deck-invalid-index','deck-close'],
 'deck-details':['deck-hidden-callbacks','deck-return','deck-close','deck-deferred-calibration'],
 'node-shop':['node-pending-hide','node-hidden-render','node-show-ready'],
 'node-picker':['node-shop-to-picker'],
 'node-return':['node-picker-to-shop'],
};
const requiredPhases=['battle-hand','battle-reward','deck-capacity-refill','deck-ready-reuse',
 'deck-invalid-index','deck-hidden-callbacks','deck-return','deck-close','deck-deferred-calibration',
 'node-pending-hide','node-hidden-render','node-show-ready','node-shop-to-picker','node-picker-to-shop'];
let directory,generated;
before(()=>{
 directory=mkdtempSync(join(tmpdir(),'abyss-runtime-card-art-'));
 generated=process.env.ABYSS_READY_CARD_ART_DIRECTORY??directory;
 if(generated===directory)buildUI(directory);
});
after(()=>{if(directory)rmSync(directory,{recursive:true,force:true});});
test('bounded native runtime enforces global capacity, batching and fail-closed lifetime',()=>{
 const result=runLua('tests/lua/native_card_art_runtime.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/BOUNDED_NATIVE_ART_PASS/);
});
test('runtime context partitions register every original lifecycle phase',()=>{
 assert.deepEqual([...new Set(Object.values(contexts).flat())].sort(),[...requiredPhases].sort());
});
for(const [context,phases] of Object.entries(contexts))test(`actual builder's ready cards reach the real ${context} lifecycle`,()=>{
 const script=join(directory,context+'.lua');
 const modules=['abyss_presentation','abyss_ui_layout','abyss_ui_templates'];
 writeFileSync(script,"package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\n"+modules.map(name=>`package.loaded[${toLua(name)}]=dofile(${toLua(join(generated,name+'.lua'))})`).join('\n')
  +`\nrequire('abyss_card_display').bindNativeAssets(package.loaded.abyss_presentation,dofile(${toLua(join(generated,'abyss_ready_card_assets.lua'))}))\nABYSS_RUNTIME_CONTEXT=${toLua(context)}\nABYSS_RUNTIME_REQUIRE_READY=true\ndofile('tests/lua/support/native_card_art_runtime_contexts.lua')\n`);
 const result=runLua(script,{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp('NATIVE_CARD_ART_RUNTIME_CONTEXT_PASS '+context));
 for(const phase of phases)assert.ok(result.stdout.split('\n').includes('NATIVE_CARD_ART_RUNTIME_PHASE '+phase),`missing lifecycle phase ${phase}`);
});
