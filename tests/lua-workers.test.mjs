import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { runLuaWorkers, canOverlapLuaFixture } from '../scripts/lua-workers.mjs';

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
    while (readFileSync('events.jsonl', 'utf8').trim().split('\\n').map(JSON.parse).filter(e => e.kind === 'start' && e.name.startsWith('pair-')).length < 2) {
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

test('unsafe and unknown fixtures run alone before the safe pool, preserving coverage and failure continuation', async t => {
  const f = fixture(t), outputs = [], scripts = ['pair-b', 'unknown', 'heavy', 'fail', 'pair-a'];
  assert.equal(await runLuaWorkers(scripts, { cli: f.cli, cwd: f.root,
    weights: { heavy: 30000, fail: 15000, 'pair-a': 500, 'pair-b': 400 },
    onOutput: (stdout, stderr) => outputs.push({ stdout, stderr }) }), 1);
  const events = f.events();
  assert.deepEqual(events.slice(0, 6).map(event => `${event.kind}:${event.name}`),
    ['start:heavy', 'end:heavy', 'start:fail', 'end:fail', 'start:unknown', 'end:unknown']);
  let active = 0, maximum = 0;
  for (const event of events) {
    active += event.kind === 'start' ? 1 : -1;
    maximum = Math.max(maximum, active);
    if (!event.name.startsWith('pair-')) assert.equal(active, event.kind === 'start' ? 1 : 0);
  }
  assert.equal(active, 0); assert.equal(maximum, 2);
  assert.deepEqual(events.filter(event => event.kind === 'start').map(event => event.name).sort(), [...scripts].sort());
  assert.equal(outputs.length, scripts.length);
  for (const name of scripts) assert.ok(outputs.some(output => output.stdout === `stdout-start:${name}\nstdout-end:${name}\n`));
});

test('overlap eligibility uses unchanged fixture budgets with strict threefold headroom and slash normalization', () => {
  const defaultPaths = ['tests/lua/default.lua', 'tests/other/game_ui.lua', '/tmp/other/game_ui.lua',
    'tests/lua/nested/game_ui.lua', 'othertests/lua/game_ui.lua', 'tests/lua/battle_ui_slice_8.lua'];
  const uiPaths = ['tests/lua/battle_ui.lua', 'tests/lua/game_ui.lua',
    ...Array.from({ length: 6 }, (_, index) => `tests/lua/battle_ui_slice_${index + 2}.lua`)];
  const longPaths = ['encounter_coverage', 'map_floor_boundaries', 'map_no_crossings', 'map_treasure_placement'].map(name => `tests/lua/${name}.lua`);
  for (const [paths, limit] of [[defaultPaths, 10000], [uiPaths, 20000], [longPaths, 40000]]) {
    for (const path of paths) {
      assert.equal(canOverlapLuaFixture(path, limit), true, path);
      assert.equal(canOverlapLuaFixture(path, limit + 0.01), false, path);
    }
  }
  assert.equal(canOverlapLuaFixture('C:\\checkout\\tests\\lua\\game_ui.lua', 20000), true);
  assert.equal(canOverlapLuaFixture('/checkout/tests/lua/map_no_crossings.lua', 40000), true);
  for (const invalid of [undefined, null, 0, -1, NaN, Infinity, '1000', true])
    assert.equal(canOverlapLuaFixture('tests/lua/default.lua', invalid), false);
  assert.equal(canOverlapLuaFixture(undefined, 1000), false);
  assert.equal(canOverlapLuaFixture('', 1000), false);
});

test('fixtures that exceeded hosted deadlines are excluded from overlap by their measured serial duration', () => {
  const observed = { silent_final_sources: 25526, shockwave_group: 16809, act2_intent_ui: 16013,
    potion_reward_effects: 13757, node_combat_generation: 13542, silent_natural_build: 29318, encounter_coverage: 110369,
    battle_ui_potion_target_failures: 23996, card_pool: 16443, unknown_event_routing: 28350,
    battle_ui_potion_target_pointers: 27076, unknown_event_routing_upper: 20748, game_ui_class_choices: 19286 };
  for (const [name, measured] of Object.entries(observed))
    assert.equal(canOverlapLuaFixture(`tests/lua/${name}.lua`, measured), false, name);
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
