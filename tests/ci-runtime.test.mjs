import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, mkdtempSync, mkdirSync, writeFileSync, copyFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { originalLuaRunner } from './helpers/ci-lua-runner-inverse.mjs';
import {readBeforeMobileQaSource} from './helpers/mobile-qa-source-inverse.mjs';
import { partition, jsShard, discoverJs, timings } from '../scripts/ci-shards.mjs';
import { shardLuaScripts } from '../scripts/test-lua.mjs';

test('scheduler inverse preserves the frozen runner for LF/CRLF and rejects unrelated changes', () => {
  const source = readBeforeMobileQaSource('scripts/test-lua.mjs').replaceAll('\r\n', '\n');
  const sha = text => createHash('sha256').update(text).digest('hex');
  const original = '63ec149511d52b9e362f2c9210d092e4d97bd815c5b8c16e7009ade146d5d55b';
  for (const text of [source, source.replaceAll('\n', '\r\n')]) assert.equal(sha(originalLuaRunner(text)), original);
  const live=readFileSync('scripts/test-lua.mjs','utf8').replaceAll('\r\n','\n');
  assert.equal(sha(originalLuaRunner(live)),original,'the complete current runner traverses the exact historical layer');
  for(const drift of [live+'\n-- unrelated drift\n',live.replace('60000 : 30000','60000 : 60000')]){
    assert.notEqual(drift,live);
    assert.throws(()=>originalLuaRunner(drift),/exact original-deadline historical fixture dispatch/);
  }
  const changedDeadline = source.replace('60000 : 30000', '60000 : 60000');
  assert.notEqual(changedDeadline, source);
  assert.notEqual(sha(originalLuaRunner(changedDeadline)), original);
  const changedProcess = source.replace('maxBuffer: 1024 * 1024', 'maxBuffer: 1');
  assert.notEqual(changedProcess, source);
  assert.notEqual(sha(originalLuaRunner(changedProcess)), original);
  const changedSchedule = source.replace('return partition(scripts, value, weights, luaSchedulingWeight(timings.unknownLuaMs, workers), initial?.map(load => load * workers)).files;', 'return [];');
  assert.notEqual(changedSchedule, source);
  assert.throws(() => originalLuaRunner(changedSchedule), /exact reviewed scheduler/);
  const changedWorkers = source.replace('workers === 2 && scripts.length', 'workers === 3 && scripts.length');
  assert.notEqual(changedWorkers, source);
  assert.throws(() => originalLuaRunner(changedWorkers), /exact reviewed worker wiring/);
});

test('weighted scheduling balances unequal files deterministically and rejects unsafe inputs', () => {
  const files = ['a', 'b', 'c', 'd'], weights = { a: 100, b: 80, c: 20, d: 10 };
  assert.deepEqual(partition(files, '1/2', weights, 1).loads, [110, 100]);
  assert.deepEqual(partition(files, '1/2', weights, 1), partition([...files].reverse(), '1/2', weights, 1));
  for (const shard of ['', '0/2', '3/2', '01/2', '1/65', '1/2/3']) assert.throws(() => partition(files, shard, weights, 1));
  assert.throws(() => partition(['a', 'a'], '1/2', weights, 1));
  for (const weight of [0, -1, NaN, Infinity]) assert.throws(() => partition(['a'], '1/2', { a: weight }, 1));
  assert.throws(() => partition(files, '1/2', weights, 1, [NaN, 0]));
});

test('platform gates reserve measured time only for the corresponding complete hosted matrix', () => {
  for (const [platform, count] of [['win32', 8], ['linux', 5]]) {
    const initial = timings.initialMs[platform];
    assert.equal(initial.length, count);
    assert.ok(initial[0] > 0);
    assert.ok(initial.slice(1).every(value => value === 0));
    assert.deepEqual(jsShard([], `1/${count}`, platform).loads, initial);
    assert.deepEqual(jsShard([], '1/1', platform).loads, [0], 'local serial diagnostics do not inherit hosted matrix offsets');
  }
});

