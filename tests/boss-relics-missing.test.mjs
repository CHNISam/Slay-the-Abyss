import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('missing boss relics execute real acquisition, combat and selection boundaries', () => {
  buildLuaData();
  const sources = new Set(['Velvet Choker', 'Runic Dome', 'Snecko Eye', "Pandora's Box", 'Cursed Key',
    'Busted Crown', 'Ectoplasm', 'Tiny House', "Philosopher's Stone", 'Astrolabe', 'Empty Cage',
    'Runic Pyramid', 'Calling Bell', 'Mark of Pain', 'Runic Cube']);
  const definitions = JSON.parse(readFileSync('data/relics.json', 'utf8')).relics.filter(d => sources.has(d.sourceId));
  assert.equal(definitions.length, 15, 'all source boss identities need canonical definitions');
  const result = runLua('tests/lua/boss_relics_missing.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_BOSS_RELICS_MISSING_PASS/);
});

test('Runic Dome hides all intent projections while core enemy damage is unchanged', () => {
  buildLuaData();
  const result = runLua('tests/lua/boss_relics_dome.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_BOSS_RELICS_DOME_PASS/);
});
