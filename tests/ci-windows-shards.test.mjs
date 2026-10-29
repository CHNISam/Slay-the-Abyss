import { nativeShardProbe } from './helpers/native-shard-probe.mjs';
import { originalWorkflow } from './helpers/ci-runtime-workflow.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { shardLuaScripts } from '../scripts/test-lua.mjs';

const workflow = originalWorkflow(readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n'));
const job = (name, source = workflow) => (source + '\n  end-of-workflow:\n')
  .match(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:)`, 'm'))?.[1];

const lfsShardStep = `      - name: Materialize reviewed PNGs for this shard\n        timeout-minutes: 2\n        env:\n          CI_LFS_TOKEN: \${{ github.token }}\n        run: node scripts/ci-reviewed-lfs.mjs --shard=\${{ matrix.shard }}/\${{ strategy.job-total }}\n`;

test('eight Windows VMs change only the hosted matrix, preserving every gate and original deadline', () => {
  const rules = job('rules');
  assert.match(rules, /shard: \$\{\{ fromJSON\(inputs.runner_pool == 'local-special' && '\[1\]' \|\| '\[1,2,3,4,5,6,7,8\]'\) \}\}/);
  assert.match(rules, /^      fail-fast: false$/m);
  assert.match(rules, /^    timeout-minutes: \$\{\{ inputs.runner_pool == 'local-special' && 75 \|\| 30 \}\}$/m);
  assert.match(rules, /node --test --test-concurrency=1 --test-shard=\$\{\{ matrix.shard \}\}\/\$\{\{ strategy.job-total \}\} tests\/\*\.test\.mjs/);
  assert.match(rules, /node scripts\/test-lua.mjs --shard \$\{\{ matrix.shard \}\}\/\$\{\{ strategy.job-total \}\}/);
  // Restore the Windows matrix edit and the reviewed POSIX 2 -> 4 partition
  // to the full workflow in Git 9226012. The original hash stays unchanged.
  // This also freezes the existing hosted isolation, gate commands, toolchain,
  // strict aggregates and POSIX shards, rather than permitting hidden omissions.
  const restore = source => {
    // Remove only the exact reviewed-PNG additions at their intended positions.
    // The separate LFS contract tests reject altered permissions, scope and ordering.
    const beforeLfs = source
      .replace(lfsShardStep + '      - name: JavaScript regression shard\n', '      - name: JavaScript regression shard\n')
      .replace(lfsShardStep + '      - name: POSIX JavaScript regression shard\n', '      - name: POSIX JavaScript regression shard\n')
      .replace("          CI_REPOSITORY: ${{ github.repository }}\n          GIT_LFS_SKIP_SMUDGE: '1'\n        run:", "          CI_REPOSITORY: ${{ github.repository }}\n        run:");
    const posix = job('engineering-posix-shards', beforeLfs);
    assert.equal((posix?.match(/^        shard: \[1, 2, 3, 4\]$/gm) ?? []).length, 1,
      'only the single reviewed POSIX matrix may be inverted');
    return beforeLfs.replace("'[1,2,3,4,5,6,7,8]'", "'[1,2,3,4]'")
      .replace(posix, posix.replace('        shard: [1, 2, 3, 4]', '        shard: [1, 2]'));
  };
  const expandGates = source => source.replace('# One shard runs the non-test gates;', '# Every shard runs the same non-test gates;').replace(/(      - run: npm run (?:check:network|verify:backlog|check:syntax|validate:data|build:theme|check:engineering)\n)        if: matrix.shard == 1\n/g, '$1')
    .replace(/(      - uses: actions\/upload-artifact@[^\n]+\n)        if: matrix.shard == 1\n(        with:\n          name: engineering-)/g, '$1$2');
  for (const gate of ['check:network', 'verify:backlog', 'check:syntax', 'validate:data', 'build:theme', 'check:engineering']) {
    assert.ok(rules.includes(`      - run: npm run ${gate}\n        if: matrix.shard == 1\n`), `${gate} must run on Windows shard 1`);
  }
  const restored = restore(expandGates(workflow));
  assert.notEqual(restored, workflow);
  assert.equal(createHash('sha256').update(restored).digest('hex'), '3a45b50a847b89870825560a6f3d83906a2a02a062c9dc5b2469e7d0439b15f0');
  assert.throws(() => restore(workflow.replace('        shard: [1, 2, 3, 4]', '        shard: [1, 2, 3]')),
    /single reviewed POSIX matrix/);
  assert.throws(() => restore(workflow.replace('        shard: [1, 2, 3, 4]', '        shard: [1, 2, 3, 4]\n        shard: [1, 2, 3, 4]')),
    /single reviewed POSIX matrix/);
  const missingGate = restore(expandGates(workflow.replace('      - run: npm run check:engineering', '      - run: echo omitted')));
  assert.notEqual(createHash('sha256').update(missingGate).digest('hex'), createHash('sha256').update(restored).digest('hex'),
    'the precise partition inverse cannot hide unrelated workflow edits');
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
  // Run name-only probes through Node's actual CLI selector. These empty
  // synthetic modules share no state, so avoid hundreds of empty child starts;
  // production game tests retain the unchanged per-file process isolation.
  for (const name of files) writeFileSync(join(root, name), `import test from 'node:test'; test(${JSON.stringify(name)}, () => {});\n`);
  const seen = [];
  for (let shard = 1; shard <= 8; shard++) {
    const result = nativeShardProbe(root, shard, 8);
    assert.deepEqual(result.command.filter(arg => arg.endsWith('.test.mjs')), ['*.test.mjs'],
      'native probe argv must retain one relative basename pattern, never an absolute root or filename inventory');
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    const selected = [...result.stdout.matchAll(/^# Subtest: ([^\r\n]+)$/gm)].map(match => match[1]);
    assert.ok(selected.length > 0 && selected.length < files.length, `shard ${shard} must contain a proper subset`);
    seen.push(...selected);
  }
  assert.equal(new Set(seen).size, seen.length, 'no JS file is duplicated');
  assert.deepEqual(seen.sort(), files, 'all current tests/*.test.mjs names execute once');
});

test('native shard probe command stays bounded while a large filename inventory executes exactly once', t => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-shard-probe-bound-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const files = Array.from({ length: 512 }, (_, index) =>
    `probe-${String(index).padStart(4, '0')}-spaces [literal]-中文-${'x'.repeat(80)}.test.mjs`);
  const writeProbe = name => writeFileSync(join(root, name), `import test from 'node:test'; test(${JSON.stringify(name)}, () => {});\n`);
  files.slice(0, 16).forEach(writeProbe);
  const small = nativeShardProbe(root, 1, 8);
  assert.ifError(small.error);
  assert.equal(small.status, 0, small.stderr + small.stdout);
  files.slice(16).forEach(writeProbe);
  // This inventory alone exceeds Windows' command-line limit even before
  // absolute directory prefixes or quoting are added to individual paths.
  assert.ok(files.join(' ').length > 32767);
  const seen = [];
  for (let shard = 1; shard <= 8; shard++) {
    const result = nativeShardProbe(root, shard, 8);
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.ok(result.command.join(' ').length < 1024, 'the emitted native command must not carry the filename inventory');
    if (shard === 1) assert.deepEqual(result.command, small.command, 'growing the inventory cannot grow or change argv');
    const selected = [...result.stdout.matchAll(/^# Subtest: ([^\r\n]+)$/gm)].map(match => match[1]);
    assert.ok(selected.length > 0 && selected.length < files.length, `shard ${shard} must contain a proper subset`);
    seen.push(...selected);
  }
  assert.equal(new Set(seen).size, seen.length, 'no large-inventory filename executes twice');
  assert.deepEqual(seen.sort(), files, 'all long filenames, including spaces and literal brackets, execute once');
});