test('all current JS and Lua files are scheduled exactly once; new unmeasured files cannot disappear', () => {
  const js = discoverJs(), lua = readdirSync('tests/lua').filter(f => f.endsWith('.lua')).map(f => `tests/lua/${f}`);
  for (const [files, count, select] of [
    [js, 8, (files, value) => jsShard(files, value, 'win32').files],
    [js, 5, (files, value) => jsShard(files, value, 'linux').files],
    [lua, 8, shardLuaScripts], [lua, 1, shardLuaScripts],
  ]) {
    const input = [...files, 'tests/unmeasured-new-file'];
    const slices = Array.from({ length: count }, (_, i) => select(input, `${i + 1}/${count}`));
    const union = slices.flat();
    assert.equal(new Set(union).size, union.length);
    assert.deepEqual(union.sort(), input.sort());
  }
  for (const [platform, count] of [['win32', 8], ['linux', 5]]) {
    const loads = jsShard(js, `1/${count}`, platform).loads;
    const weights = timings.js[platform];
    const old = Array(count).fill(0);
    [...js].sort().forEach((file, i) => old[i % count] += weights[file] ?? timings.unknownJsMs);
    assert.ok(Math.max(...loads) < Math.max(...old), `${platform}: weighted schedule must improve measured critical path`);
  }
});

test('workflow uses the same balanced plan for materialization and execution without changing concurrency', () => {
  const workflow = readFileSync('.github/workflows/quality.yml', 'utf8');
  assert.ok(workflow.includes("--workers ${{ inputs.runner_pool == 'local-special' && 1 || 2 }}"));
  assert.equal((workflow.match(/node scripts\/ci-shards.mjs --prepare=/g) ?? []).length, 2);
  assert.equal((workflow.match(/node scripts\/ci-shards.mjs --shard=/g) ?? []).length, 2);
  const source = readFileSync('scripts/ci-shards.mjs', 'utf8');
  assert.match(source, /plan.files.includes\('tests\/reviewed-traveler-geo-assets.test.mjs'\)/);
  assert.match(source, /--test-concurrency=1/);
  assert.doesNotMatch(source, /--test-name-pattern|--test-skip-pattern|--test-timeout/);
});

test('real executor preserves test failure, continues later files, reports timings and includes added files', t => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-ci-runtime-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const dir of ['tests', 'scripts', 'build']) mkdirSync(join(root, dir));
  copyFileSync('scripts/ci-timing-reporter.mjs', join(root, 'scripts/ci-timing-reporter.mjs'));
  for (const [file, body] of [['a', "throw new Error('expected failure')"], ['b', "console.log('later-file-ran')"]]) {
    writeFileSync(join(root, `tests/${file}.test.mjs`), `import test from 'node:test';test('${file}',()=>{${body}});`);
  }
  const env = { ...process.env }; delete env.NODE_TEST_CONTEXT;
  const result = spawnSync(process.execPath, [resolve('scripts/ci-shards.mjs'), '--shard=1/1'], {
    cwd: root, env, encoding: 'utf8', windowsHide: true, timeout: 30000,
  });
  assert.ifError(result.error);
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /expected failure/);
  assert.match(result.stdout, /later-file-ran/);
  const records = readFileSync(join(root, 'build/ci-js-timings.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  assert.deepEqual(records.map(record => record.file).sort(), ['tests/a.test.mjs', 'tests/b.test.mjs']);
  assert.ok(records.every(record => Number.isFinite(record.durationMs) && record.durationMs > 0));
});


test('current timing records preserve all measured corrections without duplicate JSON keys',()=>{
 const raw=readFileSync('scripts/ci-test-timings.json','utf8');
 assert.equal((raw.match(/^  "jsCorrections":/gm)||[]).length,1,'one unambiguous correction inventory');
 assert.equal(timings.jsCorrections.length,3);
 for(const entry of timings.jsCorrections){
  assert.equal(timings.js[entry.platform][entry.file],Math.ceil(entry.durationMs),'measured conservative weight: '+entry.file);
  assert.ok(Number.isSafeInteger(entry.runId)&&Number.isSafeInteger(entry.jobId));
  assert.match(entry.headSha,/^[a-f0-9]{40}$/);
 }
 assert.equal(createHash('sha256').update(JSON.stringify(timings.js.linux)).digest('hex'),'3fdcb1aa1e50352a164eb3ebde77f0a01ac4b0ad76b1302939021ae7d76d8755','current accepted Linux weights remain exact');
});

test('fresh relic base retains its complete accepted scheduling measurements', () => {
  assert.equal(createHash('sha256').update(preIntegrationSource('scripts/ci-test-timings.json',readFileSync('scripts/ci-test-timings.json','utf8')).replaceAll('\r\n','\n')).digest('hex'),
    '4039efc1bc954f541bcacac619550daa1231a4b3894ebe6568697d2f10af7ad8', 'exact acb09e46 scheduling contract; no obsolete PR366 correction reapplied');
});
