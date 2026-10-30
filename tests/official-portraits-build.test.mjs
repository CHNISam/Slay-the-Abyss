import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {gameLayout} from '../scripts/game-ui-layout.mjs';

const modulePath=new URL('../scripts/official-portraits.mjs',import.meta.url);
test('portrait builder exists and preserves two dedicated hosts without four button-state copies',async()=>{
 assert(existsSync(modulePath),'portrait helper must implement actual asset integration');
 const {attachOfficialPortraits}=await import(modulePath);
 const layout={controls:[{name:'stage',kind:'container',children:gameLayout().controls}]};
 const before=structuredClone(layout),templates=[];attachOfficialPortraits(layout,templates);
 const stage=layout.controls[0],panel=stage.children.find(c=>c.name==='characterPanel');
 const traveler=panel.children.find(c=>c.name==='traveler'),host=traveler.children.find(c=>c.name==='officialAvatar');
 assert(host);assert.equal(host.kind,'container');assert.equal(host.visible,false);assert.deepEqual(host.children,[]);
 assert.deepEqual(host.size,[96,96]);assert.deepEqual(host.scale,[1/3,1/3]);
 const bust=traveler.children.find(c=>c.name==='hit').children[0].children.find(c=>c.name==='bust');
 assert.deepEqual(host.position,bust.position);assert.equal(traveler.children.filter(c=>c.name==='officialAvatar').length,1);
 const hero=stage.children.find(c=>c.name==='battlePanel').children.find(c=>c.name==='hero');
 const figure=hero.children.find(c=>c.name==='officialFigure');assert(figure);assert.equal(figure.visible,false);
 assert.equal(hero.children.indexOf(figure),hero.children.findIndex(c=>c.name==='portrait')+1);
 assert.deepEqual(figure.size,[133,133]);assert.deepEqual(figure.scale,[(400/3)/133,(400/3)/133]);
 traveler.children=traveler.children.filter(c=>c!==host);hero.children=hero.children.filter(c=>c!==figure);
 assert.deepEqual(layout,before,'no existing input, HUD or fallback may be changed by attaching hosts');
 assert.equal(templates.length,0,'parent supplies shared image/container templates, no private duplicate');
});

test('candidate binding rejects placeholders and extracts frozen byte-identical ROOT/ELEMENTS blocks',async t=>{
 assert(existsSync(modulePath),'portrait helper missing');
 const {writePortraitModule,bindPortraitTemplates,portraitModule,portraitInputs,portraitRuntimeInventory}=await import(modulePath);
 const dir=mkdtempSync(join(tmpdir(),'abyss-portrait-build-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 assert.throws(()=>bindPortraitTemplates(dir,{image:{templateIndex:0},container:{templateIndex:88}}),/templateIndex/);
 assert.throws(()=>bindPortraitTemplates(dir,{image:{imageId:100001},container:{templateIndex:88}}),/templateIndex/);
 const source=bindPortraitTemplates(dir,{image:{templateIndex:77},container:{templateIndex:88}});
 assert.equal(readFileSync(join(dir,portraitModule+'.lua'),'utf8'),source);
 for(const kind of ['avatar96','battle133']){
  const path=`art/characters/traveler-geo/portraits/${kind}/runtime-no-snapshot.lua`;
  const original=readFileSync(path,'utf8');
  const block=original.slice(original.indexOf('local ROOT = '),original.indexOf('\nlocal created = {}'));
  assert(source.includes(block),'real original literal bytes are consumed, not recreated');
  assert(portraitInputs.includes(path));assert(portraitInputs.includes(path.replace('runtime-no-snapshot.lua','native-art.json')));
 }
 assert(!source.includes('function OnStart'),'must not retain synchronous original creation path');
 assert(source.includes(readFileSync('art/characters/traveler-geo/portraits/avatar96/LICENSE-runtime-MIT.txt','utf8')),'candidate runtime must carry the upstream permission notice');
 assert.throws(()=>writePortraitModule(dir,{imageTemplateIndex:100001,containerTemplateIndex:88}),/templateIndex/);
 const inventory=portraitRuntimeInventory(dir);assert.equal(inventory.batchSize,64);assert.equal(inventory.peakDynamicControls,9294);
 assert.equal(inventory.maxDirectDynamicChildren,60);assert.equal(inventory.officialCapacity,'not_measured');
});
