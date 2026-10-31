import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
// 消耗堆 ≠ 弃牌堆: the top-bar exhaust feather + count stay visible for the whole fight, even at 0.
test('exhaust pile icon and count show during combat regardless of count', () => {
  const src = readFileSync(new URL('../src/lua/abyss_battle_render_hud.lua', import.meta.url), 'utf8');
  assert.match(src, /show\("exhaustIcon", frame\.fighting == true\)/);
  assert.match(src, /show\("exhaust", frame\.fighting == true\)/);
  assert.doesNotMatch(src, /exhausted > 0/);
});
