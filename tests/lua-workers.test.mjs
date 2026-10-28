import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { runLuaWorkers } from '../scripts/lua-workers.mjs';

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-lua-workers-'));
  t.after(() => {
    assert.equal(dirname(resolve(root)), resolve(tmpdir()));
    assert.match(basename(root), /^abyss-lua-workers-/);
    rmSync(root, { recursive: true, force: true });
  });
  const cli = join(root, 'wrapper.mjs');
  writeFileSync(cli, `
import { appendFileSync, readFileSync } from 'node:fs';
const name = process.argv[2];
const event = kind => appendFileSync('events.jsonl', JSON.stringify({ kind, name, pid: process.pid, context: process.env.NODE_TEST_CONTEXT ?? null }) + '\\n');
event('start');
if (name.startsWith('overflow-')) { process[name.slice(9)].write(Buffer.alloc(4 * 1024 * 1024 + 65536, 120)); setInterval(() => {}, 100); }
else {
  process.stdout.write('stdout-start:' + name + '\\n');
  process.stderr.write('stderr-start:' + name + '\\n');
  if (name.startsWith('pair-')) {
    const started = Date.now();
    while (readFileSync('events.jsonl', 'utf8').trim().split('\\n').map(JSON.parse).filter(e => e.kind === 'start').length < 2) {
      if (Date.now() - started > 5000) throw new Error('Second worker never overlapped');
      await new Promise(resolve => setTimeout(resolve, 5));
    }
  }
  await new Promise(resolve => setTimeout(resolve, 30));
  process.stdout.write('stdout-end:' + name + '\\n');
  process.stderr.write('stderr-end:' + name + '\\n');
  event('end');
  if (name === 'signal') process.kill(process.pid, 'SIGTERM');
  else if (name === 'fail') process.exitCode = 7;
}
`);
  return { root, cli, events: () => readFileSync(join(root, 'events.jsonl'), 'utf8').trim().split('\n').map(JSON.parse) };
}

test('two fresh workers overlap, never exceed two and deliver complete stdout/stderr without interleaving', async t => {
  const f = fixture(t), outputs = [], scripts = ['later', 'pair-b', 'pair-a', 'last'];
  const result = await runLuaWorkers(scripts, { cli: f.cli, cwd: f.root,
    weights: { 'pair-a': 400, 'pair-b': 300, later: 200, last: 100 },
    onOutput: (stdout, stderr) => outputs.push({ stdout, stderr }) });
  assert.equal(result, 0);
  const events = f.events(), starts = events.filter(e => e.kind === 'start');
  assert.deepEqual(starts.slice(0, 2).map(e => e.name).sort(), ['pair-a', 'pair-b']);
  assert.deepEqual(starts.map(e => e.name).sort(), [...scripts].sort());
  assert.equal(new Set(starts.map(e => e.pid)).size, scripts.length);
  assert.ok(starts.every(e => e.context === null));
  let active = 0, maximum = 0;
  for (const event of events) { active += event.kind === 'start' ? 1 : -1; maximum = Math.max(maximum, active); }
  assert.equal(active, 0); assert.equal(maximum, 2);
  assert.equal(outputs.length, scripts.length);
  for (const name of scripts) {
    const output = outputs.find(value => value.stdout === `stdout-start:${name}\nstdout-end:${name}\n`);
    assert.ok(output, name);
    assert.equal(output.stderr, `stderr-start:${name}\nstderr-end:${name}\n`);
  }
  assert.deepEqual(scripts, ['later', 'pair-b', 'pair-a', 'last']);
});

test('a single worker uses measured longest-first order and continues after exit failure and signal', async t => {
  const f = fixture(t), outputs = [];
  const result = await runLuaWorkers(['success', 'fail', 'signal'], { cli: f.cli, cwd: f.root, workers: 1,
    weights: { fail: 30000, signal: 20000 }, onOutput: (stdout, stderr) => outputs.push({ stdout, stderr }) });
  assert.equal(result, 1);
  const events = f.events();
  assert.deepEqual(events.map(e => `${e.kind}:${e.name}`), ['start:fail', 'end:fail', 'start:signal', 'end:signal', 'start:success', 'end:success']);
  assert.equal(outputs.length, 3);
  assert.ok(outputs.some(output => output.stdout.includes('stdout-end:success')));
});

test('spawn errors fail the aggregate and still visit every requested fixture', async t => {
  const f = fixture(t), outputs = [];
  assert.equal(await runLuaWorkers(['one', 'two', 'three'], { cli: f.cli, cwd: join(f.root, 'missing'),
    onOutput: (stdout, stderr) => outputs.push({ stdout, stderr }) }), 1);
  assert.equal(outputs.length, 3);
  for (const name of ['one', 'two', 'three']) assert.ok(outputs.some(output => output.stderr.includes(`could not run ${name}:`)));
});

test('overflow terminates the child, bounds captured output and continues to the next fixture', async t => {
  const f = fixture(t), outputs = [];
  assert.equal(await runLuaWorkers(['overflow-stdout', 'overflow-stderr', 'success'], { cli: f.cli, cwd: f.root, workers: 1,
    weights: { 'overflow-stdout': 30000, 'overflow-stderr': 20000 }, onOutput: (stdout, stderr) => outputs.push({ stdout, stderr }) }), 1);
  assert.equal(outputs.length, 3);
  assert.ok(outputs[0].stdout.length <= 4 * 1024 * 1024);
  assert.match(outputs[0].stderr, /output exceeded 4194304 bytes \(overflow-stdout, stdout\)/);
  assert.ok(outputs[1].stderr.length <= 4 * 1024 * 1024 + 200);
  assert.match(outputs[1].stderr, /output exceeded 4194304 bytes \(overflow-stderr, stderr\)/);
  assert.match(outputs[2].stdout, /stdout-end:success/);
});

test('invalid worker counts, fixture identities and weights are rejected before spawning', async () => {
  for (const scripts of [undefined, [], [''], ['  '], ['a', 'a'], [1]])
    await assert.rejects(runLuaWorkers(scripts, { cli: 'unused.mjs' }), /unique nonempty/);
  for (const workers of [0, 3, -1, 1.5, NaN, '2'])
    await assert.rejects(runLuaWorkers(['a'], { cli: 'unused.mjs', workers }), /integer from 1 to 2/);
  for (const value of [0, -1, NaN, Infinity, '10'])
    await assert.rejects(runLuaWorkers(['a'], { cli: 'unused.mjs', weights: { a: value } }), /positive finite/);
  await assert.rejects(runLuaWorkers(['a']), /CLI path/);
  await assert.rejects(runLuaWorkers(['a'], { cli: 'unused.mjs', onOutput: true }), /callback/);
});
