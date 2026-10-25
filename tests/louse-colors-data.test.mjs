import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const pool = ['red_louse', 'green_louse'];
const get = (d, id) => d.enemies.encounters.find(e => e.id === id);
const setup = () => {
  const d = loadContent('data');
  for (const [id, n] of [['louse_pair', 2], ['louse_trio', 3]]) {
    const e = get(d, id); delete e.enemies; e.lousePool = [...pool]; e.louseCount = n;
  }
  return d;
};
test('louse encounters declare independent two-color slots, not fixed groups', () => {
  const d = loadContent('data');
  for (const [id, n, min, max] of [['louse_pair',2,1,14], ['louse_trio',3,4,14]]) {
    assert.deepEqual(get(d,id), {id,tier:'normal',lousePool:pool,louseCount:n,minFloor:min,maxFloor:max});
  }
  assert.equal(d.enemies.encounters.length,18);
  assert.equal(d.enemies.encounters.filter(e => e.lousePool !== undefined).length,2);
});
test('both restricted louse modes validate with pool candidates rather than occupied slots', () => assert.deepEqual(validateContent(setup()), []));
for (const id of ['louse_pair','louse_trio']) for (const [name, mutate, pattern] of [
  ['missing pool', e => delete e.lousePool, /lousePool/],
  ['non-array pool', e => e.lousePool=false, /lousePool/],
  ['empty pool', e => e.lousePool=[], /lousePool/],
  ['reordered pool', e => e.lousePool.reverse(), /lousePool.*ordered/],
  ['duplicate color', e => e.lousePool[1]='red_louse', /lousePool.*ordered/],
  ['extra color', e => e.lousePool.push('red_louse'), /lousePool.*ordered/],
  ['unknown reference', e => e.lousePool[0]='missing', /lousePool.*unknown enemies ID/],
  ['wrong tier reference', e => e.lousePool[0]='guardian', /lousePool.*does not match encounter tier/],
  ['split capacity', e => e.lousePool[0]='acid_slime_l', /lousePool.*five UI slots/],
  ['missing count', e => delete e.louseCount, /louseCount/],
  ['zero count', e => e.louseCount=0, /louseCount/],
  ['other louse count', e => e.louseCount=e.louseCount===2?3:2, /louseCount/],
  ['fractional count', e => e.louseCount=2.5, /louseCount/],
  ['string count', e => e.louseCount='2', /louseCount/],
  ['overflow count', e => e.louseCount=6, /louseCount/],
  ['static conflict', e => e.enemies=['red_louse'], /enemies.*lousePool/],
  ['Boolean variant conflict', e => e.enemiesOnTrue=['green_louse'], /enemiesOnTrue.*lousePool/],
  ['gremlin pool conflict', e => e.gremlinPool=['mad_gremlin'], /gremlinPool/],
  ['gremlin count conflict', e => e.gremlinCount=4, /gremlinCount/],
]) test(id+' rejects '+name, () => {
  const d=setup();mutate(get(d,id));assert.match(validateContent(d).join('\n'),pattern);
});
test('louse fields cannot silently become generic encounter options', () => {
  for (const id of ['cultist_solo','small_slimes','gremlin_gang']) for (const field of ['lousePool','louseCount']) {
    const d=setup();get(d,id)[field]=field==='lousePool'?[...pool]:2;
    assert.match(validateContent(d).join('\n'),new RegExp(field+'.*louse_pair.*louse_trio'));
  }
});
