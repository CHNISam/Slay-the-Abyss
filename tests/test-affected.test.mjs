import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, mkdtempSync, mkdirSync, writeFileSync, rmSync, renameSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { selectTests, parseGitChanges } from '../scripts/test-affected.mjs';
import {frozenBattleHandFixtures} from './helpers/battle-life-frozen-hand.mjs';

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

test('prose and comments stay unrelated while unresolved literal modules remain conservative', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...luaSources,
    'tests/lua/comments.lua': '-- alias = require\n-- pcall(require, name)\nreturn "tests require coverage"',
    'tests/lua/external.lua': 'return require("external")',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/direct.lua', 'tests/lua/external.lua']);
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

const generatedSources = {
  ...luaSources,
  'scripts/node-ui-layout.mjs': 'export const nodeLayout = () => ({})',
  'scripts/game-ui-layout.mjs': 'import {nodeLayout} from "./node-ui-layout.mjs"; export const gameLayout = nodeLayout',
  'scripts/build-ui.mjs': 'import {gameLayout} from "./game-ui-layout.mjs"; export const buildUI = gameLayout',
  // The shared runner's CLI must not make every literal wrapper discover every fixture.
  'scripts/test-lua.mjs': 'export function runLua(path){}; readdirSync("tests/lua").forEach(runLua)',
  'tests/lua/support/host.lua': 'local Layout=require("abyss_ui_layout"); return Layout',
  'tests/lua/host.lua': 'return dofile("tests/lua/support/host.lua")',
  'tests/host.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua("tests/lua/host.lua")',
  'tests/other.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua("tests/lua/other.lua")',
};
test('generated UI producer chains reach Lua fixtures and their literal JS wrappers without build files', () => {
  const plan = selectTests(['scripts/node-ui-layout.mjs'], generatedSources);
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/host.lua']);
  assert.deepEqual(plan.integration, ['tests/host.test.mjs']);
});

test('generated Lua literal paths and long/protected Lua file loaders preserve the same chain', () => {
  const plan = selectTests(['scripts/node-ui-layout.mjs'], {
    ...generatedSources,
    'tests/lua/long.lua': 'return dofile [[tests/lua/support/host.lua]]',
    'tests/lua/protected.lua': 'return pcall(loadfile,"tests/lua/support/host.lua")',
    'tests/generated.test.mjs': 'runLua("build/lua/abyss_ui_layout.lua")',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/host.lua', 'tests/lua/long.lua', 'tests/lua/protected.lua']);
  assert.deepEqual(plan.integration, ['tests/host.test.mjs', 'tests/generated.test.mjs']);
});

for (const expression of [
  'runLua(path)', 'runLua("tests/lua/" + name)', 'runLua(`tests/lua/${name}.lua`)',
  'const execute=runLua; execute(path)', 'runLua()',
  'import {runLua as execute} from "../scripts/test-lua.mjs"; execute(path)',
  'const result = `${runLua(path)}`',
]) {
  test(`unresolved Lua execution remains conservative for generated and ordinary Lua changes: ${expression}`, () => {
    const input = { ...generatedSources, 'tests/dynamic.test.mjs': expression };
    for (const change of ['scripts/node-ui-layout.mjs', 'src/lua/abyss_low.lua', 'tests/lua/other.lua']) {
      const plan = selectTests([change], input);
      assert.equal(plan.full, false);
      assert.ok(plan.integration.includes('tests/dynamic.test.mjs'), change);
    }
  });
}

test('literal runLua, aliased literal calls, comments and prose do not become catch-all discovery', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], {
    ...generatedSources,
    'tests/alias.test.mjs': 'import {runLua as execute} from "../scripts/test-lua.mjs"; execute("tests/lua/other.lua")',
    'tests/prose.test.mjs': 'const text="runLua(path) and readdirSync(directory)"; /* runLua(path) */ // readdirSync(dir)',
    'tests/template.test.mjs': 'runLua(`tests/lua/other.lua`)',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.integration, []);
  assert.deepEqual(plan.fast, []);
});

test('known directory discovery is bounded, including generated outputs and imported helper discovery', () => {
  const input = { ...generatedSources,
    'tests/lua/audio/fixture.lua': 'return require("abyss_low")',
    'tests/lua/unrelated/fixture.lua': 'return true',
    'tests/support/discover.mjs': 'import {readdirSync as list} from "node:fs"; export const files=list("tests/lua/audio")',
    'tests/audio.test.mjs': 'import {files} from "./support/discover.mjs"',
    'tests/unrelated-directory.test.mjs': 'readdirSync("tests/lua/unrelated")',
    'tests/generated-directory.test.mjs': 'readdirSync("build/lua")',
  };
  const ordinary = selectTests(['src/lua/abyss_low.lua'], input);
  assert.equal(ordinary.full, false);
  assert.deepEqual(ordinary.integration, ['tests/audio.test.mjs']);
  const layout = selectTests(['scripts/node-ui-layout.mjs'], input);
  assert.ok([...layout.fast, ...layout.integration].includes('tests/generated-directory.test.mjs'));
  assert.ok(![...layout.fast, ...layout.integration].includes('tests/unrelated-directory.test.mjs'));
});

for (const expression of ['readdirSync(directory)', 'readdirSync(join(root,"tests"))', 'const list=readdirSync; list(directory)', 'import(modulePath)']) {
  test(`unsupported discovery remains conservative: ${expression}`, () => {
    const input = { ...generatedSources, 'tests/discovery.test.mjs': expression };
    for (const path of ['scripts/node-ui-layout.mjs', 'src/lua/abyss_low.lua']) {
      const plan = selectTests([path], input);
      assert.equal(plan.full, false);
      assert.ok([...plan.fast, ...plan.integration].includes('tests/discovery.test.mjs'));
    }
  });
}

test('missing literal Lua inputs remain conservative and empty existing inputs are not deleted', () => {
  const input = { ...generatedSources,
    'src/lua/abyss_empty.lua': '',
    'tests/lua/empty.lua': 'return require("abyss_empty")',
    'tests/missing.test.mjs': 'runLua("tests/lua/missing.lua")',
    'tests/lua/missing.lua': 'return require("abyss_missing_generated")',
  };
  const plan = selectTests(['src/lua/abyss_low.lua'], input);
  assert.equal(plan.full, false);
  assert.ok(plan.lua.includes('tests/lua/missing.lua'));
  assert.ok(plan.integration.includes('tests/missing.test.mjs'));
  assert.equal(selectTests(['src/lua/abyss_empty.lua'], input).full, false);
  delete input['tests/lua/missing.lua'];
  assert.ok(selectTests(['src/lua/abyss_low.lua'], input).integration.includes('tests/missing.test.mjs'));
  assert.equal(selectTests(['tests/lua/missing.lua'], input).full, true);
});

test('NUL git records retain both rename/copy sides and exact whitespace paths', () => {
  const old = 'scripts/old layout\tname.mjs', next = 'scripts/new layout\nname.mjs';
  assert.deepEqual(parseGitChanges(`R100\0${old}\0${next}\0M\0tests/plain.test.mjs\0C085\0scripts/a.mjs\0scripts/b.mjs\0`),
    [old, next, 'tests/plain.test.mjs', 'scripts/a.mjs', 'scripts/b.mjs']);
  // A realistic removed rename source is deliberately a full fallback; dynamic
  // candidates cannot claim that either old-path or new-path coverage is enough.
  assert.equal(selectTests(parseGitChanges(`R100\0${old}\0${next}\0`), { [next]: '' }).full, true);
  const before = 'scripts/old layout.mjs', after = 'scripts/new layout.mjs';
  const both = selectTests(parseGitChanges(`R100\0${before}\0${after}\0`), {
    [before]: '', [after]: '',
    'tests/old.test.mjs': `import '../${before}'`,
    'tests/new.test.mjs': `import '../${after}'`,
  });
  assert.equal(both.full, false);
  assert.deepEqual(both.fast, ['tests/old.test.mjs', 'tests/new.test.mjs']);
  for (const invalid of ['M\0file', 'R100\0old\0', 'not-a-status\0file\0']) assert.throws(() => parseGitChanges(invalid));
});

// Win32 rejects control characters in real filenames. Every platform still
// exercises spaces and Unicode; POSIX additionally exercises tabs/newlines.
// The synthetic NUL-record assertions above retain both controls on Windows.
for (const [kind, next, untracked] of [
  ['portable spaces and Unicode', 'scripts/new layout 雪.mjs', 'tests/new case 雪.test.mjs'],
  ...(process.platform === 'win32' ? [] : [['POSIX control characters', 'scripts/new\tlayout.mjs', 'tests/new\ncase.test.mjs']]),
]) {
test(`CLI reads real staged renames and untracked whitespace names without quoting or trimming: ${kind}`, () => {
  if (kind === 'portable spaces and Unicode') for (const path of [next, untracked]) {
    assert.match(path, / /);
    assert.match(path, /[^\x00-\x7f]/u);
    assert.doesNotMatch(path, /[<>:"\\|?*\u0000-\u001f]/u, 'portable fixture must use Windows-valid filename characters');
  }
  const root = mkdtempSync(join(tmpdir(), 'abyss-affected-git-'));
  const git = args => {
    const result = spawnSync('git', args, { cwd: root, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr); return result.stdout;
  };
  const put = (path, source) => { mkdirSync(dirname(join(root, path)), {recursive:true}); writeFileSync(join(root, path), source); };
  try {
    git(['init', '-q']);
    const old = 'scripts/old layout.mjs';
    put(old, 'export const value=1'); put('src/lua/abyss_empty.lua', ''); put('tests/direct.test.mjs', '');
    git(['add', '.']); git(['-c','user.name=Selector Test','-c','user.email=selector@example.invalid','commit','-qm','baseline']);
    renameSync(join(root, old), join(root, next)); git(['add', '-A']); put(untracked, '');
    const result = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/test-affected.mjs', import.meta.url)), '--plan', '--base', 'HEAD'], {cwd:root,encoding:'utf8'});
    assert.equal(result.status, 0, result.stderr);
    const plan = JSON.parse(result.stdout);
    assert.deepEqual(plan.changed, [old, next, untracked]);
    assert.equal(plan.full, true); assert.match(plan.reason, /old layout/);
  } finally { rmSync(root, {recursive:true,force:true}); }
});
}

test('real generated node layout changes retain actual host Lua regressions and exclude literal unrelated wrappers', () => {
  const plan = selectTests(['scripts/node-ui-layout.mjs'], repositorySources);
  assert.equal(plan.full, false);
  for (const fixture of ['game_ui', 'game_ui_boss_treasure', 'presentation_trace_native']) assert.ok(plan.lua.includes(`tests/lua/${fixture}.lua`), fixture);
  assert.ok(plan.integration.includes('tests/game-ui.test.mjs'));
  assert.ok(!plan.integration.includes('tests/reward-upgrades.test.mjs'));
});

test('the conditional historical replay helper selects its fixture without tainting ordinary Lua wrappers',()=>{
  const plan=selectTests(['tests/helpers/historical-presentation-runner.mjs'],repositorySources);
  assert.equal(plan.full,false);
  assert.ok(plan.lua.includes('tests/lua/presentation_responsibilities_trace.lua'));
  assert.ok(!plan.integration.includes('tests/reward-upgrades.test.mjs'));
});

test('opening-hand setup selects all eighteen actual fixture entries without tainting ordinary Lua wrappers',()=>{
  const plan=selectTests(['tests/helpers/battle-life-frozen-hand.mjs'],repositorySources);
  assert.equal(plan.full,false);
  assert.equal(frozenBattleHandFixtures.length,18);
  for(const fixture of frozenBattleHandFixtures)assert.ok(plan.lua.includes(fixture),fixture);
  assert.ok(!plan.integration.includes('tests/reward-upgrades.test.mjs'));
});

test('current card-view changes still select real opening input and every adapted fixture',()=>{
  const plan=selectTests(['src/lua/abyss_battle_card_view.lua'],repositorySources);
  assert.equal(plan.full,false);
  assert.ok(plan.lua.includes('tests/lua/battle_life_opening_input.lua'),'current unadapted input must remain selected');
  for(const fixture of frozenBattleHandFixtures)assert.ok(plan.lua.includes(fixture),fixture);
});


test('regex assertions are not executable discovery calls', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], { ...generatedSources,
    'tests/assertion.test.mjs': String.raw`assert.match(runner, /readdirSync\('tests\/lua'\)/); assert.match(source,/runLua\(/);`,
  });
  assert.equal(plan.full, false);
  assert.ok(![...plan.fast, ...plan.integration].includes('tests/assertion.test.mjs'));
});

for (const expression of [
  `import * as runner from '../scripts/test-lua.mjs'; runner['runLua'](path)`,
  `import * as runner from '../scripts/test-lua.mjs'; runner[method](path)`,
  `import * as fs from 'node:fs'; fs['readdirSync'](directory)`,
  `import * as fs from 'node:fs'; fs[method](directory)`,
]) {
  test(`namespace/computed unknown calls remain conservative: ${expression}`, () => {
    const plan = selectTests(['src/lua/abyss_low.lua'], { ...generatedSources, 'tests/namespace.test.mjs': expression });
    assert.equal(plan.full, false);
    assert.ok([...plan.fast, ...plan.integration].includes('tests/namespace.test.mjs'));
  });
}

test('computed literal calls retain only their actual fixture while directory literals are normalized', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], { ...generatedSources,
    'tests/literal.test.mjs': `import * as runner from '../scripts/test-lua.mjs'; runner['runLua']('tests/lua/other.lua')`,
    'tests/normal.test.mjs': `readdirSync('tests/lua/../lua')`,
    'tests/root.test.mjs': `readdirSync('./')`,
    'tests/unknown.test.mjs': `readdirSync('unknown-directory')`,
  });
  assert.equal(plan.full, false);
  assert.ok(!plan.integration.includes('tests/literal.test.mjs'));
  for (const file of ['normal', 'root', 'unknown']) assert.ok([...plan.fast, ...plan.integration].includes(`tests/${file}.test.mjs`));
});

