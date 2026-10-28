import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import * as checker from '../scripts/check-syntax.mjs';

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-syntax-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const scripts = join(root, 'scripts'), tests = join(root, 'tests');
  mkdirSync(join(scripts, 'nested'), { recursive: true });
  mkdirSync(tests);
  const files = [join(scripts, 'a.js'), join(scripts, 'nested/b.cjs'), join(tests, 'c.mjs'), join(tests, 'd.js')];
  for (const file of files) writeFileSync(file, 'throw new Error("syntax checks must never execute this");');
  writeFileSync(join(tests, 'ignored.txt'), 'invalid syntax !');
  return { root, directories: [scripts, tests], files };
}

test('CLI recursively checks JS variants without executing them and rejects actual invalid syntax', t => {
  const f = fixture(t), cli = resolve('scripts/check-syntax.mjs');
  const run = () => spawnSync(process.execPath, [cli], { cwd: f.root, encoding: 'utf8', timeout: 30000 });
  assert.equal(run().status, 0);
  writeFileSync(f.files[1], 'const = ;');
  const failed = run();
  assert.notEqual(failed.status, 0);
  assert.match(failed.stderr, /SyntaxError/);
  assert.ok(failed.stderr.includes(f.files[1]));
});

test('two real child processes overlap while every discovered file runs exactly once', async t => {
  assert.equal(typeof checker.checkSyntax, 'function');
  const f = fixture(t), eventsFile = join(f.root, 'events.jsonl');
  const body = `const fs=require('node:fs'); const [events,path]=process.argv.slice(1);
    const emit=kind=>fs.appendFileSync(events,JSON.stringify({kind,path})+'\\n');
    emit('start'); const wait=setInterval(()=>{
      const starts=fs.readFileSync(events,'utf8').trim().split('\\n').map(JSON.parse).filter(e=>e.kind==='start').length;
      if(starts>=2) {clearInterval(wait);emit('end');}
    },10);`;
  await checker.checkSyntax(f.directories, (file, args, options, callback) => {
    assert.equal(file, process.execPath);
    assert.equal(args[0], '--check');
    assert.equal(options.timeout, 10000);
    return execFile(file, ['-e', body, eventsFile, args[1]], options, callback);
  });
  const events = readFileSync(eventsFile, 'utf8').trim().split('\n').map(JSON.parse);
  assert.deepEqual(events.filter(e => e.kind === 'start').map(e => e.path).sort(), [...f.files].sort());
  assert.deepEqual(events.filter(e => e.kind === 'end').map(e => e.path).sort(), [...f.files].sort());
  let active = 0, maximum = 0;
  for (const event of events) {
    active += event.kind === 'start' ? 1 : -1;
    assert.ok(active >= 0 && active <= 2);
    maximum = Math.max(maximum, active);
  }
  assert.equal(active, 0);
  assert.equal(maximum, 2);
});

test('real startup failures fail the check without omitting remaining files', async t => {
  assert.equal(typeof checker.checkSyntax, 'function');
  const f = fixture(t), seen = [];
  await assert.rejects(checker.checkSyntax(f.directories, (file, args, options, callback) => {
    seen.push(args[1]);
    return execFile(join(f.root, 'missing-node'), args, options, callback);
  }), error => error instanceof AggregateError && error.errors.length === f.files.length
    && error.errors.every(item => /ENOENT/.test(item.message)));
  assert.deepEqual(seen.sort(), [...f.files].sort());
});

test('real child timeout fails the check and still visits every file', async t => {
  assert.equal(typeof checker.checkSyntax, 'function');
  const f = fixture(t), seen = [];
  await assert.rejects(checker.checkSyntax(f.directories, (file, args, options, callback) => {
    seen.push(args[1]);
    assert.equal(options.timeout, 10000, 'production retains its original per-file deadline');
    // Exercise actual subprocess termination quickly, after checking the production deadline.
    return args[1] === f.files[0]
      ? execFile(file, ['-e', 'setInterval(()=>{},1000)'], { ...options, timeout: 100 }, callback)
      : execFile(file, args, options, callback);
  }), error => error instanceof AggregateError && error.errors.length === 1
    && error.errors[0].message.includes(f.files[0]));
  assert.deepEqual(seen.sort(), [...f.files].sort());
});
