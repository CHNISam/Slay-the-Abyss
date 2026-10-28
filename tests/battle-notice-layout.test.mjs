import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
import { battleLayout, theme } from '../scripts/ui-layout.mjs';

test('foreground battle notices clear 1–5 actors, Boss intents, statuses and selected hands without dropping long text', () => {
  const result = runLua('tests/lua/battle_notice_layout.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /BATTLE_NOTICE_LAYOUT_PASS 7 \d+ \d+ /);
  console.log(result.stdout.match(/^BATTLE_NOTICE_LAYOUT_PASS .+$/m)[0]);
  const notice = battleLayout().controls.find(c => c.name === 'stage').children.find(c => c.name === 'notice');
  assert.equal(notice.kind, 'text');
  assert.equal(notice.text.autoSize, true);
  assert.equal(notice.text.minFontSize, theme.font.minimum);
  const [w, h] = notice.size, [x, y] = notice.position;
  assert.ok(Math.abs(x) + w / 2 <= theme.canvas.base[0] / 2 - theme.canvas.safe.x);
  assert.ok(Math.abs(y) + h / 2 <= theme.canvas.base[1] / 2 - theme.canvas.safe.y);
  const samples = result.stdout.split(/\r?\n/).filter(line => line.startsWith('BATTLE_NOTICE_TEXT\t'))
    .map(line => line.slice('BATTLE_NOTICE_TEXT\t'.length).replaceAll('\\n', '\n'));
  assert.ok(samples.length > 100, 'all declared source intent notices are measured');
  // Conservative full-width glyphs, at the readable minimum. Use the existing
  // offline battle preview's 1.35 leading; this is not native-font acceptance.
  const font = notice.text.minFontSize, columns = Math.floor(w / font);
  for (const text of samples) {
    const rows = text.split('\n').reduce((n, line) => n + Math.max(1, Math.ceil([...line].length / columns)), 0);
    assert.ok(rows * Math.ceil(font * 1.35) <= h, `notice would clip at readable minimum: ${text}`);
  }
});
