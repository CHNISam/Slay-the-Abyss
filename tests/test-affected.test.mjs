import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
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
  assert.equal(selectTests(['src/lua/abyss_high.lua'], { ...sources, 'tests/lua/relevant.lua': '' }).full, true,
    'dynamic Lua builders cannot prove coverage for an unmapped input');
});

const mixedSources = {
  ...sources,
  'scripts/unmapped.mjs': 'export const unused=1',
  'src/lua/abyss_unmapped.lua': 'return {}',
  'tests/support/unmapped.lua': 'return {}',
  'tests/discovery.test.mjs': 'import {readdirSync} from "node:fs"; readdirSync(directory)',
};
for (const unmapped of ['scripts/unmapped.mjs', 'src/lua/abyss_unmapped.lua', 'tests/support/unmapped.lua']) {
  for (const changed of [[unmapped], ['scripts/pure.mjs', unmapped], [unmapped, 'src/lua/abyss_low.lua']]) {
    test(`every unmapped input forces complete regression: ${changed.join(', ')}`, () => {
      const plan = selectTests(changed, mixedSources);
      assert.equal(plan.full, true, changed.join(', '));
      assert.ok(plan.reason.includes(unmapped), plan.reason);
      assert.deepEqual([plan.fast, plan.integration, plan.lua], [[], [], []]);
    });
  }
}

test('each mapped change retains its own direct or transitive regression', () => {
  const plan = selectTests(['scripts/pure.mjs', 'src/lua/abyss_low.lua', 'tests/lua/unrelated.lua'], sources);
  assert.equal(plan.full, false);
  assert.deepEqual(plan.fast, ['tests/pure.test.mjs']);
  assert.deepEqual(plan.integration, ['tests/dynamic.test.mjs']);
  assert.deepEqual(plan.lua, ['tests/lua/relevant.lua', 'tests/lua/unrelated.lua']);
});

const luaSources = {
  'src/lua/abyss_low.lua': 'return {}',
  'src/lua/abyss_high.lua': 'return require("abyss_low")',
  'src/lua/abyss_other.lua': 'return {}',
  'tests/lua/direct.lua': 'return require("abyss_low")',
  'tests/lua/other.lua': 'return require("abyss_other")',
};
for (const expression of [
  'require("abyss_high")', "require 'abyss_high'", 'require [[abyss_high]]',
  'pcall(require,"abyss_high")', "pcall ( require , 'abyss_high' )",
  'pcall\n(\nrequire\n,\n"abyss_high"\n)',
]) {
  test(`literal Lua imports retain transitive coverage: ${JSON.stringify(expression)}`, () => {
    const fixture = 'tests/lua/literal.lua';
    const input = { ...luaSources, [fixture]: `local value = ${expression}` };
    const plan = selectTests(['src/lua/abyss_low.lua'], input);
    assert.equal(plan.full, false);
    assert.deepEqual(plan.lua, ['tests/lua/direct.lua', fixture]);
    const unrelated = selectTests(['src/lua/abyss_other.lua'], input);
    assert.equal(unrelated.full, false);
    assert.deepEqual(unrelated.lua, ['tests/lua/other.lua'], 'static imports must not become dynamic catch-alls');
  });
}

test('protected imports in source modules participate in the transitive graph', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'src/lua/abyss_high.lua': 'local ok, value = pcall(require, "abyss_low"); return value',
    'tests/lua/transitive.lua': 'return require("abyss_high")',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/transitive.lua']);
});

for (const expression of [
  'pcall(require, name)', 'pcall ( require , "abyss_" .. name )',
  'local loader = require; loader(name)', 'local loader = require\nloader(name)',
  'require("abyss_" .. name)', 'xpcall(require, handler, name)',
]) {
  test(`ambiguous Lua imports stay conservative without forcing the full suite: ${JSON.stringify(expression)}`, () => {
    const plan = selectTests(['src/lua/abyss_low.lua'], {
      ...luaSources, 'tests/lua/dynamic.lua': expression,
    });
    assert.equal(plan.full, false);
    assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/dynamic.lua']);
  });
}

