import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, theme } from '../scripts/ui-layout.mjs';
import { mapLayout } from '../scripts/map-ui-layout.mjs';
import { assertNativeUiCapacity } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';
const find = (rows, name) => rows.flatMap(row => [row, ...flatten(row.children ?? [])]).find(row => row.name === name);
const flatten = rows => rows.flatMap(row => [row, ...flatten(row.children ?? [])]);

test('generated Emerald controls use named map text, native capacity and six readable reward rows inside safe bounds', () => {
  const battle = battleLayout(), map = mapLayout();
  const key = find(battle.controls, 'emeraldKeyReward');
  assert.ok(key, 'missing real generated key button');
  assert.equal(key.kind, 'presetButton');
  assert.equal(key.focusable, true);
  assert.equal(key.size[1], 64);
  const badge = find(map.controls, 'emeraldLabel');
  assert.ok(badge && badge.text.content === '绿钥匙');
  assert.ok(badge.size[1] >= 40 && badge.text.fontSize >= theme.font.minimum);
  assertNativeUiCapacity(battle.controls);assertNativeUiCapacity(map.controls);
  const dense = theme.layout.battleRewards.expanded;
  assert.equal(dense.rowStep >= 64, true);
  const lastBottom = dense.rowOrigin[1] - 5 * dense.rowStep - theme.layout.battleRewards.rowSize[1] / 2;
  assert.ok(lastBottom > dense.potionLabel[1] + dense.potionLabel[3] / 2);
  assert.ok(dense.potionLabel[1] - dense.potionLabel[3] / 2 > dense.continue[1] + theme.layout.battleRewards.continue[3] / 2);
  const safeBottom = -theme.canvas.base[1] / 2 + theme.canvas.safe.y;
  assert.ok(dense.continue[1] - theme.layout.battleRewards.continue[3] / 2 >= safeBottom);
});

test('strict generated Host UI exposes source burning elite, independent six-row claims, focus and retired gestures', () => {
  const result = runLua('tests/lua/emerald_key_ui.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /EMERALD_KEY_UI 3 groups; 0 failed; native\/natural NOT_RUN/);
});
