import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {validateTheme} from '../scripts/build-ui-theme.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const specs=[['swift_potion','Swift Potion','common','self','draw',null,3],['weak_potion','Weak Potion','common','enemy_one','applyStatus','weak',3],['fear_potion','FearPotion','common','enemy_one','applyStatus','vulnerable',3],['ancient_potion','Ancient Potion','uncommon','self','gainStatus','artifact',1],['liquid_bronze','LiquidBronze','uncommon','self','gainStatus','thorns',3]];
const budget=JSON.parse(readFileSync('tests/fixtures/potion-basic-five-budget.json','utf8'));
const readLF=file=>readFileSync(file,'utf8').replaceAll('\r\n','\n');
const sha=text=>createHash('sha256').update(text).digest('hex');
function assertPartition(){
 assert.equal(budget.base,'28869011c26bcead7f925e78f00dbda454daa231');
 assert.equal(budget.originalLogicalGroups,11);assert.equal(budget.originalAcquisitionGroups,1);
 assert.equal(budget.defaultLuaTimeoutMilliseconds,30000);assert.equal(budget.slices.length,4);
 const actual={production:[],refusals:[],overflow:[]},sizes=[];
 for(const part of budget.slices){
  const source=readLF(`tests/fixtures/js-owned/tests/lua/${part.file}`);
  assert.equal(sha(source.slice(0,source.indexOf('test('))),budget.headerSha256LF,`${part.file}: original bindings`);
  const loops=[...source.matchAll(/ for _,(?:id|spec) in ipairs\((.*?)\) do\n([\s\S]*?)\n end/g)];
  assert.equal(loops.length,1,`${part.file}: one bounded original loop`);
  assert.equal(sha(loops[0][2]),budget.originalBodySha256LF[part.section],`${part.file}: original body/each assertion`);
  const inputs=[...loops[0][1].matchAll(/'([^']*)'/g)].map(m=>m[1]);actual[part.section].push(...inputs);
  if(part.section==='refusals')sizes.push(inputs.length);
  assert.equal(part.count,1);assert.equal(part.logicalCount,1);
  assert.ok(source.endsWith(`H.finish(1,'${part.marker}')\n`));
 }
 assert.deepEqual(actual,budget.originalInputs);assert.deepEqual(sizes,[2,3]);
 assert.deepEqual(actual.production,specs.map(p=>p[0]));assert.deepEqual(actual.refusals,actual.production);
 assert.deepEqual(actual.overflow,['ancient_potion','artifact','liquid_bronze','thorns','weak_potion','weak','fear_potion','vulnerable']);
 for(const [file,hash]of Object.entries(budget.unchangedSha256LF))assert.equal(sha(readLF(file)),hash,`${file}: original fixture/helper unchanged`);
}

test('bounded partitions retain every original bottle, overflow pair and assertion exactly once',assertPartition);
test('five production definitions retain fixed-source potency/rarity/targets in the complete source pool',()=>{
 const data=loadContent('data');assert.deepEqual(validateContent(data),[]);
 const catalog=JSON.parse(readFileSync('data/catalogs/sts1-ironclad-potions.json','utf8'));
 for(const [id,sourceId,rarity,targetPolicy,op,status,value] of specs){
  const p=data.potions.potions.find(p=>p.id===id);assert(p,id);
  assert.equal(p.rarity,rarity);assert.equal(p.targetPolicy,targetPolicy);assert.equal(p.acquisitionPending,undefined);
  assert.deepEqual(p.effects,[{op,...status&&{status},value}]);
  const source=catalog.pool.find(p=>p.sourceId===sourceId);assert.equal(source.rarity,rarity);assert.equal(source.basePotencyA0,value);
 }
 const theme=JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));assert.deepEqual(validateTheme(theme,data),[]);
});
test('normal Run potion entry executes all five effects and atomic failures',()=>{
 buildLuaData();assertPartition();let physical=0;const logical=new Map();
 for(const {file,marker,count,logicalGroup,logicalCount} of [
  ...budget.slices,
  {file:'potion_basic_five_draw.lua',marker:'LUA_POTION_BASIC_FIVE_DRAW_PASS',count:5,logicalGroup:'draw',logicalCount:5},
  {file:'potion_basic_five_status.lua',marker:'LUA_POTION_BASIC_FIVE_STATUS_PASS',count:4,logicalGroup:'status',logicalCount:4},
 ]){
  const started=Date.now();
  const result=runLua(`tests/fixtures/js-owned/tests/lua/${file}`);
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,new RegExp(`^${marker} ${count}$`,'m'));
  console.log(`Lua fixture ${file}: ${Date.now()-started} ms`);
  physical+=count;
  if(logical.has(logicalGroup))assert.equal(logical.get(logicalGroup),logicalCount);
  logical.set(logicalGroup,logicalCount);
 }
 assert.equal(physical,13);assert.equal([...logical.values()].reduce((a,b)=>a+b,0),11);
});
test('missing definitions cannot alter or renormalize complete source acquisition trajectories',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/potion_basic_five_acquisition.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);assert.match(result.stdout,/LUA_POTION_BASIC_FIVE_ACQUISITION_PASS 1/);
});

test('snapshot comparison preserves values, all fields, bidirectional aliases and cycles',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/potion_basic_five_graph.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);
 assert.match(result.stdout,/^LUA_POTION_BASIC_FIVE_GRAPH_PASS 6$/m);
});
