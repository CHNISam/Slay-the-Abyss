import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { cpSync, linkSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { buildOriginalV4, loadOriginalV4, originalV4ToLua } from '../scripts/build-original-v4.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { traversesLinkBeforeParent } from './helpers/parent-traversal.mjs';

const files = ['cards_v4.json', 'rules_v4.json'];
const hashes = ['89229cdd7f6c1640d47bca95338f5e7887fbfd8720af181f7561d6eb45a45fca',
  'a100f8b0fd61e3724f0eda5e077055f82bcacb7a4536d337096d9a6389419c8e'];
function temporary(action) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-original-v4-'));
  try {
    const directory = join(root, 'data');
    cpSync('data/original_v4', directory, { recursive: true });
    return action(root, directory);
  } finally { rmSync(root, { recursive: true, force: true }); }
}
function snapshots(directory) { return files.map(file => readFileSync(join(directory, file))); }
function unchanged(directory, before) {
  for (const [index, file] of files.entries()) assert.deepEqual(readFileSync(join(directory, file)), before[index]);
}
function makeSymlink(t, target, output, type = 'file') {
  try { symlinkSync(target, output, type); return true; }
  catch (error) {
    if (['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return false; }
    throw error;
  }
}
test('canonical V4 bytes, 300 stable IDs, 600 definitions and every role starter remain frozen', () => {
  files.forEach((file, index) => assert.equal(createHash('sha256').update(readFileSync(`data/original_v4/${file}`)).digest('hex'), hashes[index]));
  const data = loadOriginalV4();
  assert.deepEqual(Object.keys(data), ['version', 'cards', 'rules']);
  assert.equal(data.version, 'original_v4.0_frozen_2026-10-26');
  assert.equal(data.cards.length, 300);
  for (const role of ['HT', 'AR', 'FR', 'RD']) {
    const cards = data.cards.filter(card => card.role === role);
    assert.equal(cards.length, 75);
    assert.deepEqual(cards.map(card => card.id), Array.from({ length: 75 }, (_, index) => `${role}2-${String(index + 1).padStart(3, '0')}`));
    assert.deepEqual(Object.fromEntries(['基础', '普通', '罕见', '稀有'].map(rarity => [rarity, cards.filter(card => card.rarity === rarity).length])),
      { '基础': 6, '普通': 26, '罕见': 25, '稀有': 18 });
    assert.equal(data.rules.roles[role].starter.length, 10);
    for (const card of cards) { assert.equal(typeof card.base.cost, 'number'); assert.equal(typeof card.upgrade.cost, 'number'); }
  }
  assert.equal(data.cards.find(card => card.id === 'RD2-006').base.effects[0].n, 5);
  assert.equal(data.cards.find(card => card.id === 'RD2-017').base.effects[1].n, 0);
  assert.equal(data.cards.find(card => card.id === 'AR2-004').base.effects[2].coefficient, 0);
  assert.deepEqual(data.cards.find(card => card.id === 'FR2-004').requirements, ['fan4']);
});

const corruptions = [
  ['missing card', d => d.cards.pop(), /300 cards/],
  ['duplicate stable ID', d => d.cards[1].id = d.cards[0].id, /Duplicate/],
  ['wrong role', d => d.cards[0].role = 'FR', /ID\/role/],
  ['missing upgrade', d => delete d.cards[0].upgrade, /definition/],
  ['unknown op', d => d.cards[0].base.effects[0].op = 'unknown_damage', /unknown op/],
  ['unknown nested op', d => d.cards[3].base.effects[1].effects[0].op = 'unknown_heal', /unknown op/],
  ['unknown when condition', d => d.cards[3].base.effects[1].condition = 'hp36', /unknown condition/],
  ['unknown requirement', d => d.cards[0].requirements = ['hp36'], /requirements/],
  ['misplaced requirement', d => { delete d.cards[0].requirements; d.cards[0].base.requires = []; }, /requirements/],
  ['unknown effect field', d => d.cards[0].base.effects[0].value = 6, /unsupported/],
  ['missing target', d => delete d.cards[0].base.effects[0].target, /missing/],
  ['negative payment', d => d.cards[2].base.effects[0].n = -1, /invalid.*n/],
  ['silent numerical adjustment', d => d.cards[0].base.effects[0].n = 7, /hash mismatch/],
];
for (const [name, corrupt, expected] of corruptions) {
  test(`reject ${name} before replacing an existing build`, () => temporary((root, directory) => {
    const path = join(directory, files[0]), data = JSON.parse(readFileSync(path, 'utf8'));
    corrupt(data); writeFileSync(path, JSON.stringify(data));
    const output = join(root, 'prior.lua'); writeFileSync(output, 'prior valid output');
    assert.throws(() => buildOriginalV4(directory, output), expected);
    assert.equal(readFileSync(output, 'utf8'), 'prior valid output');
  }));
}
test('rule edits and whitespace-only source changes also fail the frozen hash', () => temporary((root, directory) => {
  const rules = join(directory, files[1]), original = readFileSync(rules, 'utf8');
  const changed = JSON.parse(original); changed.common.battle_actual_heal_cap = 13;
  writeFileSync(rules, JSON.stringify(changed));
  assert.throws(() => loadOriginalV4(directory), /hash mismatch: rules_v4/);
  writeFileSync(rules, original + '\n');
  assert.throws(() => loadOriginalV4(directory), /hash mismatch/);
}));

for (const file of files) for (const mode of ['direct', 'hardlink', 'symlink', 'directory-symlink']) {
  test(`generator protects ${file} through ${mode} aliases`, t => temporary((root, directory) => {
    const input = join(directory, file), before = snapshots(directory);
    let output = input;
    if (mode === 'hardlink') { output = join(root, 'alias.lua'); linkSync(input, output); }
    if (mode === 'symlink') { output = join(root, 'alias.lua'); if (!makeSymlink(t, input, output)) return; }
    if (mode === 'directory-symlink') {
      const alias = join(root, 'alias');
      if (!makeSymlink(t, directory, alias, 'junction')) return;
      output = join(alias, file);
    }
    assert.throws(() => buildOriginalV4(directory, output), /must not overwrite an input/);
    unchanged(directory, before);
  }));
}
for (const file of files) {
  test(`generator protects actual symlink-parent traversal destination for ${file}`, t => temporary((root, directory) => {
    const child = join(directory, 'child'); mkdirSync(child);
    const alias = join(root, 'alias'); mkdirSync(alias);
    if (!makeSymlink(t, child, join(alias, 'linked'), 'junction')) return;
    const output = `${alias}/linked/../${file}`, before = snapshots(directory);
    if (traversesLinkBeforeParent(root)) {
      assert.throws(() => buildOriginalV4(directory, output), /must not overwrite an input/);
    } else {
      const source = buildOriginalV4(directory, output);
      assert.equal(readFileSync(output, 'utf8'), source);
    }
    unchanged(directory, before);
  }));
}

function independentDigest(value) {
  let digest = 7, count = 0;
  function visit(item, path) {
    if (item === null) return;
    const type = typeof item === 'object' ? 'table' : typeof item;
    const text = type === 'table' ? '' : String(item);
    for (const byte of Buffer.from(`${path}\0${type}\0${text}\0`)) digest = (digest * 33 + byte) % 1000000007;
    count++;
    if (type === 'table') {
      const entries = Array.isArray(item) ? item.map((v, i) => [String(i + 1), v]) : Object.entries(item);
      for (const [key, child] of entries.sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) visit(child, `${path}[${key}]`);
    }
  }
  visit(value, '$'); return `${count}|${digest}`;
}
test('generated Lua executes and preserves every table/scalar in all 600 definitions and rules', () => temporary((root, directory) => {
  const output = join(root, 'generated', 'abyss_original_v4_data.lua'), before = snapshots(directory);
  const first = buildOriginalV4(directory, output);
  assert.equal(first, buildOriginalV4(directory, output));
  assert.equal(readFileSync(output, 'utf8'), first);
  const script = join(root, 'read.lua');
  writeFileSync(script, `local data=dofile(${originalV4ToLua(output.replaceAll('\\', '/'))})
local count,h=0,7.0
local function feed(text) for i=1,#text do h=(h*33+string.byte(text,i))%1000000007 end end
local function visit(value,path)
 local kind=type(value); local text=kind=='table' and '' or tostring(value)
 feed(path..'\\0'..kind..'\\0'..text..'\\0'); count=count+1
 if kind=='table' then
  local keys={};for key in pairs(value) do keys[#keys+1]=key end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,key in ipairs(keys)do visit(value[key],path..'['..tostring(key)..']')end
 end
end
visit(data,'$');io.write(string.format('%d|%.0f',count,h))
`);
  const result = runLua(script);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, independentDigest(loadOriginalV4(directory)));
  unchanged(directory, before);
}));
test('Lua string escaping roundtrips UTF8 controls, following digits and injection text', () => temporary(root => {
  const value = '胡桃 😀 " \\ \n\r\t\0' + '123\x1f return os.exit(9) --';
  const script = join(root, 'string.lua');
  writeFileSync(script, `local s=${originalV4ToLua(value)};for i=1,#s do io.write(string.format('%02x',string.byte(s,i)))end`);
  const result = runLua(script);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, Buffer.from(value).toString('hex'));
  assert.throws(() => originalV4ToLua('\uD800'), /well-formed/);
  assert.throws(() => originalV4ToLua(Infinity), /Unsupported/);
}));
test('CLI fails on unsupported data without replacing prior output', () => temporary((root, directory) => {
  const source = join(directory, files[0]), data = JSON.parse(readFileSync(source, 'utf8'));
  data.cards[0].base.effects[0].op = 'unsupported'; writeFileSync(source, JSON.stringify(data));
  const output = join(root, 'output.lua'); writeFileSync(output, 'prior output');
  const result = spawnSync(process.execPath, [resolve('scripts/build-original-v4.mjs'), directory, output], { encoding: 'utf8' });
  assert.notEqual(result.status, 0); assert.match(result.stderr, /unknown op/);
  assert.equal(readFileSync(output, 'utf8'), 'prior output');
}));
