import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';

const read = path => JSON.parse(readFileSync(path, 'utf8'));
// Living Wall is the only event copy added by the separately authorized full-pool work.
// Keep the original user packet unchanged and require this exact additional entry.
const livingWallCopy = {
  intro: '墙壁上浮现出一张张人脸。它们低声重复着三个词：遗忘、改变、成长。\n\n你可以选择一张卡牌，留下旧日的招式，或让它成为新的力量。',
  choices: ['forget', 'change', 'grow'],
};
function assertNarrativeCopy(copy, core, support) {
  assert.deepEqual(copy.flow, core.flow);
  assert.deepEqual(copy.merchant, support.merchant);
  assert.deepEqual(copy.eventCopy, { ...support.eventCopy, living_wall: livingWallCopy });
}
test('shipped narrative preserves the user packet verbatim and event paragraphs fit without smaller type', () => {
  const copy = read('data/presentation/narrative.zh-CN.json');
  const core = read('docs/lore/v2/04-copy/core.zh-CN.json');
  const support = read('docs/lore/v2/04-copy/supporting.zh-CN.json');
  assertNarrativeCopy(copy, core, support);
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
  // The approved three-option narrative screens keep their original footer gap.
  // The new fourth option shares the footer area only while confirm is hidden;
  // native event UI regressions enforce that exclusive visibility.
  assert.ok(event.options.rows[2] - event.options.size[1] / 2 >= top(nativeTheme.layout.nativeNode.confirm));
  assert.ok(event.options.rows[3] - event.options.size[1] / 2 >= -nativeTheme.canvas.base[1] / 2 + nativeTheme.canvas.safe.y);
  const menu = nativeTheme.layout.nativeMenu;
  assert.ok(bottom(menu.title) >= top(menu.tagline));
  assert.ok(bottom(menu.tagline) >= top(menu.summary));
  assert.ok(bottom(menu.summary) >= top(menu.start));
  assert.ok(bottom(menu.subtitle) >= menu.stats.origin[1] + menu.stats.size[1] / 2);
  assert.ok(menu.stats.origin[1] - menu.stats.size[1] / 2 >= top(menu.detail));
  assert.ok(bottom(menu.detail) >= top(menu.settle));
});

test('verbatim guard rejects a changed character in every original approved copy field', () => {
  const copy = read('data/presentation/narrative.zh-CN.json');
  const core = read('docs/lore/v2/04-copy/core.zh-CN.json');
  const support = read('docs/lore/v2/04-copy/supporting.zh-CN.json');
  const approved = { flow: core.flow, merchant: support.merchant, eventCopy: support.eventCopy };
  function check(value, path = []) {
    if (typeof value === 'string') {
      const changed = structuredClone(copy);
      const parent = path.slice(0, -1).reduce((entry, key) => entry[key], changed);
      parent[path.at(-1)] = (value.startsWith('改') ? '变' : '改') + [...value].slice(1).join('');
      assert.throws(() => assertNarrativeCopy(changed, core, support), { code: 'ERR_ASSERTION' }, path.join('.'));
    } else {
      for (const [key, entry] of Object.entries(value)) check(entry, [...path, key]);
    }
  }
  check(approved);
});

test('event-copy guard rejects unregistered keys and changes to Living Wall intro or choices', () => {
  const copy = read('data/presentation/narrative.zh-CN.json');
  const core = read('docs/lore/v2/04-copy/core.zh-CN.json');
  const support = read('docs/lore/v2/04-copy/supporting.zh-CN.json');
  const mutations = [
    changed => { changed.eventCopy.unregistered_event = structuredClone(livingWallCopy); },
    changed => { changed.eventCopy.living_wall.intro += '改'; },
    changed => { changed.eventCopy.living_wall.choices[0] = 'leave'; },
  ];
  for (const mutate of mutations) {
    const changed = structuredClone(copy);
    mutate(changed);
    assert.throws(() => assertNarrativeCopy(changed, core, support), { code: 'ERR_ASSERTION' });
  }
});
