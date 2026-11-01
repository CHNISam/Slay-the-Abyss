import {preReadableUnitTypography} from './helpers/readable-unit-typography-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {enemyUnitTemplate,battleLayout} from '../scripts/ui-layout.mjs';
import {buildUI,assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {monsterActorTemplateName,monsterActorInventory} from '../scripts/monster-art.mjs';
const descendants=n=>[n,...(n.children??n.controls??[]).flatMap(descendants)];
const digest=n=>createHash('sha256').update(JSON.stringify(n)).digest('hex');
const layers=new Set(['intentVfxBehind','intentVfxAfter']);
function assertLayers(actor) {
  const names=actor.children.map(n=>n.name),start=names.indexOf('intentVfxBehind');
  assert.deepEqual(names.slice(start,start+6),['intentVfxBehind','intentIcon','intentBadge','intentExtra','intentVfxAfter','intent']);
  for(const name of layers) {
    const matches=descendants(actor).filter(n=>n.name===name);assert.equal(matches.length,1);
    assert.deepEqual(matches[0],{name,kind:'container',position:[0,0],size:[...actor.size],visible:true,children:[]});
  }
  assertNativeUiCapacity(actor);
}
test('enemy intent effect layers add exactly two empty draw-order roots without changing hero or existing actor fields',()=>{
  const actor=enemyUnitTemplate();assertLayers(actor);assert.equal(actor.children.length,34);
  actor.children=actor.children.filter(n=>!layers.has(n.name));
  // Approved native readability delta: horizontal intent values are vertically centered.
  const intent=actor.children.find(n=>n.name==='intent');assert.equal(intent.text.valign,'middle');
  intent.text.valign='top'; // Retain the frozen digest for every other existing actor field.
  assert.equal(digest(preReadableUnitTypography(actor)),'e17a5a9bdaa32056b274d7b12d2a492eee381d4fc70f70c521a4d9b705232f5d');
  const hero=descendants(battleLayout()).find(n=>n.name==='hero');
  assert.equal(digest(preReadableUnitTypography(hero,{hero:true})),'ee457437376d90ded5fe29ce2018ed9266eda755a59779022c9571b8439a3d97');
  assert(!descendants(hero).some(n=>layers.has(n.name)));
  const second=enemyUnitTemplate('second');second.children.find(n=>n.name==='intentVfxBehind').children.push({name:'local'});
  assertLayers(enemyUnitTemplate());
});
test('actual candidate build emits both ordered layers in its complete 647-control actor template',t=>{
  const dir=mkdtempSync(join(tmpdir(),'monster-intent-layers-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
  buildUI(dir,undefined,{artFeatures:{monsters:true}});
  const templates=JSON.parse(readFileSync(join(dir,'game-ui-templates.json')));
  const actors=templates.filter(n=>n.name===monsterActorTemplateName);assert.equal(actors.length,1);
  const actor=actors[0];assertLayers(actor);assert.equal(actor.children.length,35);assert.equal(actor.visible,false);
  assert.equal(descendants(actor).length,647);assert.equal(monsterActorInventory(actor).controlsPerActor,647);
  assert.deepEqual(actor.children.slice(1),enemyUnitTemplate().children);
  assert.equal(descendants(actor).filter(n=>/^shape\d+$/.test(n.name)).length,600);
  assert.deepEqual(actor.children.find(n=>n.name==='statusRow').children,[]);
  const layout=JSON.parse(readFileSync(join(dir,'game-ui.json')));
  for(const tree of [layout,...templates])assertNativeUiCapacity(tree);
  assert(!descendants(layout).some(n=>layers.has(n.name)),'no live actor instances or hero layers added');
});
