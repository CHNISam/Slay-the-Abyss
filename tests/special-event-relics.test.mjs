import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
for (const [file, marker] of [
  ['face_nloth_skull_events', 'FACE_NLOTH_SKULL 11 passed'],
  ['special_event_relics', 'SPECIAL_EVENT_RELICS 12 passed'],
]) test(`${file}: current production commands preserve source rewards and object lifecycle`, () => {
  const result = runLua(`tests/lua/${file}.lua`);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(result.stdout.includes(marker));
});
