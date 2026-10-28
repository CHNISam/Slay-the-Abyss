import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {integration} from './helpers/presentation-m3-integration.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';

const evidence=readFileSync('docs/reviews/official-update-log-removal-20261028.json.gz');
assert.equal(createHash('sha256').update(evidence).digest('hex'),'02cc28a2c1d8478b3d790645b7a73e2f120ba9f3d2c4cfdc22ad1f31f5b9c2b9');
const proof=JSON.parse(gunzipSync(evidence));
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
function verifyCombinedRetirement(entries){
 // Both independently reviewed changes start at the exact same frozen source
 // trace. Their owned writes are disjoint, so compose them without new goldens.
 verifyRetirement(proof.before.filter(row=>!retired(row)));
 assert.deepEqual(proof.before,integration.before,'both approvals share the original 79543 writes');
 assert.equal(integration.after.length,79757);assert.equal(traceHash(integration.after),1467902785);
 const removed=integration.after.filter(retired);
 assert.deepEqual(removed,proof.removed.map(item=>item.row),'the same 68 retired writes retain their values and order after M3');
 const expected=integration.after.filter(row=>!retired(row));
 assert.equal(expected.length,79689);assert.equal(traceHash(expected),2034622601);
 assert.deepEqual(entries,expected,'all reviewed M3 and other native writes retain their values and global order');
 return expected;
}
function runConservedTrace(){
 const expected=verifyCombinedRetirement(integration.after.filter(row=>!retired(row)));
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
   `  assert(Trace.serialize(value)==rows[order[index]],'non-announcement write changed at '..index)\n`+
   `  return originalAdd(self,value)\n end\n return trace\nend\n`;
  const path=join(directory,'trace.lua');
  writeFileSync(path,source.replace(binding,guard)+`\nassert(index==${expected.length},'all conserved writes executed')\n`);
  return runLua(path); // Keep the existing 30s deadline and complete original scenario.
 }finally{rmSync(directory,{recursive:true,force:true});}
}


for (const [fixture, marker] of [
  ['text', 'PRESENTATION_WORDING_TRACE 361 1837256485'],
  ['trace', 'PRESENTATION_NATIVE_TRACE 79689 2034622601'],
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

test('combined M3 retirement rejects lost visual changes and restored or changed unrelated writes',()=>{
 const current=integration.after.filter(row=>!retired(row));
 verifyCombinedRetirement(current);
 assert.throws(()=>verifyCombinedRetirement(proof.before.filter(row=>!retired(row))));
 assert.throws(()=>verifyCombinedRetirement(integration.after));
 assert.throws(()=>verifyCombinedRetirement(current.slice(1)));
 const changed=[...current];changed[0]+=' UNREVIEWED';assert.throws(()=>verifyCombinedRetirement(changed));
 const reordered=[...current];[reordered[0],reordered[1]]=[reordered[1],reordered[0]];
 assert.notEqual(current[0],current[1]);assert.throws(()=>verifyCombinedRetirement(reordered));
 assert.throws(()=>verifyCombinedRetirement([...current,'unreviewed insertion']));
});
