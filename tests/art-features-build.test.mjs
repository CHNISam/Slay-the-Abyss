import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync,cpSync,linkSync,symlinkSync,mkdirSync,writeFileSync,existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {buildUI} from '../scripts/build-ui.mjs';
import {sourceInputs} from '../scripts/build-native-candidate.mjs';

const off={cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false};
function output(t){const dir=mkdtempSync(join(tmpdir(),'abyss-flags-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));return dir;}
function nodes(tree){return [tree,...(tree.children??tree.controls??[]).flatMap(nodes)];}

test('default official build emits no drawing hosts/templates or large optional data',t=>{
 const dir=output(t);buildUI(dir);
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))),templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 assert.deepEqual(nodes(layout).filter(n=>['officialBackground','officialAvatar','officialFigure','artSamples'].includes(n.name)),[]);
 assert.deepEqual(templates.map(t=>t.name),['AbyssDeckCard']);
 for(const name of ['abyss_ready_card_assets','abyss_menu_background_asset','abyss_traveler_portrait_assets'])assert(readFileSync(join(dir,name+'.lua')).length<256,name+' disabled stub');
 const module=readFileSync(join(dir,'abyss_art_features.lua'),'utf8');
 for(const [key,value]of Object.entries(off))assert(module.includes(`${key}=${value}`));
 assert.equal(sourceInputs(process.cwd()).some(row=>row.path.startsWith('art/')),false);
});

test('invalid feature values are rejected before any optional input/output work',t=>{
 for(const artFeatures of [null,[],true,{unknown:true},{cards:'true'},{cards:0}])
  assert.throws(()=>buildUI(output(t),undefined,{artFeatures}),/art feature/i);
});

for(let mask=0;mask<16;mask++)test(`independent category build ${mask.toString(2).padStart(4,'0')} prunes disabled payloads`,t=>{
 const artFeatures={cards:!!(mask&1),menuBackground:!!(mask&2),selectionAvatar:!!(mask&4),battlePortrait:!!(mask&8)};
 const dir=output(t);buildUI(dir,undefined,{artFeatures});
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))),templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 const counts=Object.fromEntries(['officialBackground','officialAvatar','officialFigure','artSamples'].map(name=>[name,nodes(layout).filter(n=>n.name===name).length]));
 assert.equal(counts.officialBackground,artFeatures.menuBackground?1:0);
 assert.equal(counts.officialAvatar,artFeatures.selectionAvatar?1:0);
 assert.equal(counts.officialFigure,artFeatures.battlePortrait?1:0);
 assert.equal(counts.artSamples,artFeatures.cards?38:0);
 assert.equal(templates.some(t=>t.name==='AbyssOfficialBackgroundImage'),artFeatures.menuBackground);
 assert.equal(templates.some(t=>t.name==='AbyssReadyCardImage'),artFeatures.cards||artFeatures.menuBackground||artFeatures.selectionAvatar||artFeatures.battlePortrait);
 const cards=readFileSync(join(dir,'abyss_ready_card_assets.lua'),'utf8'),portraits=readFileSync(join(dir,'abyss_traveler_portrait_assets.lua'),'utf8');
 assert.equal((cards.match(/\["runtime"\]=true/g)??[]).length,artFeatures.cards?75:0);
 assert.equal(/\bavatar96=/.test(portraits),artFeatures.selectionAvatar);
 assert.equal(/\bbattle133=/.test(portraits),artFeatures.battlePortrait);
 const inputs=sourceInputs(process.cwd(),{artFeatures}).map(r=>r.path);
 assert.equal(inputs.some(p=>p.includes('runtime-candidate/rectangles.json')),artFeatures.cards);
 assert.equal(inputs.some(p=>p.endsWith('background_data.lua')),artFeatures.menuBackground);
 assert.equal(inputs.some(p=>p.endsWith('avatar96/runtime-no-snapshot.lua')),artFeatures.selectionAvatar);
 assert.equal(inputs.some(p=>p.endsWith('battle133/runtime-no-snapshot.lua')),artFeatures.battlePortrait);
});

