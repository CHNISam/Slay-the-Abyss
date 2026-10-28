import test from 'node:test';
import assert from 'node:assert/strict';
import {cpSync,existsSync,mkdirSync,mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {runLua} from '../scripts/test-lua.mjs';
import {integration as proof,acceptedPresentationSource,digest,historicalRelics} from './helpers/presentation-m3-integration.mjs';

import {retirementSources,preRetirementSource} from './helpers/presentation-announcement-retirement.mjs';

const oldTheme=JSON.parse(proof.beforeSources['data/presentation/ui_theme.json']);
const theme=JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));
const rgba=hex=>`{a=255,b=${parseInt(hex.slice(5,7),16)},g=${parseInt(hex.slice(3,5),16)},r=${parseInt(hex.slice(1,3),16)}}`;
const row=source=>{
  const match=/^\{1=string:([^,]+),2=string:([^,]+),3=(.*)\}$/.exec(source);
  assert(match,'complete native write row');
  return {path:match[1],field:match[2],value:match[3]};
};
const hash=entries=>{
  let value=0;
  for(const entry of entries)for(const byte of Buffer.from(entry+'\n'))value=(value*131+byte)%2147483647;
  return value;
};
function addition(source){
  const {path,field,value}=row(source);
  const name=/^root\/(?:battlePanel\/card[12]|nodePanel\/pickerView\/(?:before|after|forgeGrid\/card(?:[1-9]|10)))\/(nameBand|nameRule)$/.exec(path);
  if(name){
    assert.equal(field,'imageColor');
    assert.equal(value,rgba(name[1]==='nameBand'?theme.color.rarityBand.basic:theme.color.rarity.basic));
    return 'rarityDecoration';
  }
  assert.match(path,/^root\/nodePanel\/pickerView\/(?:before|after|forgeGrid\/card(?:[1-9]|10))\/cost$/);
  assert.equal(field,'fontColor');
  assert([theme.color.energy,theme.color.positive,theme.color.textMuted].map(rgba).includes(value));
  return 'nodeCostInk';
}
function replacement(before,after,flight){
  const a=row(before),b=row(after);
  assert.equal(a.path,b.path,'visual migration cannot change control ownership');
  assert.equal(a.field,b.field,'visual migration cannot change native API');
  if(/\/(?:card[12]|pickerView\/(?:before|after|forgeGrid\/card(?:[1-9]|10)))\/border$/.test(a.path)){
    assert.equal(a.field,'imageColor');assert.equal(a.value,rgba(oldTheme.color.rarity.basic));
    assert.equal(b.value,rgba(theme.color.rarity.basic));return 'rarityInk';
  }
  if(/^root\/battlePanel\/card[12]\/cost$/.test(a.path)){
    assert.equal(a.field,'fontColor');assert.equal(a.value,rgba(oldTheme.color.textOnLight));
    assert.equal(b.value,rgba(theme.color.energy));return 'energyInk';
  }
  if(a.path==='root/battlePanel/feedback/playedCard'){
    assert(['SetAnchoredPosition','x'].includes(a.field));
    const x=value=>Number(a.field==='x'?value:/^\{1=([^,]+),2=/.exec(value)[1]);
    if(a.field==='SetAnchoredPosition'){
      flight.count++;
      assert.equal(a.value.slice(a.value.indexOf(',2=')),b.value.slice(b.value.indexOf(',2=')),'flight y is unchanged');
    }
    assert(flight.count>=1&&flight.count<=14);
    const expected=(theme.layout.enemyRow.xFromFew-oldTheme.layout.enemyRow.xFrom)*(flight.count/14)**2;
    assert(Math.abs((x(b.value)-x(a.value))-expected)<1e-9,'same quadratic flight follows the moved target');
    return 'targetFlight';
  }
  const enemy=/^root\/battlePanel\/enemy1(?:\/(.+))?$/.exec(a.path);
  assert(enemy,'only reviewed two-enemy geometry can otherwise change');
  const part=enemy[1]||'';
  const sizes={floating:[220,246,80],name:[196,222,40],hpBorder:[134,160,20],
    hpTrack:[130,156,16],hpGhost:[130,156,16],hpFill:[130,156,16],hp:[130,156,40],
    'statusRow/hit':[196,222,60]};
  if(part in sizes){
    const [oldWidth,newWidth,height]=sizes[part];
    assert(['SetSizeDelta','size','sizeDeltaX'].includes(a.field));
    assert.equal(a.value,a.field==='sizeDeltaX'?String(oldWidth):`{1=${oldWidth},2=${height}}`);
    assert.equal(b.value,a.field==='sizeDeltaX'?String(newWidth):`{1=${newWidth},2=${height}}`);
  }else{
    assert(['','block','blockEdge','blockIcon'].includes(part));
    assert(['SetAnchoredPosition','x'].includes(a.field));
    const [oldX,newX,y]=part?[-50,-63,-100]:[-192,32,64];
    assert.equal(a.value,a.field==='x'?String(oldX):`{1=${oldX},2=${y}}`);
    assert.equal(b.value,a.field==='x'?String(newX):`{1=${newX},2=${y}}`);
  }
  return 'enemyGeometry';
}
function verify(before,after,delta){
  assert.equal(before.length,79543);assert.equal(hash(before),1215629804,'accepted room-port trace remains frozen');
  assert.equal(after.length,79757);assert.equal(hash(after),1467902785,'reviewed integrated live trace');
  assert.equal(delta.additions.length,214);assert.equal(delta.replacements.length,593);
  const inserted=new Map(delta.additions.map(item=>[item.index,item.row]));
  assert.equal(inserted.size,214,'no duplicate insertion positions');
  const changed=new Map(delta.replacements.map(item=>[item.index,item]));
  assert.equal(changed.size,593,'no duplicate replacement positions');
  const counts={},flight={count:0};let oldIndex=0,unchanged=0;
  const count=kind=>counts[kind]=(counts[kind]||0)+1;
  for(let index=0;index<after.length;index++){
    if(inserted.has(index)){
      assert.equal(after[index],inserted.get(index),'insertion value and global position');count(addition(after[index]));continue;
    }
    if(changed.has(oldIndex)){
      const item=changed.get(oldIndex);
      assert.equal(before[oldIndex],item.before);assert.equal(after[index],item.after);
      count(replacement(item.before,item.after,flight));
    }else{assert.equal(after[index],before[oldIndex],'all other writes retain values and global order');unchanged++;}
    oldIndex++;
  }
  assert.equal(oldIndex,before.length);assert.equal(unchanged,78950);assert.equal(flight.count,14);
  assert.deepEqual(counts,{rarityInk:40,rarityDecoration:156,nodeCostInk:58,enemyGeometry:512,energyInk:13,targetFlight:28});
  return counts;
}

test('M3 frame and first UI batch retain every old native write except the explicitly reviewed visual delta',()=>{
  assert.equal(proof.base,'4f5bf5bb30821f88f33467585abec3caba7e6005');
  assert.deepEqual(proof.heads,{nest:'15b879f4b8d2f9771ac2b124adc8e8b7abd8ee9e',drag:'fcb18ea8345585e02cf869143ef9f85430bc8676',frame:'41dda081f46f0cbad68e88e9b8f6924a0d5b93ca',ui:'8849c853f8a2e7a43dd52fd9fee821872b077f38'});
  verify(proof.before,proof.after,proof.delta);
  for(const path of Object.keys(proof.beforeSources)){
    acceptedPresentationSource(path);
    assert.throws(()=>acceptedPresentationSource(path,(existsSync(path)?readFileSync(path,'utf8'):'')+'\n-- drift\n'),/unreviewed integrated/);
  }
});

test('visual proof rejects changed gameplay text, missing writes, reordered writes and broadened visual approval',()=>{
  const wrong=[...proof.after];const position=wrong.findIndex(value=>value.includes('/hp,2=string:text,'));
  assert(position>=0);wrong[position]+='0';assert.throws(()=>verify(proof.before,wrong,proof.delta));
  assert.throws(()=>verify(proof.before,proof.after.slice(1),proof.delta));
  const reordered=[...proof.after];[reordered[0],reordered[1]]=[reordered[1],reordered[0]];
  assert.notEqual(proof.after[0],proof.after[1]);assert.throws(()=>verify(proof.before,reordered,proof.delta));
  assert.throws(()=>addition('{1=string:root/nodePanel/pickerView/before/cost,2=string:text,3=string:0}'));
  assert.throws(()=>replacement('{1=string:root/battlePanel/enemy1/hp,2=string:text,3=string:30/40}',
    '{1=string:root/battlePanel/enemy1/hp,2=string:text,3=string:31/40}',{count:0}));
  const moved=structuredClone(proof.delta);moved.additions[0].index++;assert.throws(()=>verify(proof.before,proof.after,moved));
});

for(const [count,hash,sources]of [
 [79543,1215629804,{...retirementSources.beforeSources,...proof.beforeSources}],
 [79757,1467902785,retirementSources.beforeSources],
])test(`the accepted presentation sources still execute the original strict ${count}-write fixture`,()=>{
  mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/accepted-presentation-'));
  try{
    // Repository-local temporary tree inherits installed node_modules resolution.
    // No downloads, Git history dependency, shared outputs or weakened deadline.
    for(const path of ['src','data','scripts','tools','config','tests/lua','package.json','package-lock.json',
      '.release-please-manifest.json','CHANGELOG.md'])cpSync(path,join(directory,path),{recursive:true});
    for(const [path,source]of Object.entries(sources))writeFileSync(join(directory,path),source);
    writeFileSync(join(directory,'data/relics.json'),historicalRelics());
    for(const script of ['build-lua-data.mjs','build-ui.mjs','build-ui-theme.mjs']){
      const result=spawnSync(process.execPath,['scripts/'+script],{cwd:directory,encoding:'utf8',timeout:30000});
      assert.equal(result.status,0,result.stdout+result.stderr);
    }
    const result=runLua('tests/lua/presentation_responsibilities_trace.lua',{cwd:directory});
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,new RegExp(`PRESENTATION_NATIVE_TRACE ${count} ${hash}`));
    assert.match(sources['tests/lua/presentation_responsibilities_trace.lua'],/trace:assertNativeInteraction\(\)/);
    assert.equal(digest(readFileSync('tests/lua/support/presentation_trace.lua','utf8').replaceAll('\r\n','\n')),
      digest(proof.beforeSources['tests/lua/support/presentation_trace.lua']),'strict recorder is unchanged');
  }finally{rmSync(directory,{recursive:true,force:true});}
});

