import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
import {buildUI,assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {enemyUnitTemplate,enemyPowerTemplate,battleLayout} from '../scripts/ui-layout.mjs';
import {prepareMonsterArt,monsterActorTemplate,monsterActorInventory,monsterActorTemplateName,monsterPowerTemplateName,monsterActorBindingModule,bindMonsterActorTemplates} from '../scripts/monster-art.mjs';
import {buildNativeCandidate,generatedRuntimeModules,sourceInputs} from '../scripts/build-native-candidate.mjs';
import {candidateScriptFiles} from '../scripts/native-candidate-scripts.mjs';
import {artBuildOptionsFromReceipt} from '../scripts/art-features.mjs';
import {compareNativeCandidate} from '../scripts/native-candidate-audit.mjs';
const descendants=n=>[n,...(n.children??n.controls??[]).flatMap(descendants)];
// PR406 retained the floor icon/number from PR404. Guard identities, not the old
// pre-floor count of 56: replacing a required control must fail even at the same count.
const battleStageControls = Object.entries({
 container: 'playArea topBar rewardStage rewardList exhaustIcon hero energyIcon drawIcon discardIcon potionHelp actorLayer card1 card2 card3 card4 card5 card6 card7 card8 card9 card10 dragLayer statusInfo feedback',
 text: 'title player piles floor exhaust notice statuses energy draw drawLabel discard discardLabel result',
 image: 'hpIcon goldIcon floorIcon energyRing energyDisc drawBadgeRing drawBadge discardBadgeRing discardBadge resultPlate',
 presetButton: 'potion1 potion2 potion3 endTurn start continue skip goldReward cardReward claimPotion stolenGold',
}).flatMap(([kind,names])=>names.split(' ').map(name=>`${name}:${kind}`)).sort();
function expectedResourceHints() {
 const bar=nativeTheme.layout.topBar;
 return {name:'resourceHints',kind:'container',size:[...nativeTheme.canvas.base],children:['hp','gold'].map(name=>{
  const icon=bar[name+'Icon'],value=bar[name];
  const left=Math.min(icon[0]-icon[1]/2,value[0]-value[1]/2),right=Math.max(icon[0]+icon[1]/2,value[0]+value[1]/2);
  const size=[Math.max(48,right-left),Math.max(48,bar.height)];
  return {name,kind:'container',position:[(left+right)/2,bar.y],size,children:[{name:'hit',kind:'cursorArea',size:[...size],focusable:true}]};
 })};
}
function assertBattleStageContract(stage,{host=false}={}) {
 assert(stage,'battle stage exists');
 assertNativeUiCapacity(stage); // The native per-parent limit remains 60, including hidden controls.
 assert(!descendants(stage).some(n=>/^enemy\d+$/.test(n.name)||/^monsterArt\d*$/.test(n.name)),'no static enemy pool in battle stage');
 const names=stage.children.map(n=>n.name);
 assert.equal(new Set(names).size,names.length,'unique battle stage child names');
 assert.deepEqual(stage.children.map(n=>`${n.name}:${n.kind}`).sort(),[...battleStageControls,...(host?['resourceHints:container']:[])].sort(),'complete battle stage control identities');
 if(host){
  const hints=stage.children.at(-1);
  assert.deepEqual(hints,expectedResourceHints(),'only the exact read-only HP/gold hotspots occupy the host tail layer');
  // Exact themed hotspots must also cover the actual rendered visual controls.
  // Comparing the input layer alone cannot detect a moved icon/value outside it.
  for(const [name,iconName,valueName]of [['hp','hpIcon','player'],['gold','goldIcon','piles']]){
   const box=hints.children.find(n=>n.name===name);
   for(const id of [iconName,valueName]){
    const visual=stage.children.find(n=>n.name===id);
    for(let axis=0;axis<2;axis++)assert(Math.abs(visual.position[axis]-box.position[axis])+visual.size[axis]/2<=box.size[axis]/2+.001,'resource hint covers '+id);
   }
  }
 }
}

test('battle stage identity contract rejects missing, duplicate, static-enemy and overflowing controls',()=>{
 const stage=()=>structuredClone(battleLayout().controls.find(n=>n.name==='stage'));
 assert.doesNotThrow(()=>assertBattleStageContract(stage()));
 for(const name of ['floorIcon','floor','actorLayer','endTurn','card10']) {
  const missing=stage();missing.children=missing.children.filter(n=>n.name!==name);
  assert.throws(()=>assertBattleStageContract(missing),/complete battle stage control identities/,name);
 }
 const hostStage=()=>{const value=stage();value.children.push(expectedResourceHints());return value;};
 assert.doesNotThrow(()=>assertBattleStageContract(hostStage(),{host:true}));
 assert.throws(()=>assertBattleStageContract(hostStage()),/complete battle stage control identities/,'standalone battle must not acquire host hotspots');
 for(const mutate of [
  value=>{value.children.pop();},
  value=>{value.children.push({name:'extra',kind:'container'});},
  value=>{value.children.at(-1).children[0].name='energy';},
  value=>{value.children.at(-1).children[0].children.push({name:'buy',kind:'cursorArea'});},
  value=>{value.children.at(-1).children[0].children[0].focusable=false;},
  value=>{value.children.unshift(value.children.pop());},
 ]) {const value=hostStage();mutate(value);assert.throws(()=>assertBattleStageContract(value,{host:true}),/complete battle stage control identities|exact read-only HP\/gold hotspots/);}
 const clipped=hostStage();
 const hpHint=clipped.children.at(-1).children.find(n=>n.name==='hp');
 const hpIcon=clipped.children.find(n=>n.name==='hpIcon');
 hpIcon.position[0]=hpHint.position[0]-hpHint.size[0]/2;
 assert.throws(()=>assertBattleStageContract(clipped,{host:true}),/resource hint covers hpIcon/,'an exact hotspot must reject a clipped real visual');
 const duplicate=stage();duplicate.children[0]=structuredClone(duplicate.children[1]);
 assert.throws(()=>assertBattleStageContract(duplicate),/unique battle stage child names/);
 const wrongKind=stage();wrongKind.children.find(n=>n.name==='floor').kind='image';
 assert.throws(()=>assertBattleStageContract(wrongKind),/complete battle stage control identities/);
 const unexpected=stage();unexpected.children[0]={name:'unexpected',kind:'container',children:[]};
 assert.throws(()=>assertBattleStageContract(unexpected),/complete battle stage control identities/);
 const fixedEnemy=stage();fixedEnemy.children.push({name:'enemy1',kind:'container',children:[]});
 assert.throws(()=>assertBattleStageContract(fixedEnemy),/no static enemy pool/);
 const overflow=stage();
 while(overflow.children.length<=60)overflow.children.push({name:`extra${overflow.children.length}`,kind:'container',visible:false,children:[]});
 assert.throws(()=>assertBattleStageContract(overflow),/61 direct children exceeds the platform limit of 60/);
});


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
 const stage=descendants(layout).find(n=>n.children?.some(c=>c.name==='actorLayer'));assertBattleStageContract(stage,{host:true});
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
