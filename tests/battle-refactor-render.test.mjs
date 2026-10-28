import {preBattleRefactorSource} from './helpers/battle-refactor-projection.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
import {luaString,toLua} from '../scripts/build-lua-data.mjs';
import {battleLayout} from '../scripts/ui-layout.mjs';

test('existing real battle preview preserves every resolved native scene across responsibility extraction',()=>{
 const baseline=preBattleRefactorSource('src/lua/abyss_battle_ui.lua',readFileSync('src/lua/abyss_battle_ui.lua','utf8'));
 const entry=join(tmpdir(),'abyss-battle-differential-'+randomUUID()+'.lua');
 function capture(source){
  writeFileSync(entry,`ABYSS_TEST_LAYOUT=${toLua(battleLayout())}\n${source?`package.loaded.abyss_battle_ui=assert(load(${luaString(source)}))()\n`:''}dofile('scripts/battle-ui-preview.lua')\n`);
  const result=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'-e',`dofile(${luaString(entry)})`],{encoding:'utf8',timeout:120000,maxBuffer:64*1024*1024,env:{...process.env,LUA_PATH:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_PATH_5_3:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_INIT:'',LUA_INIT_5_3:''}});
  assert.ifError(result.error);
  assert.equal(result.status,0,result.stdout+result.stderr);
  const scenes=result.stdout.split('\n').find(line=>line.startsWith('[{'));
  assert.ok(scenes,'existing preview must emit its native scene trees');
  return JSON.parse(scenes);
 }
 try{const before=capture(baseline),after=capture();assert.ok(before.length>=10);assert.deepEqual(after,before);}finally{unlinkSync(entry);}
});
