import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
test('ten distinct whole official pictures are bound directly without geometric scenery',()=>{
 const ids=nativeTheme.image.officialBackdrops;
 assert.equal(new Set(Object.values(ids)).size,10);
 const layout=gameLayout();assertNativeUiCapacity(layout);
 const menu=layout.controls.find(c=>c.name==='menuPanel');
 const selection=layout.controls.find(c=>c.name==='characterPanel');
 assert.equal(menu.children.find(c=>c.name==='backdrop').image,ids.title);
 assert.equal(selection.children.find(c=>c.name==='veil').image,ids.selection);
 const battle=layout.controls.find(c=>c.name==='officialBattleBackdrop');
 assert.equal(battle.children.filter(c=>c.name!=='readabilityVeil').length,8);
 for(const c of battle.children.filter(c=>c.name!=='readabilityVeil'))assert.equal(c.image,ids[c.name]);
 assert(!JSON.stringify(layout).includes('officialVista_'));
});
