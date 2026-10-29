import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { impact } from '../scripts/ci-impact.mjs';
const timing = { js: { win32: {}, linux: {} }, lua: {}, unknownJsMs: 1000, unknownLuaMs: 1000 };
const event = { eventName: 'pull_request', base: 'develop' };
const sources = { 'scripts/value.mjs': 'export const value=1;', 'tests/value.test.mjs': 'import {value} from "../scripts/value.mjs";' };
test('complete mapped set is eligible; unknown, deleted, core and release changes require full', () => {
  const plan = impact(['scripts/value.mjs'], sources, event, timing);
  assert.equal(plan.mode, 'fast');
  assert.deepEqual(plan.js, ['tests/value.test.mjs']);
  for (const path of ['data/cards.json', 'src/lua/abyss_combat.lua', '.github/workflows/quality.yml', 'deleted.mjs', 'docs/design/UI_DESIGN.md'])
    assert.equal(impact([path], sources, event, timing).mode, 'full', path);
  for (const ev of [{ ...event, forceFull: true }, { ...event, base: 'master' }, { ...event, eventName: 'push' }, { ...event, eventName: 'workflow_dispatch' }])
    assert.equal(impact(['scripts/value.mjs'], sources, ev, timing).mode, 'full');
  assert.equal(impact([], sources, event, timing).mode, 'full');
  assert.equal(impact(['scripts/value.mjs'], sources, event, { ...timing, unknownJsMs: 180001 }).mode, 'full');
});
test('prose allowlist cannot hide additional unmodelled changes', () => {
  assert.equal(impact(['docs/CI.md'], sources, event, timing).mode, 'fast');
  assert.equal(impact(['docs/CI.md', 'unknown'], sources, event, timing).mode, 'full');
});
test('parallel platforms budget their complete selected sets, including identical Lua cost', () => {
  const input = {
    'scripts/value.mjs': 'export const value=1;',
    'tests/a.test.mjs': 'import "../scripts/value.mjs";',
    'tests/b.test.mjs': 'import "../scripts/value.mjs";',
    'tests/lua/check.lua': 'return true',
  };
  const weights = { ...timing, js: {
    win32: { 'tests/a.test.mjs': 120000, 'tests/b.test.mjs': 10000 },
    linux: { 'tests/a.test.mjs': 10000, 'tests/b.test.mjs': 120000 },
  }, lua: { 'tests/lua/check.lua': 50000 } };
  const changed = ['scripts/value.mjs', 'tests/lua/check.lua'];
  const plan = impact(changed, input, event, weights);
  assert.equal(plan.mode, 'fast', 'cross-platform slow files do not execute serially on one VM');
  assert.deepEqual(plan.js, ['tests/a.test.mjs', 'tests/b.test.mjs']);
  assert.deepEqual(plan.lua, ['tests/lua/check.lua']);
  assert.equal(plan.estimateMs, 180000);
  assert.deepEqual(plan.estimateByPlatformMs, { win32: 180000, linux: 180000 });
  for (const platform of ['win32', 'linux']) {
    const over = structuredClone(weights);
    over.js[platform]['tests/a.test.mjs']++;
    const full = impact(changed, input, event, over);
    assert.equal(full.mode, 'full', `${platform} alone exceeding budget must reject Fast`);
    assert.equal(full.estimateByPlatformMs[platform], 180001);
    assert.equal(full.estimateMs, 180001);
  }
  assert.equal(impact([...changed, 'unknown'], input, event, weights).mode, 'full');
  assert.equal(impact([...changed, 'src/lua/abyss_combat.lua'], input, event, weights).mode, 'full');
});
test('actual required gate commands reject every missing, failed, cancelled or skipped selected execution', () => {
  const workflow = readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n');
  const shell = process.platform === 'win32' ? `${process.env.ProgramFiles}/Git/bin/bash.exe` : '/bin/bash';
  for (const job of ['check', 'engineering-posix']) {
    const body = (workflow + '\n  end:\n').match(new RegExp(`^  ${job}:\\n([\\s\\S]*?)(?=^  [\\w-]+:)`, 'm'))[1];
    const command = body.split('        run: |\n')[1].trim().replaceAll('${{ needs.impact.result }}', '$PLAN').replaceAll('${{ needs.impact.outputs.mode }}', '$MODE').replaceAll('${{ needs.fast.result }}', '$FAST');
    for (const mode of ['full', 'fast', '']) for (const result of ['success', 'failure', 'cancelled', 'skipped', '']) {
      const r = spawnSync(shell, ['-e', '-c', command], { env: { ...process.env, PLAN: 'success', MODE: mode, FAST: result, RULES_RESULT: result, ENGINEERING_RESULT: result }, encoding: 'utf8' });
      assert.ifError(r.error);
      assert.equal(r.status === 0, mode !== '' && result === 'success', `${job}/${mode}/${result}: ${r.stderr}`);
    }
    for (const status of ['failure', 'cancelled', 'skipped', '']) for (const mode of ['fast', 'full']) {
      const r = spawnSync(shell, ['-e', '-c', command], { env: { ...process.env, PLAN: status, MODE: mode, FAST: 'success', RULES_RESULT: 'success', ENGINEERING_RESULT: 'success' }, encoding: 'utf8' });
      assert.ifError(r.error);
      assert.notEqual(r.status, 0, `${job}/${mode} cannot accept ${status || 'missing'} plan`);
    }
    assert.match(body, /if: always\(\)/);
  }
});
