import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync,cpSync,linkSync,symlinkSync,mkdirSync,writeFileSync,existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {buildUI} from '../scripts/build-ui.mjs';
import {sourceInputs} from '../scripts/build-native-candidate.mjs';

const off={cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false,monsters:false};
function output(t){const dir=mkdtempSync(join(tmpdir(),'abyss-flags-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));return dir;}
function nodes(tree){return [tree,...(tree.children??tree.controls??[]).flatMap(nodes)];}

test('default official build emits no drawing hosts/templates or large optional data',t=>{
 const dir=output(t);buildUI(dir);
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))),templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 assert.deepEqual(nodes(layout).filter(n=>['officialBackground','officialAvatar','officialFigure','artSamples','monsterArt'].includes(n.name)),[]);
 assert.deepEqual(templates.map(t=>t.name),['AbyssDeckCard','AbyssReadyCardGroup','AbyssMonsterActor','AbyssMonsterPower']);
 for(const name of ['abyss_ready_card_assets','abyss_menu_background_asset','abyss_traveler_portrait_assets','abyss_monster_art_data'])assert(readFileSync(join(dir,name+'.lua')).length<256,name+' disabled stub');
 const module=readFileSync(join(dir,'abyss_art_features.lua'),'utf8');
 assert(module.includes('schemaVersion=2'),'five-category builds declare their incompatible schema explicitly');
 for(const [key,value]of Object.entries(off))assert(module.includes(`${key}=${value}`));
 assert.equal(sourceInputs(process.cwd()).some(row=>row.path.startsWith('art/')),false);
});

test('invalid feature values are rejected before any optional input/output work',t=>{
 for(const artFeatures of [null,[],true,{unknown:true},{cards:'true'},{cards:0},{monsters:'true'},{monsters:0}])
  assert.throws(()=>buildUI(output(t),undefined,{artFeatures}),/art feature/i);
});

for(let mask=0;mask<32;mask++)test(`independent category build ${mask.toString(2).padStart(5,'0')} prunes disabled payloads`,t=>{
 const artFeatures={cards:!!(mask&1),menuBackground:!!(mask&2),selectionAvatar:!!(mask&4),battlePortrait:!!(mask&8),monsters:!!(mask&16)};
 const dir=output(t);buildUI(dir,undefined,{artFeatures});
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))),templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 const counts=Object.fromEntries(['officialBackground','officialAvatar','officialFigure','artSamples','monsterArt'].map(name=>[name,nodes(layout).filter(n=>n.name===name).length]));
 assert.equal(counts.officialBackground,artFeatures.menuBackground?1:0);
 assert.equal(counts.officialAvatar,artFeatures.selectionAvatar?1:0);
 assert.equal(counts.officialFigure,artFeatures.battlePortrait?1:0);
 assert.equal(counts.artSamples,artFeatures.cards?50:0,'38 existing card hosts plus twelve read-only starter-deck slots');
 assert.equal(counts.monsterArt,0,'art belongs to each dynamic actor template, not static layout');
 const actor=templates.find(t=>t.name==='AbyssMonsterActor');
 assert.equal(nodes(actor).length,artFeatures.monsters?647:35);
 assert.equal(nodes(actor).filter(node=>/^shape[0-9]+$/.test(node.name)).length,artFeatures.monsters?600:0);
 assert.equal(nodes(actor).filter(node=>node.name==='monsterArt').length,artFeatures.monsters?1:0);
 assert.equal(templates.some(t=>t.name==='AbyssOfficialBackgroundImage'),artFeatures.menuBackground);
 assert.equal(templates.some(t=>t.name==='AbyssReadyCardImage'),artFeatures.cards||artFeatures.menuBackground||artFeatures.selectionAvatar||artFeatures.battlePortrait);
 const cards=readFileSync(join(dir,'abyss_ready_card_assets.lua'),'utf8'),portraits=readFileSync(join(dir,'abyss_traveler_portrait_assets.lua'),'utf8');
 assert.equal((cards.match(/\["runtime"\]=true/g)??[]).length,artFeatures.cards?75:0);
 assert.equal(/\bavatar96=/.test(portraits),artFeatures.selectionAvatar);
 assert.equal(/\bbattle133=/.test(portraits),artFeatures.battlePortrait);
 const monsterData=readFileSync(join(dir,'abyss_monster_art_data.lua'),'utf8');
 assert.equal(monsterData.includes('acid_slime_m'),artFeatures.monsters);
 if(!artFeatures.monsters)assert(monsterData.length<256,'disabled monster payload must be a stub');
 const inputs=sourceInputs(process.cwd(),{artFeatures}).map(r=>r.path);
 assert.equal(inputs.includes('data/presentation/native-monster-art.json'),artFeatures.monsters,'monster registry is a gated payload input');
 assert.equal(inputs.some(p=>p.includes('runtime-candidate/rectangles.json')),artFeatures.cards);
 assert.equal(inputs.some(p=>p.endsWith('background_data.lua')),artFeatures.menuBackground);
 assert.equal(inputs.some(p=>p.endsWith('avatar96/runtime-no-snapshot.lua')),artFeatures.selectionAvatar);
 assert.equal(inputs.some(p=>p.endsWith('battle133/runtime-no-snapshot.lua')),artFeatures.battlePortrait);
 assert.deepEqual(inputs.filter(p=>p.startsWith('art/monsters/')),artFeatures.monsters?['art/monsters/acid_slime_m/native-art-r02/native-art.json','art/monsters/acid_slime_m/native-art-r02/native-art.lua']:[]);
});

