import test from 'node:test';
import assert from 'node:assert/strict';
import { assertNativeUiCapacity } from '../scripts/build-ui.mjs';

const children = count => Array.from({ length: count }, (_, i) => ({ name: `control${i}` }));
test('native export accepts the platform boundary of 60 direct controls', () => {
  assert.doesNotThrow(() => assertNativeUiCapacity({ name: 'layout', controls: [{ name: 'stage', children: children(60) }] }));
});
test('native export rejects 61 controls even when the overflowing container is hidden', () => {
  assert.throws(() => assertNativeUiCapacity({ name: 'layout', controls: [{ name: 'battlePanel', visible: false, children: children(61) }] }),
    /layout\/battlePanel: 61 direct children.*60/);
});
test('native export checks nested template containers and reports the offending path', () => {
  assert.throws(() => assertNativeUiCapacity({ name: 'template', children: [{ name: 'inner', children: children(61) }] }),
    /template\/inner: 61 direct children.*60/);
});
