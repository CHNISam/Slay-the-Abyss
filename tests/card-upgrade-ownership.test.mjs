import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {parseDiagnostics,reviewResponsibilityComplexity,reviewModuleSize} from '../scripts/check-lua-static.mjs';
import {requireLuaTool} from '../scripts/setup-lua-static.mjs';
import {createHash} from 'node:crypto';
import luaparse from 'luaparse';
import {discoverSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {cardUpgradeSourceProof} from './helpers/card-upgrade-source-inverse.mjs';
import {cardUpgradeBefore,runCardUpgrade,cardUpgradeErrorLocations,normalizeCardUpgradeError} from './helpers/card-upgrade-ownership-vm.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const fixture='tests/lua/card_upgrade_ownership_contract.lua';
const owner='src/lua/abyss_card_upgrade.lua';
const roots=['abyss_card_upgrade','abyss_act2_stasis'];
const closure=(graph,root)=>{
 const seen=new Set(),pending=[root];
 while(pending.length){const node=pending.pop();if(seen.has(node))continue;seen.add(node);for(const edge of graph.edges)if(edge.from===node)pending.push(edge.to);}
 return seen;
};
const component=(graph,name)=>dependencyCycles(graph.nodes,graph.edges).find(row=>row.members.includes(name))?.members??[name];
const save=(name,value)=>{mkdirSync('build/card-upgrade-ownership',{recursive:true});writeFileSync('build/card-upgrade-ownership/'+name,JSON.stringify(value,null,2)+'\n');};
test('complete frozen 333-source corpus keeps its actual epoch and authenticated d8a57cae blob manifest',()=>{
 const manifest=Object.values(cardUpgradeBefore.files).map(row=>[row.path,row.gitBlob]).sort(([a],[b])=>a<b?-1:a>b?1:0);
 assert.equal(manifest.length,333);
 assert.equal(cardUpgradeBefore.revision,'2ad07111e3d5b5cb52b4229860b3b780941e29a9');
 assert.equal(createHash('sha256').update(JSON.stringify(manifest)+'\n').digest('hex'),'45ab772c9bb36e979a3ce0b61a00ebaf4878f04d85b9c7f4d3ecd3265e9de643');
 assert.equal(cardUpgradeSourceProof.baseRevision,'d8a57cae2a867200ca8e588abc0d368e6cdb3799');
 assert.equal(cardUpgradeSourceProof.baseLuaCorpus.gitBlobManifestSha256,'45ab772c9bb36e979a3ce0b61a00ebaf4878f04d85b9c7f4d3ecd3265e9de643');
});
test('complete current AST and isolated four-source contribution remove Stasis from actual Combat SCC without hiding deferred edges',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([path,source])=>[path.slice(8,-4),source]));
 const policy=JSON.parse(read('config/architecture.json'));
 const boundary=policy.dependencyBoundaries.find(row=>row.id==='card-upgrade-custody-independence');
 assert(boundary&&boundary.forbiddenTargets.length===12);assert.deepEqual(boundary.from,roots);
 const graph=analyzeSources(sources,policy);assert.deepEqual(graph.errors,[]);
 assert.deepEqual(graph.edges.filter(edge=>edge.from===roots[0]).map(edge=>edge.to),['abyss_copy'],'owner depends only on Copy');
 for(const root of roots){
  const reachable=closure(graph,root);
  for(const forbidden of boundary.forbiddenTargets)assert(!reachable.has(forbidden),`${root} cannot reach ${forbidden}`);
  assert(!dependencyCycles(graph.nodes,graph.edges).some(cycle=>cycle.members.includes(root)));
  for(const target of ['abyss_combat','abyss_warrior_status_cards'])for(const prefix of [`local bad=require('${target}')\n`,`local function bad()return require('${target}')end\n`]){
   const source=prefix+sources[root];luaparse.parse(source,{luaVersion:'5.3'});
   const mutant=analyzeSources({...sources,[root]:source},policy);
   assert(closure(mutant,root).has(target));
   assert(mutant.errors.some(row=>row.message.includes(boundary.id)),'immediate and deferred parsed imports violate real boundary');
  }
 }
 const beforeSources=Object.fromEntries(Object.entries(cardUpgradeBefore.files).map(([name,file])=>[name,file.source]));
 const beforePolicy=JSON.parse(cardUpgradeSourceProof.files['config/architecture.json'].beforeSource);
 const slice=['abyss_card_upgrade','abyss_combat','abyss_act2_stasis','abyss_warrior_status_cards'];
 const contributionSources={...beforeSources};for(const name of slice)contributionSources[name]=sources[name];
 const contributionPolicy={...beforePolicy,layers:{...beforePolicy.layers,abyss_card_upgrade:policy.layers.abyss_card_upgrade},
  deferredImports:beforePolicy.deferredImports.filter(row=>!(row.from==='abyss_act2_stasis'&&row.to==='abyss_combat')),
  dependencyBoundaries:[...beforePolicy.dependencyBoundaries,boundary]};
 assert.equal(Object.keys(beforeSources).length,333);assert.equal(Object.keys(contributionSources).length,334);
 const before=analyzeSources(beforeSources,beforePolicy),contribution=analyzeSources(contributionSources,contributionPolicy);
 assert.deepEqual(before.errors,[]);assert.deepEqual(contribution.errors,[]);
 const oldCombat=component(before,'abyss_combat'),newCombat=component(contribution,'abyss_combat');
 assert.equal(oldCombat.length,81);assert.equal(newCombat.length,80);
 assert.deepEqual(newCombat,oldCombat.filter(name=>name!=='abyss_act2_stasis'));
 assert(newCombat.includes('abyss_act2_powers'),'Act2Powers remains honestly in its separate PowerOrder cycle');
 assert.deepEqual(component(contribution,'abyss_run'),component(before,'abyss_run'));assert.equal(component(before,'abyss_run').length,15);
 save('architecture-contribution.json',{baseRevision:cardUpgradeSourceProof.baseRevision,corpusRevision:cardUpgradeBefore.revision,
  current:{graph,cycles:dependencyCycles(graph.nodes,graph.edges),combatMembers:component(graph,'abyss_combat'),sessionMembers:component(graph,'abyss_run')},
  isolated:{overlaidLuaModules:slice,baselineGraph:before,contributionGraph:contribution,combatBefore:oldCombat,combatAfter:newCombat,
   sessionBefore:component(before,'abyss_run'),sessionAfter:component(contribution,'abyss_run')}});
});
test('only exact observed moved diagnostic strings from checked operations receive location mappings',()=>{
 const afterLines=read(owner).split('\n');assert.equal(cardUpgradeErrorLocations.length,13);
 for(const row of cardUpgradeErrorLocations){
  assert.equal(cardUpgradeBefore.files[row.beforeFile].source.split('\n')[row.beforeLine-1].trim(),row.statement);
  assert.equal(afterLines[row.afterLine-1].trim(),row.afterStatement??row.statement);
  for(const label of row.labels){
   assert.equal(normalizeCardUpgradeError(label,row.before),row.before);
   assert.equal(normalizeCardUpgradeError(label,row.after),row.before);
   assert.equal(normalizeCardUpgradeError(label,row.after+' extra'),row.after+' extra');
   assert.equal(normalizeCardUpgradeError(label,row.after.replace('.lua:', '.lua:9')),row.after.replace('.lua:', '.lua:9'));
  }
  assert.equal(normalizeCardUpgradeError('unrecognized external caller',row.after),row.after);
 }
});
test('frozen VM refuses current-only handwritten dependencies without package.path fallback',()=>{
 const result=runCardUpgrade('before',null,{prelude:"require('abyss_card_upgrade')"});
 assert.notEqual(result.status,0);assert.match(result.error,/CARD_UPGRADE_CORPUS_UNKNOWN abyss_card_upgrade/);
});
test('dedicated VM rejects successful fixtures without complete object graphs',()=>{
 assert.throws(()=>runCardUpgrade('after',null,{prelude:'assert(true)'}),/nonempty complete graph stream/);
});
test('independent frozen and current VMs preserve every field alias metatable return and real battle rollback',{concurrency:false},()=>{
 const before=runCardUpgrade('before',fixture),after=runCardUpgrade('after',fixture);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);
 assert.equal(before.graphs.length,15);assert.deepEqual(after.logs,before.logs);assert.match(after.logs.at(-1),/CARD_UPGRADE_CONTRACT_PASS all 11/);
 assert.deepEqual(after.generated,before.generated);assert.deepEqual(after.graphs,before.graphs);assert.equal(after.bytes,before.bytes);
 assert.deepEqual(after.diagnostics.map(({label,normalized})=>({label,normalized})),before.diagnostics.map(({label,normalized})=>({label,normalized})));
 save('equivalence.json',{fixture,baseRevision:cardUpgradeSourceProof.baseRevision,corpusRevision:cardUpgradeBefore.revision,
  handwrittenBefore:before.handwritten,handwrittenAfter:after.handwritten,generated:after.generated,
  checkpoints:after.graphs,bytesPerSide:after.bytes,definitions:after.definitionCount,beforeStream:before.traceFile,afterStream:after.traceFile,
  stableFullFieldGraphStream:true,diagnosticLocationMappings:cardUpgradeErrorLocations,beforeDiagnostics:before.diagnostics,afterDiagnostics:after.diagnostics,
  exclusions:['Raw module reflection (rawget/rawset/next/getmetatable/setmetatable), WarriorStatus pairs enumeration, and the legacy modules own package.loaded eviction/reload layout. Combat pairs enumeration and real copied-API queued Armaments/choice execution, ordinary dynamic public slots, saved function values, all card/state fields, aliases, metatables, cold-load owner values, pcall tuples and exact non-string exception identities remain covered.']});
});
for(const root of roots)for(const coldKind of ['function','nil','false'])test(`${root}: cold Master Reality execution excludes Combat and retains owner-first ${coldKind} slots`,{concurrency:false},()=>{
 const forbidden=JSON.parse(read('config/architecture.json')).dependencyBoundaries.find(row=>row.id==='card-upgrade-custody-independence').forbiddenTargets;
 const result=runCardUpgrade('after',null,{prelude:`
 local root=require('${root}');local U=require('abyss_card_upgrade');local S=require('abyss_act2_stasis')
 local c={cardId='strike',upgraded=false};local s={catalog={cards={strike={type='attack',cost=1,upgrade={}}}},
  hand={},player={statuses={master_reality=1}},rules={player={maxHand=10}},act2StasisCards={orb=c}}
 local returned=table.pack(S.death(s,{id='orb'}))
 assert(c.upgraded and c.upgrades==1 and returned[1].op=='stasis_return','cold Master Reality runs real owner rules')
 ${forbidden.map(name=>`assert(not package.loaded.${name},'cold Master Reality must exclude ${name}')`).join('\n')}
 local saved={};local replacements={};local meta=setmetatable({kind='replacement metadata'},{tag='shared metatable'});meta.self=meta
 for _,name in ipairs({'validSearingBlowCopy','combatBaseCost','canUpgrade','upgrade','onUpgrade'})do
  saved[name]=U[name];local token={kind=name,meta=meta};local fn
  if '${coldKind}'=='function'then fn=function()return token end elseif '${coldKind}'=='false'then fn=false end
  replacements[name]=fn;U[name]=fn
 end
 local C=require('abyss_combat');local T=require('abyss_warrior_status_cards')
 for _,name in ipairs({'validSearingBlowCopy','combatBaseCost','canUpgrade','upgrade','onUpgrade'})do
  local legacy=name=='onUpgrade'and T or C
  assert(legacy[name]==replacements[name]and U[name]==replacements[name],'loading facade must not reset owner-first replacement')
  U[name]=nil;assert(legacy[name]==nil,'owner nil remains nil');legacy[name]=false;assert(U[name]==false,'legacy false reaches owner')
  U[name]=false;assert(legacy[name]==false,'owner false remains false');legacy[name]=nil;assert(U[name]==nil,'legacy nil reaches owner')
  legacy[name]=saved[name];assert(U[name]==saved[name]and legacy[name]==saved[name],'restore retains exact saved function')
 end
 C.unrelated=meta;T.unrelated=meta;assert(U.unrelated==nil,'unrelated legacy fields are not proxied')
 U.unrelated=meta;assert(C.unrelated==meta and T.unrelated==meta,'unrelated legacy own values remain unchanged');U.unrelated=nil
 CARD_UPGRADE_GRAPH_WRITE({state=s,returned=returned,saved=saved,replacements=replacements,meta=meta},'complete cold owner-first replacement graphs',true)
 print('CARD_UPGRADE_COLD_PASS')
 `});
 assert.equal(result.status,0,result.error);assert.equal(result.graphs.length,1);assert.match(result.logs.join('\n'),/CARD_UPGRADE_COLD_PASS/);
});
for(const [label,path,group,from,to,marker]of [
 ['constructor signed maximum',owner,'rules','base<=2147483647','base<2147483647',/Searing constructor validation/],
 ['ordinary cost delta',owner,'rules','local diff=turn-before','local diff=before-turn',/positive turn cost retains signed delta/],
 ['Blood raw base delta',owner,'rules','rawBase+turn-base','math.max(0,rawBase)+turn-base',/Blood below-zero raw base precedes turn delta/],
 ['catalog before validator',owner,'slots','local d=state.catalog.cards[instance.cardId]','local checked=M.validSearingBlowCopy(instance);local d=state.catalog.cards[instance.cardId]',/catalog failure precedes validator/],
 ['Stasis exact hand equality','src/lua/abyss_act2_stasis.lua','stasis','local discard=#s.hand==s.rules.player.maxHand','local discard=#s.hand>=s.rules.player.maxHand',/death uses exact hand equality/],
 ['Stasis public upgrade lookup','src/lua/abyss_act2_stasis.lua','slots','if combat.canUpgrade(s,c)then combat.upgrade(s,c)end','if combat.canUpgrade(s,c)then c.upgraded=true end',/Stasis reads current upgrade slot/],
 ['Blood late flag order',owner,'slots','M.onUpgrade(state,instance)','instance.upgraded=true;M.onUpgrade(state,instance)',/upgrade flag follows hook/],
 ['Combat API enumeration omission','src/lua/abyss_combat.lua','pairs','__pairs=upgradePairs','__pairs=nil',/copied API retains current upgrade slot identity/],
])test(`parsed semantic mutant ${label} fails a named real assertion`,{concurrency:false},()=>{
 let source=read(path);assert.equal(source.split(from).length,2,'one exact semantic mutation');source=source.replace(from,to);
 luaparse.parse(source,{luaVersion:'5.3'});
 const result=runCardUpgrade('after',fixture,{prelude:`CARD_UPGRADE_GROUP='${group}'`,mutation:{name:path.slice(8,-4),source}});
 assert.notEqual(result.status,0,'semantic mutant survived');assert.match(result.error,/\[CARD_UPGRADE\]/,'real behavior assertion, not parse/load failure');assert.match(result.error,marker);
});

