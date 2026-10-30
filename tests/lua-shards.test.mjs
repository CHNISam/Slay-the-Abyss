import {preTextSafetySource} from './helpers/ci-text-safety-source.mjs';
import { jsShard, discoverJs } from '../scripts/ci-shards.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { preCiLuaCalibrationSource } from './helpers/ci-lua-calibration-inverse.mjs';
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
  assert.deepEqual(shardLuaScripts(scripts, '1/2', timings, 2), ['d.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '2/2', timings, 2), ['a.lua', 'b.lua', 'c.lua', 'new.lua']);
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

test('measured scheduling retains every current fixture and reduces estimated critical path', () => {
  const timings = JSON.parse(readFileSync('scripts/ci-test-timings.json', 'utf8'));
  assert.equal(timings.source.runId, 40630641377);
  assert.equal(timings.source.headSha, '257d9e0c9a4f2b680b8d1fc07c26025451eb5ac8');
  assert.equal(timings.jsSource.runId, 40980643080);
  assert.equal(timings.jsSource.runAttempt, 1);
  assert.equal(timings.jsSource.headSha, 'ce62e753065666fd26c9d85587a8f3ae2a580689');
  assert.equal(Object.keys(timings.js.win32).length, 408);
  assert.equal(Object.keys(timings.js.linux).length, 408);
  assert.equal(Object.keys(timings.lua).length, 974);
  const scripts = readdirSync('tests/lua').filter(file => file.endsWith('.lua')).sort().map(file => `tests/lua/${file}`);
  const weight = script => timings.luaShard?.[script] ?? timings.lua[script] ?? timings.unknownLuaMs;
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

test('dual-worker partition includes the full serial cost of deadline-sensitive fixtures', () => {
  const fixtures = ['a.lua', 'b.lua', 'c.lua', 'd.lua'];
  const timings = { lua: { 'a.lua': 50000, 'b.lua': 30000, 'c.lua': 8000, 'd.lua': 8000 },
    unknownLuaMs: 10000, windowsJsShardMs: [20000, 0] };
  assert.deepEqual(shardLuaScripts(fixtures, '1/2', timings, 2), ['b.lua', 'c.lua']);
  assert.deepEqual(shardLuaScripts(fixtures, '2/2', timings, 2), ['a.lua', 'd.lua']);
});

test('historical placement measurements retain their original safety snapshot and full workload', () => {
  // Only this historical calibration proof uses the exact parent snapshot.
  // Current worker admission is tested against unprojected production weights.
  const path = 'scripts/ci-test-timings.json';
  const timings = JSON.parse(preTextSafetySource(path, readFileSync(path, 'utf8')));
  assert.equal(createHash('sha256').update(JSON.stringify(timings.lua)).digest('hex'),
    'a248c3e406651577d6ead3655d4760421940a7a8d85bf77d95fc85513020153c', 'all original worker safety weights remain identical');
  assert.equal(timings.luaShardSource.runId, 40980643080);
  const files = Object.keys(timings.luaShard);
  assert.equal(files.length, 1114);
  const current = readdirSync('tests/lua').filter(file => file.endsWith('.lua')).map(file => `tests/lua/${file}`);
  assert.ok(files.every(file => current.includes(file)), 'complete measured inventory remains discovered');
  const old = { ...timings };
  delete old.luaShard;
  const short = file => (timings.lua[file] ?? timings.unknownLuaMs) < 10000;
  const js = jsShard(discoverJs(), '1/8', 'win32').loads;
  function loads(weights) {
    const bins = Array.from({ length: 8 }, (_, i) => shardLuaScripts(files, `${i + 1}/8`, weights, 2));
    assert.deepEqual(bins.flat().sort(), [...files].sort(), 'all measured files exactly once');
    return bins.map((bin, i) => {
      const pool = [0, 0];
      for (const file of bin.filter(short).sort((a, b) => timings.lua[b] - timings.lua[a] || a.localeCompare(b))) {
        pool[pool[0] <= pool[1] ? 0 : 1] += timings.luaShard[file];
      }
      return js[i] + bin.filter(file => !short(file)).reduce((sum, file) => sum + timings.luaShard[file], 0) + Math.max(...pool);
    });
  }
  const before = loads(old), after = loads(timings);
  assert.ok(Math.max(...after) < Math.max(...before) * 0.95, 'same measured workload improves projected maximum by at least 5%');
  assert.ok(Math.max(...after) - Math.min(...after) < 1000, 'projected combined spread remains under one second');
  const sample = { lua: { heavy: 20000, short: 100 }, luaShard: { heavy: 100, short: 20000 }, unknownLuaMs: 10000 };
  assert.deepEqual(shardLuaScripts(['heavy', 'short'], '1/2', sample, 2), ['short']);
  for (const invalid of [0, -1, Infinity, NaN, '100']) {
    assert.throws(() => shardLuaScripts(['heavy'], '1/2', { ...sample, luaShard: { heavy: invalid } }, 2), /positive finite/);
    assert.throws(() => shardLuaScripts(['heavy'], '1/2', { ...sample, lua: { heavy: invalid } }, 2), /positive finite/);
  }
});

test('placement inverse preserves original runner bytes and exposes every unrelated mutation', () => {
  const path = 'scripts/test-lua.mjs', source = readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
  const sha = value => createHash('sha256').update(value).digest('hex');
  const before = '66dc757b28cbe4a0f802d7f660299f1e91f8381bd44a08ac2e69aff2d3398ab2';
  for (const text of [source, source.replaceAll('\n', '\r\n')]) assert.equal(sha(preCiLuaCalibrationSource(path, text)), before);
  for (const text of [source + '\n', source.replace('60000 : 30000', '60000 : 60000'), source.replace('runtimeTimings.lua });', 'runtimeTimings.luaShard });')]) {
    assert.notEqual(text, source);
    assert.equal(preCiLuaCalibrationSource(path, text), text, 'partial and foreign sources never receive historical identity');
  }
  assert.equal(preCiLuaCalibrationSource('scripts/other.mjs', source), source);
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
