import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
const ids=['regret','injury','shame','parasite','normality','doubt','writhe','pain','decay','clumsy'];
test('ten basic curses retain fixed library selection order and Chinese presentation',()=>{
 const data=loadContent('data');
 const pools=JSON.parse(readFileSync('data/reference/sts1-card-pools/pools.json','utf8'));
 const display=JSON.parse(readFileSync('data/presentation/traveler.zh-CN.json','utf8')).cards;
 const defs=ids.map(id=>data.cards.cards.find(c=>c.id===id));
 assert.deepEqual(data.cards.cards.filter(c=>c.type==='curse').map(c=>c.id).sort(),[...ids,'curse_of_the_bell'].sort());
 const bell=data.cards.cards.find(c=>c.id==='curse_of_the_bell');
 assert.equal(bell.sourceId,'CurseOfTheBell');assert.equal(bell.cost,-2);assert.deepEqual(bell.effects,[]);
 assert.ok(!pools.pools.curseLibrarySelection.includes(bell.sourceId),'Calling Bell curse must not enter the ordinary random curse library');
 assert.deepEqual(defs.map(c=>c.sts_name),pools.pools.curseLibrarySelection);
 for(const c of defs){ assert.equal(c.cost,-2);assert.deepEqual(c.effects,[]);assert.equal(c.upgrade,undefined);assert.match(display[c.id].name,/^[\p{Script=Han}·]+$/u);assert.equal(c.name,display[c.id].name);assert.ok(display[c.id].textTemplate); }
 assert.deepEqual(validateContent(data),[]);
});
test('basic curse schema rejects fabricated lifecycle flags and damage values',()=>{
 for(const [id,field,value]of [['regret','ethereal',true],['clumsy','ethereal',false],['writhe','innate',false],['pain','innate',true],['decay','endTurnDamage',3],['injury','cost',0],['parasite','upgrade',{cost:0}]]){
  const data=loadContent('data');data.cards.cards.find(c=>c.id===id)[field]=value;assert.ok(validateContent(data).length>0,`${id}.${field}`);
 }
});
test('real combat commands implement basic curse lifecycle and permanent remove API',()=>{
 buildLuaData();const result=runLua('tests/lua/basic_curses.lua');assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/BASIC_CURSES_PASS 19/);
});
