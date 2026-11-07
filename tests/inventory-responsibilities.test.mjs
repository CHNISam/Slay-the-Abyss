import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {requireLuaTool} from '../scripts/setup-lua-static.mjs';
import {runStatic,parseDiagnostics,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
const LUA_OK=0;
const file='src/lua/abyss_inventory.lua';
const normalize=s=>s.replaceAll('\r\n','\n');
const read=p=>normalize(readFileSync(p,'utf8'));
const before=read('tests/fixtures/inventory-responsibilities-before.lua');
function replay(source,group){
 mkdirSync('build/inventory-responsibilities',{recursive:true});
 const root=mkdtempSync(join('build/inventory-responsibilities','vm-'));
 try{
  const output=join(root,'full-graph.txt');
  const result=spawnSync(process.execPath,['--max-old-space-size=512','tests/helpers/inventory-responsibilities-runner.mjs',output],{
   input:JSON.stringify({source,group}),encoding:'utf8',timeout:30000,maxBuffer:1024*1024,
  });
  assert.equal(result.error,undefined,result.error?.message);assert.equal(result.status,0,result.stderr);
  return {...JSON.parse(result.stdout),output:readFileSync(output)};
 }finally{rmSync(root,{recursive:true,force:true});}
}
test('Inventory frozen full source retains develop 2c85bc61 bytes and Git blob',()=>{
 assert.equal(createHash('sha256').update(before).digest('hex'),'8fb3dddab386d221c76de49a1ca4b9937a2edbde93511c06ef3810cd71a7557c');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0'+before).digest('hex'),'29d00e40b6423839c28d0964817a77f62348a06d');
});
for(const group of ['opening','validation','effects','failure'])test(`fresh old/new Inventory VMs preserve complete ${group} graphs, return arity and require order`,t=>{
 const old=replay(before,group),current=replay(read(file),group);
 assert.equal(old.status,LUA_OK,old.error);assert.equal(current.status,LUA_OK,current.error);
 assert(old.output.includes('complete '));assert.equal(current.checkpoints,old.checkpoints);
 assert(current.output.equals(old.output),'complete graph bytes differ');
 t.diagnostic(JSON.stringify({group,checkpoints:current.checkpoints,bytes:current.output.length,sha256:createHash('sha256').update(current.output).digest('hex')}));
});
test('Inventory entire module including initialization and future helpers has CC15 hard limit',()=>{
 const sources=discoverSources();const diagnostics=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics;
 const measured=measureSources(sources,diagnostics);assert.deepEqual(measured.errors,[]);
 const module=measured.modules.find(m=>m.file===file);assert(module.functions.length>10);
 assert(module.functions.every(f=>f.complexity<=15),JSON.stringify(module.functions.filter(f=>f.complexity>15)));
 const report=reviewResponsibilityComplexity(diagnostics,sources);assert.deepEqual(report.errors,[]);
 assert.equal(report.functions.filter(f=>f.file===file).length,module.functions.length);
 const source='local function futureHelper() return function() end end';
 const row=(column,subject,cc)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (${cc} > 0)`});
 const rows=[row(1,'main chunk',16),row(7,"function 'futureHelper'",16),row(source.indexOf('function()')+1,'function',16)];
 assert.equal(reviewResponsibilityComplexity(rows,{[file]:source}).errors.filter(e=>e.file===file&&e.message.includes('16 exceeds 15')).length,3);
 assert(reviewResponsibilityComplexity([],{[file]:source}).errors.some(e=>e.file===file&&e.message.includes('Incomplete')));
});
for(const [name,group,from,to]of [
 ['opening TOP order','opening','table.insert(battleTop,1,{{op=\'relic_hook\',id=id}})','table.insert(battleTop,{{op=\'relic_hook\',id=id}})'],
 ['late candidate overflow','failure','if state.energy + 0.0 + value > maximum then return false, "effect_overflow" end','if false then return false, "effect_overflow" end'],
 ['whole batch validation','validation','if not ok then return false, reason end\n    local target = state.enemies[targetIndex]','if false then return false, reason end\n    local target = state.enemies[targetIndex]'],
 ['deferred drain','effects',"if not deferDrain then require('abyss_card_actions').drain(Combat,state) end","if true then require('abyss_card_actions').drain(Combat,state) end"],
])test(`Inventory behavioral assertions reject ${name} semantic mutation`,()=>{
 const source=read(file);assert.equal(source.split(from).length,2,'one exact production mutation');
 const result=replay(source.replace(from,to),group);assert.notEqual(result.status,LUA_OK,'mutant survived');
 assert.match(result.error,/\[INVENTORY_RESPONSIBILITY\]/);
});

test('Inventory source inverse rereads one owner and refuses stale or foreign current bytes',async()=>{
 const {preInventoryResponsibilitiesSource:prior,inventoryResponsibilitiesReader:reader}=await import('./helpers/inventory-responsibilities-source-inverse.mjs');
 const source=read(file);let reads=0;const current=p=>{assert.equal(p,file);reads++;return source;};
 assert.equal(prior(file,source,{readSource:current}),before);assert.equal(reads,1);
 assert.equal(prior(file,source.replaceAll('\n','\r\n'),{readSource:current}),before);assert.equal(reads,2);
 const wrapped=reader(current);assert.equal(wrapped(file),before);assert.equal(reads,4);assert.equal(reader(wrapped),wrapped);
 assert.throws(()=>prior(file,source,{readSource:()=>source+'\n'}),/current owner identity/);
 assert.throws(()=>prior(file,source,{readSource:()=>before}),/current owner identity/);
 assert.throws(()=>prior(file,source,{readSource:()=>{throw Error('missing owner');}}),/missing owner/);
 for(const candidate of [before,source+'\n',source.replace('state.smoked=true','state.smoked=false')])
  assert.equal(prior(file,candidate,{readSource:()=>assert.fail('foreign inputs do not read owners')}),candidate);
});

test('raw current Inventory still enters the unchanged complete historical lifecycle oracle',async()=>{
 const {preRelicQuerySource}=await import('./helpers/relic-query-source-inverse.mjs');
 const {gunzipSync}=await import('node:zlib');
 const archive=JSON.parse(gunzipSync(readFileSync('tests/helpers/relic-lifecycle-baseline-391306af.json.gz')));
 assert.equal(preRelicQuerySource(file,read(file)),archive.files.abyss_inventory.source);
 let changed=false;const stale=p=>{if(p===file){if(changed)return read(p)+'\n';changed=true;}return read(p);};
 assert.throws(()=>preRelicQuerySource(file,read(file),{readSource:stale}),/linked owner identity/);
});


test('the genuine old Inventory source fails the new hard gate in all four previous hotspots',()=>{
 const fixture='tests/fixtures/inventory-responsibilities-before.lua';
 const result=spawnSync(requireLuaTool().file,[fixture,'--formatter','plain','--codes','--ranges','--no-color','--max-cyclomatic-complexity','0','--only','561'],{encoding:'utf8',timeout:30000});
 assert.equal(result.error,undefined);assert.equal(result.status,1,result.stderr);
 const diagnostics=parseDiagnostics(result.stdout).map(row=>({...row,file}));
 const report=reviewResponsibilityComplexity(diagnostics,{[file]:before});
 const violations=report.functions.filter(row=>row.complexity>15).map(row=>[row.subject,row.complexity]);
 assert.deepEqual(violations,[["function 'M.energyBonus'",20],["function 'M.opening'",33],["function 'validate'",34],["function 'M.apply'",53]]);
 assert.equal(report.errors.filter(e=>e.file===file&&e.message.includes('exceeds 15')).length,4);
});
