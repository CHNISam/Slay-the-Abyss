import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, unlinkSync, linkSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { verifyOfficialClient, runOfficialClientCli } from '../scripts/verify-official-client.mjs';

function fixture(t) {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-official-source-'));
  t.after(() => {
    // Delete only the unique directory created by this fixture.
    assert.equal(dirname(resolve(directory)), resolve(tmpdir()));
    assert.ok(basename(directory).startsWith('abyss-official-source-'));
    rmSync(directory, { recursive: true, force: true });
  });
  const save = join(directory, '1847'), sidecar = join(save, 'external_lua_file');
  mkdirSync(sidecar, { recursive: true });
  const map = join(save, '1847.gil');
  writeFileSync(map, 'not parsed or changed by source guard');
  const inventory = { mapPath: join(directory, 'candidate.gil'), scripts: [
    { name: 'abyss_ui', file: 'abyss_ui.lua', source: '-- 普通版入口\nreturn require("abyss_game_ui")\n' },
    { name: 'abyss_game_ui', file: 'abyss_game_ui.lua', source: 'return {new = function() end}\n' },
  ] };
  for (const script of inventory.scripts) writeFileSync(join(sidecar, script.file), script.source);
  const inventoryFile = join(directory, 'scripts.json');
  writeFileSync(inventoryFile, JSON.stringify(inventory));
  return { directory, map, sidecar, inventory, inventoryFile, verify: () => verifyOfficialClient(inventory, map) };
}
const codes = report => report.issues.map(issue => issue.code);
function cli(args) {
  let stdout = '', stderr = '';
  const status = runOfficialClientCli(args, { write: text => { stdout += text; } }, { write: text => { stderr += text; } });
  return { status, stdout, stderr };
}

test('source equality is explicit and does not read/hash the official .gil or unrelated sidecars', t => {
  const f = fixture(t);
  writeFileSync(join(f.sidecar, 'credentials.txt'), 'must not appear in reports');
  mkdirSync(join(f.sidecar, 'unrelated.json'));
  const before = readFileSync(f.map);
  const report = f.verify();
  assert.ok(report.ok);
  assert.deepEqual(report.modules.map(module => module.status), ['match', 'match']);
  assert.match(report.scope, /not ready, playable/);
  assert.deepEqual(readFileSync(f.map), before);
  assert.ok(!JSON.stringify(report).includes('credentials'));
  assert.equal(report.modules[0].embedded.rawSha256, report.modules[0].external.rawSha256);
});

test('the escaped numeric-fixture entry rejects even when the official map filename is correct', t => {
  const f = fixture(t);
  writeFileSync(join(f.sidecar, 'abyss_ui.lua'), 'return require("abyss_m3_numeric_probe")\n');
  const report = f.verify();
  assert.ok(!report.ok);
  assert.deepEqual(codes(report), ['SOURCE_DIFF']);
  assert.equal(report.modules[0].status, 'diff');
  assert.notEqual(report.modules[0].embedded.normalizedSha256, report.modules[0].external.normalizedSha256);
});

test('missing and unexpected Lua modules are separately reported with available source hashes', t => {
  const f = fixture(t);
  unlinkSync(join(f.sidecar, 'abyss_game_ui.lua'));
  writeFileSync(join(f.sidecar, 'abyss_m3_numeric_probe.lua'), 'return {}\n');
  const report = f.verify();
  assert.deepEqual(codes(report), ['MISSING_MODULE', 'UNEXPECTED_MODULE']);
  assert.equal(report.modules[1].status, 'missing');
  assert.equal(report.modules[1].external, null);
  assert.match(report.modules[1].embedded.rawSha256, /^[a-f0-9]{64}$/);
  assert.equal(report.unexpected[0].file, 'abyss_m3_numeric_probe.lua');
  assert.match(report.unexpected[0].external.normalizedSha256, /^[a-f0-9]{64}$/);
});

test('only leading UTF-8 BOM and CRLF are equivalent; raw and normalized hashes both remain', t => {
  const f = fixture(t), entry = f.inventory.scripts[0];
  writeFileSync(join(f.sidecar, entry.file), '\uFEFF' + entry.source.replaceAll('\n', '\r\n'));
  let report = f.verify();
  assert.ok(report.ok);
  assert.notEqual(report.modules[0].embedded.rawSha256, report.modules[0].external.rawSha256);
  assert.equal(report.modules[0].embedded.normalizedSha256, report.modules[0].external.normalizedSha256);
  for (const changed of [entry.source.trimEnd(), entry.source.replace('return', 'return '), entry.source.replaceAll('\n', '\r')]) {
    writeFileSync(join(f.sidecar, entry.file), changed);
    report = f.verify();
    assert.ok(codes(report).includes('SOURCE_DIFF'), JSON.stringify(changed));
  }
});

