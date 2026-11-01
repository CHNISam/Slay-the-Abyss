import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const classes=['Rebound','Recursion','ForceField','GeneticAlgorithm','HelloWorld','Recycle','Scrape','SelfRepair','StaticDischarge','Equilibrium','WhiteNoise','AllForOne','Amplify','Buffer','CreativeAI','EchoForm','Fission','MachineLearning','Reboot'];
const snake=name=>name.replace(/([A-Z]+)([A-Z][a-z])/g,'$1_$2').replace(/([a-z\d])([A-Z])/g,'$1_$2').toLowerCase();
const registration=JSON.parse(readFileSync('data/reference/sts1-card-pools/registration.json','utf8')).registration;
const expected=new Map(classes.map(name=>[snake(name),registration.find(row=>row.class===name&&row.sourcePath.startsWith('cards/blue/'))]));
const source=readFileSync('src/lua/abyss_defect_final_cards.lua','utf8');
function verify(text){
 const rows=[...text.matchAll(/\{id='([^']*)',sourceId='([^']*)'/g)].map(m=>[m[1],m[2]]);
 assert.equal(rows.length,19);const actual=new Map(rows);assert.equal(actual.size,19);
 for(const [id,row]of expected){assert.ok(row,`fixed class for ${id}`);assert.equal(actual.get(id),row.id,`sourceId for ${id}`);}
}
test('all 19 Defect final definitions match their independent fixed registration class',()=>verify(source));
test('display class names cannot replace Recursion/Equilibrium stable source IDs',()=>{
 for(const [id,name]of [['recursion','Recursion'],['equilibrium','Equilibrium']]){
  assert.throws(()=>verify(source.replace(new RegExp(`(id='${id}',sourceId=)'[^']*'`),`$1'${name}'`)),new RegExp(`sourceId for ${id}`));
 }
});
test('another registered identity cannot be assigned to Genetic Algorithm',()=>{
 assert.throws(()=>verify(source.replace("id='genetic_algorithm',sourceId='Genetic Algorithm'","id='genetic_algorithm',sourceId='Recycle'")),/sourceId for genetic_algorithm/);
});
