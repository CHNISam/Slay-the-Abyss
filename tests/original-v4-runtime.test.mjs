import {toLua} from '../scripts/build-lua-data.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
const vectors=JSON.parse(readFileSync('tests/fixtures/original-v4-production-vectors.json','utf8'));
test('production vector identities match both frozen inputs',()=>{
  assert.equal(vectors.cases.length,1200);
  for(const [file,key] of [['cards_v4.json','cardsSha256'],['rules_v4.json','rulesSha256']])
    assert.equal(createHash('sha256').update(readFileSync('data/original_v4/'+file)).digest('hex'),vectors[key]);
});
test('all 38 declared V4 direct changes match both production card versions',()=>{
  const cards=JSON.parse(readFileSync('data/original_v4/cards_v4.json','utf8')).cards;
  assert.equal(vectors.directChanges.length,38);
  assert.equal(new Set(vectors.directChanges.map(c=>c.id)).size,38);
  for(const expected of vectors.directChanges){
    const actual=cards.find(c=>c.id===expected.id);
    for(const level of ['base','upgrade'])assert.deepEqual(actual[level],expected[level],`${expected.id} ${level}`);
  }
});
test('original role atomicity, shared modifiers and critical enemy boundaries',()=>{
  const r=runLua('tests/fixtures/js-owned/tests/lua/original_v4_contract.lua');assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/ORIGINAL_V4_CONTRACT_PASS 19/);
});
for(const role of ['ht','ar','fr','rd'])for(const level of ['base','upgrade'])for(const scenario of ['lean','rich']){
  test(`${role} ${level} ${scenario}: all 75 real queue/actor resolutions match frozen expectations`,()=>{
    const value={version:vectors.version,cases:vectors.cases.filter(c=>c.role===role.toUpperCase()&&c.upgraded===(level==='upgrade')&&c.scenario===scenario)};
    const expected="-- Generated from independently frozen V4 expectations. Do not hand-edit values.\ndofile('tests/lua/support/original_v4_card_cases.lua').run('"+role.toUpperCase()+"',"+(level==='upgrade')+",'"+scenario+"',"+toLua(value)+")\n";
    assert.equal(readFileSync(`tests/fixtures/js-owned/tests/lua/original_v4_${role}_${level}_${scenario}.lua`,'utf8'),expected,'Lua expectations must exactly match independent JSON');
    const r=runLua(`tests/fixtures/js-owned/tests/lua/original_v4_${role}_${level}_${scenario}.lua`);assert.equal(r.status,0,r.stdout+r.stderr);
    assert.match(r.stdout,new RegExp(`ORIGINAL_V4_VECTORS_PASS ${role.toUpperCase()} ${level} ${scenario} 75`));
  });
}
