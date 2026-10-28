import { jsShard, discoverJs } from '../scripts/ci-shards.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { shardLuaScripts } from '../scripts/test-lua.mjs';

test('sorted shards partition every fixture without omission or duplication and reject invalid bounds', () => {
  const scripts = ['d.lua', 'b.lua', 'a.lua', 'e.lua', 'c.lua'];
  assert.deepEqual(shardLuaScripts(scripts, '1/2'), ['a.lua', 'c.lua', 'e.lua']);
  for (const count of [1, 2, 4, 64]) {
    const combined = Array.from({ length: count }, (_, index) => shardLuaScripts(scripts, `${index + 1}/${count}`)).flat();
    assert.equal(combined.length, scripts.length);
    assert.equal(new Set(combined).size, scripts.length);
    assert.deepEqual(combined.sort(), [...scripts].sort());
  }
  for (const value of ['', undefined, '0/1', '1/0', '2/1', '1/65', '-1/2', '1.5/2', '1/2/3', '01/2', 'Infinity/2']) {
    assert.throws(() => shardLuaScripts(scripts, value), /1 <= i <= n <= 64/);
  }
});

test('longest fixtures fill the least loaded combined JS/Lua shard deterministically', () => {
  const scripts = ['a.lua', 'b.lua', 'c.lua', 'd.lua', 'new.lua'];
  const timings = { lua: { 'a.lua': 80, 'b.lua': 70, 'c.lua': 20, 'd.lua': 10 }, unknownLuaMs: 30,
    windowsJsShardMs: [100, 0] };
  assert.deepEqual(shardLuaScripts(scripts, '1/2', timings), ['c.lua', 'd.lua', 'new.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '2/2', timings), ['a.lua', 'b.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '1/2', timings, 2), ['c.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '2/2', timings, 2), ['a.lua', 'b.lua', 'd.lua', 'new.lua']);
  for (const workers of [0, 3, '2', NaN]) assert.throws(() => shardLuaScripts(scripts, '1/2', timings, workers), /workers must be/);
  assert.deepEqual(shardLuaScripts([...scripts].reverse(), '1/2', timings), shardLuaScripts(scripts, '1/2', timings));
  assert.deepEqual(shardLuaScripts(scripts, '1/1', timings), [...scripts].sort());
  for (const bad of [0, -1, NaN, Infinity, '10']) {
    assert.throws(() => shardLuaScripts(['a.lua'], '1/2', { lua: { 'a.lua': bad }, unknownLuaMs: 1 }), /positive finite/);
    assert.throws(() => shardLuaScripts(['new.lua'], '1/2', { lua: {}, unknownLuaMs: bad }), /positive finite/);
  }
  assert.throws(() => shardLuaScripts(['a.lua'], '1/2', { ...timings, windowsJsShardMs: [0, -1] }), /initial shard/);
  assert.throws(() => shardLuaScripts(['a.lua', 'a.lua'], '1/2', timings), /unique nonempty/);
});

test('exclusive fixtures are budgeted as serial work alongside the parallel-safe pool', () => {
  const files = ['tests/lua/heavy.lua', 'tests/lua/safe-a.lua', 'tests/lua/safe-b.lua', 'tests/lua/unknown.lua'];
  const measured = { lua: { [files[0]]: 20000, [files[1]]: 8000, [files[2]]: 8000 },
    unknownLuaMs: 10000, windowsJsShardMs: [20000, 0] };
  assert.deepEqual(shardLuaScripts(files, '1/2', measured, 2), [files[3]]);
  assert.deepEqual(shardLuaScripts(files, '2/2', measured, 2), files.slice(0, 3));
});

test('measured scheduling retains every current fixture and reduces estimated critical path', () => {
  const timings = JSON.parse(readFileSync('scripts/ci-test-timings.json', 'utf8'));
  assert.equal(timings.source.runId, 40630641377);
  assert.equal(timings.source.headSha, '257d9e0c9a4f2b680b8d1fc07c26025451eb5ac8');
  assert.equal(Object.keys(timings.js.win32).length, 294);
  assert.equal(Object.keys(timings.js.linux).length, 294);
  assert.equal(Object.keys(timings.lua).length, 974);
  const scripts = readdirSync('tests/lua').filter(file => file.endsWith('.lua')).sort().map(file => `tests/lua/${file}`);
  const weight = script => timings.lua[script] ?? timings.unknownLuaMs;
  for (const count of [1, 2, 4, 8, 64]) {
    const bins = Array.from({ length: count }, (_, i) => shardLuaScripts(scripts, `${i + 1}/${count}`));
    const combined = bins.flat();
    assert.deepEqual(combined.sort(), scripts);
    assert.equal(new Set(combined).size, scripts.length);
    const reversed = scripts.toReversed();
    assert.deepEqual(shardLuaScripts(reversed, `1/${count}`), bins[0]);
  }
  const newLoads = jsShard(discoverJs(), '1/8', 'win32').loads;
  const oldLoads = Array(8).fill(0);
  discoverJs().sort().forEach((file, i) => { oldLoads[i % 8] += timings.js.win32[file] ?? timings.unknownJsMs; });
  scripts.forEach((script, i) => { oldLoads[i % 8] += weight(script); });
  for (let i = 0; i < 8; i++) for (const script of shardLuaScripts(scripts, `${i + 1}/8`)) newLoads[i] += weight(script);
  assert.ok(Math.max(...newLoads) < Math.max(...oldLoads), 'measured schedule must improve the estimated critical path');
  assert.ok(Math.max(...newLoads) - Math.min(...newLoads) <= Math.max(...scripts.map(weight)), 'LPT bins differ by at most one fixture');
});

test('real CLI shards retain failure exit and continuation, allow empty slices and reject invalid arguments', () => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-lua-shards-')), cli = resolve('scripts/test-lua.mjs');
  const run = args => spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 10000, windowsHide: true });
  try {
    mkdirSync(join(root, 'tests/lua'), { recursive: true });
    assert.notEqual(run(['--shard', '1/2']).status, 0, 'an undiscovered suite must still fail');
    writeFileSync(join(root, 'tests/lua/a.lua'), "print('failed block');error('CLI failure')");
    writeFileSync(join(root, 'tests/lua/b.lua'), "print('other shard')");
    writeFileSync(join(root, 'tests/lua/c.lua'), "print('later block')");
    for (const args of [['--shard'], ['--shard', '2/1'], ['--shard', '1/65'], ['--unknown'], ['some.lua', '--shard', '1/2'],
      ['--workers'], ['--workers', '0'], ['--workers', '3'], ['--workers', '2', '--workers', '1']]) {
      assert.notEqual(run(args).status, 0);
    }
    const failed = run(['--shard', '1/2']);
    assert.ifError(failed.error);
    assert.notEqual(failed.status, 0);
    assert.match(failed.stderr, /CLI failure/);
    assert.match(failed.stdout, /failed block[\s\S]*Lua fixture tests\/lua\/a.lua:[\s\S]*later block[\s\S]*Lua fixture tests\/lua\/c.lua:/);
    assert.doesNotMatch(failed.stdout, /other shard/);
    const passed = run(['--shard', '2/2']), empty = run(['--shard', '4/4']);
    assert.equal(passed.status, 0, passed.stderr);
    assert.match(passed.stdout, /other shard/);
    assert.equal(empty.status, 0, empty.stderr);
    assert.match(empty.stdout, /Lua shard 4\/4: 0 fixtures/);
    const parallel = run(['--shard', '1/2', '--workers', '2']);
    assert.ifError(parallel.error);
    assert.notEqual(parallel.status, 0);
    assert.match(parallel.stderr, /CLI failure/);
    assert.match(parallel.stdout, /failed block/);
    assert.match(parallel.stdout, /later block/);
    assert.doesNotMatch(parallel.stdout, /other shard/);
    const passedParallel = run(['--shard', '2/2', '--workers', '2']);
    assert.equal(passedParallel.status, 0, passedParallel.stderr);
    assert.match(passedParallel.stdout, /other shard/);
    const emptyParallel = run(['--shard', '4/4', '--workers', '2']);
    assert.equal(emptyParallel.status, 0, emptyParallel.stderr);
    assert.match(emptyParallel.stdout, /Lua shard 4\/4: 0 fixtures/);
  } finally {
    assert.ok(resolve(root).startsWith(resolve(tmpdir()) + sep));
    assert.match(root, /abyss-lua-shards-/);
    rmSync(root, { recursive: true, force: true });
  }
});
