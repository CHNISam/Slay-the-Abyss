import assert from 'node:assert/strict';
import {writeFileSync,readFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHistoricalRuntimeRoots,applyHistoricalRuntimeTarget} from './historical-runtime-root.mjs';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {historicalMonsterUiFixtures,historicalMonsterLuaArgs} from './historical-monster-ui-runner.mjs';
import {verifiedHistoricalMonsterSources} from './historical-monster-ui-materialize.mjs';
import {frozenBattleHandPrelude} from './battle-life-frozen-hand.mjs';
import {approvedHistoricalBattleMonolith} from './approved-battle-responsibilities.mjs';
import {multiMonsterSourceLayer} from './multi-monster-art-source-inverse.mjs';
const script=process.argv[2],timeout=Number(process.argv[3]),started=Date.now(),originalCwd=process.cwd();
assert.ok(historicalMonsterUiFixtures.includes(script)||script==='battle-refactor-render','only exact historical monster UI fixtures');
const remaining=()=>{const value=timeout-(Date.now()-started);assert(value>0,'historical monster UI exceeded original total deadline');return value;};
const originalBattleUi=/^tests\/lua\/battle_ui(?:_slice_[2-7])?\.lua$/.test(script);
const runtime=createHistoricalRuntimeRoots({source:false,target:originalBattleUi?'battleUi':undefined}),{directory,inputs}=runtime;
console.error('HISTORICAL_STAGED '+(Date.now()-started)+'ms');
console.log(originalBattleUi
 ? 'Original #372 battle UI input replay (38f4dd8aea7fa77370146e616700c68fd1bea911): unchanged frozen bodies/support/seeds; not current source-port acceptance.'
 : 'Historical pre-multi monster UI replay (03266f66) only: unchanged frozen cases/scenes; not current source-port acceptance.');
try{
 process.chdir(directory);
 // Validate the complete original closure before changing this private root.
 // This reader belongs to this call; no projected or dirty input is reused.
 if(!originalBattleUi){
  const readOriginal=path=>{assert.ok(Object.hasOwn(inputs,path),'registered original monster input: '+path);return inputs[path].toString('utf8');};
  const projected=verifiedHistoricalMonsterSources(directory,readOriginal);
  applyHistoricalRuntimeTarget(directory,Object.fromEntries(projected));
 }
 console.error('HISTORICAL_PROJECTED '+(Date.now()-started)+'ms');
 process.chdir(directory);
 for(const builder of ['build-lua-data.mjs','build-ui.mjs']){
  const result=spawnSync(process.execPath,['scripts/'+builder],{cwd:directory,encoding:'utf8',timeout:remaining(),maxBuffer:1024*1024});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 }
 console.error('HISTORICAL_BUILT '+(Date.now()-started)+'ms');
 const {luaString,toLua}=await import(pathToFileURL(join(directory,'scripts/build-lua-data.mjs')));
 const {battleLayout}=await import(pathToFileURL(join(directory,'scripts/ui-layout.mjs')));
 const cli=createRequire(import.meta.url).resolve('fengari-node-cli/src/lua-cli.js');
 const prelude=frozenBattleHandPrelude(script,{cwd:originalCwd});
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
  const current=readFileSync('src/lua/abyss_battle_ui.lua','utf8');
  assert.equal(current,multiMonsterSourceLayer.files['src/lua/abyss_battle_ui.lua'].beforeSource,'capture executes the exact materialized historical host');
  const baseline=approvedHistoricalBattleMonolith;
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
}finally{runtime.close();}
