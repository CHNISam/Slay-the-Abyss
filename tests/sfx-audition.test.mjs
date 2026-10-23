import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { sfxCandidateIds, sfxAuditionCandidates, sfxAuditionController } from '../scripts/sfx-audition-source.mjs';
import { luaString } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('native audition controller queues real IDs once, handles death and retains reviews', () => {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-sfx-'));
  try {
    const candidates = sfxAuditionCandidates({ rows: sfxCandidateIds.map(id => [id, '原生候选']) });
    const source = join(directory, 'controller.lua');
    writeFileSync(source, sfxAuditionController(candidates));
    const runner = join(directory, 'verify.lua');
    writeFileSync(runner, `arg={[1]=${luaString(source.replaceAll('\\', '/'))}}\ndofile('tools/sfx-audition/verify.lua')\n`);
    const result = runLua(runner);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS: tour order/);
    assert.throws(() => sfxAuditionCandidates({ rows: [] }), /Missing catalog sound/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
