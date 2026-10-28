import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {cpSync,readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {integration} from './helpers/presentation-m3-integration.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {spawnSync} from 'node:child_process';
import {integratedUiSources,preIntegratedUiSource} from './helpers/presentation-current-ui-inverse.mjs';

const evidence=readFileSync('docs/reviews/official-update-log-removal-20261028.json.gz');
assert.equal(createHash('sha256').update(evidence).digest('hex'),'02cc28a2c1d8478b3d790645b7a73e2f120ba9f3d2c4cfdc22ad1f31f5b9c2b9');
const proof=JSON.parse(gunzipSync(evidence));
const entryBytes=readFileSync('docs/reviews/formal-entry-integrated-insertions-20261028.json.gz');
assert.equal(createHash('sha256').update(entryBytes).digest('hex'),'d78dd2e3ada170f59e7b63a63d5927c7fd586e48901fef5c9cacda2874959840');
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
function conservedTraceGuard(rows,order){
 // The real recorder serializes each top-level write itself. Check that exact
 // value once instead of serializing a second copy in a trace.add wrapper.
 // Recursive serializer calls carry seen and never advance the global index.
 return `local rows=${toLua(rows)}\nlocal order=${toLua(order)}\nlocal index=0\n`+
  `local originalSerialize=Trace.serialize\nTrace.serialize=function(value,seen)\n`+
  ` if seen~=nil then return originalSerialize(value,seen)end\n`+
  ` local serialized=originalSerialize(value)\n index=index+1\n`+
  ` assert(serialized==rows[order[index]],'non-announcement write changed at '..index)\n`+
  ` return serialized\nend\n`;
}
function formalExpected(){
 const before=verifyCombinedRetirement(integration.after.filter(row=>!retired(row)));
 assert.equal(entryProof.beforeCount,before.length);assert.equal(entryProof.beforeHash,traceHash(before));
 const rows=[];let old=0;
 for(const insertion of entryProof.insertions){
  while(rows.length<insertion.at)rows.push(before[old++]);
  assert.equal(old,insertion.afterOld);
  const selection=insertion.row.startsWith('{1=string:root/characterPanel');
  const choice=/^\{1=string:root\/choicePanel,2=string:(?:SetVisible,3=\{1=boolean:false\}|visible,3=boolean:false)\}$/.test(insertion.row);
  assert.ok(selection||choice||old>=1564&&old<=1566,'extra redraws occur only before a Run starts');
  rows.push(insertion.row);
 }
 rows.push(...before.slice(old));
 assert.equal(rows.length,81392);assert.equal(traceHash(rows),1836812524);
 assert.equal(entryProof.insertions.length,1703);return rows;
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
  // Replay this historical 81392-write approval with its complete accepted UI
  // sources. The current UI has a separate strict trace below; it must not be
  // mistaken for the earlier formal-entry geometry and decoration approval.
  for(const path of ['src','data','scripts','tools','config','tests/lua','package.json','package-lock.json',
    '.release-please-manifest.json','CHANGELOG.md'])
   cpSync(path,join(directory,path),{recursive:true});
  for(const path of Object.keys(integratedUiSources.files))
   writeFileSync(join(directory,path),preIntegratedUiSource(path,readFileSync(path,'utf8')));
  for(const script of ['build-lua-data.mjs','build-ui.mjs','build-ui-theme.mjs']){
   const result=spawnSync(process.execPath,['scripts/'+script],{cwd:directory,encoding:'utf8',timeout:30000});
   assert.equal(result.status,0,result.stdout+result.stderr);
  }
  const source=readFileSync(join(directory,'tests/lua/presentation_responsibilities_trace.lua'),'utf8').replaceAll('\r\n','\n');
  const binding="local Trace=dofile('tests/lua/support/presentation_trace.lua')\n";
  assert.equal(source.split(binding).length,2,'one unchanged strict recorder binding');
  const guard=binding+conservedTraceGuard(rows,order);
  const path=join(directory,'trace.lua');
  writeFileSync(path,source.replace(binding,guard)+`\nassert(index==${expected.length},'all conserved writes executed')\n`);
  return runLua(path,{cwd:directory}); // Keep the existing 30s deadline and complete original scenario.
 }finally{rmSync(directory,{recursive:true,force:true});}
}

