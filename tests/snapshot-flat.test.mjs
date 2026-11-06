import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runSnapshotFlat} from './helpers/snapshot-flat-vm.mjs';

const before=readFileSync(new URL('./fixtures/snapshot-flat/before.lua',import.meta.url));
const current=()=>readFileSync(new URL('../src/lua/abyss_snapshot.lua',import.meta.url),'utf8').replaceAll('\r\n','\n');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
function evidence(name,value){
 if(process.env.SNAPSHOT_FLAT_EVIDENCE!=='1')return;
 mkdirSync('build/snapshot-flat-evidence',{recursive:true});
 writeFileSync(`build/snapshot-flat-evidence/${name}.json`,JSON.stringify(value)+'\n');
}
const field=(graph,key)=>{
 const root=graph.definitions.find(def=>def[1]===graph.root[1]);
 return root[2].find(([k])=>k[0]==='string'&&k[1]===key)?.[1]?.[1];
};
function contract(source){
 const run=runSnapshotFlat(source);
 assert.equal(run.error,null,run.error);
 assert.equal(run.trace.at(-1)?.label,'contract:complete','complete matrix ran');
 for(const prefix of ['empty','scalars',...Array.from({length:6},(_,i)=>`graph-${i+1}`),'deep']){
  const initial=run.trace.find(frame=>frame.label===`${prefix}:before`);
  const restored=run.trace.find(frame=>frame.label===`${prefix}:restored`);
  assert.ok(initial&&restored,`${prefix} full graph checkpoints`);
  assert.deepEqual(restored.graph,initial.graph,`${prefix}: every original object, raw field, key and reference restores`);
 }
 return run.trace;
}

test('frozen full 1956-byte oracle is exactly c20f9898462194d5f720f901274898e171a17ed5, never refreshed',()=>{
 assert.equal(before.length,1956);
 assert.equal(sha(before),'8952ff07bea54c924d9a04200acce11be26cbb4bc66096de72a1b6a39e079b63');
 assert.equal(createHash('sha1').update(`blob ${before.length}\0`).update(before).digest('hex'),'446db705ac66a87450bf32bf9d6cff2bbaec7d1e');
 const suffix='function M.ownedRestore(owner,target)';
 assert.equal(current().slice(current().indexOf(suffix)),before.toString('utf8').slice(before.toString('utf8').indexOf(suffix)),'owner and release remain byte-identical');
});
test('isolated old/new VMs agree on complete original graphs and API return/error observations',t=>{
 const oracle=contract(before.toString('utf8')),candidate=contract(current());
 assert.deepEqual(candidate,oracle,'every complete checkpoint and API tuple agrees with the frozen source');
 const inputs=Object.fromEntries(['tests/lua/snapshot_flat.lua','tests/helpers/snapshot-flat-vm.mjs','tests/helpers/lua-graph-observer.mjs','tests/snapshot-flat.test.mjs']
  .map(path=>[path,sha(readFileSync(path,'utf8').replaceAll('\r\n','\n'))]));
 const identity={node:process.version,platform:process.platform,arch:process.arch,beforeBase:'c20f9898462194d5f720f901274898e171a17ed5',beforeSha256:sha(before),afterSha256:sha(current()),inputs,checkpoints:oracle.length,traceSha256:sha(JSON.stringify(oracle))};
 evidence('identity',identity);
 evidence('contract',{...identity,oracle,candidate});
 t.diagnostic(`full trace checkpoints=${oracle.length}; sha256=${sha(JSON.stringify(oracle))}; deep=2048; graphSeeds=1..6`);
});
test('retained private containers do not grow with original graph width',t=>{
 const counts=source=>{
  const run=runSnapshotFlat(source,{mode:'containers'});assert.equal(run.error,null,run.error);
  const graph=run.trace[0].graph;return {narrow:Number(field(graph,'narrow')),wide:Number(field(graph,'wide'))};
 };
 const oracle=counts(before.toString('utf8')),candidate=counts(current());
 evidence('containers',{widths:[32,128],oracle,candidate});
 t.diagnostic(`width=32/128; frozen=${JSON.stringify(oracle)}; candidate=${JSON.stringify(candidate)}`);
 assert.ok(oracle.wide>oracle.narrow,'frozen source proves this observation detects per-original retained containers');
 assert.ok(candidate.narrow>0,'functional restore retains a real preimage');
 assert.equal(candidate.wide,candidate.narrow,'private retained container count must be width-independent');
});

