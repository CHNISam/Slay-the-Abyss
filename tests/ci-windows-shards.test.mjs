import { originalWorkflow } from './helpers/ci-runtime-workflow.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { shardLuaScripts } from '../scripts/test-lua.mjs';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import {qualityShardMatrices} from '../scripts/ci-quality-shape.mjs';

const workflow = readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n');
const job = (name, source = workflow) => (source + '\n  end-of-workflow:\n')
  .match(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:)`, 'm'))?.[1];

const lfsShardStep = `      - name: Materialize reviewed PNGs for this shard\n        timeout-minutes: 2\n        env:\n          CI_LFS_TOKEN: \${{ github.token }}\n        run: node scripts/ci-reviewed-lfs.mjs --shard=\${{ matrix.shard }}/\${{ strategy.job-total }}\n`;

historicalTest('eight Windows VMs change only the original hosted matrix, preserving every original gate and deadline', () => {
  const workflow=originalWorkflow(readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n'));
  const rules = job('rules',workflow);
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

test('the real Lua partitioner retains every discovered raw fixture exactly once across the current Windows shape', () => {
  const files = readdirSync('tests/lua').filter(name => name.endsWith('.lua')).sort().map(name => `tests/lua/${name}`);
  assert.ok(files.length > 0);
  const count=qualityShardMatrices.windows.length;
  const selected = Array.from({ length: count }, (_, index) => shardLuaScripts(files, `${index + 1}/${count}`));
  assert.ok(selected.every(slice => slice.length > 0));
  const combined = selected.flat();
  assert.equal(new Set(combined).size, combined.length, 'no raw fixture is duplicated');
  assert.deepEqual(combined.sort(), files, 'all raw fixtures, including the previous uncompleted tails, remain selected');
});

historicalTest('original required check aggregate rejects every non-success shard result', () => {
  const check = job('check',originalWorkflow(readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n')));
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

test('current Windows matrix consumes the shared thirteen-shard shape without changing protection or execution gates',()=>{
  const rules=job('rules');
  assert.deepEqual(qualityShardMatrices.windows,[1,2,3,4,5,6,7,8,9,10,11,12,13]);
  assert.ok(rules.includes("shard: ${{ fromJSON(inputs.runner_pool == 'local-special' && '[1]' || needs.impact.outputs.windows_shards) }}"));
  assert.ok(rules.includes("if: ${{ needs.impact.outputs.mode == 'full' && !cancelled() && (inputs.runner_pool != 'local-special' || github.event_name == 'workflow_dispatch' && (github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/master')) }}"));
  assert.ok(rules.includes("runs-on: ${{ github.event_name == 'workflow_dispatch' && inputs.runner_pool == 'local-special' && (github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/master') && fromJSON('[\"self-hosted\", \"Windows\", \"X64\", \"slay-the-abyss\"]') || 'windows-2025' }}"));
  assert.match(workflow,/^permissions:\n  contents: read$/m);
  assert.match(rules,/node-version: '24\.18\.0'/);
  assert.ok(rules.includes('Pillow==12.3.0'));
  assert.ok(rules.includes('npm run setup:lua-static'));
  assert.match(rules,/^      fail-fast: false$/m);
  assert.ok(rules.includes("timeout-minutes: ${{ inputs.runner_pool == 'local-special' && 75 || 30 }}"));
  for(const gate of ['check:network','verify:backlog','check:syntax','validate:data','build:theme','check:engineering'])
    assert.ok(rules.includes(`      - run: npm run ${gate}\n        if: matrix.shard == 1\n`),gate);
  for(const command of ['node scripts/ci-shards.mjs --prepare=','node scripts/ci-shards.mjs --shard='])
    assert.ok(rules.includes(command+'${{ matrix.shard }}/${{ strategy.job-total }}'));
  assert.ok(rules.includes("node scripts/test-lua.mjs --shard ${{ matrix.shard }}/${{ strategy.job-total }} --workers ${{ inputs.runner_pool == 'local-special' && 1 || 2 }}"));
  assert.match(job('check'),/^    needs: \[impact, rules, fast\]\n    if: always\(\)$/m);
  assert.doesNotMatch(rules,/continue-on-error:|--test-name-pattern|--test-skip-pattern/);
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
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT; // An independent CLI, as in each hosted VM.
  const seen = [];
  for (let shard = 1; shard <= 8; shard++) {
    // Repeating the temporary root for every file exceeds Windows' argv limit.
    const args = ['--test', '--test-isolation=none', '--test-concurrency=1', `--test-shard=${shard}/8`, '--test-reporter=tap', ...files];
    assert.deepEqual(args.filter(arg => arg.endsWith('.test.mjs')), files, 'native probe argv must retain sorted basenames');
    const result = spawnSync(process.execPath, args, {
      cwd: root, env, encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 2 * 1024 * 1024,
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