test('dynamic require references in transitive Lua helpers retain Lua and JS roots', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'src/lua/abyss_loader.lua': 'local loader = require; return loader',
    'tests/lua/dynamic.lua': 'return require("abyss_loader")',
    'tests/embedded.test.mjs': 'const program = `return require("abyss_loader")`',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/dynamic.lua']);
  assert.deepEqual(plan.integration, ['tests/embedded.test.mjs']);
});

for (const expression of [
  'return assert(load([[return require("abyss_high")]]))()',
  'local program = [[return require("abyss_high")]]; return assert(load(program))()',
  'local execute = load; return assert(execute(program))()',
  'return assert(loadstring([[return require("abyss_high")]]))()',
  'local execute = loadstring; return assert(execute(program))()',
  'local load = sandboxLoader; return load(program)',
  'local loadstring = sandboxLoader; return loadstring(program)',
]) {
  test(`executable Lua code strings retain conservative coverage: ${JSON.stringify(expression)}`, () => {
    const plan = selectTests(['src/lua/abyss_low.lua'], {
      ...luaSources, 'tests/lua/loaded.lua': expression,
    });
    assert.equal(plan.full, false);
    assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/loaded.lua']);
  });
}

test('code-string loaders in source helpers retain transitive Lua and JS test roots', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'src/lua/abyss_loader.lua': 'local execute = load; return execute',
    'tests/lua/loaded.lua': 'return require("abyss_loader")',
    'tests/embedded.test.mjs': 'const program = `return require("abyss_loader")`',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/loaded.lua']);
  assert.deepEqual(plan.integration, ['tests/embedded.test.mjs']);
});

test('nonexecuted strings and comments mentioning loaders remain unrelated', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'tests/lua/commented-load.lua': '-- load(program)\n-- alias = loadstring\nreturn true',
    'tests/lua/code-string.lua': 'return [[return require("abyss_high")]]',
    'tests/lua/loader-string.lua': 'return "load and loadstring do not execute here"',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua']);
});

test('unparseable Lua stays conservative instead of losing its test roots', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources, 'tests/lua/incomplete.lua': 'local value =',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/incomplete.lua']);
});

test('shadowed loader names are not assumed to behave like the Lua globals', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'tests/lua/shadowed-require.lua': 'local require = loader; return require("abyss_other")',
    'tests/lua/shadowed-pcall.lua': 'local pcall = wrapper; return pcall(require, "abyss_other")',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/shadowed-require.lua', 'tests/lua/shadowed-pcall.lua']);
});

test('literal protected imports embedded in JS retain their module edge', () => {
  const input = { ...luaSources,
    'tests/embedded.test.mjs': 'const program = `local ok, value = pcall ( require , "abyss_high" )`',
  };
  const plan = selectTests(['src/lua/abyss_low.lua'], input);
  assert.equal(plan.full, false);
  assert.deepEqual(plan.integration, ['tests/embedded.test.mjs']);
  assert.deepEqual(selectTests(['src/lua/abyss_other.lua'], input).integration, []);
});

test('prose, comments and unrelated static imports do not create dynamic Lua dependencies', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'tests/lua/comments.lua': '-- alias = require\n-- pcall(require, name)\nreturn "tests require coverage"',
    'tests/lua/external.lua': 'return require("external")',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua']);
});

test('explicit protected fixture changes select that fixture without unrelated tests', () => {
  const fixture = 'tests/lua/protected.lua';
  const input = { ...luaSources, [fixture]: 'return pcall(require, "abyss_high")' };
  const alone = selectTests([fixture], input);
  assert.equal(alone.full, false);
  assert.deepEqual(alone.lua, [fixture]);
  assert.deepEqual(selectTests(['src/lua/abyss_low.lua', fixture], input).lua,
    ['tests/lua/direct.lua', fixture]);
});

const files = dir => readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? files(`${dir}/${entry.name}`) : [`${dir}/${entry.name}`]);
const repositorySources = Object.fromEntries(['src/lua', 'scripts', 'tests'].flatMap(files)
  .filter(path => /\.(lua|mjs)$/.test(path)).map(path => [path, readFileSync(path, 'utf8')]));
for (const name of ['map', 'nodes']) {
  test(`real abyss_${name} changes retain the protected ${name} regression`, () => {
    const plan = selectTests([`src/lua/abyss_${name}.lua`], repositorySources);
    assert.equal(plan.full, false);
    assert.ok(plan.lua.includes(`tests/lua/${name}.lua`));
  });
}
