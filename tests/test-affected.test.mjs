import test from 'node:test';
import assert from 'node:assert/strict';
import { selectTests } from '../scripts/test-affected.mjs';

const sources = {
  'src/lua/abyss_low.lua': 'return {}',
  'src/lua/abyss_high.lua': 'return require("abyss_low")',
  'tests/lua/relevant.lua': 'local C=require("abyss_high")',
  'tests/lua/unrelated.lua': 'return true',
  'scripts/pure.mjs': 'export const value=1',
  'scripts/wrapper.mjs': 'import {value} from "./pure.mjs"; export {value}',
  'tests/pure.test.mjs': 'import {value} from "../scripts/wrapper.mjs"',
  'tests/dynamic.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua(path)',
  'scripts/test-lua.mjs': 'import {spawnSync} from "node:child_process"; export function runLua(){}',
};
test('related plan follows transitive Lua imports and retains dynamic Lua builders', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], sources);
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/relevant.lua']);
  assert.deepEqual(plan.integration, ['tests/dynamic.test.mjs']);
});
test('pure transitive JS imports stay in the fast tier', () => {
  const plan = selectTests(['scripts/pure.mjs'], sources);
  assert.deepEqual(plan.fast, ['tests/pure.test.mjs']);
  assert.deepEqual(plan.integration, []);
});
test('directory discovery remains conservative but unrelated process tests stay out', () => {
  const plan = selectTests(['scripts/pure.mjs'], { ...sources,
    'tests/discovery.test.mjs': 'import {readdirSync} from "node:fs"; readdirSync(directory)',
    'tests/unrelated-cli.test.mjs': 'import {spawnSync} from "node:child_process"; spawnSync("git", ["version"])',
  });
  assert.ok(plan.fast.includes('tests/discovery.test.mjs'));
  assert.ok(![...plan.fast, ...plan.integration].includes('tests/unrelated-cli.test.mjs'));
});
test('dynamic Lua imports cannot disappear from related coverage', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...sources, 'tests/lua/dynamic.lua': 'local name=selectModule(); require(name)',
  });
  assert.ok(plan.lua.includes('tests/lua/dynamic.lua'));
});
test('deleted, unknown, data, build and unmapped changes fail closed to complete regression', () => {
  for (const paths of [[], ['src/lua/deleted.lua'], ['data/cards.json'], ['package.json'], ['scripts/test-lua.mjs'], ['tests/lua/unrelated.lua', 'docs/ENGINEERING.md']])
    assert.equal(selectTests(paths, sources).full, true, String(paths));
  assert.equal(selectTests(['src/lua/abyss_high.lua'], { ...sources, 'tests/lua/relevant.lua': '' }).full, false,
    'dynamic Lua builders remain selected even when literal coverage is absent');
});
