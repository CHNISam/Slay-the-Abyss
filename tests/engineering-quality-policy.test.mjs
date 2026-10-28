import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {policyErrors} from '../scripts/check-engineering-quality.mjs';
import {sha256} from '../scripts/evidence-files.mjs';

const files=['.luacheckrc','config/lua-tools.json'];
const inputs=Object.fromEntries(files.map((f,i)=>[f,(i?'b':'a').repeat(64)]));
const fixture=()=>({schemaVersion:1,measurementContractVersion:1,
  sourceRevision:'48cb48cef5480c6b0cfa32b6269c9390acb1d57a',inputs:{...inputs}});

test('active policy pins exactly the lint/tool inputs and rejects changes, missing pins and exception options',()=>{
  assert.deepEqual(policyErrors(inputs,fixture()),[]);
  for(const file of files)assert.ok(policyErrors({...inputs,[file]:'c'.repeat(64)},fixture()).some(e=>e.file===file));
  for(const change of [p=>delete p.inputs['.luacheckrc'],p=>p.inputs.extra='x',p=>p.measurementContractVersion++,
    p=>p.ignore=['file.lua'],p=>p.sourceRevision='unknown',p=>p.schemaVersion++]) {
    const p=fixture();change(p);assert.ok(policyErrors(inputs,p).length);
  }
  assert.ok(policyErrors(inputs,null).length);
});

test('the active policy is the integrated Enum ownership move, with no new globals, ignores or exclusions',()=>{
  const baseline=JSON.parse(readFileSync('config/engineering-quality-baseline.json','utf8'));
  const policy=JSON.parse(readFileSync('config/engineering-quality-policy.json','utf8'));
  assert.equal(baseline.revision,'1f260a71972b03dae5b63e8d6f12d055973a4c83');
  assert.equal(policy.sourceRevision,'48cb48cef5480c6b0cfa32b6269c9390acb1d57a');
  const actual=Object.fromEntries(files.map(f=>[f,sha256(readFileSync(f,'utf8').replaceAll('\r\n','\n'))]));
  assert.deepEqual(policyErrors(actual,policy),[]);
  const lint=readFileSync('.luacheckrc','utf8').replaceAll('\r\n','\n');
  assert.equal(lint.split('abyss_node_ui_input.lua').length,2);
  assert.equal(sha256(lint.replace('abyss_node_ui_input.lua','abyss_node_ui.lua')),baseline.inputs['.luacheckrc'],
    'every other byte of the historical lint contract is preserved; the existing Enum grant moves with its owner only');
  assert.equal(actual['config/lua-tools.json'],baseline.inputs['config/lua-tools.json']);
});
