import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {requireLuaTool} from '../scripts/setup-lua-static.mjs';
import {runStatic,parseDiagnostics,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
const file='src/lua/abyss_card_capability.lua';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const before=read('tests/fixtures/card-capability-responsibilities-before.lua');
function replay(source,group){
 mkdirSync('build/card-capability-responsibilities',{recursive:true});
 const root=mkdtempSync(join('build/card-capability-responsibilities','vm-'));
 try{
  const output=join(root,'graph.txt');
  const result=spawnSync(process.execPath,['--max-old-space-size=512','tests/helpers/card-capability-responsibilities-vm.mjs',output],{
   input:JSON.stringify({source,group}),encoding:'utf8',timeout:30000,maxBuffer:1024*1024,
  });
  assert.equal(result.error,undefined,result.error?.message);assert.equal(result.status,0,result.stderr);
  return {...JSON.parse(result.stdout),graph:readFileSync(output)};
 }finally{rmSync(root,{recursive:true,force:true});}
}
test('Capability full original source retains develop 2ad07111 SHA256 and Git blob',()=>{
 assert.equal(createHash('sha256').update(before).digest('hex'),'b9eca8f9caf716ac5264b80ee4dd8142ae74b41f83f8fe6aa847b7247c2de1f9');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0'+before).digest('hex'),'048c09cca7c15808575d5a9779444d05c37ff536');
});
for(const group of ['catalog','boundaries','dynamic'])test(`complete independent old/new Capability ${group} graphs and read/return traces match`,t=>{
 const old=replay(before,group),current=replay(read(file),group);
 assert.equal(old.status,0,old.error);assert.equal(current.status,0,current.error);
 assert(old.graph.includes('complete '));assert.equal(current.checkpoints,old.checkpoints);assert(current.graph.equals(old.graph),'complete card/result/alias/read graph differs');
 t.diagnostic(JSON.stringify({group,checkpoints:current.checkpoints,bytes:current.graph.length,sha256:createHash('sha256').update(current.graph).digest('hex')}));
});
test('Capability entire module and all current/future nested helpers enforce CC15',()=>{
 const sources=discoverSources(),diagnostics=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics;
 const measured=measureSources(sources,diagnostics);assert.deepEqual(measured.errors,[]);
 const module=measured.modules.find(m=>m.file===file);assert(module.functions.length>3);assert(module.functions.every(f=>f.complexity<=15));
 const report=reviewResponsibilityComplexity(diagnostics,sources);assert.deepEqual(report.errors,[]);
 assert.equal(report.functions.filter(f=>f.file===file).length,module.functions.length);
 const source='local function future() return function() end end';
 const row=(column,subject)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
 const rows=[row(1,'main chunk'),row(7,"function 'future'"),row(source.indexOf('function()')+1,'function')];
 assert.equal(reviewResponsibilityComplexity(rows,{[file]:source}).errors.filter(e=>e.file===file&&e.message.includes('16 exceeds 15')).length,3);
 assert(reviewResponsibilityComplexity([],{[file]:source}).errors.some(e=>e.file===file&&e.message.includes('Incomplete')));
 const result=spawnSync(requireLuaTool().file,['tests/fixtures/card-capability-responsibilities-before.lua','--formatter','plain','--codes','--ranges','--no-color','--max-cyclomatic-complexity','0','--only','561'],{encoding:'utf8',timeout:30000});
 assert.equal(result.error,undefined);assert.equal(result.status,1,result.stderr);
 const old=reviewResponsibilityComplexity(parseDiagnostics(result.stdout).map(row=>({...row,file})),{[file]:before});
 assert(old.errors.some(e=>e.message==="Responsibility complexity 57 exceeds 15: function 'M.isImplemented'"));
});
for(const [name,group,from,to]of [
 ['experimental activation','boundaries',"if card.condition=='draw_pile_empty' and card.experimental~=true then return false end","if false then return false end"],
 ['status exhaustion contract','boundaries',"card.cost==1 and card.exhaust==true and not card.ethereal","card.cost==1 and card.exhaust~=true and not card.ethereal"],
 ['exact boolean effect admission','dynamic',"return Effects.supported(card.effects)==true","return Effects.supported(card.effects)"],
 ['original raw binding','dynamic',"and e.raw and e.raw.id==card.id and require('abyss_original_v4').supported(card.originalV4)","and require('abyss_original_v4').supported(card.originalV4)"],
])test(`Capability explicit behavior detects ${name} semantic mutation`,()=>{
 const source=read(file);assert.equal(source.split(from).length,2,'one real production mutation');
 const result=replay(source.replace(from,to),group);assert.notEqual(result.status,0,'mutant survived');assert.match(result.error,/\[CAPABILITY_RESPONSIBILITY\]/);
});


test('independent read-order probe preserves every accessible fault point and nil-hole tail return',()=>{
 const result=spawnSync(process.execPath,['--max-old-space-size=512','tests/helpers/card-capability-access-traces.mjs'],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
 assert.equal(result.error,undefined,result.error?.message);assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/PASS paired trace\/error\/arity probes: 612/);
});
