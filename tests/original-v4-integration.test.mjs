import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for (const [file,marker] of [
  ['acquisition','ORIGINAL_V4_ACQUISITION_PASS 4'],
  ['lifecycle','ORIGINAL_V4_LIFECYCLE_PASS'],
  ['ui','ORIGINAL_V4_UI_PASS 4 roles 600 full faces'],
  ['cards','ORIGINAL_V4_BATTLE_UI_PASS 4'],
]) test(`original V4 production ${file}`,()=>{
  const r=runLua(`tests/fixtures/js-owned/tests/lua/original_v4_${file}.lua`);
  assert.equal(r.status,0,r.stdout+r.stderr);assert.ok(r.stdout.includes(marker),r.stdout);
});
