import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {enemyUnitTemplate,battleLayout} from '../scripts/ui-layout.mjs';
import {preReadableUnitTypography} from './helpers/readable-unit-typography-inverse.mjs';
const digest=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
test('readability inverse preserves frozen geometry and rejects typography or unrelated drift',()=>{
 for(const hero of [false,true]){
  const source=hero?battleLayout().controls.find(n=>n.name==='stage').children.find(n=>n.name==='hero'):enemyUnitTemplate();
  const frozen=hero?'ee457437376d90ded5fe29ce2018ed9266eda755a59779022c9571b8439a3d97':'e17a5a9bdaa32056b274d7b12d2a492eee381d4fc70f70c521a4d9b705232f5d';
  const project=value=>{const old=preReadableUnitTypography(value,{hero});if(!hero){old.children=old.children.filter(n=>!['intentVfxBehind','intentVfxAfter'].includes(n.name));old.children.find(n=>n.name==='intent').text.valign='top';}return old;};
  const before=structuredClone(source);assert.equal(digest(project(source)),frozen);assert.deepEqual(source,before,'projection never mutates production layout');
  for(const key of ['fontSize','minFontSize']){const changed=structuredClone(source);changed.children.find(n=>n.name==='hp').text[key]--;assert.throws(()=>project(changed),/exact readable typography/);}
  for(const mutate of [n=>{n.size[0]++;},n=>{n.children.find(c=>c.name==='portrait').image++;},n=>{n.children.push({name:'unknown',kind:'container'});}]){
   const changed=structuredClone(source);mutate(changed);assert.notEqual(digest(project(changed)),frozen,'unrelated drift must reach the unchanged frozen oracle');
  }
  const missing=structuredClone(source);missing.children=missing.children.filter(n=>n.name!=='hp');assert.throws(()=>project(missing),/unique reviewed text/);
 }
});
