import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import luaparse from 'luaparse';
import {discoverSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {runColorlessCatalog} from './helpers/colorless-catalog-vm.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const leaf='src/lua/abyss_colorless_catalog.lua';
function graph(){const sources=Object.fromEntries(Object.entries(discoverSources()).map(([p,s])=>[p.slice(8,-4),s]));const policy=JSON.parse(read('config/architecture.json'));return {sources,policy,graph:analyzeSources(sources,policy)};}
function closure(g,root){const found=new Set(),pending=[root];while(pending.length){const n=pending.pop();if(found.has(n))continue;found.add(n);for(const edge of g.edges)if(edge.from===n)pending.push(edge.to);}return [...found].sort();}
test('preparation and definition registration cannot transitively load combat execution, including deferred edges',()=>{
 const {sources,policy,graph:g}=graph();assert.deepEqual(g.errors,[]);
 const allowed=['abyss_colorless_catalog','abyss_combat_catalog','abyss_copy'];
 assert.deepEqual(closure(g,'abyss_combat_catalog'),allowed);
 assert(!dependencyCycles(g.nodes,g.edges).some(c=>c.members.includes('abyss_combat_catalog')));
 for(const prefix of ["local bad=require('abyss_actor')\n","local function bad()return require('abyss_actor')end\n"]){
  const negative=analyzeSources({...sources,abyss_colorless_catalog:prefix+sources.abyss_colorless_catalog},policy);
  assert(negative.errors.some(e=>e.message.includes('colorless-catalog-independence')));
  assert.throws(()=>assert.deepEqual(closure(negative,'abyss_combat_catalog'),allowed));
 }
});
test('all extracted registration functions, initializers and nested helpers retain CC15',()=>{
 const source='local function outer() return function()end end';
 const rows=[{file:leaf,line:1,column:1,code:'W561',message:'cyclomatic complexity of main chunk is too high (16 > 0)'},
 {file:leaf,line:1,column:7,code:'W561',message:"cyclomatic complexity of function 'outer' is too high (16 > 0)"},
 {file:leaf,line:1,column:source.indexOf('function()')+1,code:'W561',message:'cyclomatic complexity of function is too high (16 > 0)'}];
 const errors=reviewResponsibilityComplexity(rows,{[leaf]:source}).errors.filter(e=>e.file===leaf&&e.message.startsWith('Responsibility complexity'));
 assert.equal(errors.length,3);
});
for(const fixture of ['colorless_catalog_contract','colorless_cards','colorless_powers'])test(`${fixture}: independent complete before/current graphs preserve state, aliases, random streams and failure order`,()=>{
 const path='tests/lua/'+fixture+'.lua',options={trace:fixture!=='colorless_catalog_contract'};
 const before=runColorlessCatalog('before',path,options),after=runColorlessCatalog('after',path,options);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);
 assert(before.graphs.length>0);assert.deepEqual(after.generated,before.generated);assert.deepEqual(after.logs,before.logs);
 assert.deepEqual(after.graphs,before.graphs);assert.equal(after.bytes,before.bytes);
 mkdirSync('build/colorless-catalog',{recursive:true});writeFileSync(`build/colorless-catalog/${fixture}-equivalence.json`,JSON.stringify({fixture,checkpoints:after.graphs,bytesPerSide:after.bytes,generated:after.generated},null,2)+'\n');
});
test('cold preparation loads no runtime and both ordinary interface directions remain one slot',()=>{
 const prelude=`local C=require('abyss_combat_catalog');local D=require('abyss_colorless_catalog')
 assert(not package.loaded.abyss_actor and not package.loaded.abyss_card_actions and not package.loaded.abyss_colorless_cards)
 local replacement=function(data)return data end;local old=D.withCards;D.withCards=replacement
 local F=require('abyss_colorless_cards');assert(F.withCards==replacement);F.withCards=nil;assert(D.withCards==nil);D.withCards=old;assert(F.withCards==old)
 for _,key in ipairs({'withCards','powerDescription','powerIcon'})do local original=F[key];local value={key=key};D[key]=value;assert(F[key]==value);F[key]=false;assert(D[key]==false);D[key]=nil;assert(F[key]==nil);F[key]=original;assert(D[key]==original)end`;
 const result=runColorlessCatalog('after','tests/lua/colorless_catalog_contract.lua',{prelude});assert.equal(result.status,0,result.error);
});
for(const [label,from,to]of [
 ['owned containers','if not owned then','if true then'],
 ['pool order','srcColorless=words(src)','srcColorless=words(raw)'],
 ['status description','description=M.powerDescription({statuses={[id]=1}},id)',"description='wrong'"],
])test(`real parsed ${label} mutation is killed by registration behavior`,()=>{
 const s=read(leaf);assert.equal(s.split(from).length,2);const mutation=s.replace(from,to);luaparse.parse(mutation,{luaVersion:'5.3'});
 const result=runColorlessCatalog('after','tests/lua/colorless_catalog_contract.lua',{mutation:{name:'abyss_colorless_catalog',source:mutation}});
 assert.notEqual(result.status,0,'semantic mutant survived');assert.match(result.error,/owned graph publication|source pool order|saved registrar reads dynamic description/);
});
