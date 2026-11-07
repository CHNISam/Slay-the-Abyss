import test from 'node:test';
import assert from 'node:assert/strict';
import childProcess from 'node:child_process';
import Module, { syncBuiltinESMExports } from 'node:module';
import { runLua } from '../scripts/test-lua.mjs';
import {luaTimeoutMs,sapphireSliceMs} from '../scripts/ci-timeout-policy.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preLuaTimeoutPolicySource} from './helpers/lua-timeout-policy-source-inverse.mjs';

test('central Lua execution guards are finite and immutable',()=>{
  assert.deepEqual(luaTimeoutMs,{default:90000,heavy:120000,veryHeavy:180000});
  assert.ok(Object.isFrozen(luaTimeoutMs));assert.equal(sapphireSliceMs,90000);
});

test('timeout policy inverse preserves the complete old runner and exposes foreign edits',()=>{
  const source=readFileSync(new URL('../scripts/test-lua.mjs',import.meta.url),'utf8').replaceAll('\r\n','\n');
  const sha=value=>createHash('sha256').update(value).digest('hex');
  const previous=preLuaTimeoutPolicySource('scripts/test-lua.mjs',source);
  assert.notEqual(previous,source);
  assert.equal(preLuaTimeoutPolicySource('scripts/test-lua.mjs',source.replaceAll('\n','\r\n')),previous);
  assert.equal(preLuaTimeoutPolicySource('scripts/test-lua.mjs',previous),previous);
  for(const changed of [source+'\n// foreign drift\n',source.replace('luaTimeoutMs.heavy : luaTimeoutMs.default','luaTimeoutMs.heavy : luaTimeoutMs.heavy'),
    source.replace('maxBuffer = 1024 * 1024','maxBuffer = 1')]){
    assert.notEqual(changed,source);assert.notEqual(sha(changed),sha(previous));
    assert.equal(preLuaTimeoutPolicySource('scripts/test-lua.mjs',changed),changed);
  }
});

// Formatting/forwarding tests only, not Lua or process-timing acceptance.
// Test-file isolation and synchronous callbacks bound both temporary substitutions.
function withResult(result, action) {
  const originalSpawn = childProcess.spawnSync;
  const originalResolve = Module._resolveFilename;
  const calls = [];
  childProcess.spawnSync = (...args) => { calls.push(args); return result; };
  Module._resolveFilename = function(request, ...args) {
    return request === 'fengari-node-cli/src/lua-cli.js'
      ? '/diagnostic-fixture/lua-cli.js' : originalResolve.call(this, request, ...args);
  };
  syncBuiltinESMExports();
  try { return action(calls); }
  finally {
    childProcess.spawnSync = originalSpawn;
    Module._resolveFilename = originalResolve;
    syncBuiltinESMExports();
  }
}

function timedOut(stdout, stderr) {
  const error = Object.assign(new Error('spawnSync node ETIMEDOUT'), { code: 'ETIMEDOUT' });
  return { error, stdout, stderr, status: null, signal: 'SIGTERM' };
}

test('timeout preserves captured UTF-8 stdout/stderr and exact original error cause', () => {
  const result = timedOut('ok 第七组\n', '诊断错误\n');
  withResult(result, () => {
    assert.throws(() => runLua('tests/lua/diagnostic.lua'), error => {
      assert.equal(error.cause, result.error);
      assert.equal(error.cause.code, 'ETIMEDOUT');
      assert.equal(error.message, 'Lua runner failed (tests/lua/diagnostic.lua, 90000 ms): spawnSync node ETIMEDOUT'
        + '\n--- Lua stdout ---\nok 第七组\n\n--- Lua stderr ---\n诊断错误\n');
      return true;
    });
  });
});

test('null, missing and empty child output produce no empty sections', () => {
  for (const result of [timedOut(null, null), timedOut(undefined, undefined), timedOut('', '')]) {
    withResult(result, () => {
      assert.throws(() => runLua('tests/lua/diagnostic.lua'), error => {
        assert.equal(error.cause, result.error);
        assert.equal(error.message, 'Lua runner failed (tests/lua/diagnostic.lua, 90000 ms): spawnSync node ETIMEDOUT');
        return true;
      });
    });
  }
});

test('only nonempty output streams receive a section', () => {
  for (const [stdout, stderr, section] of [['one\n', null, 'stdout'], [null, 'one\n', 'stderr']]) {
    withResult(timedOut(stdout, stderr), () => {
      assert.throws(() => runLua('tests/lua/diagnostic.lua'), error => {
        assert.equal(error.message, 'Lua runner failed (tests/lua/diagnostic.lua, 90000 ms): spawnSync node ETIMEDOUT'
          + `\n--- Lua ${section} ---\none\n`);
        return true;
      });
    });
  }
});

