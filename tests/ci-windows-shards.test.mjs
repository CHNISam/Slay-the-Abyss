import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { shardLuaScripts } from '../scripts/test-lua.mjs';

const workflow = readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n');
const job = name => (workflow + '\n  end-of-workflow:\n')
  .match(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:)`, 'm'))?.[1];

test('eight Windows VMs change only the hosted matrix, preserving every gate and original deadline', () => {
  const rules = job('rules');
  assert.match(rules, /shard: \$\{\{ fromJSON\(inputs.runner_pool == 'local-special' && '\[1\]' \|\| '\[1,2,3,4,5,6,7,8\]'\) \}\}/);
  assert.match(rules, /^      fail-fast: false$/m);
  assert.match(rules, /^    timeout-minutes: \$\{\{ inputs.runner_pool == 'local-special' && 75 \|\| 30 \}\}$/m);
  assert.match(rules, /node --test --test-concurrency=1 --test-shard=\$\{\{ matrix.shard \}\}\/\$\{\{ strategy.job-total \}\} tests\/\*\.test\.mjs/);
  assert.match(rules, /node scripts\/test-lua.mjs --shard \$\{\{ matrix.shard \}\}\/\$\{\{ strategy.job-total \}\}/);
  // Restore the single matrix edit to the full workflow in Git 9226012.
  // This also freezes the existing hosted isolation, gate commands, toolchain,
  // strict aggregates and POSIX shards, rather than permitting hidden omissions.
  const restored = workflow.replace("'[1,2,3,4,5,6,7,8]'", "'[1,2,3,4]'");
  assert.notEqual(restored, workflow);
  assert.equal(createHash('sha256').update(restored).digest('hex'), '3a45b50a847b89870825560a6f3d83906a2a02a062c9dc5b2469e7d0439b15f0');
});

test('the real Lua partitioner retains every discovered raw fixture exactly once across eight VMs', () => {
  const files = readdirSync('tests/lua').filter(name => name.endsWith('.lua')).sort().map(name => `tests/lua/${name}`);
  assert.ok(files.length > 0);
  const selected = Array.from({ length: 8 }, (_, index) => shardLuaScripts(files, `${index + 1}/8`));
  assert.ok(selected.every(slice => slice.length > 0));
  const combined = selected.flat();
  assert.equal(new Set(combined).size, combined.length, 'no raw fixture is duplicated');
  assert.deepEqual(combined.sort(), files, 'all raw fixtures, including the previous uncompleted tails, remain selected');
});

test('required check aggregate rejects every non-success shard result', () => {
  const check = job('check');
  assert.match(check, /^    needs: rules$/m);
  assert.match(check, /^    if: always\(\)$/m);
  assert.match(check, /^          RULES_RESULT: \$\{\{ needs.rules.result \}\}$/m);
  assert.doesNotMatch(check, /continue-on-error:|\|\| true/);
  const command = check.match(/^        run: (.+)$/m)?.[1];
  assert.equal(command, 'test "$RULES_RESULT" = success');
  const shell = process.platform === 'win32' ? join(process.env.ProgramFiles, 'Git', 'bin', 'bash.exe') : '/bin/sh';
  for (const result of [undefined, '', 'skipped', 'cancelled', 'failure', 'timed_out', 'success']) {
    const env = { ...process.env };
    delete env.RULES_RESULT;
    if (result !== undefined) env.RULES_RESULT = result;
    const actual = spawnSync(shell, ['-c', command], { env, encoding: 'utf8', windowsHide: true, timeout: 30000 });
    assert.ifError(actual.error);
    assert.equal(actual.status === 0, result === 'success', `aggregate result ${String(result)}: ${actual.stderr}`);
  }
});

test('native Node eight-shard selection executes every current JS file name exactly once', t => {
  const files = readdirSync('tests').filter(name => name.endsWith('.test.mjs')).sort();
  assert.ok(files.length > 0);
  const root = mkdtempSync(join(tmpdir(), 'abyss-windows-shards-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  // Run name-only probes through Node's actual CLI selector; game assertions
  // stay in the unchanged real test bodies executed by their selected VM.
  for (const name of files) writeFileSync(join(root, name), `import test from 'node:test'; test(${JSON.stringify(name)}, () => {});\n`);
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT; // An independent CLI, as in each hosted VM.
  const seen = [];
  for (let shard = 1; shard <= 8; shard++) {
    const result = spawnSync(process.execPath, ['--test', '--test-concurrency=1', `--test-shard=${shard}/8`, '--test-reporter=tap', ...files.map(name => join(root, name))], {
      env, encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 2 * 1024 * 1024,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    const selected = [...result.stdout.matchAll(/^# Subtest: ([^\r\n]+)$/gm)].map(match => match[1]);
    assert.ok(selected.length > 0 && selected.length < files.length, `shard ${shard} must contain a proper subset`);
    seen.push(...selected);
  }
  assert.equal(new Set(seen).size, seen.length, 'no JS file is duplicated');
  assert.deepEqual(seen.sort(), files, 'all current tests/*.test.mjs names execute once');
});