const liveBytes=readFileSync('tests/fixtures/presentation-current-native-trace.json.gz');
const digest=value=>createHash('sha256').update(value).digest('hex');
assert.equal(digest(liveBytes),'c13ec9b00493041008b2007a7a57c71bb4162da7d87638e026d78709640fc701');
const liveProof=JSON.parse(gunzipSync(liveBytes));
function currentExpected(){
 assert.equal(liveProof.sourceInverseSha256,digest(readFileSync('tests/fixtures/presentation-current-ui-inverse.json.gz')));
 assert.equal(liveProof.base,'e3cd8492b2c05e3acc13c26168fdc476668b2468');
 const rows=liveProof.order.map(id=>{assert.ok(Number.isInteger(id)&&id>=1&&id<=liveProof.rows.length);return liveProof.rows[id-1];});
 assert.equal(rows.length,73316);assert.equal(traceHash(rows),1014606304);
 const panel=row=>{const path=/^\{1=string:([^,]+)/.exec(row)[1];return path.split('/')[1]||path;};
 // Shared source/interaction writes are conserved exactly. Card skins, battle
 // geometry, the new map canvas, character visuals and the common exit menu
 // have explicit new rows; every live row is checked below, without filtering.
 const changed=new Set(['nodePanel','battlePanel','mapPanel','characterPanel','exitPanel','runMenu']);
 const before=formalExpected(),unchanged=list=>list.filter(row=>!changed.has(panel(row)));
 assert.deepEqual(unchanged(rows),unchanged(before),'all other native values and their global order remain unchanged');
 const counts=list=>{const out={};for(const row of list){const name=panel(row);if(changed.has(name))out[name]=(out[name]||0)+1;}return out;};
 assert.deepEqual(counts(before),{nodePanel:5003,battlePanel:28066,mapPanel:46809,characterPanel:144,exitPanel:52});
 assert.deepEqual(counts(rows),{nodePanel:7679,battlePanel:36236,mapPanel:27745,characterPanel:240,exitPanel:58,runMenu:40});
 return rows;
}

test('approved current UI executes every ordered native write while all historical contracts remain frozen',()=>{
 const expected=currentExpected();
 for(const [path,binding]of Object.entries(integratedUiSources.files)){
  const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(digest(source),binding.afterSha256,'complete current UI source: '+path);
  assert.equal(digest(preIntegratedUiSource(path,source)),binding.beforeSha256);
  for(const mutated of [source+'\n',source.replace(binding.edits[0].after.join('\n'),binding.edits[0].before.join('\n'))]){
   assert.notEqual(mutated,source,'negative really changes current UI source');
   assert.notEqual(digest(mutated),binding.afterSha256,'incomplete or unrelated source cannot inherit review');
  }
 }
 for(const [path,hash]of Object.entries(integratedUiSources.liveOnlySources))
  assert.equal(digest(readFileSync(path,'utf8').replaceAll('\r\n','\n')),hash,'complete new live UI input: '+path);
 const rows=[],order=[],ids=new Map();
 for(const row of expected){if(!ids.has(row)){rows.push(row);ids.set(row,rows.length);}order.push(ids.get(row));}
 const binding="local Trace=dofile('tests/lua/support/presentation_trace.lua')\n";
 const current="assert(trace.count==73316 and trace.hash==1014606304,'current approved UI native writes changed')";
 let source=readFileSync('tests/lua/presentation_responsibilities_trace.lua','utf8').replaceAll('\r\n','\n');
 assert.equal(source.split(binding).length,2);assert.equal(source.split(current).length,2);
 // The raw Lua runner executes this same current fixture and semantic guards.
 // JS adds ordered-row checking; it never substitutes an obsolete assertion.
 source=source.replace(binding,binding+conservedTraceGuard(rows,order))+"\nassert(index==73316,'all current writes executed')\n";
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/current-ui-trace-'));
 try{const path=join(directory,'trace.lua');writeFileSync(path,source);const result=runLua(path);
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/PRESENTATION_NATIVE_TRACE 73316 1014606304/);
  assert.match(result.stdout,/PRESENTATION_CURRENT_UI_PASS/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});


for (const [fixture, marker] of [
  ['text', 'PRESENTATION_WORDING_TRACE 361 1837256485'],
  ['trace', 'PRESENTATION_NATIVE_TRACE 81392 1836812524'],
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

test('strict recorder checks every nested write once and rejects missing changed reordered or extra writes',()=>{
 const rows=['{1={1=string:nested}}','{1=string:last}'],order=[1,2];
 const cases=[
  ["trace:add({{'nested'}});trace:add({'last'})",true],
  ["trace:add({{'nested'}})",false],
  ["trace:add({{'changed'}});trace:add({'last'})",false],
  ["trace:add({'last'});trace:add({{'nested'}})",false],
  ["trace:add({{'nested'}});trace:add({'last'});trace:add({'extra'})",false],
 ];
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/strict-trace-guard-'));
 try{
  const source=cases.map(([writes,accepted])=>[
   'do','local function replay()',"local Trace=dofile('tests/lua/support/presentation_trace.lua')",
   'local originalSerialize=Trace.serialize','local calls=0','Trace.serialize=function(value,seen)',
   ' if seen==nil then calls=calls+1 end',' return originalSerialize(value,seen)','end',
   conservedTraceGuard(rows,order),'local trace=Trace.new()',writes,
   "assert(index==2,'every write exactly once')",
   `assert(trace.count==2 and trace.hash==${traceHash(rows)},'original strict hash retained')`,
   "assert(calls==2,'each real write is serialized only once, nested recursion is not a new event')",'end',
   'local ok,why=pcall(replay)',`assert(ok==${accepted},tostring(why))`,'end',
  ].join('\n')).join('\n');
  const path=join(directory,'guard.lua');writeFileSync(path,source+"\nprint('STRICT_TRACE_GUARD_PASS')\n");
  const result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/STRICT_TRACE_GUARD_PASS/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('formal entry retains all integrated front-end writes and rejects unreviewed rows',()=>{
 const rows=formalExpected(),before=verifyCombinedRetirement(integration.after.filter(row=>!retired(row)));
 const inserted=new Set(entryProof.insertions.map(row=>row.at));
 assert.deepEqual(rows.filter((_,i)=>!inserted.has(i)),before);
 const verify=actual=>assert.deepEqual(actual,rows);
 assert.throws(()=>verify(rows.slice(1)));const changed=[...rows];changed[0]+=' changed';assert.throws(()=>verify(changed));
 const reordered=[...rows];[reordered[0],reordered[1]]=[reordered[1],reordered[0]];assert.throws(()=>verify(reordered));
 assert.throws(()=>verify([...rows,'unreviewed insertion']));
});