test('candidate flags CLI rejects unknown, duplicate, nonboolean and legacy conflicts before asset preparation',async()=>{
 const {nativeAudioBuildArgs}=await import('../scripts/build-native-audio-game.mjs');
 for(const args of [['--art-monsters=1'],['--art-monsters=true','--art-monsters=false'],['--art-cards=1'],['--art-unknown=true'],['--art-cards'],['--art-cards=true','--art-cards=true'],['--art-cards=true','--no-ready-card-art'],['--art-cards=true','--native-card-art-count=0'],['--art-cards=false','--native-card-art-registry=missing.json','--native-card-art-count=1']])
  assert.throws(()=>nativeAudioBuildArgs(['base.gil',...args]),/art feature|Conflicting/);
 // Deferred cards stay off; independent scene and portrait defaults remain enabled.
 const custom={...off,menuBackground:true,selectionAvatar:true,battlePortrait:true};
 const ordinary=nativeAudioBuildArgs(['base.gil']);assert.deepEqual(ordinary.options.artFeatures,custom);
 const official=nativeAudioBuildArgs(['base.gil','--art-cards=false','--art-selection-avatar=false','--art-menu-background=false','--art-battle-portrait=false']);assert.deepEqual(official.options.artFeatures,off);
 const single=nativeAudioBuildArgs(['base.gil','--art-battle-portrait=true']);assert.deepEqual(single.options.artFeatures,{...custom,battlePortrait:true});
 const monster=nativeAudioBuildArgs(['base.gil','--art-monsters=true']);assert.deepEqual(monster.options.artFeatures,{...custom,monsters:true});
 const legacy=nativeAudioBuildArgs(['base.gil','--native-card-art-registry=missing.json','--native-card-art-count=1']);assert.deepEqual(legacy.options.artFeatures,{...custom,cards:true});
 const legacyOff=nativeAudioBuildArgs(['base.gil','--no-ready-card-art']);assert.deepEqual(legacyOff.options.artFeatures,{...off,menuBackground:true,selectionAvatar:true,battlePortrait:true});
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
 for(const name of ['abyss_ready_card_assets','abyss_menu_background_asset','abyss_traveler_portrait_assets','abyss_monster_art_data'])assert(readFileSync(join(root,'generated/'+name+'.lua')).length<256);
 assert.equal(sourceInputs(root).some(row=>row.path.startsWith('art/')),false);
 const enabled=spawnSync(process.execPath,['scripts/build-ui.mjs','monster-enabled','--art-monsters=true'],{cwd:root,encoding:'utf8',timeout:15000});
 assert.notEqual(enabled.status,0,'explicit enabled monster source must not silently downgrade when absent');
 assert.match(enabled.stderr,/native-art\.(?:lua|json)|ENOENT/);
 assert.equal(existsSync(join(root,'monster-enabled/game-ui.json')),false,'missing enabled sources fail before output');
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


test('all-off build ignores absent or malformed monster registry; explicit enable fails before output',t=>{
 const root=output(t),registry='data/presentation/native-monster-art.json';
 for(const path of ['scripts','data','tools','package.json','package-lock.json','CHANGELOG.md','.release-please-manifest.json'])cpSync(path,join(root,path),{recursive:true});
 assert.equal(existsSync(join(root,'art')),false);
 for(const state of ['missing','malformed']){
  if(state==='missing')rmSync(join(root,registry));
  else writeFileSync(join(root,registry),'{ malformed monster payload');
  const disabledOutput='disabled-'+state;
  const disabled=spawnSync(process.execPath,['scripts/build-ui.mjs',disabledOutput],{cwd:root,encoding:'utf8',timeout:15000});
  assert.equal(disabled.status,0,disabled.stderr);
  assert(readFileSync(join(root,disabledOutput,'abyss_monster_art_data.lua')).length<256);
  const inputs=sourceInputs(root).map(row=>row.path);
  assert.equal(inputs.includes(registry),false,'disabled registry must not enter source digest');
  assert.equal(inputs.some(path=>path.startsWith('art/')),false);
  const enabledOutput='enabled-'+state;
  const enabled=spawnSync(process.execPath,['scripts/build-ui.mjs',enabledOutput,'--art-monsters=true'],{cwd:root,encoding:'utf8',timeout:15000});
  assert.notEqual(enabled.status,0,'enabled '+state+' registry must fail closed');
  assert.match(enabled.stderr,state==='missing'?/ENOENT|native-monster-art/:/JSON|Unexpected|property|position/);
  assert.equal(existsSync(join(root,enabledOutput,'game-ui.json')),false,'invalid registry fails before any output');
 }
});
