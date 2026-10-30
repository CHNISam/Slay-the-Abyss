import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {sourceInputs} from '../scripts/build-native-candidate.mjs';

test('real UI build registers one shared hidden background host and one native image template without moving controls',t=>{
 const dir=mkdtempSync(join(tmpdir(),'abyss-background-build-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 buildUI(dir,undefined,{artFeatures:{menuBackground:true},monsterArt:{...JSON.parse(readFileSync('data/presentation/native-monster-art.json','utf8')),enabled:true}});
 const layout=JSON.parse(readFileSync(join(dir,'game-ui.json'))), stage=layout.controls.find(c=>c.name==='stage');
 const hosts=stage.children.filter(c=>c.name==='officialBackground');
 assert.equal(hosts.length,1,'one actual background host must be registered');
 assert.equal(stage.children[0],hosts[0]);assert.equal(hosts[0].visible,false);assert.deepEqual(hosts[0].size,[480,270]);
 const templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
 const images=templates.filter(t=>t.name==='AbyssOfficialBackgroundImage');assert.equal(images.length,1);
 assert.equal(images[0].kind,'image');assert.equal(images[0].image,100001);
 assert.equal(images[0].mask,undefined,'native reader omits disabled masks; retain canonical default-off template');
 const descendants=node=>[node,...(node.children??node.controls??[]).flatMap(descendants)];
 const monsterHosts=descendants(stage).filter(n=>n.name==='monsterArt');
 assert.equal(monsterHosts.length,1,'exact combined monster drawing host');
 assert.equal(descendants(monsterHosts[0]).length,609,'bounded prototype controls');
 assert.equal(monsterHosts[0].visible,false);assert.deepEqual(monsterHosts[0].size,[106,106]);
 const original=structuredClone(stage.children.slice(1));
 const strip=nodes=>{for(const node of nodes){if(node.children){node.children=node.children.filter(c=>!['artSamples','officialAvatar','officialFigure','monsterArt'].includes(c.name));strip(node.children);}}};
 strip(original);
 assert.deepEqual(original,JSON.parse(JSON.stringify(gameLayout().controls)),'approved controls/input remain byte-equivalent apart from explicit empty artwork hosts');
 const source=readFileSync(join(dir,'abyss_menu_background_asset.lua'),'utf8');
 for(const file of ['background_adapter.lua','background_data.lua'])assert(source.includes(readFileSync(`art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/${file}`,'utf8')),'frozen runtime bytes '+file);
 assert(source.includes('imagePrefabId = 0'),'ordinary UI must not invent template index');
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
 const dir=mkdtempSync(join(tmpdir(),'abyss-background-inventory-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const {buildLuaData}=await import('../scripts/build-lua-data.mjs');
 buildLuaData('data',join(dir,'abyss_data.lua'));
 buildUI(dir,undefined,{artFeatures:{menuBackground:true}});
 const report=packageInventory(dir);
 assert.equal(report.runtimeBackgrounds.length,1);
 assert.equal(report.runtimeBackgrounds[0].peakDynamicControls,13201);
 assert.equal(report.runtimeBackgrounds[0].instances,1);
 assert.equal(report.runtimeBackgrounds[0].batchSize,64);
 assert(report.modules.some(m=>m.name==='abyss_menu_background_asset'&&m.bytes>1111305));
});
