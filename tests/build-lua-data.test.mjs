import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { buildLuaData, luaString, toLua } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { contentFiles, loadContent } from '../scripts/validate-data.mjs';

function temporary(action) {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-lua-'));
  try { return action(directory); } finally { rmSync(directory, { recursive: true, force: true }); }
}

test('serialization is deterministic regardless of object key insertion order', () => {
  assert.equal(toLua({ z: [1, true], a: 'x' }), toLua({ a: 'x', z: [1, true] }));
  assert.throws(() => toLua(null), /Unsupported/);
  assert.throws(() => toLua(Infinity), /Unsupported/);
  assert.throws(() => luaString('\uD800'), /well-formed Unicode/);
});

test('UTF8 strings roundtrip through actual Lua, including controls and injection text', () => temporary(directory => {
  const text = '中文 😀 " \\ \n\r\t\0' + '123\x1f return os.exit(9) --';
  const script = join(directory, 'roundtrip.lua');
  writeFileSync(script, `local s=${luaString(text)}\nfor i=1,#s do io.write(string.format("%02x",string.byte(s,i))) end\n`);
  const result = runLua(script);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, Buffer.from(text).toString('hex'));
}));

test('validated six-table bundle builds identically and loads as abyss_data in Lua', () => temporary(directory => {
  const output = join(directory, 'abyss_data.lua');
  const first = buildLuaData('data', output);
  assert.equal(first, buildLuaData('data', output));
  const script = join(directory, 'load.lua');
  writeFileSync(script, `package.path=${luaString(directory.replaceAll('\\', '/') + '/?.lua;')}..package.path\nlocal data=require('abyss_data')\nassert(#data.cards.cards>0)\nassert(#data.enemies.enemies>0)\nassert(data.rules.map.floors==17 and data.rules.map.generatedRows==15)\nprint('data loaded')\n`);
  const result = runLua(script);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /data loaded/);
}));

test('invalid or missing input fails before replacing existing output', () => temporary(directory => {
  const data = loadContent('data');
  for (const file of contentFiles) writeFileSync(join(directory, `${file}.json`), JSON.stringify(data[file]));
  const output = join(directory, 'out.lua');
  writeFileSync(output, 'previous output');
  data.rules.player.maxHp = -1;
  writeFileSync(join(directory, 'rules.json'), JSON.stringify(data.rules));
  assert.throws(() => buildLuaData(directory, output), /maxHp/);
  assert.equal(readFileSync(output, 'utf8'), 'previous output');
  rmSync(join(directory, 'cards.json'));
  assert.throws(() => buildLuaData(directory, output), /ENOENT/);
}));

test('Lua runner propagates failures and enforces finite timeout', () => temporary(directory => {
  const script = join(directory, 'failure.lua');
  writeFileSync(script, 'error("intentional failure")');
  const failure = runLua(script);
  assert.notEqual(failure.status, 0);
  assert.match(failure.stderr, /intentional failure/);
  writeFileSync(script, 'this is not valid Lua !');
  assert.notEqual(runLua(script).status, 0);
  assert.notEqual(runLua(join(directory, 'missing.lua')).status, 0);
  writeFileSync(script, 'while true do end');
  assert.throws(() => runLua(script, { timeout: 200 }), /timed out|ETIMEDOUT/);
}));

test('Lua suite discovers every file in order and stops on first failure', () => temporary(directory => {
  const scripts = join(directory, 'tests/lua');
  mkdirSync(scripts, { recursive: true });
  const cli = resolve('scripts/test-lua.mjs');
  const run = () => spawnSync(process.execPath, [cli], { cwd: directory, encoding: 'utf8', timeout: 5000 });
  assert.notEqual(run().status, 0, 'empty suite must fail');
  writeFileSync(join(scripts, 'a.lua'), 'print("suite first")');
  writeFileSync(join(scripts, 'b.lua'), 'print("suite second")');
  let result = run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /suite first[\s\S]*suite second/);
  writeFileSync(join(scripts, 'a.lua'), 'error("suite failure")');
  result = run();
  assert.notEqual(result.status, 0);
  assert.doesNotMatch(result.stdout, /suite second/);
}));
