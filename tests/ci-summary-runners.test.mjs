import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { originalWorkflow } from './helpers/ci-runtime-workflow.mjs';

const workflow = readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n');
const job = name => workflow.match(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:|(?![\\s\\S]))`, 'm'))[1];
const digest = text => createHash('sha256').update(text).digest('hex');

test('only the two short required summaries use the slim hosted container', () => {
  assert.equal((workflow.match(/^    runs-on: ubuntu-slim$/gm) ?? []).length, 2);
  for (const name of ['check', 'engineering-posix']) {
    const body = job(name);
    assert.match(body, /^    runs-on: ubuntu-slim$/m);
    assert.match(body, /^    timeout-minutes: 2$/m);
    assert.match(body, /^    if: always\(\)$/m);
    assert.doesNotMatch(body, /uses:|continue-on-error:|permissions:|^    name:/m);
  }
  assert.match(job('check'), /^    needs: \[impact, rules, fast\]$/m);
  assert.match(job('engineering-posix'), /^    needs: \[impact, engineering-posix-shards, fast\]$/m);
  assert.match(job('presentation'), /^    runs-on: ubuntu-24\.04$/m);
  assert.match(job('engineering-posix-shards'), /^    runs-on: ubuntu-24\.04$/m);
  assert.match(job('rules'), /\|\| 'windows-2025'/);
});

test('reviewed summary runner inverse retains the original complete workflow contract', () => {
  const expected = 'd44ae4e29ef74a972f329ecdc8f8131c464d30196300a600387479945660d35d';
  assert.equal(digest(originalWorkflow(workflow)), expected);
  assert.equal(digest(originalWorkflow(workflow.replaceAll('\n', '\r\n').replaceAll('\r\n', '\n'))), expected);
  for (const name of ['check', 'engineering-posix']) {
    const body = job(name);
    for (const changed of [
      body.replace('    timeout-minutes: 2', '    timeout-minutes: 3'),
      body.replace('    steps:\n', '    steps:\n      - run: echo unreviewed\n'),
      body.replace('    if: always()', '    if: success()'),
      body.replace('    runs-on: ubuntu-slim', '    runs-on: ubuntu-24.04'),
      body.replace('    runs-on: ubuntu-slim', '    runs-on: ubuntu-slim\n    runs-on: ubuntu-slim'),
    ]) {
      const drift = workflow.replace(body, changed);
      let rejected = false;
      try { rejected = digest(originalWorkflow(drift)) !== expected; }
      catch { rejected = true; }
      assert.equal(rejected, true, `${name} must not hide unrelated summary changes`);
    }
  }
});
