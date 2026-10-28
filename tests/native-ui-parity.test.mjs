import test from 'node:test';
import assert from 'node:assert/strict';
import { controlsGuide } from '../scripts/controls-guide-layout.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('six native instruction tiles fit the approved modal and do not promise unbound keyboard shortcuts', () => {
  const guide = controlsGuide(), tiles = guide.children.filter(c => c.name.startsWith('tip'));
  assert.equal(tiles.length, 6);
  const visit = (c, x=0, y=0) => {
    x += c.position?.[0] ?? 0; y += c.position?.[1] ?? 0;
    assert(Math.abs(x) + c.size[0]/2 <= 640, c.name);
    assert(Math.abs(y) + c.size[1]/2 <= 360, c.name);
    if (c.text) assert(c.size[1] >= 40, c.name);
    for (const child of c.children ?? []) visit(child,x,y);
  };
  visit(guide);
  const content = JSON.stringify(guide);
  assert(!content.includes('1–9') && !content.includes('Esc') && !content.includes('Tab'));
  const exit = gameLayout().controls.find(c=>c.name==='exitPanel');
  const help = exit.children.find(c=>c.name==='help'), title = exit.children.find(c=>c.name==='title');
  assert(Math.abs(help.position[0]-title.position[0]) >= (help.size[0]+title.size[0])/2);
  assert.deepEqual(help.position,theme.layout.nativeGuide.entry.slice(0,2));
});

test('real host isolates guide input, returns controller focus, and retains map navigation after input switching', () => {
  const result=runLua('tests/lua/native_ui_parity.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_UI_PARITY_PASS/);
});