test('candidate flags CLI rejects unknown, duplicate, nonboolean and legacy conflicts before asset preparation',async()=>{
 const {nativeAudioBuildArgs}=await import('../scripts/build-native-audio-game.mjs');
 for(const args of [['--art-cards=1'],['--art-unknown=true'],['--art-cards'],['--art-cards=true','--art-cards=true'],['--art-cards=true','--no-ready-card-art'],['--art-cards=true','--native-card-art-count=0'],['--art-cards=false','--native-card-art-registry=missing.json','--native-card-art-count=1']])
  assert.throws(()=>nativeAudioBuildArgs(['base.gil',...args]),/art feature|Conflicting/);
 const ordinary=nativeAudioBuildArgs(['base.gil']);assert.deepEqual(ordinary.options.artFeatures,off);
 const single=nativeAudioBuildArgs(['base.gil','--art-battle-portrait=true']);assert.deepEqual(single.options.artFeatures,{...off,battlePortrait:true});
 const legacy=nativeAudioBuildArgs(['base.gil','--native-card-art-registry=missing.json','--native-card-art-count=1']);assert.deepEqual(legacy.options.artFeatures,{...off,cards:true});
});

test('audio forwards a complete explicit default-off snapshot without changing unrelated release flags',async()=>{
 const {buildNativeAudioGame}=await import('../scripts/build-native-audio-game.mjs');
 const stop=Error('before SDK');
 await assert.rejects(buildNativeAudioGame({baseMap:'unused.gil',buildFull:async options=>{
  assert.deepEqual(options.artFeatures,off);assert.equal(options.workKey,'alpha-test');assert.equal(options.releaseCandidate,false);throw stop;
 }}),error=>error===stop);
});


test('default CLI is dependency-free and needs no optional drawing directory',t=>{
 const root=output(t);
 for(const path of ['scripts','data','tools','package.json','package-lock.json','CHANGELOG.md','.release-please-manifest.json'])cpSync(path,join(root,path),{recursive:true});
 assert.equal(existsSync(join(root,'node_modules')),false);assert.equal(existsSync(join(root,'art')),false);
 const result=spawnSync(process.execPath,['scripts/build-ui.mjs','generated'],{cwd:root,encoding:'utf8',timeout:15000});
 assert.equal(result.status,0,result.stderr);
 assert(readFileSync(join(root,'generated/abyss_ready_card_assets.lua')).length<256);
 assert.equal(sourceInputs(root).some(row=>row.path.startsWith('art/')),false);
});

for(const symbolic of [false,true])test('disabled output stubs cannot overwrite optional drawings via '+(symbolic?'symlinks':'hardlinks'),t=>{
 for(const input of ['art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/background_data.lua','art/cards/traveler-geo/bash/preview-144x64.png']){
  const dir=output(t),source=join(dir,input),out=join(dir,'generated');mkdirSync(out);mkdirSync(join(source,'..'),{recursive:true});writeFileSync(source,'preserved drawing source');
  for(const path of ['data','tools','package.json','package-lock.json','CHANGELOG.md','.release-please-manifest.json'])cpSync(path,join(dir,path),{recursive:true});
  try{(symbolic?symlinkSync:linkSync)(source,join(out,'abyss_ready_card_assets.lua'));}
  catch(error){if(symbolic&&['EPERM','EACCES','ENOSYS'].includes(error.code)){t.skip('Symlink unavailable: '+error.code);return;}throw error;}
  const cwd=process.cwd();try{process.chdir(dir);assert.throws(()=>buildUI(out),/overwrite an input/);}finally{process.chdir(cwd);}
  assert.equal(readFileSync(source,'utf8'),'preserved drawing source');
  assert.equal(existsSync(join(out,'game-ui.json')),false);
 }
});

test('malformed legacy API options cannot silently opt into dynamic card drawing',async t=>{
 const {buildNativeAudioGame}=await import('../scripts/build-native-audio-game.mjs');
 for(const nativeCardArt of [null,false,0,'registry.json',[],{}]){
  assert.throws(()=>buildUI(output(t),undefined,{nativeCardArt}),/native art|art feature/i);
  let called=false;
  await assert.rejects(buildNativeAudioGame({baseMap:'unused',nativeCardArt,buildFull:async()=>{called=true;throw Error('unexpected full build');}}),/native art|art feature/i);
  assert.equal(called,false);
 }
});
