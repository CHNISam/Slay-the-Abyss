import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('native CursorArea fields and generated startup reject unsupported properties while preserving input gates',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/native_cursor_fields.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_CURSOR_FIELDS_PASS/);
});
