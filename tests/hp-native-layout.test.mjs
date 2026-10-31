import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const child=(node,name)=>{const found=node.children.find(c=>c.name===name);assert.ok(found,name);return found;};
test('map and node HP reserve native glyph room between the existing resource icons',()=>{
 const controls=gameLayout().controls,root={children:controls};
 for(const row of [child(root,'nodePanel'),child(child(root,'mapPanel'),'resources')]){
  const hp=child(row,'hp'),left=child(row,'hpIcon'),right=child(row,'goldIcon');
  assert.deepEqual(hp.position,[-524,316]);assert.deepEqual(hp.size,[104,40]);
  assert.ok(hp.position[0]-hp.size[0]/2-(left.position[0]+left.size[0]/2)>=4);
  assert.ok(right.position[0]-right.size[0]/2-(hp.position[0]+hp.size[0]/2)>=5);
  const gold=child(row,'gold');
  assert.ok(gold.position[0]-gold.size[0]/2-(right.position[0]+right.size[0]/2)>=1);
  assert.equal(hp.text.autoSize,true);assert.equal(hp.text.fontSize,18);assert.equal(hp.text.minFontSize,14);
 }
 const node=child(root,'nodePanel'),gold=child(node,'gold'),potions=child(node,'potions');
 assert.ok(potions.position[0]-potions.size[0]/2-(gold.position[0]+gold.size[0]/2)>=5);
 const battle=child(child(root,'battlePanel'),'player');
 assert.deepEqual(battle.position,[-551,328]);assert.equal(battle.size[0],68);
 assert.equal(battle.text.autoSize,true);assert.equal(battle.text.fontSize,18);assert.equal(battle.text.minFontSize,14);
});
test('real host keeps exact current/max HP strings across opening and map resource refresh',()=>{
 const result=runLua('tests/lua/hp_native_layout.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/HP_NATIVE_LAYOUT_PASS/);
});
