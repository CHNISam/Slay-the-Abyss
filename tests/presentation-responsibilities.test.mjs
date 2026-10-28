import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {toLua} from '../scripts/build-lua-data.mjs';

const evidence=readFileSync('docs/reviews/official-update-log-removal-20261028.json.gz');
assert.equal(createHash('sha256').update(evidence).digest('hex'),'02cc28a2c1d8478b3d790645b7a73e2f120ba9f3d2c4cfdc22ad1f31f5b9c2b9');
const proof=JSON.parse(gunzipSync(evidence));
const entryBytes=readFileSync('docs/reviews/formal-entry-native-insertions-20261028.json.gz');
assert.equal(createHash('sha256').update(entryBytes).digest('hex'),'8abd6d09c39c11e43fdd708dc1e62cb8afd2c770acdd078e344b8369a1d8bad6');
const entryProof=JSON.parse(gunzipSync(entryBytes));
const retired=row=>/^\{1=string:root\/(?:releaseNotesPanel|menuPanel\/releaseNotes),/.test(row);
function traceHash(entries){
 let value=0;
 for(const row of entries)for(const byte of Buffer.from(row+'\n'))value=(value*131+byte)%2147483647;
 return value;
}
function verifyRetirement(entries){
 assert.equal(proof.base,'5a27fea79ba9d33ca5486b8fc6044a98ab81d41b');
 assert.equal(proof.before.length,79543);assert.equal(traceHash(proof.before),1215629804,'old room-port trace remains frozen');
 const removed=proof.before.flatMap((row,index)=>retired(row)?[{index,row}]:[]);
 assert.equal(removed.length,68,'only 68 entry/panel native visibility writes retire');
 assert.deepEqual(removed,proof.removed,'each removed value and original global position is bound');
 const expected=proof.before.filter(row=>!retired(row));
 assert.equal(expected.length,79475);assert.equal(traceHash(expected),1007819925);
 assert.deepEqual(entries,expected,'every other native write retains its exact value and global order');
 return expected;
}
function formalExpected(){
 const before=verifyRetirement(proof.before.filter(row=>!retired(row)));
 assert.equal(entryProof.beforeCount,before.length);assert.equal(entryProof.beforeHash,traceHash(before));
 const rows=[];let old=0;
 for(const insertion of entryProof.insertions){
  while(rows.length<insertion.at)rows.push(before[old++]);
  assert.equal(old,insertion.afterOld);
  const selection=insertion.row.startsWith('{1=string:root/characterPanel');
  const choice=/^\{1=string:root\/choicePanel,2=string:(?:SetVisible,3=\{1=boolean:false\}|visible,3=boolean:false)\}$/.test(insertion.row);
  assert.ok(selection||choice||old>=1564&&old<=1566,'extra redraws occur only while the no-Run selection page opens');
  rows.push(insertion.row);
 }
 rows.push(...before.slice(old));
 assert.equal(rows.length,81178);assert.equal(traceHash(rows),580852422);
 assert.equal(entryProof.insertions.length,1703);
 return rows;
}
function runConservedTrace(){
 const expected=formalExpected();
 // Encode repeated rows once; every ordered write is still checked individually.
 const rows=[],order=[],ids=new Map();
 for(const row of expected){
  if(!ids.has(row)){rows.push(row);ids.set(row,rows.length);}
  order.push(ids.get(row));
 }
 assert.deepEqual(order.map(index=>rows[index-1]),expected);
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/announcement-retirement-'));
 try{
  const source=readFileSync('tests/lua/presentation_responsibilities_trace.lua','utf8').replaceAll('\r\n','\n');
  const binding="local Trace=dofile('tests/lua/support/presentation_trace.lua')\n";
  assert.equal(source.split(binding).length,2,'one unchanged strict recorder binding');
  const guard=binding+`local rows=${toLua(rows)}\nlocal order=${toLua(order)}\nlocal index=0\nlocal originalNew=Trace.new\n`+
   `Trace.new=function(...)\n local trace=originalNew(...)\n local originalAdd=trace.add\n`+
   ` trace.add=function(self,value)\n  index=index+1\n`+
   `  assert(Trace.serialize(value)==rows[order[index]],'unreviewed native write changed at '..index)\n`+
   `  return originalAdd(self,value)\n end\n return trace\nend\n`;
  const path=join(directory,'trace.lua');
  writeFileSync(path,source.replace(binding,guard)+`\nassert(index==${expected.length},'all conserved writes executed')\n`);
  return runLua(path); // Keep the existing 30s deadline and complete original scenario.
 }finally{rmSync(directory,{recursive:true,force:true});}
}


for (const [fixture, marker] of [
  ['text', 'PRESENTATION_WORDING_TRACE 361 1837256485'],
  ['trace', 'PRESENTATION_NATIVE_TRACE 81178 580852422'],
]) {
  test(`presentation responsibilities preserve the frozen ${fixture} contract`, () => {
    const result = fixture==='trace' ? runConservedTrace() : runLua(`tests/lua/presentation_responsibilities_${fixture}.lua`);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stdout.includes(marker), result.stdout);
  });
}
test('native write recorder retains strict field guards and inverts only the reviewed P0 field changes',()=>{
  const result=runLua('tests/lua/presentation_trace_native.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/PRESENTATION_TRACE_NATIVE_PASS/);
});

test('announcement retirement rejects restored notices and deleted changed reordered or added unrelated writes',()=>{
 const current=proof.before.filter(row=>!retired(row));
 verifyRetirement(current);
 assert.throws(()=>verifyRetirement(proof.before),'old announcement writes cannot return');
 assert.throws(()=>verifyRetirement(current.slice(1)),'other native writes cannot disappear');
 const changed=[...current];changed[0]+=' UNREVIEWED';assert.throws(()=>verifyRetirement(changed));
 const reordered=[...current];[reordered[0],reordered[1]]=[reordered[1],reordered[0]];
 assert.notEqual(current[0],current[1]);assert.throws(()=>verifyRetirement(reordered));
 assert.throws(()=>verifyRetirement([...current,'unreviewed insertion']));
});

test('formal entry adds exactly its reviewed selection redraws and keeps every historical write ordered',()=>{
 const expected=formalExpected();
 const before=verifyRetirement(proof.before.filter(row=>!retired(row)));
 const inserted=new Set(entryProof.insertions.map(row=>row.at));
 assert.deepEqual(expected.filter((_,i)=>!inserted.has(i)),before);
 const verify=rows=>assert.deepEqual(rows,expected);
 assert.throws(()=>verify(expected.slice(1)));
 const changed=[...expected];changed[0]+=' changed';assert.throws(()=>verify(changed));
 const reordered=[...expected];[reordered[0],reordered[1]]=[reordered[1],reordered[0]];assert.throws(()=>verify(reordered));
 assert.throws(()=>verify([...expected,'unreviewed insertion']));
});
