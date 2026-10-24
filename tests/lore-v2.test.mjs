import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';

const read = path => JSON.parse(readFileSync(path, 'utf8'));
test('shipped narrative preserves the user packet verbatim and event paragraphs fit without smaller type', () => {
  const copy = read('data/presentation/narrative.zh-CN.json');
  const core = read('docs/lore/v2/04-copy/core.zh-CN.json');
  const support = read('docs/lore/v2/04-copy/supporting.zh-CN.json');
  assert.deepEqual(copy.flow, core.flow);
  assert.deepEqual(copy.merchant, support.merchant);
  assert.deepEqual(copy.eventCopy, support.eventCopy);
  const event = nativeTheme.layout.nativeNode.event;
  for (const { intro } of Object.values(copy.eventCopy)) {
    const rows = intro.replaceAll('\n\n', '\n').split('\n')
      .reduce((n, line) => n + Math.ceil([...line].length * nativeTheme.font.body / event.body[2]), 0);
    assert.ok(rows * nativeTheme.layout.nativeText.lineHeight <= event.body[3]);
  }
  const bottom = frame => frame[1] - frame[3] / 2;
  const top = frame => frame[1] + frame[3] / 2;
  assert.ok(bottom(event.name) >= top(event.body));
  assert.ok(bottom(event.body) >= event.options.rows[0] + event.options.size[1] / 2);
  assert.ok(event.options.rows.at(-1) - event.options.size[1] / 2 >= top(nativeTheme.layout.nativeNode.confirm));
  const menu = nativeTheme.layout.nativeMenu;
  assert.ok(bottom(menu.title) >= top(menu.summary));
  assert.ok(bottom(menu.summary) >= top(menu.tagline));
  assert.ok(bottom(menu.tagline) >= top(menu.start));
  assert.ok(bottom(menu.subtitle) >= menu.stats.origin[1] + menu.stats.size[1] / 2);
  assert.ok(menu.stats.origin[1] - menu.stats.size[1] / 2 >= top(menu.detail));
  assert.ok(bottom(menu.detail) >= top(menu.settle));
});
