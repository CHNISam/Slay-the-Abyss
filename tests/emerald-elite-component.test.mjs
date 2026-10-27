import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { runLua } from '../scripts/test-lua.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

test('Emerald source locks distinguish map selection, entry boost and independent reward ownership', () => {
  const lock = JSON.parse(readFileSync('tests/fixtures/emerald-elite-source.json', 'utf8'));
  assert.equal(lock.sourceCommit, '319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.equal(lock.archiveSha256, '3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
  assert.equal(lock.files['rooms/MonsterRoomElite.java'].sha256, 'c5207d745f383e1de615e613da8e5c8f832e237444c3b757d85a61f8b3f5ee3f');
  assert.equal(lock.files['rewards/RewardItem.java'].gitBlob, 'a23c192d58c6304acd76505da7365490636f1f31');
  assert.equal(Object.keys(lock.files).length, 12);
  for (const file of Object.values(lock.files)) {
    assert.match(file.sha256, /^[a-f0-9]{64}$/);
    assert.match(file.gitBlob, /^[a-f0-9]{40}$/);
    assert.ok(file.bytes > 0);
  }
  assert.deepEqual(lock.contract.selectionOrder, ['source_y', 'source_x']);
  assert.equal(lock.contract.selectionStream, 'existing post-room-assignment mapRng');
  assert.equal(lock.contract.boostTiming, 'entry after monster pre-battle actions are queued');
  assert.equal(lock.contract.greenConsumesRelic, false);
  assert.equal(lock.boundary.naturalAcquisition, 'NOT_IMPLEMENTED_BY_COMPONENT');
  assert.equal(lock.boundary.monsterRegenRouting, 'CALLER_REQUIRED');
});

test('Emerald independent oracle reproduces selection, boost and subsequent source RNG state', () => {
  const result = spawnSync('python', ['tests/fixtures/emerald-elite-oracle.py'],
    { encoding: 'utf8', timeout: 15000, windowsHide: true });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /EMERALD_ORACLE 8 complete RNG continuations; 9 rounded HP vectors/);
});

test('Emerald pure component preserves source choices, callback boundaries and reward owner rejection', () => {
  const vectors = JSON.parse(readFileSync('tests/fixtures/emerald-elite-vectors.json', 'utf8'));
  const directory = mkdtempSync(join(tmpdir(), 'abyss-emerald-'));
  try {
    const script = join(directory, 'component.lua');
    writeFileSync(script, `EMERALD_VECTORS=${toLua(vectors)}\ndofile('tests/lua/emerald_elite_component.lua')\n`);
    const result = runLua(script);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /EMERALD_COMPONENT 8 groups; 0 failed; integration NOT_RUN/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
