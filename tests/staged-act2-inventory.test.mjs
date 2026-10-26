import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateLaunchContent } from '../scripts/verify-launch-content.mjs';
const fresh=()=>JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
const check=manifest=>validateLaunchContent(manifest,{runtime:false});

test('staged Act2 enemy remains REQUIRED-M3, explicitly unwired and absent from formal channels',()=>{
  const manifest=fresh(),row=manifest.exclusions.enemies[0];
  assert.equal(row.id,'spheric_guardian');assert.equal(row.scope,'REQUIRED-M3');assert.equal(row.implementation,'OFFLINE_SLICE_ONLY');assert.equal(row.admission,'UNWIRED');
  assert.deepEqual(row.channels,[]);assert.deepEqual(row.evidence,{local:'FOCUSED_REGRESSION_ONLY',platform:'NOT_RUN',naturalPlaythrough:'NOT_RUN'});
  assert.deepEqual(check(manifest),[]);
});

for(const [name,mutate,pattern] of [
  ['omitted accounting',m=>delete m.exclusions.enemies,/staged enemies/],
  ['omitted ID',m=>m.exclusions.enemies=[],/enemy definitions/],
  ['duplicate ID',m=>m.exclusions.enemies.push(structuredClone(m.exclusions.enemies[0])),/duplicate|enemy definitions/],
  ['unknown ID',m=>m.exclusions.enemies[0].id='fake_sphere',/enemy definitions|Act2 definition/],
  ['formal Act1 enemy',m=>{const row=m.enemies.find(e=>e.id==='sentry');m.enemies=m.enemies.filter(e=>e.id!=='sentry');m.exclusions.enemies.push({...m.exclusions.enemies[0],id:row.id});},/formal runtime binding cannot be excluded/],
  ['formal and staged overlap',m=>m.exclusions.enemies.push({...m.exclusions.enemies[0],id:'sentry'}),/overlapping|formal enemy cannot be staged/],
  ['scope removal',m=>m.exclusions.enemies[0].scope='OUT_OF_SCOPE',/status drift/],
  ['forged full implementation',m=>m.exclusions.enemies[0].implementation='IMPLEMENTED',/status drift/],
  ['forged completion field',m=>m.exclusions.enemies[0].completed=true,/fields/],
  ['forged admission',m=>m.exclusions.enemies[0].admission='PRODUCTION',/status drift/],
  ['invented legal channel',m=>m.exclusions.enemies[0].channels=['encounter:act2_spheric_guardian'],/channels/],
  ['wrong act',m=>m.exclusions.enemies[0].act=1,/Act2 roster/],
  ['forged platform pass',m=>m.exclusions.enemies[0].evidence.platform='PASSED',/evidence/],
  ['forged natural completion',m=>m.exclusions.enemies[0].evidence.naturalPlaythrough='PASSED',/evidence/],
  ['forged local completion',m=>m.exclusions.enemies[0].evidence.local='FULL_ACCEPTANCE',/evidence/],
  ['extra evidence',m=>m.exclusions.enemies[0].evidence.screenshot='fake.png',/evidence/],
  ['missing AI file',m=>m.exclusions.enemies[0].aiEntry='missing.lua',/AI entry/],
  ['forged tests',m=>m.exclusions.enemies[0].testFiles=['tests/lua/guardian_ai.lua'],/test files/],
  ['missing reason',m=>delete m.exclusions.enemies[0].reason,/reason/],
  ['forged formal row',m=>{m.enemies.push({...m.enemies[0],id:'spheric_guardian'});m.exclusions.enemies=[];},/channels/],
]) test(`staged accounting rejects ${name}`,()=>{
  const manifest=fresh();mutate(manifest);assert.match(check(manifest).join('\n'),pattern);
});
