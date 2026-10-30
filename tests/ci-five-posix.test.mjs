import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,copyFileSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {beforeFivePosixWorkflow} from './helpers/platform-load-wiring.mjs';
import {discoverJs,jsShard,partition,timings} from '../scripts/ci-shards.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
const acceptedBefore='4087f48d8cfa3bcbd55e3ebdc8365b703a6b90a231d41b53edac6c3b171e097d';
function requireCurrentWorkflow(text){
 const jobs=[...text.matchAll(/^  engineering-posix-shards:\n([\s\S]*?)(?=^  [\w-]+:|(?![\s\S]))/gm)];
 assert.equal(jobs.length,1);
 assert.equal((jobs[0][0].match(/^        shard:/gm)||[]).length,1);
 assert.match(jobs[0][0],/shard: \[1, 2, 3, 4, 5\]\n    runs-on: ubuntu-24\.04\n    timeout-minutes: 20/);
 assert.equal(hash(beforeFivePosixWorkflow(text)),acceptedBefore);
}
function exactCoverage(input,slices){
 assert.equal(slices.length,5);const combined=slices.flat();
 assert.equal(new Set(combined).size,combined.length,'no file may execute twice');
 assert.deepEqual([...combined].sort(),[...input].sort(),'every current and newly discovered file must execute');
}
test('fifth POSIX VM is the sole workflow change and preserves the exact original full workflow for LF and CRLF',()=>{
 for(const source of [workflow,workflow.replaceAll('\n','\r\n')])requireCurrentWorkflow(source.replaceAll('\r\n','\n'));
 assert.equal(beforeFivePosixWorkflow(beforeFivePosixWorkflow(workflow)),beforeFivePosixWorkflow(workflow));
 for(const mutant of [
  workflow.replace('shard: [1, 2, 3, 4, 5]','shard: [1, 2, 3, 4]'),
  workflow.replace('shard: [1, 2, 3, 4, 5]','shard: [1, 2, 3, 4, 5, 6]'),
  workflow.replace('        shard: [1, 2, 3, 4, 5]','        shard: [1, 2, 3, 4, 5]\n        shard: [1, 2, 3, 4, 5]'),
  workflow.replace('    timeout-minutes: 20','    timeout-minutes: 21'),
  workflow.replace('      - run: npm run check:engineering','      - run: echo omitted'),
  workflow.replace('      fail-fast: false','      fail-fast: true'),
  workflow.replace('  engineering-posix-shards:\n','  renamed-posix-shards:\n'),
 ]){
  assert.notEqual(mutant,workflow);
  assert.throws(()=>requireCurrentWorkflow(mutant),'only the complete current five-VM workflow may pass');
 }
 assert.match(workflow,/engineering-posix-shards:[\s\S]*?shard: \[1, 2, 3, 4, 5\]\n    runs-on: ubuntu-24\.04\n    timeout-minutes: 20/);
 assert.match(workflow,/name: engineering-posix \(\$\{\{ matrix.shard \}\}\/\$\{\{ strategy.job-total \}\}\)/);
});
test('five weighted independent bins retain all current files exactly once; omission and duplication fail closed',()=>{
 const input=[...discoverJs(),'tests/unmeasured-fifth-vm.test.mjs'];
 const slices=Array.from({length:5},(_,i)=>jsShard(input,`${i+1}/5`,'linux').files);
 exactCoverage(input,slices);assert.ok(slices.every(x=>x.length>0));
 const omitted=structuredClone(slices);omitted[0].pop();assert.throws(()=>exactCoverage(input,omitted));
 const duplicate=structuredClone(slices);duplicate[1].push(duplicate[0][0]);assert.throws(()=>exactCoverage(input,duplicate));
 assert.deepEqual(timings.initialMs.linux,[44000,0,0,0,0]);
 for(let i=1;i<=8;i++)assert.deepEqual(jsShard(input,`${i}/8`,'win32'),partition(input,`${i}/8`,timings.js.win32,timings.unknownJsMs,timings.initialMs.win32),'Windows placement remains unchanged');
});
test('real five-way executor runs all new files once and propagates failure without hiding later files',()=>{
 const root=mkdtempSync(join(tmpdir(),'five-posix-executor-'));
 try{
  for(const p of ['tests','scripts','build'])mkdirSync(join(root,p));
  copyFileSync('scripts/ci-timing-reporter.mjs',join(root,'scripts/ci-timing-reporter.mjs'));
  const files=Array.from({length:13},(_,i)=>`tests/probe-${String(i).padStart(2,'0')}.test.mjs`);
  for(const [i,file]of files.entries())writeFileSync(join(root,file),`import test from 'node:test';test('probe',()=>{console.log('FILE ${file}');${i===0?"throw Error('intentional five-way failure');":''}});`);
  const env={...process.env};delete env.NODE_TEST_CONTEXT;const rows=[];let failures=0;
  for(let i=1;i<=5;i++){
   const result=spawnSync(process.execPath,[resolve('scripts/ci-shards.mjs'),`--shard=${i}/5`],{cwd:root,env,encoding:'utf8',timeout:30000});
   assert.ifError(result.error);if(result.status!==0)failures++;
   rows.push(...[...result.stdout.matchAll(/^FILE (tests\/probe-\d+\.test\.mjs)$/gm)].map(m=>m[1]));
  }
  assert.equal(failures,1);assert.deepEqual(rows.sort(),files.sort());
 }finally{rmSync(root,{recursive:true,force:true});}
});
