import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
// Independently transcribed from MonsterHelper.spawnGremlins at fixed 319009d.
const pool = ['mad_gremlin','mad_gremlin','sneaky_gremlin','sneaky_gremlin','fat_gremlin','fat_gremlin','shield_gremlin','wizard_gremlin'];
const gang = d => d.enemies.encounters.find(e => e.id === 'gremlin_gang');
const setup = () => {
  const d = loadContent('data'), e = gang(d);
  delete e.enemies; e.gremlinPool = [...pool]; e.gremlinCount = 4;
  return d;
};
test('gremlin_gang declares the exact source pool and four slots without changing map eligibility', () => {
  const d = loadContent('data');
  assert.deepEqual(gang(d), {id:'gremlin_gang',tier:'normal',gremlinPool:pool,gremlinCount:4,minFloor:5,maxFloor:14});
  assert.deepEqual(validateContent(d), []);
  assert.equal(d.enemies.encounters.length, 18);
  assert.equal(d.enemies.encounters.filter(e => e.gremlinPool !== undefined).length, 1);
});
test('eight candidates are not eight occupied UI slots', () => assert.deepEqual(validateContent(setup()), []));
for (const [label,mutate,pattern] of [
  ['missing pool',e => delete e.gremlinPool,/gremlinPool/],
  ['not array',e => e.gremlinPool=false,/gremlinPool/],
  ['empty pool',e => e.gremlinPool=[],/gremlinPool/],
  ['wrong order',e => [e.gremlinPool[0],e.gremlinPool[7]]=[e.gremlinPool[7],e.gremlinPool[0]],/gremlinPool.*source/],
  ['missing weight',e => e.gremlinPool.splice(1,1),/gremlinPool.*source/],
  ['extra weight',e => e.gremlinPool.push('wizard_gremlin'),/gremlinPool.*source/],
  ['missing enemy',e => e.gremlinPool[0]='missing',/gremlinPool.*unknown enemies ID/],
  ['wrong tier',e => e.gremlinPool[0]='guardian',/gremlinPool.*does not match encounter tier/],
  ['missing count',e => delete e.gremlinCount,/gremlinCount/],
  ['zero count',e => e.gremlinCount=0,/gremlinCount/],
  ['five count',e => e.gremlinCount=5,/gremlinCount/],
  ['fractional count',e => e.gremlinCount=3.5,/gremlinCount/],
  ['count over pool and slots',e => e.gremlinCount=9,/gremlinCount/],
  ['numeric string',e => e.gremlinCount='4',/gremlinCount/],
  ['static enemies conflict',e => e.enemies=['mad_gremlin'],/enemies.*gremlinPool/],
  ['Boolean branch conflict',e => e.enemiesOnTrue=['mad_gremlin'],/enemiesOnTrue.*gremlinPool/],
  ['split overflow',e => e.gremlinPool[0]='acid_slime_l',/gremlinPool.*five UI slots/],
]) test('gremlin schema rejects '+label, () => {
  const d=setup();mutate(gang(d));const errors=validateContent(d);
  assert.ok(errors.some(e=>pattern.test(e)), errors.join('\n'));
});
test('source-specific pool fields cannot silently spread to other encounters', () => {
  for (const field of ['gremlinPool','gremlinCount']) {
    const d=setup();d.enemies.encounters[0][field]=field==='gremlinPool'?[...pool]:4;
    assert.match(validateContent(d).join('\n'),new RegExp(field+'.*gremlin_gang'));
  }
});
test('ordinary static groups retain the five-slot cap including split parents', () => {
  const d=setup();d.enemies.encounters[0].enemies=['acid_slime_l','spike_slime_l'];
  assert.match(validateContent(d).join('\n'),/enemies.*five UI slots/);
});
