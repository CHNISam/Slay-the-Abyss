import test from 'node:test';import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';import {join} from 'node:path';
import {createHash} from 'node:crypto';import {spawnSync} from 'node:child_process';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
import {preEndTurnResponsibilitiesSource as prior,endTurnResponsibilitiesReader as reader} from './helpers/end-turn-responsibilities-source-inverse.mjs';
import {preRelicQuerySource,relicQueryReader} from './helpers/relic-query-source-inverse.mjs';
const file='src/lua/abyss_end_turn_powers.lua',read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n'),hash=s=>createHash('sha256').update(s).digest('hex');
const before=read('tests/fixtures/end-turn-responsibilities-before.lua');
function replay(source,fixture){mkdirSync('build/end-turn-responsibilities',{recursive:true});const root=mkdtempSync(join('build/end-turn-responsibilities','vm-'));
 try{const output=join(root,'graph.txt');const r=spawnSync(process.execPath,['--max-old-space-size=512','tests/helpers/end-turn-responsibilities-vm.mjs',output],{input:JSON.stringify({source,fixture}),encoding:'utf8',timeout:30000,maxBuffer:1048576});assert.equal(r.error,undefined,r.error?.message);assert.equal(r.status,0,r.stderr);return {...JSON.parse(r.stdout),graph:readFileSync(output)};
 }finally{rmSync(root,{recursive:true,force:true});}}
test('EndTurn retains the complete develop original source and Git blob',()=>{
 assert.equal(hash(before),'0f8881d917f93efb26c7b53f67545c05e6c4f39b43b1694bc3d3d6080173ebda');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0'+before).digest('hex'),'aba3f7fdbf7b675b84fc330ac1d4d3a14fe1362c');
});
for(const fixture of ['matrix',...['powers','retention','rollback','orb_callbacks'].map(n=>'tests/lua/owner_end_'+n+'.lua')])test(`EndTurn fresh old/new complete action, state and return graph: ${fixture}`,t=>{
 const old=replay(before,fixture),now=replay(read(file),fixture);assert.equal(old.status,0,old.error);assert.equal(now.status,0,now.error);assert(old.checkpoints>1);assert(now.graph.includes('complete '));assert.equal(now.checkpoints,old.checkpoints);
 if(!now.graph.equals(old.graph)){const a=old.graph.toString(),b=now.graph.toString();let i=0;while(i<a.length&&a[i]===b[i])i++;assert.fail('graph differs '+i+' before='+a.slice(i-70,i+180)+' current='+b.slice(i-70,i+180));}
 assert.deepEqual(old.relocatedErrors,[]);if(fixture!=='matrix')assert.deepEqual(now.relocatedErrors,[]);
 t.diagnostic(JSON.stringify({fixture,checkpoints:now.checkpoints,bytes:now.graph.length,sha256:hash(now.graph),relocatedErrors:now.relocatedErrors}));
});
test('EndTurn full module includes every callback and initialization under unchanged CC15',()=>{
 const sources=discoverSources(),diagnostics=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics,measured=measureSources(sources,diagnostics);assert.deepEqual(measured.errors,[]);
 const module=measured.modules.find(m=>m.file===file);assert.equal(module.functions.length,38);assert(module.functions.every(f=>f.complexity<=15));const report=reviewResponsibilityComplexity(diagnostics,sources);assert.deepEqual(report.errors,[]);assert.equal(report.functions.filter(f=>f.file===file).length,38);
 const source='local function future() return function() end end',row=(column,subject)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
 const rows=[row(1,'main chunk'),row(7,"function 'future'"),row(source.indexOf('function()')+1,'function')];assert.equal(reviewResponsibilityComplexity(rows,{[file]:source}).errors.filter(e=>e.file===file&&e.message.includes('16 exceeds 15')).length,3);assert(reviewResponsibilityComplexity([],{[file]:source}).errors.some(e=>e.file===file&&e.message.includes('Incomplete')));
});
test('EndTurn exact outer source bridge freshly rechecks owner, CRLF and wrapper forms',()=>{
 const current=read(file);for(const wrap of [r=>r,reader,r=>reader(reader(r))]){let count=0,live=current;const r=wrap(p=>{assert.equal(p,file);count++;return live;});assert.equal(prior(file,current,{readSource:r}),before);assert.equal(count,1);live='foreign';assert.throws(()=>prior(file,current,{readSource:r}),/EndTurn current owner identity/);assert.equal(count,2);}
 assert.equal(prior(file,current.replaceAll('\n','\r\n'),{readSource:()=>current.replaceAll('\n','\r\n')}),before);
 for(const s of [current+'\n',current.replace('return top','return bottom'),before,null])assert.equal(prior(file,s,{readSource:()=>{throw Error('must not read unmatched epoch');}}),s);
 assert.throws(()=>prior(file,current,{readSource:()=>{throw Error('missing owner');}}),/missing owner/);
});
test('EndTurn current source composes into frozen N35 without replacing its prior source or oracle',()=>{
 const raw=p=>readFileSync(p,'utf8'),current=read(file),old=preRelicQuerySource(file,before,{readSource:p=>prior(p,raw(p),{readSource:raw})});
 assert.equal(preRelicQuerySource(file,current,{readSource:raw}),old);assert.equal(relicQueryReader(raw)(file),old);assert.notEqual(old,current);
 assert.throws(()=>preRelicQuerySource(file,current,{readSource:p=>p===file?'foreign':raw(p)}),/EndTurn current owner identity/);
});
for(const [name,from,to]of [
 ['negative Ritual guard',"if n>0 then add(bottom,{op='gainStatus',status='strength',value=n})end","if n>=0 then add(bottom,{op='gainStatus',status='strength',value=n})end"],
 ['retaining Ethereal cards','if not combat.cardDefinition(state,c).ethereal then c.retain=true end','if combat.cardDefinition(state,c).ethereal then c.retain=true end'],
 ['Regen decay','p.statuses.regen=math.max(0,(p.statuses.regen or 0)-1)','p.statuses.regen=math.max(0,(p.statuses.regen or 0)-2)'],
])test(`EndTurn real semantic mutant is killed: ${name}`,()=>{const source=read(file);assert.equal(source.split(from).length,2);const r=replay(source.replace(from,to),'matrix');assert.notEqual(r.status,0,'mutant survived');assert.match(r.error,/\[END_TURN_RESPONSIBILITY\]/);});
