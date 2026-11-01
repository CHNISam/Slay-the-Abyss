import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
test('resource hints share read-only deck inspection and isolate modal and stale inputs',()=>{
 const r=runLua('tests/lua/resource_hints.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/RESOURCE_HINTS_PASS/);
});
test('resource hint hit areas contain the displayed resources and avoid other top bar entries',()=>{
 const controls=gameLayout().controls;
 for(const name of ['battlePanel','mapPanel']){
  const panel=controls.find(c=>c.name===name),hint=panel.children.find(c=>c.name==='resourceHints');
  const a=hint.children[0],b=hint.children[1];
  for(const box of [a,b]){
   assert.ok(box.size[0]>=48&&box.size[1]>=48);
   assert.ok(Math.abs(box.position[0])+box.size[0]/2<=640);
   assert.ok(Math.abs(box.position[1])+box.size[1]/2<=360);
   assert.equal(box.children[0].focusable,true);
  }
  assert.ok(a.position[0]+a.size[0]/2<b.position[0]-b.size[0]/2,'health and gold targets overlap');
 }
});
