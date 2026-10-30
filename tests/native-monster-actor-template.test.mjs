import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {buildUI,assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {enemyUnitTemplate,enemyPowerTemplate,battleLayout} from '../scripts/ui-layout.mjs';
import {prepareMonsterArt,monsterActorTemplate,monsterActorInventory,monsterActorTemplateName,monsterPowerTemplateName,monsterActorBindingModule,bindMonsterActorTemplates} from '../scripts/monster-art.mjs';
import {buildNativeCandidate,generatedRuntimeModules,sourceInputs} from '../scripts/build-native-candidate.mjs';
import {candidateScriptFiles} from '../scripts/native-candidate-scripts.mjs';
import {artBuildOptionsFromReceipt} from '../scripts/art-features.mjs';
import {compareNativeCandidate} from '../scripts/native-candidate-audit.mjs';
const descendants=n=>[n,...(n.children??n.controls??[]).flatMap(descendants)];

test('real generated layout uses an empty actor layer and one complete hidden candidate template',t=>{
 const dir=mkdtempSync(join(tmpdir(),'monster-actor-build-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 buildUI(dir,undefined,{artFeatures:{monsters:true}});
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))),templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 const layer=descendants(layout).filter(n=>n.name==='actorLayer');assert.equal(layer.length,1);assert.deepEqual(layer[0].position,[0,0]);assert.deepEqual(layer[0].children,[]);assert(!layer[0].mask);
 assert(!descendants(layout).some(n=>/^enemy\d+$/.test(n.name)||/^monsterArt\d*$/.test(n.name)),'no fixed live/corpse pool cap');
 const [actor]=templates.filter(t=>t.name===monsterActorTemplateName);assert(actor);assert.equal(templates.filter(t=>t.name===monsterActorTemplateName).length,1);
 assert.equal(actor.visible,false);assert.equal(actor.children.length,35);assert.equal(actor.children[0].name,'monsterArt');assert.equal(actor.children[0].visible,false);
 assert.deepEqual(actor.children.slice(1),enemyUnitTemplate().children,'entire existing HP/intent/status/target unit retained byte-exact');
 assert.deepEqual(monsterActorInventory(actor),{templateName:monsterActorTemplateName,controlsPerActor:647,shapesPerActor:600,powerTemplateName:monsterPowerTemplateName,controlsPerPower:7,powerAllocation:'per-power-instance',allocation:'per-drawable-actor-instance',measurement:'offline-template-count-not-official-load',officialImport:'not_run',devices:'not_run'});
 const shapes=descendants(actor).filter(n=>/^shape\d+$/.test(n.name));assert.equal(shapes.length,600);assert(shapes.every(n=>n.visible===false&&n.opacity===0));
 for(const tree of [layout,...templates])assertNativeUiCapacity(tree);
 const stage=descendants(layout).find(n=>n.children?.some(c=>c.name==='actorLayer'));assert.equal(stage.children.length,56);
 assert.match(readFileSync(join(dir,monsterActorBindingModule+'.lua'),'utf8'),/templateIndex=0,containerTemplateIndex=0,powerTemplateIndex=0,enabled=false/);
 assert(generatedRuntimeModules[monsterActorBindingModule]);
 const inputs=sourceInputs(process.cwd(),{artFeatures:{monsters:true}});for(const path of prepareMonsterArt().inputPaths)assert(inputs.some(row=>row.path===path),'actual native source is in candidate provenance: '+path);
 // Module inventory must include the generated binding even when discovered without custom overrides.
 writeFileSync(join(dir,'abyss_data.lua'),'return {}');writeFileSync(join(dir,'abyss_original_v4_data.lua'),'return {}');
 assert(candidateScriptFiles('src/lua',dir).some(m=>m.name===monsterActorBindingModule));
 const noArt=monsterActorTemplate(null);assert.equal(descendants(noArt).length,35);assert.equal(noArt.visible,false);
 assert.equal(descendants(battleLayout()).filter(n=>n.name==='actorLayer').length,1);
});
function fixture(t,{invalid=false,invalidPower=false}={}) {
 mkdirSync('build',{recursive:true});const dir=mkdtempSync(join(process.cwd(),'build/monster-actor-candidate-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const baseMap=join(dir,'base.gil');writeFileSync(baseMap,'offline MCP test fixture, not an official GIL');
 const calls=[],sources=new Map();let index=1000;
 const indices=new Map();
 const client={async readResource(){return {contents:[]}},async close(){},async callTool({name,arguments:args}){
  calls.push({name,args});const data={mapPath:args.mapPath};
  if(name==='scene_add_client_template'){data.templateIndex=((invalid&&args.template.name===monsterActorTemplateName)||(invalidPower&&args.template.name===monsterPowerTemplateName))?0:++index;indices.set(args.template.name,data.templateIndex);}
  if(name==='scene_set_client_script')sources.set(args.name,readFileSync(args.sourceFile,'utf8'));
  if(name==='scene_list_client_scripts')data.scripts=[...sources].map(([name,source])=>({name,file:name+'.lua',source}));
  if(name==='inspect_map')data.graphs=[{name:'_GSTS_ABYSS_SETTLEMENT',id:23,type:20000,writable:true}];
  if(name==='scene_list_signals')data.signals=['ABYSS_WIN','ABYSS_LOSE'];
  if(name==='write_graphs')data.written=[23];
  if(name==='scene_check_client')Object.assign(data,{ok:true,errors:0,warnings:0,checked:[...sources.keys()]});
  return {structuredContent:data};
 }};
 return {calls,sources,indices,run:()=>buildNativeCandidate({baseMap,output:join(dir,'out'),client,artFeatures:{monsters:true}})};
}
test('candidate registers the complete actor and binds exact returned actor/group indices before payload copy',async t=>{
 const f=fixture(t),receipt=await f.run(),actor=f.indices.get(monsterActorTemplateName),group=f.indices.get('AbyssReadyCardGroup'),power=f.indices.get(monsterPowerTemplateName);
 assert.deepEqual(artBuildOptionsFromReceipt(receipt),{artFeatures:{cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false,monsters:true}});
 assert.equal(receipt.monsterActors.powerTemplateIndex,power);
 assert.equal(receipt.monsterActors.templateIndex,actor);assert.equal(receipt.monsterActors.containerTemplateIndex,group);assert.equal(receipt.monsterActors.controlsPerActor,647);
 assert.match(f.sources.get(monsterActorBindingModule),new RegExp(`templateIndex=${actor},containerTemplateIndex=${group},powerTemplateIndex=${power},enabled=true`));
 const registered=f.calls.findIndex(c=>c.name==='scene_add_client_template'&&c.args.template.name===monsterActorTemplateName);
 assert(registered>=0);assert(f.calls.findIndex(c=>c.name==='scene_set_client_script')>registered);
 assert(receipt.productionManifest.modules.some(m=>m.name===monsterActorBindingModule&&m.sha256===receipt.moduleDigests[monsterActorBindingModule]));
 assert.equal(receipt.statuses.officialImport,'not_run');assert.equal(receipt.statuses.playtest,'not_run');
});
test('invalid actor binding rejects before installing any script and refuses alias/malformed indices',async t=>{
 const f=fixture(t,{invalid:true});await assert.rejects(f.run(),/monster actor template index/);assert(!f.calls.some(c=>c.name==='scene_set_client_script'));
 for(const value of [undefined,null,0,-1,1.5,'123',Infinity,Number.MAX_SAFE_INTEGER+1])assert.throws(()=>bindMonsterActorTemplates('must-not-write',{actor:{templateIndex:value},group:{templateIndex:50},power:{templateIndex:51}}));
 assert.throws(()=>bindMonsterActorTemplates('must-not-write',{actor:{templateIndex:50},group:{templateIndex:50},power:{templateIndex:51}}),/distinct/);
});
test('native readback checks actor template identity, index and every nested primitive',()=>{
 const {actual,expected}=JSON.parse(readFileSync('tests/fixtures/native-candidate-audit/readback-slice.json'));
 const template=monsterActorTemplate(prepareMonsterArt());
 expected.runtimeTemplates=[{template,templateIndex:1024}];actual.runtimeTemplates=[{template:structuredClone(template),templateIndex:1024}];
 const issues=()=>compareNativeCandidate({actual,expected,sourceSha:'a'.repeat(40),candidateBefore:'b',candidateAfter:'b'}).issues.filter(i=>i.code.startsWith('RUNTIME_TEMPLATE'));
 assert.deepEqual(issues(),[]);actual.runtimeTemplates[0].templateIndex++;assert(issues().some(i=>i.code==='RUNTIME_TEMPLATE_BINDING'));
 actual.runtimeTemplates[0].templateIndex=1024;descendants(actual.runtimeTemplates[0].template).find(n=>n.name==='shape0599').image=100003;assert(issues().some(i=>i.code==='RUNTIME_TEMPLATE_MISMATCH'));
 actual.runtimeTemplates=[];assert(issues().some(i=>i.code==='RUNTIME_TEMPLATE_BINDING'));
});

test('invalid actual power template index rejects before script installation',async t=>{
 const f=fixture(t,{invalidPower:true});await assert.rejects(f.run(),/monster actor template index/);assert(!f.calls.some(c=>c.name==='scene_set_client_script'));
});
