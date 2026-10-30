import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {buildNativeCandidate} from '../scripts/build-native-candidate.mjs';
import {backgroundInputs,backgroundModule, backgroundTemplate, bindBackgroundTemplate} from '../scripts/official-background.mjs';

function fixture(t,templateIndex=1470123456,templateOverrides={}){
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(join(process.cwd(),'build/background-candidate-'));
 t.after(()=>rmSync(directory,{recursive:true,force:true}));
 const baseMap=join(directory,'base.gil');writeFileSync(baseMap,'offline test boundary, not a native GIL');
 const sources=new Map(),calls=[];
 const client={async readResource(){return {contents:[]}},async close(){},async callTool({name,arguments:args}){
  calls.push({name,args});let data={mapPath:args.mapPath};
  if(name==='scene_add_client_template')data.templateIndex=Object.hasOwn(templateOverrides,args.template.name)?templateOverrides[args.template.name]:
   templateIndex===null?null:templateIndex+(args.template.name==='AbyssReadyCardImage'?1:args.template.name==='AbyssReadyCardGroup'?2:args.template.name==='AbyssMonsterActor'?3:args.template.name==='AbyssMonsterPower'?4:0);
  if(name==='scene_set_client_script')sources.set(args.name,readFileSync(args.sourceFile,'utf8'));
  if(name==='scene_list_client_scripts')data.scripts=[...sources].map(([name,source])=>({name,file:name+'.lua',source}));
  if(name==='inspect_map')data.graphs=[{name:'_GSTS_ABYSS_SETTLEMENT',id:23,type:20000,writable:true}];
  if(name==='scene_list_signals')data.signals=['ABYSS_WIN','ABYSS_LOSE'];
  if(name==='write_graphs')data.written=[23];
  if(name==='scene_check_client')Object.assign(data,{ok:true,errors:0,warnings:0,checked:[...sources.keys()]});
  return {structuredContent:data};
 }};
 return {calls,sources,run:(options={})=>buildNativeCandidate({baseMap,output:join(directory,'out'),client,artFeatures:{menuBackground:true},...options})};
}
test('background-only budget candidate binds returned image/group templates before payload mapping and readback',async t=>{
 const f=fixture(t),receipt=await f.run();
 const template=f.calls.findIndex(c=>c.name==='scene_add_client_template'&&c.args.template.name===backgroundTemplate);
 const script=f.calls.findIndex(c=>c.name==='scene_set_client_script'&&c.args.name===backgroundModule);
 const sharedImage=f.calls.findIndex(c=>c.name==='scene_add_client_template'&&c.args.template.name==='AbyssReadyCardImage');
 const sharedGroup=f.calls.findIndex(c=>c.name==='scene_add_client_template'&&c.args.template.name==='AbyssReadyCardGroup');
 assert(template>=0&&sharedImage>=0&&sharedGroup>=0&&script>Math.max(template,sharedImage,sharedGroup));
 const source=f.sources.get(backgroundModule);
 assert.match(source,/imagePrefabId=1470123456,containerPrefabId=1470123458/);
 assert.match(source,/renderProfile='background-budget-v1'/);
 assert.equal(receipt.officialBackground.templateIndex,1470123456);
 assert.equal(receipt.officialBackground.imageTemplateIndex,1470123457);
 assert.equal(receipt.officialBackground.containerTemplateIndex,1470123458);
 assert.equal(receipt.officialBackground.images,4500);
 assert.equal(receipt.officialBackground.peakDynamicControls,4577);
 assert.equal(receipt.officialBackground.renderProfile,'background-budget-v1');
 assert.deepEqual(receipt.artFeatures.flags,{cards:false,menuBackground:true,selectionAvatar:false,battlePortrait:false,monsters:false});
 assert.equal(receipt.officialPortraits,undefined,'background-only candidate must not enable portrait artwork');
 assert.equal(receipt.readyCardArt,undefined,'background-only candidate must not enable card artwork');
 assert.equal(receipt.officialBackground.inputs.length,backgroundInputs.length);
 for(const path of backgroundInputs){
  const rows=receipt.officialBackground.inputs.filter(row=>row.path.replaceAll('\\','/')===path||row.path.replaceAll('\\','/').endsWith('/'+path));
  assert.equal(rows.length,1,'source provenance missing or ambiguous: '+path);
  const bytes=readFileSync(path);
  assert.equal(rows[0].sha256,createHash('sha256').update(bytes).digest('hex'));
  assert.equal(rows[0].bytes,bytes.length);
 }
 const hash=path=>createHash('sha256').update(readFileSync(path)).digest('hex');
 assert.equal(receipt.officialBackground.budgetSha256,hash('art/performance/background-budget-v1.json'));
 assert.equal(receipt.officialBackground.sourcePreviewSha256,hash('art/characters/key-visual/traveler-geo/official-landscape-v1/preview-native.png'));
 assert.equal(receipt.moduleDigests[backgroundModule],createHash('sha256').update(source).digest('hex'));
 assert(receipt.productionManifest.modules.some(m=>m.name===backgroundModule&&m.sha256===receipt.moduleDigests[backgroundModule]));
 assert.equal(receipt.statuses.playtest,'not_run');assert.equal(receipt.statuses.officialImport,'not_run');
 assert(!f.calls.some(c=>c.name.startsWith('playtest')));
});

