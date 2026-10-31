import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {theme} from '../scripts/ui-layout.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const child=(node,name)=>{const found=node.children.find(c=>c.name===name);assert.ok(found,name);return found;};
test('map and node HP reserve native glyph room between the existing resource icons',()=>{
 const controls=gameLayout().controls,root={children:controls};
 for(const row of [child(root,'nodePanel'),child(child(root,'mapPanel'),'resources')]){
  const hp=child(row,'hp'),left=child(row,'hpIcon'),right=child(row,'goldIcon');
  assert.deepEqual(hp.position,[-536,316]);assert.deepEqual(hp.size,[80,40]);
  assert.ok(hp.position[0]-hp.size[0]/2-(left.position[0]+left.size[0]/2)>=4);
  assert.ok(right.position[0]-right.size[0]/2-(hp.position[0]+hp.size[0]/2)>=5);
  assert.equal(hp.text.autoSize,true);assert.equal(hp.text.fontSize,18);assert.equal(hp.text.minFontSize,14);
 }
 const battle=child(child(root,'battlePanel'),'player');
 // STS TopPanel.renderHP: hpIconX + HP_NUM_OFFSET_X (60 × 2/3), left aligned.
 assert.deepEqual(battle.position,[theme.layout.topBar.hp[0],328]);assert.equal(battle.size[0],theme.layout.topBar.hp[1]);
 assert.equal(battle.text.autoSize,true);assert.equal(battle.text.fontSize,18);assert.equal(battle.text.minFontSize,14);
});
test('real host keeps exact current/max HP strings across opening and map resource refresh',()=>{
 const result=runLua('tests/lua/hp_native_layout.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/HP_NATIVE_LAYOUT_PASS/);
});
