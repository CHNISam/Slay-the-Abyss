import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const small = d => d.enemies.encounters.find(e => e.id === 'small_slimes');
const setup = () => { const d = loadContent('data'); small(d).enemies = ['acid_slime_s', 'spike_slime_m']; small(d).enemiesOnTrue = ['spike_slime_s', 'acid_slime_m']; return d; };
test('small_slimes stores exactly the source false/true slot arrays without changing floor eligibility', () => {
  const d = loadContent('data'), e = small(d);
  assert.deepEqual(e, {id:'small_slimes',tier:'normal',enemies:['acid_slime_s','spike_slime_m'],enemiesOnTrue:['spike_slime_s','acid_slime_m'],minFloor:1,maxFloor:14});
  assert.deepEqual(validateContent(d), []);
  assert.equal(d.enemies.encounters.length, 18);
  assert.equal(d.enemies.encounters.filter(e => e.enemiesOnTrue !== undefined).length, 1);
});
test('one optional true Boolean branch is valid', () => assert.deepEqual(validateContent(setup()), []));
for (const [label,value,pattern] of [
  ['not array', false, /enemiesOnTrue/], ['empty array', [], /enemiesOnTrue/],
  ['missing enemy', ['missing'], /enemiesOnTrue.*unknown enemies ID/],
  ['wrong tier', ['guardian'], /enemiesOnTrue.*does not match encounter tier/],
  ['split slots overflow', ['acid_slime_l','spike_slime_l'], /enemiesOnTrue.*five UI slots/],
]) test('true branch validates '+label, () => {
  const d=setup();small(d).enemiesOnTrue=value;
  assert.ok(validateContent(d).some(e => pattern.test(e)), validateContent(d).join('\n'));
});