test('unsafe identities, duplicate names/files, missing source and missing entry reject before file reads', t => {
  const f = fixture(t);
  for (const file of ['../abyss_ui.lua', '..\\abyss_ui.lua', '/abyss_ui.lua', 'C:\\abyss_ui.lua', 'abyss_ui.lua:stream', 'CON.lua', 'bad.lua.', 'bad.lua ']) {
    const inventory = structuredClone(f.inventory); inventory.scripts[0].file = file;
    assert.ok(codes(verifyOfficialClient(inventory, f.map)).includes('UNSAFE_SCRIPT_IDENTITY'), file);
  }
  for (const script of [f.inventory.scripts[0], { ...f.inventory.scripts[0], name: 'ABYSS_UI', file: 'ABYSS_UI.lua' },
    { ...f.inventory.scripts[0], name: 'other' }]) {
    const inventory = structuredClone(f.inventory); inventory.scripts.push(script);
    assert.ok(codes(verifyOfficialClient(inventory, f.map)).includes('DUPLICATE_MODULE'));
  }
  const missingSource = structuredClone(f.inventory); delete missingSource.scripts[0].source;
  assert.ok(codes(verifyOfficialClient(missingSource, f.map)).includes('MISSING_EMBEDDED_SOURCE'));
  assert.ok(codes(verifyOfficialClient({ ...f.inventory, scripts: f.inventory.scripts.slice(1) }, f.map)).includes('MISSING_ENTRY'));
  const alias = structuredClone(f.inventory); alias.scripts[1].file = 'other.lua';
  assert.ok(codes(verifyOfficialClient(alias, f.map)).includes('MODULE_FILE_MISMATCH'));
});

test('a different candidate cannot borrow an existing successful import', t => {
  const f = fixture(t), changed = structuredClone(f.inventory);
  changed.mapPath = join(f.directory, 'next-candidate.gil');
  changed.scripts[1].source = 'return {new = function() return "next candidate" end}\n';
  const report = verifyOfficialClient(changed, f.map);
  assert.ok(!report.ok && codes(report).includes('SOURCE_DIFF'));
  assert.equal(report.candidateMapPath, changed.mapPath);
});

test('invalid UTF-8, Lua-named directories and absent sidecar directory fail closed', t => {
  const f = fixture(t);
  writeFileSync(join(f.sidecar, 'abyss_ui.lua'), Buffer.from([0xc3, 0x28]));
  assert.ok(codes(f.verify()).includes('UNREADABLE_EXTERNAL_SOURCE'));
  unlinkSync(join(f.sidecar, 'abyss_ui.lua'));
  mkdirSync(join(f.sidecar, 'abyss_ui.lua'));
  assert.ok(codes(f.verify()).includes('UNSAFE_EXTERNAL_FILE'));
  const otherMap = join(f.directory, 'empty.gil'); writeFileSync(otherMap, '');
  const missing = verifyOfficialClient(f.inventory, otherMap);
  assert.ok(codes(missing).includes('MISSING_SIDECAR_DIRECTORY'));
  assert.ok(missing.modules.every(module => module.status === 'missing'));
});

test('CLI reports source-only success, exits one for mismatches, and cannot overwrite inputs or official files', t => {
  const f = fixture(t), reportFile = join(f.directory, 'report.json');
  assert.equal(cli([f.inventoryFile, f.map, reportFile]).status, 0);
  const report = JSON.parse(readFileSync(reportFile));
  assert.ok(report.ok && report.inventory.rawSha256);
  assert.match(report.scope, /not ready, playable/);
  const inventoryBefore = readFileSync(f.inventoryFile);
  for (const output of [f.inventoryFile, join(dirname(f.map), 'report.json'), join(f.sidecar, 'report.json'), f.map]) {
    assert.equal(cli([f.inventoryFile, f.map, output]).status, 1, output);
  }
  assert.deepEqual(readFileSync(f.inventoryFile), inventoryBefore);
  writeFileSync(join(f.sidecar, 'abyss_ui.lua'), 'old entry\n');
  assert.equal(cli([f.inventoryFile, f.map, reportFile]).status, 1);
  assert.ok(!JSON.parse(readFileSync(reportFile)).ok);
  assert.equal(cli([]).status, 1);
  const processResult = spawnSync(process.execPath, ['scripts/verify-official-client.mjs', f.inventoryFile, f.map],
    { cwd: resolve('.'), encoding: 'utf8' });
  assert.equal(processResult.status, 1, processResult.stderr);
  assert.ok(JSON.parse(processResult.stdout).diff.includes('abyss_ui.lua'));
});

test('report output cannot overwrite a hardlink alias of the independent inventory', t => {
  const f = fixture(t), output = join(f.directory, 'linked-report.json');
  linkSync(f.inventoryFile, output);
  const before = readFileSync(f.inventoryFile);
  assert.equal(cli([f.inventoryFile, f.map, output]).status, 1);
  assert.deepEqual(readFileSync(f.inventoryFile), before);
});

test('Lua symlinks are rejected instead of following a source path outside the save', t => {
  const f = fixture(t), entry = join(f.sidecar, 'abyss_ui.lua'), outside = join(f.directory, 'outside.lua');
  writeFileSync(outside, f.inventory.scripts[0].source);
  unlinkSync(entry);
  try { symlinkSync(outside, entry); }
  catch (error) {
    if (['EPERM', 'EACCES', 'ENOTSUP'].includes(error.code)) { t.skip('OS does not permit this fixture symlink'); return; }
    throw error;
  }
  assert.ok(codes(f.verify()).includes('UNSAFE_EXTERNAL_FILE'));
});
