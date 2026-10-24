import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateLaunchContent } from '../scripts/verify-launch-content.mjs';

const fresh = () => JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));
test('frozen inventory matches production data and actual Lua support pools', () => {
  assert.deepEqual(validateLaunchContent(fresh()), []);
});
test('inventory gate rejects missing content, candidate admission and invented live completion', () => {
  const missing = fresh(); missing.cards.pop();
  assert.ok(validateLaunchContent(missing, { runtime: false }).some(error => error.includes('cards')));
  const candidate = fresh(); candidate.events.push({ ...candidate.events[0], id: 'Match and Keep!' });
  assert.ok(validateLaunchContent(candidate, { runtime: false }).some(error => error.includes('excluded content admitted')));
  const falsePass = fresh(); falsePass.profiles.cards.live.status = 'passed';
  assert.ok(validateLaunchContent(falsePass, { runtime: false }).some(error => error.includes('acceptance requires')));
});
test('inventory gate rejects reward/encounter drift and omitted final-floor relic boundary', () => {
  const rarity = fresh(); rarity.cards.find(card => card.id === 'strike').bossReward = true;
  assert.ok(validateLaunchContent(rarity, { runtime: false }).some(error => error.includes('Boss reward rarity')));
  const encounter = fresh(); encounter.encounters[0].enemies = ['guardian'];
  assert.ok(validateLaunchContent(encounter, { runtime: false }).some(error => error.includes('encounters/')));
  const relic = fresh(); delete relic.relics.find(row => row.id === 'sozu').naturalExecutionLimitation;
  assert.ok(validateLaunchContent(relic, { runtime: false }).some(error => error.includes('final-floor')));
});
test('actual production predicate rejects replacing a supported card with an unimplemented definition', () => {
  const manifest = fresh();
  manifest.cards.find(row => row.id === 'cleave').id = 'clash';
  manifest.exclusions.cards.find(row => row.id === 'clash').id = 'cleave';
  assert.ok(validateLaunchContent(manifest).some(error => error.includes('Playable card pool drift')));
});
