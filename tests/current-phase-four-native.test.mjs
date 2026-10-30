import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {currentPhaseFourNativeFixtures as fixtures,currentPhaseFourNativePrelude as prelude} from './helpers/current-phase-four-native.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('only four exact current frozen render witnesses receive the real native platform',()=>{
 assert.deepEqual(fixtures,[ 'tests/lua/phase_four_presentation_render.lua', ...[2,3,4].map(n=>`tests/lua/phase_four_presentation_render_slice_${n}.lua`)]);
 for(const path of fixtures){
  assert.ok(prelude(path).includes('F.withMonsterActors(platform)'));
  for(const other of [path+'.other','other/'+path,resolve(path)])assert.equal(prelude(other),'');
  assert.equal(prelude(path,{cwd:'/tmp/unrelated-current-world'}),'');
 }
 for(const path of ['tests/lua/phase_four_presentation.lua','tests/lua/battle_life_regression.lua','tests/lua/support/native_card_art_contexts.lua','tests/lua/game_ui.lua'])assert.equal(prelude(path),'');
});
test('current native boundary never repairs an explicitly invalid actor binding',()=>{
 const dir=mkdtempSync(join(tmpdir(),'phase-four-binding-'));
 try {
  const file=join(dir,'invalid.lua');
  writeFileSync(file,prelude(fixtures[0])+`
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
require('abyss_battle_ui').new(root:GetChild('battlePanel'),F.Data,F.Presentation,'click',{
 imageSource='static',color=function(...)return {...}end,monsterActors={enabled=false,templateIndex=1,containerTemplateIndex=2}}, {embedded=true})
`);
  const result=runLua(file);
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/monster actor template is not bound/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
