import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {attachVictoryEasterEgg} from '../scripts/victory-easter-egg-layout.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
test('victory-only result button loads art lazily and blocks underlying result actions',()=>{
 const r=runLua('tests/lua/victory_easter_egg_integration.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/VICTORY_EASTER_EGG_INTEGRATION_PASS/);
});
test('victory artwork is lazy, cached and stopped while closed',()=>{
 const r=runLua('tests/lua/victory_easter_egg.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/VICTORY_EASTER_EGG_PASS/);
});
test('egg overlay uses existing theme, visible return action and full input blocker',()=>{
 const theme=structuredClone(nativeTheme);
 theme.layout.victoryEgg={open:[0,-300,220,48],thanks:[0,250,1120,64],status:[0,180,1120,44],close:[0,-280,220,60]};
 const result={name:'result',children:[]};
 const layout={controls:[{name:'menuPanel',children:[result]}]};
 const panel=attachVictoryEasterEgg(layout,theme);
 assert.equal(result.children[0].name,'viewEasterEgg');assert.equal(result.children[0].visible,false);
 assert.equal(panel.visible,false);assert.equal(panel.isolateNavigation,true);
 assert.deepEqual(panel.children.find(c=>c.name==='blocker').size,theme.canvas.base);
 assert.equal(panel.children.find(c=>c.name==='thanks').text.content,'感谢您的游玩~！');
 assert.equal(panel.children.find(c=>c.name==='close').children.find(c=>c.name==='label').text.content,'返回结算');
 assert.throws(()=>attachVictoryEasterEgg(layout,theme),/fresh/);
});
