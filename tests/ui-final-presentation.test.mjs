import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { deckCardTemplate } from '../scripts/deck-ui-layout.mjs';
import { assertNativeUiCapacity } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('current native source intent and uncapped signed power counts run through real controls', () => {
 const result=runLua('tests/lua/ui_final_presentation.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/UI_FINAL_PRESENTATION_PASS/);
});

test('all final native images use importer-safe RGB and separate alpha, including rounded card corners', () => {
 const trees=[gameLayout(),deckCardTemplate()];
 function visit(control,path) {
  if(control.kind==='image' && typeof control.colour==='string') assert.match(control.colour,/^#[0-9a-f]{6}$/i,path);
  if(control.opacity!==undefined) assert.ok(Number.isFinite(control.opacity)&&control.opacity>=0&&control.opacity<=1,path);
  for(const child of control.children??control.controls??[])visit(child,path+'/'+child.name);
 }
 for(const tree of trees){assertNativeUiCapacity(tree);visit(tree,tree.name);}
});

test('approved global menu retires help and retains internal guide isolation, map preview, resume and separate abandon confirmation', () => {
 const result=runLua('tests/lua/ui_final_menu.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/UI_FINAL_MENU_PASS/);
});
