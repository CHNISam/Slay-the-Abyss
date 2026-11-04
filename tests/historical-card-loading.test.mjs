import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

function probe(mode){
 const child=spawnSync(process.execPath,[fileURLToPath(new URL('./helpers/historical-card-loading-probe.mjs',import.meta.url)),mode],
  {encoding:'utf8',timeout:30000,maxBuffer:1024*1024,windowsHide:true});
 assert.ifError(child.error);assert.equal(child.status,0,child.stdout+child.stderr);
 return JSON.parse(child.stdout);
}
test('cold helper and complete runner imports avoid historical proof I/O for unselected entries',()=>{
 for(const mode of ['helper','runner']){
  const result=probe(mode);
  assert.deepEqual(result.cold.reads,[],'ordinary imports must not open historical proof witnesses');
  assert.deepEqual(result.warm,result.cold,'warm imports, ordinary paths and foreign roots do not load proof inputs');
 }
});
test('all three selected entries synchronously load the original proof and still freshly reject unavailable or corrupt archives',()=>{
 const active=probe('active'),faulted=probe('warm-faults');
 assert.deepEqual(active.cold.reads,[]);
 assert.ok(active.historical.reads>0,'selected entries really load the original archive and inverse closure');
 assert.equal(faulted.historical.sha256,active.historical.sha256);
 assert.equal(faulted.historical.bytes,active.historical.bytes);
});
