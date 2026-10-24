import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('all 75 class cards and their five status/curse tokens retain original names',()=>{
  const cards=JSON.parse(readFileSync('data/cards.json','utf8')).cards;
  const display=JSON.parse(readFileSync('data/presentation/traveler.zh-CN.json','utf8')).cards;
  assert.equal(cards.filter(c=>!['status','curse'].includes(c.type)).length,75);
  for(const c of cards){assert.equal(c.name,c.sts_name,c.id);assert.equal(display[c.id].name,c.sts_name,c.id);}
  for(const [id,name]of Object.entries({dazed:'Dazed',slimed:'Slimed',regret:'Regret',wound:'Wound',burn:'Burn'})){
    assert.equal(cards.find(c=>c.id===id).name,name);
  }
});
