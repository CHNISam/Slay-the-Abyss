import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { originalWorkflow } from './helpers/ci-runtime-workflow.mjs';
import { beforePlatformWorkflow } from './helpers/platform-load-wiring.mjs';

const workflow = readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n');
const job = (name,source=workflow) => source.match(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:|(?![\\s\\S]))`, 'm'))[1];
const digest = text => createHash('sha256').update(text).digest('hex');

test('only the lightweight impact planner and two required summaries use slim', () => {
  assert.equal((workflow.match(/^    runs-on: ubuntu-slim$/gm) ?? []).length, 3);
  const impact = job('impact');
  assert.match(impact, /^    runs-on: ubuntu-slim$/m);
  assert.match(impact, /^    timeout-minutes: 3$/m);
  assert.match(impact, /node-version: '24\.18\.0'/);
  assert.match(impact, /npm ci --ignore-scripts/);
  assert.match(impact, /run: npm run check:guidance/);
  assert.match(impact, /run: node scripts\/ci-impact\.mjs/);
  assert.doesNotMatch(impact, /^    needs:|^    if:|continue-on-error:|permissions:/m);
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

historicalTest('reviewed summary runner inverse retains the original complete workflow contract', () => {
  const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
  const expected = 'd44ae4e29ef74a972f329ecdc8f8131c464d30196300a600387479945660d35d';
  assert.equal(digest(originalWorkflow(workflow)), expected);
  assert.equal(digest(originalWorkflow(workflow.replaceAll('\n', '\r\n').replaceAll('\r\n', '\n'))), expected);
  for (const name of ['impact', 'check', 'engineering-posix']) {
    const body = job(name,workflow);
    const timeout = name === 'impact' ? 3 : 2;
    for (const changed of [
      body.replace(`    timeout-minutes: ${timeout}`, `    timeout-minutes: ${timeout + 1}`),
      body.replace('    steps:\n', '    steps:\n      - run: echo unreviewed\n'),
      name === 'impact' ? body.replace('    outputs:', '    if: success()\n    outputs:')
        : body.replace('    if: always()', '    if: success()'),
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

historicalTest('direct platform projection and layered replay share the same exact runner migration', () => {
  const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
  const historical = workflow.replaceAll('    runs-on: ubuntu-slim\n', '    runs-on: ubuntu-24.04\n');
  const expected = 'c1759c590177f4a2389fa04e700167d0948eae41b9f12e67db4b6bf48f5871ae';
  assert.equal(digest(beforePlatformWorkflow(historical)), expected, 'historical all-VM input remains accepted');
  assert.equal(beforePlatformWorkflow(workflow), beforePlatformWorkflow(historical));
  assert.equal(digest(originalWorkflow(historical)), digest(originalWorkflow(workflow)));
  for (const name of ['impact', 'check', 'engineering-posix']) {
    const body = job(name,workflow);
    for (const changed of [
      body.replace('    runs-on: ubuntu-slim\n', ''),
      body.replace('    runs-on: ubuntu-slim', '    runs-on: ubuntu-24.04'),
      body.replace('    runs-on: ubuntu-slim', '    runs-on: windows-2025'),
      body.replace('    runs-on: ubuntu-slim', '    runs-on: ubuntu-slim\n    runs-on: ubuntu-slim'),
    ]) assert.equal(beforePlatformWorkflow(workflow.replace(body, changed)), null, `${name} malformed or partial migration`);
    assert.equal(beforePlatformWorkflow(workflow.replace(`  ${name}:\n`, `  ${name}:\n${body}  ${name}:\n`)), null, `${name} duplicate job`);
    assert.equal(beforePlatformWorkflow(workflow.replace(`  ${name}:\n${body}`, '')), null, `${name} missing job`);
    const timeout = name === 'impact' ? 3 : 2;
    for (const changed of [
      body.replace(`    timeout-minutes: ${timeout}`, `    timeout-minutes: ${timeout + 1}`),
      body.replace('    steps:\n', '    steps:\n      - run: echo unreviewed\n'),
    ]) assert.notEqual(digest(beforePlatformWorkflow(workflow.replace(body, changed))), expected, `${name} unrelated bytes stay visible`);
  }
  for (const changed of [
    workflow.replace('contents: read', 'contents: write'),
    workflow.replace('    runs-on: ubuntu-24.04', '    runs-on: ubuntu-slim'),
  ]) assert.notEqual(digest(beforePlatformWorkflow(changed)), expected, 'external workflow drift remains visible');
});
