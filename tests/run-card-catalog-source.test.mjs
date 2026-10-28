import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';

const registration=JSON.parse(readFileSync('data/reference/sts1-card-pools/registration.json','utf8')).registration;
const colors=new Set(['RED','GREEN','BLUE','PURPLE']);
const snake=s=>s.replace(/([A-Z]+)([A-Z][a-z])/g,'$1_$2').replace(/([a-z\d])([A-Z])/g,'$1_$2').toLowerCase();
const aliases={Strike_Red:'strike',Defend_Red:'defend',ThunderClap:'thunderclap',AThousandCuts:'thousand_cuts',
 ConserveBattery:'charge_battery',Heatsinks:'heat_sinks',Defend_Watcher:'defend_purple',Judgement:'judgment'};
const expected=new Map(registration.filter(c=>colors.has(c.color)).map(c=>[aliases[c.class]||snake(c.class),c]));
function verify(rows){
 assert.equal(expected.size,300);assert.equal(rows.length,300);
 const actual=new Map(rows.map(row=>[row[0],row]));assert.equal(actual.size,300);
 for(const [id,want]of expected){
  const got=actual.get(id);assert.ok(got,`fixed class ${want.class} must exist under stable local ${id}`);
  assert.equal(got[1],want.id,`sourceId ${id}`);
  assert.equal(got[2],want.type.toLowerCase(),`type ${id}`);
  assert.equal(got[3],want.color.toLowerCase(),`color ${id}`);
  assert.equal(got[4],want.rarity.toLowerCase(),`rarity ${id}`);
  assert.equal(got[5],String(want.tags.includes('HEALING')),`actual HEALING ${id}`);
  assert.equal(Number(got[6]),want.cost,`base cost ${id}`);
 }
}
let rows;
test('ordinary Run definitions match all independent fixed300 registration classes and actual HEALING tags',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/run_card_catalog_export.lua');assert.equal(result.status,0,result.stderr);
 rows=result.stdout.split(/\r?\n/).filter(line=>line.startsWith('CATALOG\t')).map(line=>line.split('\t').slice(1));verify(rows);
});
test('another valid registered source ID and metadata-only HEALING cannot conceal incorrect actual definitions',()=>{
 assert.ok(rows,'runtime definitions were exported');
 for(const [id,column,value,message]of [['cold_snap',1,'Coolheaded','sourceId cold_snap'],['self_repair',5,'false','actual HEALING self_repair']]){
  const mutated=rows.map(row=>[...row]);mutated.find(row=>row[0]===id)[column]=value;
  assert.throws(()=>verify(mutated),new RegExp(message));
 }
});
