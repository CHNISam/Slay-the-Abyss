import {preBetaCurrentTestSource} from './helpers/beta-current-test-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
test('Act2 enemy intentions describe healing, cleanse and life-drain without changing combat',()=>{
 for(const file of ['act2_intent_ui.lua','act2_intent_ui_slice_2.lua']){
  const result=runLua('tests/lua/'+file,{timeout:30000});
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/ACT2_INTENT_UI_PASS 7/);
 }
});

test('both intent slices retain every original assertion and cover all fourteen cases once',()=>{
 const source=preBetaCurrentTestSource('tests/lua/support/act2_intent_ui_cases.lua',readFileSync('tests/lua/support/act2_intent_ui_cases.lua','utf8')).replaceAll('\r\n','\n');
 const cases=[...source.matchAll(/^function\(\)\n([\s\S]*?)\nend,\n/gm)].map(m=>m[1]);
 assert.equal(cases.length,14);
 const original=source.slice(0,source.indexOf('local cases={\n'))+cases.join('')+"print('ACT2_INTENT_UI_PASS 14')\n";
 assert.equal(createHash('sha256').update(original).digest('hex'),'169b05dc33fb3268924f6a345a2697cee54b5ea67e1302b5a3ffc96536d9730e');
 for(const [file,first,last] of [['act2_intent_ui.lua',1,7],['act2_intent_ui_slice_2.lua',8,14]])
  assert.equal(readFileSync('tests/lua/'+file,'utf8').trim(),`dofile('tests/lua/support/act2_intent_ui_cases.lua')(${first},${last})`);
});
