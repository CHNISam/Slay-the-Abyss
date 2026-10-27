import test from 'node:test';
import assert from 'node:assert/strict';
import { assertNativeUiCapacity } from '../scripts/build-ui.mjs';

const children = count => Array.from({ length: count }, (_, i) => ({ name: `control${i}` }));
test('native export accepts the platform boundary of 60 direct controls', () => {
  assert.doesNotThrow(() => assertNativeUiCapacity({ name: 'layout', controls: [{ name: 'stage', kind: 'container', children: children(60) }] }));
});
test('native export rejects 61 controls even when the overflowing container is hidden', () => {
  assert.throws(() => assertNativeUiCapacity({ name: 'layout', controls: [{ name: 'battlePanel', kind: 'container', visible: false, children: children(61) }] }),
    /layout\/battlePanel: 61 direct children.*60/);
});
test('native export checks nested template containers and reports the offending path', () => {
  assert.throws(() => assertNativeUiCapacity({ name: 'template', children: [{ name: 'inner', kind: 'container', children: children(61) }] }),
    /template\/inner: 61 direct children.*60/);
});
test('native export rejects children under leaf controls including hidden icons', () => {
  for (const kind of ['image', 'text', 'cursorArea', 'grid']) {
    assert.throws(() => assertNativeUiCapacity({ name: 'layout', controls: [
      { name: 'bad', kind, visible: false, children: children(1) },
    ] }), /layout\/bad: only a container or presetButton may hold child controls/);
  }
  assert.doesNotThrow(() => assertNativeUiCapacity({ controls: [
    { name: 'button', kind: 'presetButton', children: children(1) },
  ] }));
});
