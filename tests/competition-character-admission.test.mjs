import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';

test('Alpha and Production admit only the user-approved Geo traveler; development retains eight loadouts', () => {
  const result = runLua('tests/lua/competition_character_admission.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /COMPETITION_CHARACTER_ADMISSION_PASS 5/);
});

test('ordinary non-test players start the real native Geo adventure without an acceptance blocker',()=>{
  const result=runLua('tests/lua/geo_public_entry.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/GEO_PUBLIC_ENTRY_PASS 4/);
});

test('release admission records the user authorization without changing the inventory evidence status',()=>{
  const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
  assert.deepEqual(manifest.runtimeAdmission.alphaCharacters,['ironclad']);
  assert.deepEqual(manifest.runtimeAdmission.productionCharacters,['ironclad']);
  assert.equal(manifest.runtimeAdmission.developmentCharacters.length,8);
  assert.deepEqual(manifest.runtimeAdmission.acts,[1,2]);
  assert.equal(manifest.runtimeAdmission.authorization.kind,'user-confirmation');
  assert.equal(manifest.status,'scope-baseline-awaiting-per-item-acceptance');
});
