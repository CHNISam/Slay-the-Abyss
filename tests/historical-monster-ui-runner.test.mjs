import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import childProcess from 'node:child_process';
import {syncBuiltinESMExports} from 'node:module';
import {historicalMonsterUiFixtures,runHistoricalMonsterUi,historicalMonsterLuaArgs} from './helpers/historical-monster-ui-runner.mjs';
import {verifiedHistoricalMonsterSources} from './helpers/historical-monster-ui-materialize.mjs';
import {multiMonsterSourceLayer} from './helpers/multi-monster-art-source-inverse.mjs';
const helperPaths=['tests/lua/support/game_ui_fixture.lua','tests/lua/support/battle_gesture_fixture.lua'];
test('only twelve exact frozen fixtures and the two-capture differential are historical',()=>{
 assert.deepEqual(historicalMonsterUiFixtures,[
  'tests/lua/battle_ui.lua',...Array.from({length:6},(_,i)=>`tests/lua/battle_ui_slice_${i+2}.lua`),
  'tests/lua/battle_ui_card_play.lua','tests/lua/battle_ui_card_play_slice_2.lua','tests/lua/battle_ui_card_play_slice_3.lua',
 'tests/lua/battle_ui_drag_click_compatibility.lua','tests/lua/battle_ui_drag_click_compatibility_slice_2.lua',
 ]);
 for(const path of ['tests/lua/game_ui.lua','tests/lua/support/battle_ui_cases.lua','tests/lua/battle_ui_slice_8.lua','../tests/lua/battle_ui.lua','/tests/lua/battle_ui.lua'])
  assert.throws(()=>runHistoricalMonsterUi(path),/only exact/);
 assert.throws(()=>runHistoricalMonsterUi(historicalMonsterUiFixtures[0],{caseName:'skip others'}),/complete frozen/);
});
test('full current inverse and both historical helper closures reject every foreign edit',()=>{
 const paths=[...Object.keys(multiMonsterSourceLayer.files),...helperPaths];
 const current=new Map(paths.map(p=>[p,readFileSync(p,'utf8')]));
 assert.equal(verifiedHistoricalMonsterSources('.',p=>current.get(p)).length,paths.length);
 for(const dirty of paths)assert.throws(()=>verifiedHistoricalMonsterSources('.',p=>current.get(p)+(p===dirty?'\n-- foreign source drift\n':'')),/unreviewed current/);
 for(const dirty of paths)assert.throws(()=>verifiedHistoricalMonsterSources('.',p=>p===dirty?'':current.get(p)),/unreviewed current/);
 assert.equal(verifiedHistoricalMonsterSources('.',p=>current.get(p).replaceAll('\r\n','\n').replaceAll('\n','\r\n')).length,paths.length);
});
test('historical child keeps original total deadlines, buffer, signals and full error output',()=>{
 const original=childProcess.spawnSync,calls=[];
 let result={status:0,signal:null,stdout:'ok',stderr:''};
 childProcess.spawnSync=(...args)=>{calls.push(args);return result;};syncBuiltinESMExports();
 try{
  for(const script of historicalMonsterUiFixtures){
   calls.length=0;assert.equal(runHistoricalMonsterUi(script),result);
   assert.equal(calls.length,1);assert.match(calls[0][1][0],/historical-monster-ui-entry\.mjs$/);
   assert.equal(calls[0][1][1],script);assert.equal(calls[0][2].timeout,(script.includes('card_play')||script.includes('drag_click_compatibility'))?30000:60000);
   assert.equal(calls[0][2].maxBuffer,1024*1024);
  }
  calls.length=0;runHistoricalMonsterUi('battle-refactor-render');assert.equal(calls[0][2].timeout,120000);assert.equal(calls[0][2].maxBuffer,64*1024*1024);
  calls.length=0;runHistoricalMonsterUi(historicalMonsterUiFixtures[0],{timeout:321});assert.equal(calls[0][2].timeout,321);
  const error=new Error('original ETIMEDOUT');result={error,status:null,signal:'SIGTERM',stdout:'已执行组\n',stderr:'原始错误\n'};
  assert.throws(()=>runHistoricalMonsterUi(historicalMonsterUiFixtures[0]),e=>e.cause===error&&e.message.includes('已执行组')&&e.message.includes('原始错误'));
  result={status:null,signal:'SIGKILL',stdout:'',stderr:''};assert.throws(()=>runHistoricalMonsterUi(historicalMonsterUiFixtures[0]),/terminated by SIGKILL/);
  result={status:7,signal:null,stdout:'actual Lua failure',stderr:'stack'};assert.equal(runHistoricalMonsterUi(historicalMonsterUiFixtures[0]),result);
 }finally{childProcess.spawnSync=original;syncBuiltinESMExports();}
});

test('historical Fengari alone has an exact 1GiB old-space cap without changing its script',()=>{
 assert.deepEqual(historicalMonsterLuaArgs('/pinned/fengari.lua-cli.js','dofile(\"unchanged\")'),['--max-old-space-size=1024','/pinned/fengari.lua-cli.js','-e','dofile(\"unchanged\")']);
 const entry=readFileSync(new URL('./helpers/historical-monster-ui-entry.mjs',import.meta.url),'utf8');
 assert.match(entry,/spawnSync\(process\.execPath,historicalMonsterLuaArgs\(cli,/);
 assert.doesNotMatch(entry,/NODE_OPTIONS\s*[:=]/);
});