test('shared runner imports stay transitive without importing its CLI fixture discovery', () => {
  const plan = selectTests(['scripts/helper.mjs'], { ...generatedSources,
    'scripts/helper.mjs': 'export const serializer=1',
    'scripts/test-lua.mjs': 'import {serializer} from "./helper.mjs"; export function runLua(path){}; readdirSync("tests/lua").forEach(runLua)',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.integration, ['tests/host.test.mjs', 'tests/other.test.mjs']);
});

for (const expression of [
  'import * as runner from "../scripts/test-lua.mjs"; const text = `${runner[method](path)}`',
  'import * as fs from "node:fs"; const text = `${fs[method](directory)}`',
  'import {runLua as execute} from "../scripts/test-lua.mjs"; const text = `${execute(path)}`',
]) {
  test(`template expressions preserve unresolved imported calls: ${expression}`, () => {
    const plan = selectTests(['src/lua/abyss_low.lua'], { ...generatedSources, 'tests/expression.test.mjs': expression });
    assert.equal(plan.full, false);
    assert.ok([...plan.fast, ...plan.integration].includes('tests/expression.test.mjs'));
  });
}

test('unknown JS discovery covers changed test modules, not only scripts', () => {
  const plan = selectTests(['tests/changed.test.mjs'], { ...generatedSources,
    'tests/changed.test.mjs': 'export const value=1',
    'tests/discovery.test.mjs': 'readdirSync(directory)',
    'tests/import.test.mjs': 'import(modulePath)',
  });
  assert.equal(plan.full, false);
  for (const file of ['changed', 'discovery', 'import']) assert.ok([...plan.fast, ...plan.integration].includes(`tests/${file}.test.mjs`));
});

test('plain arrays and static array assertions do not count as computed invocation', () => {
  const plan = selectTests(['src/lua/abyss_low.lua'], { ...generatedSources,
    'tests/arrays.test.mjs': 'const names=["runLua"]; assert.deepEqual(names,["readdirSync"]); function namesOnly(){return ["runLua"]}',
  });
  assert.equal(plan.full, false);
  assert.ok(![...plan.fast, ...plan.integration].includes('tests/arrays.test.mjs'));
});

test('runner scheduling helpers keep static import coverage without executing their CLI discovery', () => {
  const input = { ...generatedSources,
    'scripts/scheduler.mjs': 'export function discover(){return readdirSync(directory)}',
    'scripts/test-lua.mjs': 'import {discover} from "./scheduler.mjs"; export function runLua(path){}; if (import.meta.url === pathToFileURL(resolve(process.argv[1])).href) discover()',
  };
  assert.deepEqual(selectTests(['scripts/scheduler.mjs'], input).integration, ['tests/host.test.mjs', 'tests/other.test.mjs']);
  assert.deepEqual(selectTests(['src/lua/abyss_low.lua'], input).integration, []);
  assert.deepEqual(selectTests(['scripts/node-ui-layout.mjs'], input).integration, ['tests/host.test.mjs']);
  input['tests/scheduler.test.mjs'] = 'import {discover} from "../scripts/scheduler.mjs"; discover()';
  assert.ok([...selectTests(['src/lua/abyss_low.lua'], input).integration, ...selectTests(['src/lua/abyss_low.lua'], input).fast].includes('tests/scheduler.test.mjs'));
});

for (const expression of [
  'const runner=await import("../scripts/test-lua.mjs"); runner[method](path)',
  'const { ["runLua"]: execute }=await import("../scripts/test-lua.mjs"); execute(path)',
  'const fs=await import("node:fs"); fs[method](directory)',
]) {
  test(`unsupported literal import namespace consumption stays conservative: ${expression}`, () => {
    const plan = selectTests(['src/lua/abyss_low.lua'], { ...generatedSources, 'tests/imported.test.mjs': expression });
    assert.equal(plan.full, false);
    assert.ok([...plan.fast, ...plan.integration].includes('tests/imported.test.mjs'));
  });
}

for (const [module, path] of [
  ['shared', 'src/lua/shared.lua'],
  ['support.shared', 'src/lua/support/shared.lua'],
  ['shared-helper', 'src/lua/shared-helper.lua'],
  ['shared helper', 'src/lua/shared helper.lua'],
]) {
  for (const expression of [`require("${module}")`, `require [[${module}]]`, `pcall(require,"${module}")`]) {
    test(`ordinary literal Lua modules retain consumers and literal JS wrappers: ${expression}`, () => {
      const input = {
        [path]: 'return {}',
        'src/lua/other.lua': 'return {}',
        'scripts/test-lua.mjs': 'export function runLua(path){}',
        'tests/lua/mapped.lua': `return dofile("${path}")`,
        'tests/lua/consumer.lua': `return ${expression}`,
        'tests/lua/unrelated.lua': 'return require("other")',
        'tests/consumer.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua("tests/lua/consumer.lua")',
        'tests/unrelated.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua("tests/lua/unrelated.lua")',
      };
      const plan = selectTests([path], input);
      assert.equal(plan.full, false);
      assert.deepEqual(plan.lua, ['tests/lua/mapped.lua', 'tests/lua/consumer.lua']);
      assert.deepEqual(plan.integration, ['tests/consumer.test.mjs']);
    });
  }
}

test('unresolved ordinary literal modules retain their Lua and JS roots conservatively', () => {
  const plan = selectTests(['src/lua/shared.lua'], {
    'src/lua/shared.lua': 'return {}',
    'scripts/test-lua.mjs': 'export function runLua(path){}',
    'tests/lua/mapped.lua': 'return dofile("src/lua/shared.lua")',
    'tests/lua/consumer.lua': 'return require("unmodelled-plugin")',
    'tests/consumer.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua("tests/lua/consumer.lua")',
  });
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, ['tests/lua/mapped.lua', 'tests/lua/consumer.lua']);
  assert.deepEqual(plan.integration, ['tests/consumer.test.mjs']);
});
