import test from 'node:test';
import assert from 'node:assert/strict';
import {sceneBackdrop,officialVistaVariants} from '../scripts/official-vista-layout.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('rejected geometric scenery is absent while battle transitions still work',()=>{
 const r=runLua('tests/lua/official_battle_scenery.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/REJECTED_GEOMETRIC_SCENERY_REMOVED_PASS/);
});
test('retired geometry experiment remains separate from the production layout',()=>{
 const scenes=officialVistaVariants.map(v=>sceneBackdrop(nativeTheme,v));
 for(const scene of scenes){assert.equal(scene.children.length,14);assert(scene.children.every(c=>c.kind==='image'&&Number.isSafeInteger(c.image)));}
 assert.equal(new Set(scenes.map(s=>JSON.stringify(s.children))).size,3);
 const layout=gameLayout();assertNativeUiCapacity(layout);
 assert(!layout.controls.some(c=>c.name==='officialBattleScenes'));
 assert(!layout.controls.find(c=>c.name==='menuPanel').children.some(c=>c.name==='officialVista_title'));
});
