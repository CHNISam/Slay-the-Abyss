import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
for (const [file,marker] of [
  ['m3_combined_queue.lua',/M3_COMBINED_QUEUE 15 passed=15 failed=0/],
  ['m3_current_owner_event_keys.lua',/M3_CURRENT_OWNER_EVENT_KEYS_PASS/],
]) {
  test(`bounded current-head cross-layer composition: ${file}`,()=>{
    const result=runLua(`tests/fixtures/js-owned/tests/lua/${file}`);
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,marker);
  });
}
