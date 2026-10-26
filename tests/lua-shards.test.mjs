import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
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

test('real CLI shards retain failure exit and continuation, allow empty slices and reject invalid arguments', () => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-lua-shards-')), cli = resolve('scripts/test-lua.mjs');
  const run = args => spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 10000, windowsHide: true });
  try {
    mkdirSync(join(root, 'tests/lua'), { recursive: true });
    assert.notEqual(run(['--shard', '1/2']).status, 0, 'an undiscovered suite must still fail');
    writeFileSync(join(root, 'tests/lua/a.lua'), "print('failed block');error('CLI failure')");
    writeFileSync(join(root, 'tests/lua/b.lua'), "print('other shard')");
    writeFileSync(join(root, 'tests/lua/c.lua'), "print('later block')");
    for (const args of [['--shard'], ['--shard', '2/1'], ['--shard', '1/65'], ['--unknown'], ['some.lua', '--shard', '1/2']]) {
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
  } finally { rmSync(root, { recursive: true, force: true }); }
});
