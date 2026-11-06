import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

const slices=[['tests/lua/joust_event.lua',[1,2]],['tests/lua/joust_event_slice_2.lua',[3,4,5,6]]];
const cases='tests/lua/support/joust_event_cases.lua';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
// git 31005d173d1147b6b370aac832dd5beaf177cdb3:tests/lua/joust_event.lua,
// not a hash of the newly extracted helper. Reconstruct every original byte.
const originalSha256='5ea9fd9e36215c9bfab708f46a2c71eab2d93bb69fe9a0d6afc857e651ec95c1';
const groupsSha256='68fab1c78b15f48264a11dabc9a9592f4c31a1018e9ecc6d00362cf127f64fc5';
const originalDispatcher="local n=0\nlocal function test(name,fn)fn();n=n+1;print('PASS joust '..n..' '..name)end\n";
const slicedDispatcher=`local n,registered=0,0
local function test(name,fn)
 registered=registered+1
 if registered<first or registered>last then return end
 fn();n=n+1;print('PASS joust '..registered..' '..name)
end
`;
const prefix='return function(first,last)\n';
const summary="print('JOUST_EVENT '..n..' passed')\n";
const suffix="assert(registered==6,'all six original Joust groups must remain registered')\n"
 +"assert(n==last-first+1,'Joust slice group coverage')\n"+summary+'end\n';
function assertOriginalJoust(source){
 source=source.replaceAll('\r\n','\n');
 assert.ok(source.startsWith(prefix)&&source.endsWith(suffix),'Joust extraction envelope');
 assert.equal(source.split(slicedDispatcher).length,2,'Joust has one range-only dispatcher');
 const original=source.slice(prefix.length,-suffix.length).replace(slicedDispatcher,originalDispatcher)+summary;
 assert.equal(hash(original),originalSha256,'Joust complete original fixture identity');
 const groups=original.slice(original.indexOf("test('five source"),original.lastIndexOf(summary));
 assert.equal(hash(groups),groupsSha256,'Joust original ordered groups and bodies');
}
function assertJoustCoverage(outputs){
 assert.deepEqual(outputs.map(output=>output.file),slices.map(([file])=>file),'Joust requires both actual entry outputs');
 const union=[];
 for(const [index,{stdout}]of outputs.entries()){
  const [file,expected]=slices[index];
  const ids=[...stdout.matchAll(/^PASS joust (\d+) .+$/gm)].map(match=>Number(match[1]));
  assert.deepEqual(ids,expected,`Joust executed original groups: ${file}`);
  assert.match(stdout,new RegExp(`^JOUST_EVENT ${expected.length} passed$`,'m'));
  union.push(...ids);
 }
 assert.deepEqual(union,[1,2,3,4,5,6],'Joust original groups 1..6 execute exactly once');
}

test('original Joust fixture bytes and ordered group bodies survive range-only extraction',()=>{
 assert.ok(existsSync(cases),'Joust shared original cases must exist');
 const source=read(cases);assertOriginalJoust(source);assertOriginalJoust(source.replaceAll('\n','\r\n'));
 for(const [file,ids]of slices)assert.equal(read(file),`dofile('${cases}')(${ids[0]},${ids.at(-1)})\n`,'Joust entry only selects a complete original group range');
});
test('original Joust identity rejects seed, assertion, helper and group-order drift',()=>{
 assert.ok(existsSync(cases),'Joust shared original cases must exist');
 const source=read(cases);
 const first=source.indexOf("test('five source"),second=source.indexOf("test('source boolean"),third=source.indexOf("test('stale funds");
 const mutations=[
  source.replace('for seed=0,31 do','for seed=0,30 do'),
  source.replace('for seed=0,15 do','for seed=0,14 do'),
  source.replace("{'bet_against','bet_for'}","{'bet_against'}"),
  source.replace("eq(why,'transaction_failed');same(r,before)","eq(why,'transaction_failed')"),
  source.replace('eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event)','eq(r.nodeFlow,flow)'),
  source.replace('r.gold=100','r.gold=101'),
  source.slice(0,first)+source.slice(second,third)+source.slice(first,second)+source.slice(third),
  source.replace(' if registered<first or registered>last then return end',' if registered<=first or registered>last then return end'),
 ];
 for(const mutation of mutations){assert.notEqual(mutation,source);assert.throws(()=>assertOriginalJoust(mutation),/Joust/);}
});
test('Joust coverage guard rejects missing slices, duplicate groups and range drift',()=>{
 const outputs=slices.map(([file,ids])=>({file,stdout:ids.map(id=>`PASS joust ${id} original group\n`).join('')+`JOUST_EVENT ${ids.length} passed\n`}));
 assertJoustCoverage(outputs);
 for(const mutation of [outputs.slice(0,1),[outputs[0],outputs[0]],
  [outputs[0],{...outputs[1],stdout:outputs[1].stdout.replace('PASS joust 3','PASS joust 2')}],
  [outputs[0],{...outputs[1],stdout:outputs[1].stdout.replace('PASS joust 6 original group\n','')}],
  [outputs[0],{...outputs[1],stdout:outputs[1].stdout.replace('JOUST_EVENT 4 passed','JOUST_EVENT 6 passed')}],
 ])assert.throws(()=>assertJoustCoverage(mutation));
});
test('Joust preserves five screens, exact RNG timing, payout rules and rollback',()=>{
 const outputs=slices.map(([file])=>{
  const started=performance.now(),result=runLua(file);
  assert.equal(result.status,0,result.stdout+result.stderr);
  console.log(`Joust entry ${file}: ${(performance.now()-started).toFixed(3)} ms (original 30000 ms budget)`);
  return {file,stdout:result.stdout};
 });
 assertJoustCoverage(outputs);
});
