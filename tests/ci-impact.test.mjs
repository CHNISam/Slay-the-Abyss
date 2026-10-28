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
    assert.match(body, /if: always\(\)/);
  }
});
