import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('stateful sleep AI references only declared, correctly typed intents', () => {
  assert.deepEqual(validateContent(loadContent('data')), []);
});

for (const [name, mutate, expected] of [
  ['nonobject HP range', e => e.hpRange = [], /hpRange/],
  ['reversed HP range', e => e.hpRange = {min:111,max:109}, /hpRange/],
  ['zero HP endpoint', e => e.hpRange.min = 0, /hpRange/],
  ['fractional HP endpoint', e => e.hpRange.max = 110.5, /hpRange/],
  ['baseline outside HP range', e => e.hp = 112, /hp/],
  ['unknown policy', e => e.ai.kind = 'guess', /ai.kind/],
  ['unknown field', e => e.ai.guess = 1, /ai.guess/],
  ['zero sleep duration', e => e.ai.sleepTurns = 0, /ai.sleepTurns/],
  ['fractional sleep block', e => e.ai.sleepBlock = 0.5, /ai.sleepBlock/],
  ['unknown sleeping intent', e => e.ai.sleepIntent = 'missing', /ai.sleepIntent/],
  ['wrong sleeping intent kind', e => e.ai.sleepIntent = 'lagavulin_2', /ai.sleepIntent/],
  ['wrong stunned intent kind', e => e.ai.stunnedIntent = 'lagavulin_2', /ai.stunnedIntent/],
  ['empty awake cycle', e => e.ai.awakeCycle = [], /ai.awakeCycle/],
  ['unknown awake intent', e => e.ai.awakeCycle[0] = 'missing', /ai.awakeCycle/],
  ['inactive awake intent', e => e.ai.awakeCycle[0] = 'lagavulin_1', /ai.awakeCycle/],
  ['active sleeping effects', e => e.intents[0].effects = [{ op: 'block', value: 8 }], /effects/],
  ['empty attack effects', e => e.intents[1].effects = [], /effects/]
]) {
  test(`rejects ${name}`, () => {
    const data = loadContent('data');
    mutate(data.enemies.enemies.find(e => e.id === 'lagavulin'));
    assert.match(validateContent(data).join('\n'), expected);
  });
}

for (const [name, mutate, expected] of [
  ['unknown ritual policy field', e => e.ai.guess = 1, /ai.guess/],
  ['missing opener', e => delete e.ai.openingIntent, /openingIntent/],
  ['unknown opener', e => e.ai.openingIntent = 'missing', /openingIntent/],
  ['attack as opener', e => e.ai.openingIntent = 'cultist_1', /openingIntent/],
  ['buff as attack', e => e.ai.attackIntent = 'cultist_2', /attackIntent/],
  ['immediate Strength opener', e => e.intents[1].effects[0].status = 'strength', /openingIntent/],
  ['player-targeted Ritual', e => e.intents[1].effects[0].op = 'applyStatus', /openingIntent/],
  ['wrong Ritual amount', e => e.intents[1].effects[0].value = 4, /openingIntent/],
  ['Ritual extra effect', e => e.intents[1].effects.push({op:'block',value:1}), /openingIntent/],
  ['wrong attack damage', e => e.intents[0].effects[0].value = 7, /attackIntent/],
  ['multi-hit attack', e => e.intents[0].effects[0].times = 2, /attackIntent/],
  ['empty opener', e => e.intents[1].effects = [], /effects|openingIntent/],
  ['sleep policy fields on Ritual', e => e.ai.sleepTurns = 3, /sleepTurns/]
]) {
  test(`rejects ${name}`, () => {
    const data = loadContent('data');
    mutate(data.enemies.enemies.find(e => e.id === 'cultist'));
    assert.match(validateContent(data).join('\n'), expected);
  });
}
