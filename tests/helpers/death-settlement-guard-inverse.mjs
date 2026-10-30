import {preMultiGestureFixtureSource} from './multi-gesture-fixture-source.mjs';
import {preMultiHistoricalUiTest} from './multi-historical-ui-tests.mjs';
// One exact outer guard only. Accepted PR330's eleven-input witness/helper
// remain immutable; unknown or partial sources still reach their strict guards.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/death-settlement-guard-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'24d9338f6ef0c38d2047e9ae46680fd2495e01629598ed68c74cdead7b3ac5aa','complete exact settlement-guard layer identity');
export const deathSettlementGuardLayer=JSON.parse(bytes);
export function preDeathSettlementGuardSource(path,source){
  source=preMultiGestureFixtureSource(path,source);
  if(path==='tests/lua/support/game_ui_fixture.lua')source=preMultiHistoricalUiTest(path,source);
  const binding=deathSettlementGuardLayer.files[path];
  if(!binding||typeof source!=='string')return source;
  source=source.replaceAll('\r\n','\n');
  if(hash(source)!==binding.afterSha256)return source;
  const lines=source.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact settlement-guard hunk and position: '+path);
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const accepted=lines.join('\n');
  assert.equal(hash(accepted),binding.beforeSha256,'complete accepted PR330 source recovered: '+path);
  return accepted;
}
