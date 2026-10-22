import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
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
  writeFileSync(script, `package.path=${luaString(directory.replaceAll('\\', '/') + '/?.lua;')}..package.path\nlocal data=require('abyss_data')\nassert(#data.cards.cards>0)\nassert(#data.enemies.enemies>0)\nassert(data.rules.map.floors==15)\nprint('data loaded')\n`);
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
  writeFileSync(script, 'while true do end');
  assert.throws(() => runLua(script, { timeout: 200 }), /timed out|ETIMEDOUT/);
}));
