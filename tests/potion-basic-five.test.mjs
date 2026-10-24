import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {validateTheme} from '../scripts/build-ui-theme.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const specs=[['swift_potion','Swift Potion','common','self','draw',null,3],['weak_potion','Weak Potion','common','enemy_one','applyStatus','weak',3],['fear_potion','FearPotion','common','enemy_one','applyStatus','vulnerable',3],['ancient_potion','Ancient Potion','uncommon','self','gainStatus','artifact',1],['liquid_bronze','LiquidBronze','uncommon','self','gainStatus','thorns',3]];
test('five production definitions retain fixed-source potency/rarity/targets and explicit pending acquisition',()=>{
 const data=loadContent('data');assert.deepEqual(validateContent(data),[]);
 const catalog=JSON.parse(readFileSync('data/catalogs/sts1-ironclad-potions.json','utf8'));
 const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
 for(const [id,sourceId,rarity,targetPolicy,op,status,value] of specs){
  const p=data.potions.potions.find(p=>p.id===id);assert(p,id);
  assert.equal(p.rarity,rarity);assert.equal(p.targetPolicy,targetPolicy);assert.equal(p.acquisitionPending,true);
  assert.deepEqual(p.effects,[{op,...status&&{status},value}]);
  const source=catalog.pool.find(p=>p.sourceId===sourceId);assert.equal(source.rarity,rarity);assert.equal(source.basePotencyA0,value);
  assert(!manifest.potions.some(p=>p.id===id));assert(manifest.exclusions.potions.some(p=>p.id===id&&p.reason.includes('33')));
 }
 const theme=JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));assert.deepEqual(validateTheme(theme,data),[]);
});
test('normal Run potion entry executes all five effects and atomic failures',()=>{
 buildLuaData();const result=runLua('tests/lua/potion_basic_five.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);assert.match(result.stdout,/LUA_POTION_BASIC_FIVE_PASS 11/);
});
test('pending acquisition preserves old trajectories and its removal admits all five bottles',()=>{
 const result=runLua('tests/lua/potion_basic_five_acquisition.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);assert.match(result.stdout,/LUA_POTION_BASIC_FIVE_ACQUISITION_PASS 1/);
});
