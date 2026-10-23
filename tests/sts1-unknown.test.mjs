import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('actual Lua implements all nine supplied basic unknown-room vectors and state regressions', () => {
  const vectors = JSON.parse(readFileSync('tests/fixtures/sts1/unknown_vectors.json', 'utf8'));
  assert.equal(vectors.cases.length, 9);
  mkdirSync('build/lua', { recursive: true });
  writeFileSync('build/lua/sts1_unknown_vectors.lua', `return ${toLua(vectors)}\n`);
  const result = runLua('tests/sts1/unknown.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_UNKNOWN_PASS 6/);
});
