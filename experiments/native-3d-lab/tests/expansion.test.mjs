import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import luaparse from 'luaparse';
import {instrumentEntry} from '../build.mjs';
import {expansionEntry} from '../expand.mjs';
import {expansionControls} from '../expansion-layout.mjs';
import {assertNativeUiCapacity} from '../../../scripts/build-ui.mjs';
test('one existing entry hosts all additional samples and destroys them before the old lab',()=>{
 const oldId='12345678-1234-1234-1234-123456789abc',newId='12345678-1234-1234-1234-123456789def';
 const base=instrumentEntry(readFileSync('src/lua/abyss_ui.lua','utf8'),oldId);
 const result=expansionEntry(base,oldId,newId);
 assert.doesNotThrow(()=>luaparse.parse(result,{luaVersion:'5.3'}));
 assert.equal(result.match(/function OnStart\(/g).length,1);
 assert.ok(result.indexOf('expansion:destroy()')<result.indexOf('lab:destroy()'));
 assert.ok(!result.includes(oldId));assert.ok(result.includes(newId));
 assert.throws(()=>expansionEntry(result,newId,oldId),/anchor changed/);
});
test('new UI is three bounded sample buttons and runtime/probe preserve failure boundaries',()=>{
 assertNativeUiCapacity({controls:[expansionControls()]});
 for(const file of ['expansion-runtime.lua','runtime.lua','selector/runtime.lua'])assert.doesNotThrow(()=>luaparse.parse(readFileSync('experiments/native-3d-lab/'+file,'utf8'),{luaVersion:'5.3'}));
 const probe=readFileSync('experiments/native-3d-lab/motion-probe.mjs','utf8');
 assert.match(probe,/diagnostic:skill_entered_1ms/);assert.match(probe,/return;/);
 assert.ok(!probe.includes('completed:attack'));
});
