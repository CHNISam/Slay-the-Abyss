import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

for (const [name, mutate, field] of [
  ['unknown field', e => e.ai.immediateStrength = 3, 'immediateStrength'],
  ['missing opening', e => delete e.ai.ritualIntent, 'ritualIntent'],
  ['missing attack', e => delete e.ai.attackIntent, 'attackIntent'],
  ['opening points to attack', e => e.ai.ritualIntent = 'cultist_1', 'ritualIntent'],
  ['attack points to opening', e => e.ai.attackIntent = 'cultist_2', 'attackIntent'],
  ['immediate Strength substitute', e => e.intents[1].effects[0].status = 'strength', 'ritualIntent'],
  ['zero Ritual', e => e.intents[1].effects[0].value = 0, 'ritualIntent'],
  ['empty opening', e => e.intents[1].effects = [], 'effects'],
  ['nonarray intents', e => e.intents = {}, 'intents'],
  ['nonarray opening effects', e => e.intents[1].effects = {}, 'effects'],
]) {
  test(`Cultist policy rejects ${name}`, () => {
    const data = loadContent('data');
    mutate(data.enemies.enemies.find(e => e.id === 'cultist'));
    assert.ok(validateContent(data).some(error => error.includes(field)));
  });
}
