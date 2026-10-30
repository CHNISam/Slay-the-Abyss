import test from 'node:test';import assert from 'node:assert/strict';import{mkdtempSync,readFileSync,rmSync}from'node:fs';import{tmpdir}from'node:os';import{join}from'node:path';
import{buildUI}from'../scripts/build-ui.mjs';
function holders(tree){let found=[];function walk(n){if(n.name==='artSamples')found.push(n);for(const c of n.children??n.controls??[])walk(c);}walk(tree);return found;}
test('normal production UI contains empty runtime artwork holders in all contexts and 75 lazily bound card definitions',()=>{
 const dir=mkdtempSync(join(tmpdir(),'ready-card-production-'));
 try{
  buildUI(dir);const game=JSON.parse(readFileSync(join(dir,'game-ui.json'))),templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
  assert.equal(holders(game).length,38);assert.equal(holders(templates.find(t=>t.name==='AbyssDeckCard')).length,1);
  for(const holder of holders(game))assert.deepEqual(holder.children,[]);
  const lua=readFileSync(join(dir,'abyss_presentation.lua'),'utf8');assert.equal((lua.match(/\["runtime"\]=true/g)??[]).length,0,'ordinary rule/text presentation must not eagerly load artwork');
  const assets=readFileSync(join(dir,'abyss_ready_card_assets.lua'),'utf8');
  assert.equal((assets.match(/\["runtime"\]=true/g)??[]).length,75);
  assert.equal((assets.match(/\["rectangleEncoding"\]=/g)??[]).length,72);
  assert.equal((assets.match(/\["path"\]=/g)??[]).length,6534);
  assert(templates.some(t=>t.name==='AbyssReadyCardImage'));assert(templates.some(t=>t.name==='AbyssReadyCardGroup'));
  assert.match(readFileSync(join(dir,'abyss_ready_card_binding.lua'),'utf8'),/imageTemplateIndex=0/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('native production manifest maps the ready-art binding module',async()=>{
 const {generatedRuntimeModules}=await import('../scripts/build-native-candidate.mjs');
 assert.equal(generatedRuntimeModules.abyss_ready_card_binding,'scripts/build-ui.mjs');
});
test('readback refuses wrong, missing or altered runtime image/container templates',async()=>{
 const {compareNativeCandidate}=await import('../scripts/native-candidate-audit.mjs');
 const {readyArtTemplates}=await import('../scripts/art/ready-card-runtime.mjs');
 const {actual,expected}=JSON.parse(readFileSync('tests/fixtures/native-candidate-audit/readback-slice.json'));
 expected.runtimeTemplates=readyArtTemplates().map((template,i)=>({template,templateIndex:1101+i}));actual.runtimeTemplates=structuredClone(expected.runtimeTemplates);
 const check=()=>compareNativeCandidate({actual,expected,sourceSha:'a'.repeat(40),candidateBefore:'b',candidateAfter:'b'});
 assert(!check().issues.some(i=>i.code.startsWith('RUNTIME_TEMPLATE')));
 actual.runtimeTemplates[0].templateIndex=999;assert(check().issues.some(i=>i.code==='RUNTIME_TEMPLATE_BINDING'));
 actual.runtimeTemplates=structuredClone(expected.runtimeTemplates);actual.runtimeTemplates[0].template.image=105301;
 assert(check().issues.some(i=>i.code==='RUNTIME_TEMPLATE_MISMATCH'));
 actual.runtimeTemplates=[];assert(check().issues.some(i=>i.code==='RUNTIME_TEMPLATE_BINDING'));
});