function replaceOnce(source,from,to){
 assert.equal(source.split(from).length,2,`unique live negative-control anchor: ${from}`);
 return source.replace(from,to);
}
test('real semantic negative controls reject no-op, edge/boundary/falsy/cycle and owner regressions',t=>{
 const source=current(),rejected=[];
 const start=source.indexOf('    local function restore()');
 const end=source.indexOf('    if target~=nil then',start);
 assert.ok(start>0&&end>start,'complete restore region exists');
 const mutants=[
  ['no-op zero-container restore',source.slice(0,start)+'    local function restore()end\n'+source.slice(end)],
  ['wrong table boundary',replaceOnce(source,'ends[#originals]=entryCount','ends[#originals]=entryCount-2')],
  ['drop false value',replaceOnce(source,'entries[entryCount+2]=v','entries[entryCount+2]=v~=false and v or nil')],
  ['omit table-key-only subtree',replaceOnce(source,'if tableKey and not seen[k] then','if false and tableKey and not seen[k] then')],
  ['omit data/catalog value subtree',replaceOnce(source,"if kind(v)=='table' and not seen[v] then","if k~='data' and k~='catalog' and kind(v)=='table' and not seen[v] then")],
  ['lose cycle reference',replaceOnce(source,'entries[entryCount+2]=v','entries[entryCount+2]=not rawequal(v,original) and v')],
  ['retain new raw fields',replaceOnce(source,'for k in next,original do rawset(original,k,nil) end','for k in next,original do end')],
  ['reusable owner',replaceOnce(source,'owners[owner]=nil -- one nested play only','owners[owner]=captured -- one nested play only')],
  ['release without invalidation',replaceOnce(source,'owners[owner]=nil;return true','owners[owner]=owners[owner];return true')],
  ['ordinary restore consumes owner',replaceOnce(source,'        local first=1','        owners[restore]=nil;local first=1')],
  ['cross-target consumption',replaceOnce(source,'if captured and rawequal(captured,target)then','if captured then')],
  ['metamethod equality instead of identity',replaceOnce(source,'rawequal(captured,target)','captured==target')],
 ];
 for(const [name,mutant]of mutants){
  const run=runSnapshotFlat(mutant);
  assert.ok(run.error,`${name}: actual functional contract must fail`);
  assert.match(run.error,/raw original field\/identity must restore|new raw field must disappear|owner|fresh release|release once|wrong owner|raw-identical|table index is nil/,`${name}: semantic failure, not a load error`);
  rejected.push({name,error:run.error,checkpoints:run.trace.length,traceSha256:sha(JSON.stringify(run.trace))});
 }
 evidence('negative-controls',rejected);
 t.diagnostic(`semantic negative controls rejected=${rejected.length}/${mutants.length}; ${rejected.map(value=>value.name).join('; ')}`);
});

test('optional paired local capture/restore initial measurement', {skip:process.env.SNAPSHOT_FLAT_BENCHMARK!=='1'},t=>{
 const samples=[];
 for(let pair=0;pair<4;pair++){
  const order=pair%2?['after','before']:['before','after'];
  for(const side of order){
   const run=runSnapshotFlat(side==='before'?before.toString('utf8'):current(),{mode:'benchmark',iterations:120});
   assert.equal(run.error,null,run.error);
   const graph=run.trace[0].graph;
   samples.push({pair,side,captureSeconds:Number(field(graph,'capture')),restoreSeconds:Number(field(graph,'restore')),iterations:Number(field(graph,'iterations'))});
  }
 }
 evidence('local-benchmark',{node:process.version,samples});
 t.diagnostic(`local initial capture/restore only (128 children, paired alternating order): ${JSON.stringify(samples)}`);
});