test('historical replay inputs bind every changed build, host and version source, including the deleted module',()=>{
 assert.deepEqual(retirementSources.trace,{before:[79757,1467902785],removed:68,after:[79689,2034622601]});
 for(const [path,before]of Object.entries(retirementSources.beforeSources)){
  assert.equal(preRetirementSource(path),before);
  const live=existsSync(path)?readFileSync(path,'utf8'):'';
  assert.throws(()=>preRetirementSource(path,live+'\n-- unreviewed drift\n'),/unreviewed integrated retirement source drift/);
 }
 assert.equal(existsSync('src/lua/abyss_release_notes_ui.lua'),false);
 assert.match(retirementSources.beforeSources['tests/lua/presentation_responsibilities_trace.lua'],/assert\(trace.count==79757 and trace.hash==1467902785/);
});

test('historical relic projection rejects changed, missing, reordered and unrelated definitions',()=>{
 const source=readFileSync('data/relics.json','utf8');
 assert.equal(historicalRelics(source),historicalRelics(source.replaceAll('\r\n','\n').replaceAll('\n','\r\n')));
 const original=JSON.parse(source);
 for(const mutate of [
  data=>{data.relics.find(row=>row.id==='molten_egg').rarity='common';},
  data=>{data.relics=data.relics.filter(row=>row.id!=='odd_mushroom');},
  data=>{data.relics.reverse();},
  data=>{data.relics[0].name+='drift';},
 ]){
  const data=structuredClone(original);mutate(data);
  assert.throws(()=>historicalRelics(JSON.stringify(data,null,2)+'\n'),/unreviewed integrated/);
 }
});
