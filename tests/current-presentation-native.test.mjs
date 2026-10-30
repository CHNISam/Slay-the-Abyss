import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {currentPresentationNativeFixtures as fixtures,currentPresentationNativePrelude as prelude} from './helpers/current-presentation-native.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('only exact current frozen presentation entries receive the native actor platform',()=>{
 assert.deepEqual(fixtures,['tests/lua/phase_four_presentation.lua','tests/lua/phase_three_presentation.lua',...['2','3'].map(n=>`tests/lua/phase_three_presentation_slice_${n}.lua`),'tests/lua/character_presentation.lua',...Array.from({length:15},(_,i)=>`tests/lua/character_presentation_budget_${i+2}.lua`)]);
 assert.equal(new Set(fixtures).size,20);
 for(const path of fixtures){
  assert.ok(prelude(path).includes('F.withMonsterActors(platform)'));
  for(const other of [path+'.other','other/'+path,resolve(path)])assert.equal(prelude(other),'');
  assert.equal(prelude(path,{cwd:'/tmp/unrelated-current-world'}),'');
 }
 for(const path of ['tests/lua/phase_four_presentation_render.lua','tests/lua/game_ui_phase_four.lua','tests/lua/battle_ui.lua','tests/lua/support/character_presentation.lua','tests/lua/character_presentation_budget_17.lua'])assert.equal(prelude(path),'');
});
test('presentation boundary preserves rejection of explicitly invalid actor binding',()=>{
 const dir=mkdtempSync(join(tmpdir(),'presentation-binding-'));
 try{
  const file=join(dir,'invalid.lua');
  writeFileSync(file,prelude(fixtures[0])+`
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
require('abyss_battle_ui').new(root:GetChild('battlePanel'),F.Data,F.Presentation,'click',{
 imageSource='static',color=function(...)return {...}end,monsterActors={enabled=false,templateIndex=1,containerTemplateIndex=2}}, {embedded=true})
`);
  const r=runLua(file,{timeout:30000});assert.notEqual(r.status,0);assert.match(r.stderr,/monster actor template is not bound/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
