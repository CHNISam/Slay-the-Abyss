import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('all 75 rules retain original identity while traveler display names stay Chinese',()=>{
  const cards=JSON.parse(readFileSync('data/cards.json','utf8')).cards;
  const display=JSON.parse(readFileSync('data/presentation/traveler.zh-CN.json','utf8')).cards;
  const reference=JSON.parse(readFileSync('data/reference/warrior75.json','utf8')).cards;
  assert.equal(cards.filter(c=>!['status','curse'].includes(c.type)).length,75);
  for(const c of cards){
    assert.match(display[c.id].name,/^[\p{Script=Han}·]+$/u,c.id);
    assert.ok(c.sts_name && c.sts_name!==display[c.id].name,c.id+' keeps the source name separate');
  }
  assert.equal(new Set(Object.values(display).map(c=>c.name)).size,cards.length,'display names are unambiguous');
  for(const c of reference) assert.equal(cards.find(d=>d.id===c.id).sts_name,c.sts_name,c.id);
  for(const [id,name]of Object.entries({dazed:'Dazed',slimed:'Slimed',regret:'Regret',wound:'Wound',burn:'Burn'})){
    assert.equal(cards.find(c=>c.id===id).sts_name,name);
  }
});

test('the 40 existing traveler names survive card pool expansion unchanged',()=>{
  const baseline=JSON.parse(readFileSync('tests/fixtures/traveler-card-names-baseline.json','utf8').replace(/^\uFEFF/,''));
  const display=JSON.parse(readFileSync('data/presentation/traveler.zh-CN.json','utf8')).cards;
  assert.equal(Object.keys(baseline.names).length,40);
  for(const [id,name] of Object.entries(baseline.names)) assert.equal(display[id].name,name,id);
  assert.equal(display.cleave.name,'星陨剑');
  assert.equal(display.whirlwind.name,'岩潮叠嶂');
  assert.equal(display.barricade.name,'永世的磐岩');
});
