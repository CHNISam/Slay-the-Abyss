import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {sourceInputs} from '../scripts/build-native-candidate.mjs';
import {writeBackgroundModule} from '../scripts/official-background.mjs';
import {createOptInArtFixture} from './helpers/opt-in-art-fixture.mjs';

test('real UI build registers one shared hidden background host and one native image template without moving controls',t=>{
 const dir=mkdtempSync(join(tmpdir(),'abyss-background-build-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 buildUI(dir,undefined,{artFeatures:{menuBackground:true,monsters:true}});
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))), stage=layout.controls.find(c=>c.name==='stage');
 const hosts=stage.children.filter(c=>c.name==='officialBackground');
 assert.equal(hosts.length,1,'one actual background host must be registered');
 assert.equal(stage.children[0],hosts[0]);assert.equal(hosts[0].visible,false);assert.deepEqual(hosts[0].size,[480,270]);
 const templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 const images=templates.filter(t=>t.name==='AbyssOfficialBackgroundImage');assert.equal(images.length,1);
 assert.equal(images[0].kind,'image');assert.equal(images[0].image,100001);
 assert.equal(images[0].mask,undefined,'native reader omits disabled masks; retain canonical default-off template');
 const descendants=node=>[node,...(node.children??node.controls??[]).flatMap(descendants)];
 const monsterHosts=descendants(stage).filter(n=>/^monsterArt(?:[2-5])?$/.test(n.name));
 assert.equal(monsterHosts.length,0,'dynamic actor art must not leave fixed scene pools');
 const actor=templates.find(n=>n.name==='AbyssMonsterActor');assert(actor);
 assert.equal(descendants(actor).length,647);assert.equal(actor.children[0].name,'monsterArt');
 assert.equal(actor.visible,false);assert.equal(actor.children[0].visible,false);
 const original=structuredClone(stage.children.slice(1));
 const strip=nodes=>{for(const node of nodes){if(node.children){node.children=node.children.filter(c=>!['artSamples','officialAvatar','officialFigure','officialSelectionFigure','monsterArt'].includes(c.name));strip(node.children);}}};
 strip(original);
 assert.deepEqual(original,JSON.parse(JSON.stringify(gameLayout().controls)),'approved controls/input remain byte-equivalent apart from explicit empty artwork hosts');
 const source=readFileSync(join(dir,'abyss_menu_background_asset.lua'),'utf8');
 assert(source.includes("renderProfile='background-budget-v1'"),'experiment must use adaptive original-resolution background');
 assert(source.includes('imagePrefabId=0'),'ordinary UI must not invent template index');
 const legacyDir=mkdtempSync(join(tmpdir(),'abyss-background-legacy-'));t.after(()=>rmSync(legacyDir,{recursive:true,force:true}));
 const legacy=writeBackgroundModule(legacyDir);
 for(const file of ['background_adapter.lua','background_data.lua'])assert(legacy.includes(readFileSync(`art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/${file}`,'utf8')),'explicit legacy frozen bytes '+file);
});

test('candidate payload provenance includes the actual frozen runtime inputs, not just source directories',()=>{
 const inputs=sourceInputs(process.cwd(),{artFeatures:{menuBackground:true}});
 for(const file of ['background_adapter.lua','background_data.lua']){
  const row=inputs.find(r=>r.path===`art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/${file}`);
  assert(row,`missing runtime provenance ${file}`);assert(row.bytes>0);assert.match(row.sha256,/^[a-f0-9]{64}$/);
 }
});

test('daily production inventory includes actual dynamic background peak, never official-storage estimates',async t=>{
 const {packageInventory}=await import('../scripts/platform-load.mjs');
 const fixture=createOptInArtFixture({artFeatures:{menuBackground:true}});t.after(()=>fixture.dispose());
 const dir=fixture.directory;
 const report=packageInventory(dir);
 assert.equal(report.runtimeBackgrounds.length,1);
 assert.equal(report.runtimeBackgrounds[0].peakDynamicControls,4577);
 assert.equal(report.runtimeBackgrounds[0].renderProfile,'background-budget-v1');
 assert.equal(report.runtimeBackgrounds[0].instances,1);
 assert.equal(report.runtimeBackgrounds[0].batchSize,256);
 assert.equal(report.runtimeBackgrounds[0].timeBudgetMs,8);
 assert(report.modules.some(m=>m.name==='abyss_menu_background_asset'&&m.bytes>0));
});

test('adaptive background covers every original-resolution pixel exactly once',()=>{
 const a=JSON.parse(readFileSync('art/performance/background-budget-v1.json'));
 assert.deepEqual([a.width,a.height,a.count],[480,270,4500]);
 const pixels=new Uint8Array(480*270);
 for(const r of a.rows){
  assert.equal(r.length,18);assert.equal(r[0],100001);assert.equal(r[17],255);
  const x=r[1]+240-r[3]/2,y=135-r[2]-r[4]/2;
  assert([x,y,r[3],r[4]].every(Number.isInteger));assert(x>=0&&y>=0&&x+r[3]<=480&&y+r[4]<=270);
  for(let yy=y;yy<y+r[4];yy++)for(let xx=x;xx<x+r[3];xx++)assert.equal(pixels[yy*480+xx]++,0);
 }
 assert(pixels.every(n=>n===1),'background has holes');
});
