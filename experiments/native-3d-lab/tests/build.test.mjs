import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import luaparse from 'luaparse';
import {instrumentEntry} from '../build.mjs';
import {labControls} from '../layout.mjs';
import {assertNativeUiCapacity} from '../../../scripts/build-ui.mjs';
import {equivalent,normalizeUi} from '../../../scripts/native-candidate-audit.mjs';
import {uiEquivalent} from '../ui-readback.mjs';
const id='12345678-1234-1234-1234-123456789abc';
test('experimental entry keeps production startup and owns lab lifecycle plus typed bridge',()=>{
  const source=readFileSync('src/lua/abyss_ui.lua','utf8');
  const entry=instrumentEntry(source,id);
  assert.doesNotThrow(()=>luaparse.parse(entry,{luaVersion:'5.3'}));
  assert.equal(entry.match(/function OnStart\(/g).length,1);
  assert.equal(entry.match(/function OnDestroy\(/g).length,1);
  assert.match(entry,/signal:AddString\(command\)[\s\S]*signal:AddInt\(model\)[\s\S]*signal:AddInt\(actor\)[\s\S]*signal:AddInt\(sequence\)/);
  assert.match(entry,/pcall\(lab.update, lab, dt\)/);
  assert.match(entry,/ABYSS_BUILD 12345678-1234-1234-1234-123456789abc/);
  assert.match(entry,/lab:destroy\(\)/);
  assert.throws(()=>instrumentEntry(entry,id),/anchor changed/);
  assert.throws(()=>instrumentEntry(source,'bad'),/Invalid/);
});
test('all experiment controls stay within native child/font capacity',()=>{
  const controls=labControls();assertNativeUiCapacity({controls:[controls]});
  const menu=controls.children.find(n=>n.name==='menu');
  for(const name of ['compare','model','animations','combat','cards','performance','all','stop','reset'])
    assert.ok(menu.children.some(n=>n.name===name),name);
});
test('native readback accepts codec quantization but rejects meaningful geometry and text changes',()=>{
  const source=[{name:'sample',kind:'image',position:[1/3,2/3],size:[80,120],image:100001,opacity:.5}];
  const actual=[{name:'sample',kind:'image',position:[.3333,.6667],size:[80,120],image:100001,opacity:128/255}];
  assert.ok(equivalent(normalizeUi(source,'controls',true),normalizeUi(actual),'controls'));
  actual[0].position[0]=.334;assert.equal(equivalent(normalizeUi(source,'controls',true),normalizeUi(actual),'controls'),false);
  const a=[{name:'text',kind:'text',text:{content:'原生未验证'}}],b=[{name:'text',kind:'text',text:{content:'已验证'}}];
  assert.equal(equivalent(normalizeUi(a,'controls',true),normalizeUi(b),'controls'),false);
});
test('native empty-container default does not excuse missing nonempty children or metadata',()=>{
  const expected={name:'Lab',controls:[{name:'empty',kind:'container',children:[]}]};
  const actual={name:'Lab',controls:[{name:'empty',kind:'container'}]};
  assert.ok(uiEquivalent(expected,actual));
  expected.controls[0].children.push({name:'required',kind:'text',text:{content:'HP'}});
  assert.equal(uiEquivalent(expected,actual),false);
  expected.controls[0].children=[];actual.blockKeys=true;
  assert.equal(uiEquivalent(expected,actual),false);
});
test('native minimum font default is exactly 20, and every other minimum stays strict',()=>{
  const actual={name:'Lab',controls:[{name:'label',kind:'text',text:{content:'HP'}}]};
  const expected=structuredClone(actual);expected.controls[0].text.minFontSize=20;
  assert.ok(uiEquivalent(expected,actual));
  for(const size of [14,16,21]){expected.controls[0].text.minFontSize=size;assert.equal(uiEquivalent(expected,actual),false);}
});
