import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {buildNativeCandidate} from '../scripts/build-native-candidate.mjs';
import {backgroundModule, backgroundTemplate, bindBackgroundTemplate} from '../scripts/official-background.mjs';

function fixture(t,templateIndex=1470123456){
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(join(process.cwd(),'build/background-candidate-'));
 t.after(()=>rmSync(directory,{recursive:true,force:true}));
 const baseMap=join(directory,'base.gil');writeFileSync(baseMap,'offline test boundary, not a native GIL');
 const sources=new Map(),calls=[];
 const client={async readResource(){return {contents:[]}},async close(){},async callTool({name,arguments:args}){
  calls.push({name,args});let data={mapPath:args.mapPath};
  if(name==='scene_add_client_template')data.templateIndex=templateIndex===null?null:templateIndex+(args.template.name==='AbyssReadyCardImage'?1:args.template.name==='AbyssReadyCardGroup'?2:0);
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
test('actual candidate route binds only returned MCP template index before payload mapping and readback',async t=>{
 const f=fixture(t),receipt=await f.run();
 const template=f.calls.findIndex(c=>c.name==='scene_add_client_template'&&c.args.template.name===backgroundTemplate);
 const script=f.calls.findIndex(c=>c.name==='scene_set_client_script'&&c.args.name===backgroundModule);
 assert(template>=0&&script>template);assert.match(f.sources.get(backgroundModule),/local imagePrefabId = 1470123456\n/);
 assert.equal(receipt.officialBackground.templateIndex,1470123456);
 assert.equal(receipt.officialBackground.peakDynamicControls,13201);
 assert.equal(receipt.officialBackground.inputs.length,2);
 assert(receipt.productionManifest.modules.some(m=>m.name===backgroundModule&&m.sha256===receipt.moduleDigests[backgroundModule]));
 assert.equal(receipt.statuses.playtest,'not_run');assert.equal(receipt.statuses.officialImport,'not_run');
 assert(!f.calls.some(c=>c.name.startsWith('playtest')));
});
test('missing template binding refuses the candidate before any runtime script can be installed',async t=>{
 const f=fixture(t,null);await assert.rejects(f.run(),/valid official background templateIndex/);
 assert.equal(f.calls.some(c=>c.name==='scene_set_client_script'),false);
});
test('template binder rejects absent, malformed, unsafe or nonpositive indexes',()=>{
 for(const templateIndex of [undefined,null,0,-1,1.5,'1234',Infinity,Number.MAX_SAFE_INTEGER+1])
  assert.throws(()=>bindBackgroundTemplate('must-not-write',{templateIndex}),/valid official background templateIndex/);
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
 assert.deepEqual(receipt.artFeatures.flags,{cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false,...artFeatures});
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