test('invalid returned shared group binding refuses background-only candidate before installing runtime scripts',async t=>{
 const f=fixture(t,1470123456,{AbyssReadyCardGroup:0});
 await assert.rejects(f.run(),/valid official background containerTemplateIndex/);
 assert.equal(f.calls.some(c=>c.name==='scene_set_client_script'),false);
});
test('missing template binding refuses the candidate before any runtime script can be installed',async t=>{
 const f=fixture(t,null);await assert.rejects(f.run(),/valid official background templateIndex/);
 assert.equal(f.calls.some(c=>c.name==='scene_set_client_script'),false);
});
test('template binder rejects absent, malformed, unsafe or nonpositive indexes',()=>{
 for(const templateIndex of [undefined,null,0,-1,1.5,'1234',Infinity,Number.MAX_SAFE_INTEGER+1])
  assert.throws(()=>bindBackgroundTemplate('must-not-write',{templateIndex}),/valid official background templateIndex/);
});

test('native budget template binder rejects absent or invalid group indexes',t=>{
 mkdirSync('build',{recursive:true});const dir=mkdtempSync(join(process.cwd(),'build/background-binding-'));
 t.after(()=>rmSync(dir,{recursive:true,force:true}));
 writeFileSync(join(dir,'art-render-v2.json'),'{}');
 for(const containerTemplateIndex of [undefined,null,0,-1,1.5,'1234',Infinity,Number.MAX_SAFE_INTEGER+1])
  assert.throws(()=>bindBackgroundTemplate(dir,{templateIndex:1470123456},{containerTemplateIndex}),/valid official background containerTemplateIndex/);
});

test('readback verifies both the bound template identity and its actual image body',async()=>{
 const {compareNativeCandidate}=await import('../scripts/native-candidate-audit.mjs');
 const {actual,expected}=JSON.parse(readFileSync('tests/fixtures/native-candidate-audit/readback-slice.json'));
 const background={name:'AbyssOfficialBackgroundImage',kind:'image',size:[20,20],image:100001};
 expected.background={template:background,templateIndex:1470123456};
 actual.background={template:background,templateIndex:1470123456};
 const inspect=()=>compareNativeCandidate({actual,expected,sourceSha:'a'.repeat(40),candidateBefore:'b',candidateAfter:'b'});
 assert(!inspect().issues.some(i=>i.code.startsWith('BACKGROUND_')));
 actual.background.templateIndex=1470123457;
 assert(inspect().issues.some(i=>i.code==='BACKGROUND_TEMPLATE_BINDING'));
 actual.background.templateIndex=1470123456;actual.background.template={...background,mask:true};
 assert(inspect().issues.some(i=>i.code==='BACKGROUND_TEMPLATE_MISMATCH'),'enabled mask must never normalize away');
 actual.background.template={...background,image:105301};
 assert(inspect().issues.some(i=>i.code==='BACKGROUND_TEMPLATE_MISMATCH'));
 delete actual.background;assert(inspect().issues.some(i=>i.code==='BACKGROUND_TEMPLATE_BINDING'));
});


for(const [name,artFeatures]of [['default',{}],['cards',{cards:true}],['avatar',{selectionAvatar:true}],['battle',{battlePortrait:true}],['both portraits',{selectionAvatar:true,battlePortrait:true}]])test(`candidate ${name} binds only enabled artwork and carries effective config`,async t=>{
 const f=fixture(t),receipt=await f.run({artFeatures});
 assert.deepEqual(receipt.artFeatures.flags,{cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false,monsters:false,...artFeatures});
 const templates=f.calls.filter(c=>c.name==='scene_add_client_template').map(c=>c.args.template.name);
 assert.equal(templates.includes('AbyssOfficialBackgroundImage'),false);
 assert.equal(templates.includes('AbyssReadyCardImage'),name!=='default');
 assert.equal(Boolean(receipt.readyCardArt),Boolean(artFeatures.cards));
 assert.equal(Boolean(receipt.officialPortraits),Boolean(artFeatures.selectionAvatar||artFeatures.battlePortrait));
 if(receipt.officialPortraits){
  assert.equal(receipt.officialPortraits.assets.some(a=>a.asset.endsWith('avatar96')),Boolean(artFeatures.selectionAvatar));
  assert.equal(receipt.officialPortraits.assets.some(a=>a.asset.endsWith('battle133')),Boolean(artFeatures.battlePortrait));
 }
 if(!artFeatures.cards)assert(f.sources.get('abyss_ready_card_binding').includes('imageTemplateIndex=0,containerTemplateIndex=0,enabled=false'));
 assert(receipt.moduleDigests.abyss_art_features);
});
