import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
const file='src/lua/abyss_run_card_catalog.lua';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const before=read('tests/fixtures/run-catalog-responsibilities-before.lua');
const hash=s=>createHash('sha256').update(s).digest('hex');
function replay(source,fixture){
 mkdirSync('build/run-catalog-responsibilities',{recursive:true});
 const root=mkdtempSync(join('build/run-catalog-responsibilities','vm-'));
 try{
  const output=join(root,'graph.txt');
  const result=spawnSync(process.execPath,['--max-old-space-size=512','tests/helpers/run-catalog-responsibilities-vm.mjs',output],{
   input:JSON.stringify({source,fixture}),encoding:'utf8',timeout:30000,maxBuffer:1024*1024,
  });
  assert.equal(result.error,undefined,result.error?.message);assert.equal(result.status,0,result.stderr);
  return {...JSON.parse(result.stdout),graph:readFileSync(output)};
 }finally{rmSync(root,{recursive:true,force:true});}
}
test('Run catalogue full frozen source retains exact develop 2ad07111 SHA256 and Git blob',()=>{
 assert.equal(hash(before),'d8d7f52778dbfd6814ddebc1ecc960c6732317d3746a6aabf104e4b7ef7f4a54');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0'+before).digest('hex'),'ed69e39fb618c3efb332cda1fcfe6db37f0ccc8c');
});
for(const suffix of ['contracts','isolation','caller_foreign','review_card_graph','review_array','review_metadata','metadata_conflicts','owned_registration'])test(`complete fresh old/new Run catalogue ${suffix} graph and returned values match`,t=>{
 const fixture=`tests/lua/run_card_catalog_${suffix}.lua`;
 const old=replay(before,fixture),current=replay(read(file),fixture);
 assert.equal(old.status,0,old.error);assert.equal(current.status,0,current.error);
 assert.deepEqual(old.relocatedErrors,[]);
 assert.deepEqual(current.relocatedErrors,suffix==='caller_foreign'?['src/lua/abyss_run_card_catalog.lua:143: incompatible caller Power: rushdown']:[]);
 assert(old.checkpoints>1);assert(old.graph.includes('complete '));assert.equal(current.checkpoints,old.checkpoints);
 if(!current.graph.equals(old.graph)){
  const a=old.graph.toString(),b=current.graph.toString();let i=0;while(i<a.length&&a[i]===b[i])i++;
  assert.fail('complete graph differs at '+i+': before='+a.slice(i-100,i+180)+' after='+b.slice(i-100,i+180));
 }
 t.diagnostic(JSON.stringify({suffix,checkpoints:current.checkpoints,bytes:current.graph.length,sha256:hash(current.graph)}));
});
test('Run catalogue full module includes every helper, callback and initialization in CC15',()=>{
 const sources=discoverSources(),diagnostics=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics;
 const measured=measureSources(sources,diagnostics);assert.deepEqual(measured.errors,[]);
 const module=measured.modules.find(m=>m.file===file);assert.equal(module.functions.length,35);assert(module.functions.every(f=>f.complexity<=15));
 const report=reviewResponsibilityComplexity(diagnostics,sources);assert.deepEqual(report.errors,[]);
 assert.equal(report.functions.filter(f=>f.file===file).length,module.functions.length);
 const source='local function future() return function() end end';
 const row=(column,subject)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
 const rows=[row(1,'main chunk'),row(7,"function 'future'"),row(source.indexOf('function()')+1,'function')];
 assert.equal(reviewResponsibilityComplexity(rows,{[file]:source}).errors.filter(e=>e.file===file&&e.message.includes('16 exceeds 15')).length,3);
 assert(reviewResponsibilityComplexity([],{[file]:source}).errors.some(e=>e.file===file&&e.message.includes('Incomplete')));
});
const oracle='tests/helpers/run-catalog-responsibilities-oracle.lua';
test('Run catalogue semantic oracle passes both complete source versions',()=>{
 for(const source of [before,read(file)]){const r=replay(source,oracle);assert.equal(r.status,0,r.error);}
});
for(const [name,from,to]of [
 ['caller directory identity','fillList(out.cards.cards,cards)','out.cards.cards=cards'],
 ['shared Power priority','statuses.intangible.priority=75','statuses.intangible.priority=74'],
 ['native ABI ownership','c.runNativeABI=native[c.id]or nil','c.runNativeABI=nil'],
])test(`Run catalogue real semantic mutation detects ${name}`,()=>{
 const source=read(file);assert.equal(source.split(from).length,2,'one real expression');
 const result=replay(source.replace(from,to),oracle);assert.notEqual(result.status,0,'mutant survived');assert.match(result.error,/\[CATALOG_RESPONSIBILITY\]/);
});