test('successful and ordinary nonzero child results retain identity and output', () => {
  for (const status of [0, 7]) {
    const result = { status, signal: null, stdout: 'marker\n', stderr: 'warning\n' };
    withResult(result, () => assert.equal(runLua('tests/lua/diagnostic.lua'), result));
  }
});

test('signal without spawn error remains a thrown failure', () => {
  withResult({ status: null, signal: 'SIGTERM', stdout: '', stderr: '' }, () => {
    assert.throws(() => runLua('tests/lua/diagnostic.lua'), { message: 'Lua runner terminated by SIGTERM' });
  });
});

test('central defaults and explicit timeout plus maxBuffer reach spawnSync unchanged', () => {
  for (const [script, options, timeout] of [
    ['tests/lua/diagnostic.lua', {}, 90000],
    ['tests/lua/sapphire_treasure.lua', {}, 90000],
    ['tests/lua/sapphire_treasure_slice_2.lua', { timeout: 321 }, 321],
    ['tests/lua/game_ui.lua', {}, 120000],
    ['tests/lua/encounter_coverage.lua', {}, 180000],
    ['tests/lua/map_floor_boundaries.lua', {}, 180000],
    ['tests/lua/map_no_crossings.lua', {}, 180000],
    ['tests/lua/map_treasure_placement.lua', {}, 180000],
    ['tests/lua/encounter_coverage.lua', { timeout: 321 }, 321],
    ['tests/lua/map_no_crossings.lua', { timeout: 321 }, 321],
    ['tests/lua/diagnostic.lua', { timeout: 180 }, 180],
    ['tests/lua/battle_ui.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_2.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_2.lua', { timeout: 321 }, 321],
    ['tests/lua/battle_ui_slice_3.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_3.lua', { timeout: 321 }, 321],
    ['tests/lua/battle_ui_slice_4.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_4.lua', { timeout: 321 }, 321],
    ['tests/lua/battle_ui_slice_5.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_5.lua', { timeout: 321 }, 321],
    ['tests/lua/battle_ui_slice_6.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_6.lua', { timeout: 321 }, 321],
    ['tests/lua/battle_ui_slice_7.lua', {}, 120000],
    ['tests/lua/battle_ui_slice_7.lua', { timeout: 321 }, 321],
    ['tests/lua/living_wall_slice_2.lua', {}, 90000],
    ['tests/lua/living_wall_slice_3.lua', {}, 90000],
    ['tests/lua/diagnostic.lua', { timeout: 321 }, 321],
  ]) {
    withResult({ status: 0, signal: null, stdout: '', stderr: '' }, calls => {
      runLua(script, options);
      assert.equal(calls.length, 1);
      const [command, args, settings] = calls[0];
      assert.equal(command, process.execPath);
      if (script.startsWith('tests/lua/battle_ui')) {
        assert.match(args[0], /historical-monster-ui-entry\.mjs$/);
        assert.equal(args[1], script);assert.equal(args[2], String(timeout));
      } else if (script.includes('sapphire_treasure')) {
        assert.match(args[0], /historical-sapphire-entry\.mjs$/);
        assert.equal(args[1], script);assert.equal(args[2],String(timeout));
      } else {
        assert.equal(args[0], '/diagnostic-fixture/lua-cli.js');
        assert.equal(args[1], '-e');
      }
      assert.equal(settings.timeout, timeout);
      assert.equal(settings.maxBuffer, 1024 * 1024);
      assert.equal(settings.encoding, 'utf8');
    });
  }
});

test('injected failures restore original built-in bindings', () => {
  const spawn = childProcess.spawnSync, resolve = Module._resolveFilename;
  const failure = new Error('test callback sentinel');
  assert.throws(() => withResult({}, () => { throw failure; }), error => error === failure);
  assert.equal(childProcess.spawnSync, spawn);
  assert.equal(Module._resolveFilename, resolve);
});

// Real byte capture/overflow and trailing-state checks live in
// lua-runner-output-buffer.test.mjs; this only verifies routing arguments.
test('explicit output buffer reaches ordinary and historical adapters without changing deadlines', () => {
  for (const [script, timeout] of [
    ['tests/lua/diagnostic.lua', 90000],
    ['tests/lua/battle_ui.lua', 120000],
    ['tests/lua/presentation_responsibilities_text.lua', 90000],
  ]) {
    withResult({ status: 0, signal: null, stdout: '', stderr: '' }, calls => {
      runLua(script, { maxBuffer: 2 * 1024 * 1024 });
      assert.equal(calls.length, 1);
      assert.equal(calls[0][2].maxBuffer, 2 * 1024 * 1024);
      assert.equal(calls[0][2].timeout, timeout);
    });
  }
});
