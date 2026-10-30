import assert from 'node:assert/strict';
import {mkdirSync,mkdtempSync,rmSync,writeFileSync,readFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {historicalMonsterUiFixtures,historicalMonsterLuaArgs} from './historical-monster-ui-runner.mjs';
import {materializeHistoricalMonsterUi} from './historical-monster-ui-materialize.mjs';
import {frozenBattleHandPrelude} from './battle-life-frozen-hand.mjs';
const script=process.argv[2],timeout=Number(process.argv[3]),started=Date.now(),sourceRoot=process.cwd();
assert.ok(historicalMonsterUiFixtures.includes(script)||script==='battle-refactor-render','only exact historical monster UI fixtures');
const remaining=()=>{const value=timeout-(Date.now()-started);assert(value>0,'historical monster UI exceeded original total deadline');return value;};
mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/historical-monster-ui-'));
console.log('Historical pre-multi monster UI replay (03266f66) only: unchanged frozen cases/scenes; not current source-port acceptance.');
try{
 materializeHistoricalMonsterUi(directory,sourceRoot);
 for(const builder of ['build-lua-data.mjs','build-ui.mjs']){
  const result=spawnSync(process.execPath,['scripts/'+builder],{cwd:directory,encoding:'utf8',timeout:remaining(),maxBuffer:1024*1024});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 }
 const {luaString,toLua}=await import(pathToFileURL(join(directory,'scripts/build-lua-data.mjs')));
 const {battleLayout}=await import(pathToFileURL(join(directory,'scripts/ui-layout.mjs')));
 const cli=createRequire(import.meta.url).resolve('fengari-node-cli/src/lua-cli.js');
 const prelude=frozenBattleHandPrelude(script,{cwd:sourceRoot});
 const entry=join(directory,'build/historical-ui-case.lua');
 const execute=source=>{
  writeFileSync(entry,source);
  const result=spawnSync(process.execPath,historicalMonsterLuaArgs(cli,`dofile(${luaString(entry)})`),{cwd:directory,encoding:'utf8',timeout:remaining(),maxBuffer:script==='battle-refactor-render'?64*1024*1024:1024*1024,
   env:{...process.env,LUA_PATH:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_PATH_5_3:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_INIT:'',LUA_INIT_5_3:''}});
  if(result.error||result.signal){
   process.stdout.write(result.stdout??'');process.stderr.write(result.stderr??'');
   throw new Error(result.error?`Historical Fengari failed: ${result.error.message}`:`Historical Fengari terminated by ${result.signal}`,{cause:result.error});
  }
  return result;
 };
 if(script==='battle-refactor-render'){
  process.chdir(directory);
  const {preBattleRefactorSource}=await import(pathToFileURL(join(directory,'tests/helpers/battle-refactor-projection.mjs')));
  const current=readFileSync('src/lua/abyss_battle_ui.lua','utf8');
  const baseline=preBattleRefactorSource('src/lua/abyss_battle_ui.lua',current);
  assert.notEqual(baseline,current,'historical before/after must execute distinct reviewed implementations');
  const capture=source=>{
   const r=execute(`ABYSS_TEST_LAYOUT=${toLua(battleLayout())}\n${source?`package.loaded.abyss_battle_ui=assert(load(${luaString(source)}))()\n`:''}dofile('scripts/battle-ui-preview.lua')\n`);
   assert.equal(r.status,0,r.stdout+r.stderr);
   const scenes=r.stdout.split('\n').find(line=>line.startsWith('[{'));assert.ok(scenes,'existing preview must emit native scene trees');return JSON.parse(scenes);
  };
  const before=capture(baseline),after=capture();
  console.log(JSON.stringify({before,after}));
 }else{
  const layout=script.includes('battle_ui_card_play')?'':`ABYSS_TEST_LAYOUT=${toLua(battleLayout())}\n`;
  const result=execute(`${layout}${prelude}dofile(${luaString(script)})`);
  process.stdout.write(result.stdout);process.stderr.write(result.stderr);process.exitCode=result.status??1;
 }
}finally{process.chdir(sourceRoot);rmSync(directory,{recursive:true,force:true});}