test('real static collector enforces all owner responsibilities future nested functions five bridges nested iterator and physical line limit',()=>{
 const tool=requireLuaTool();
 const measure=(file,source)=>{
  luaparse.parse(source,{luaVersion:'5.3'});
  const directory=mkdtempSync(join(tmpdir(),'card-upgrade-static-')),path=join(directory,'candidate.lua');
  try{
   writeFileSync(path,source);
   const result=spawnSync(tool.file,[path,'--formatter','plain','--codes','--ranges','--no-color','--max-cyclomatic-complexity','0','--only','561'],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
   assert(!result.error&&!result.signal&&[0,1].includes(result.status),result.stderr);assert.equal(result.stderr,'');
   const diagnostics=parseDiagnostics(result.stdout);assert(diagnostics.length>0,'real measured main/function diagnostics');
   return diagnostics.map(row=>({...row,file}));
  }finally{rmSync(directory,{recursive:true,force:true});}
 };
 const source=read(owner),diagnostics=measure(owner,source);
 const actual=reviewResponsibilityComplexity(diagnostics,{[owner]:source});
 assert.deepEqual(actual.errors.filter(row=>row.file===owner),[]);assert.equal(actual.functions.filter(row=>row.subject==='main chunk').length,1);
 assert(actual.functions.length>=11&&actual.functions.every(row=>row.complexity<=15),'complete current owner main/helpers/functions');
 for(const row of diagnostics){
  const mutant=diagnostics.map(item=>item===row?{...item,message:item.message.replace(/\(\d+ > 0\)/,'(16 > 0)')}:item);
  assert(reviewResponsibilityComplexity(mutant,{[owner]:source}).errors.some(item=>item.message.includes('16 exceeds 15')),'every present measured owner responsibility has real CC15 policy');
 }
 const branches=Array.from({length:15},(_,i)=>`if value==${i} then value=value+1 end`).join('\n');
 const future='local function futureOwner(value) return function()\n'+branches+'\nend end\n'+source;
 const futureReport=reviewResponsibilityComplexity(measure(owner,future),{[owner]:future});
 assert(futureReport.errors.some(row=>row.message==='Responsibility complexity 16 exceeds 15: function'),'future anonymous nested owner function is governed');
 const initialization='local value=0\n'+branches+'\n'+source;
 assert(reviewResponsibilityComplexity(measure(owner,initialization),{[owner]:initialization}).errors.some(row=>row.message==='Responsibility complexity 16 exceeds 15: main chunk'));
 for(const file of ['src/lua/abyss_combat.lua','src/lua/abyss_warrior_status_cards.lua']){
  const original=read(file),measured=measure(file,original);
  assert.deepEqual(reviewResponsibilityComplexity(measured,{[file]:original}).errors.filter(row=>row.file===file),[]);
  for(const name of ['upgradeIndex','upgradeNewIndex',...(file==='src/lua/abyss_combat.lua'?['upgradePairs','iterate']:[])]){
   const needle=`local function ${name}(`;assert.equal(original.split(needle).length,2);
   const start=original.indexOf('\n',original.indexOf(needle))+1;
   const mutant=original.slice(0,start)+' local value=0\n'+branches+'\n'+original.slice(start);
   assert(reviewResponsibilityComplexity(measure(file,mutant),{[file]:mutant}).errors.some(row=>row.message.includes(`function '${name}'`)&&row.message.includes('exceeds 15')),'actual measured facade bridge exceeds CC15');
  }
 }
 assert.deepEqual(reviewModuleSize({[owner]:source}).errors.filter(row=>row.file===owner),[]);
 const oversized=source+'\n'.repeat(1001);luaparse.parse(oversized,{luaVersion:'5.3'});
 assert(reviewModuleSize({[owner]:oversized}).errors.some(row=>row.file===owner&&/1000/.test(row.message)));
 save('static-contract.json',{owner:{...actual,errors:actual.errors.filter(row=>row.file===owner)},negativeControls:['every present owner diagnostic at CC16','future anonymous nested helper measured CC16','initialization measured CC16','five actual bridges and nested iterator measured above CC15','1001 added physical lines']});
});
