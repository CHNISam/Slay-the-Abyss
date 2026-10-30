// Source artwork is shared; each monster instance owns a candidate-bound output surface.
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {enemyUnitTemplate,enemyPowerTemplate} from './ui-layout.mjs';
import {createHash} from 'node:crypto';
import {nativeArtPool,validateNativeCardArt} from './card-art-samples.mjs';
export const monsterSourceInputs=Object.freeze(['art/monsters/acid_slime_m/native-art-r02/native-art.lua','art/monsters/acid_slime_m/native-art-r02/native-art.json']);
export function prepareMonsterArt(input) {
  return prepareMonsterArtRegistry(input,false);
}
// Inventory consumers need the validated source paths, not mutable output art.
// No cache: each invocation reads, hashes and validates the real JSON/source.
// JSON-only input keeps omitted structuredClone calls free of observable errors.
export function monsterArtInputPaths() {
  const art=prepareMonsterArtRegistry(undefined,true);
  return art===null?null:art.inputPaths;
}
function prepareMonsterArtRegistry(input,inventoryOnly) {
  const registry=input??JSON.parse(readFileSync('data/presentation/native-monster-art.json','utf8'));
  const inputPaths=[];
  if(!input&&registry.enabled) {
    if(!Array.isArray(registry.sourceInputs)||registry.sourceInputs.length!==4)throw new Error('Missing monster art provenance');
    for(const [index,record] of registry.sourceInputs.entries()) {
      if(typeof record.path!=='string'||!record.path.startsWith(index<2?'art/monsters/acid_slime_m/native-art-r02/':'art/monster-benchmarks/genshin-v1/dendro-slime/')||record.path.includes('..')||!/^([a-f0-9]{64})$/.test(record.sha256))throw new Error('Invalid monster art source record');
      // Raw source PNG/prompt are provenance, not runtime image dependencies.
      if(index<2) {
        if(record.path!==`art/monsters/acid_slime_m/native-art-r02/native-art.${index===0?'lua':'json'}`||record.sha256!==registry.asset?.[index===0?'luaSha256':'jsonSha256'])throw new Error('Monster art provenance identity mismatch');
        if(createHash('sha256').update(readFileSync(record.path)).digest('hex')!==record.sha256)throw new Error('Monster native source hash mismatch');
        inputPaths.push(record.path);
      }
    }
  }
  if(registry.schemaVersion!==1||typeof registry.enabled!=='boolean'||![undefined,1,5].includes(registry.poolCount))throw new Error('Invalid monster art registry');
  if(!registry.enabled)return null;
  const asset=registry.asset;
  if(asset?.enemyId!=='acid_slime_m'||!Array.isArray(registry.canvas)||registry.canvas.length!==2||registry.canvas.some(n=>!Number.isFinite(n)||n<=0)
    ||!Array.isArray(asset.slots)||asset.slots.length>600||asset.slots.some(slot=>![100001,100002,100003].includes(slot.image)))throw new Error('Invalid bounded monster art asset');
  // Keep the mature native slot/type validation, without loosening its contract.
  const capacity=validateNativeCardArt({schemaVersion:2,editorCommit:'103025f9095d8089e3f9bf097f4d0c5fe039d546',canvas:[144,64],
    assets:{cleave:{...asset,cardId:'cleave'}}});
  const assets={[asset.enemyId]:inventoryOnly?{capacity}:{...structuredClone(asset),cardId:asset.enemyId,capacity}};
  const bindings=registry.bindings??{[asset.enemyId]:asset.enemyId};
  if(!bindings||typeof bindings!=='object'||Array.isArray(bindings)||Object.keys(bindings).length>42||Object.keys(registry.additionalAssets??{}).length>41)throw new Error('Invalid bounded monster catalog');
  for(const [id,entry] of Object.entries(registry.additionalAssets??{})) {
    if(!/^[a-z][a-z0-9-]+$/.test(id)||entry.enemyId!==id||assets[id]||!Array.isArray(entry.slots)||entry.slots.length>600||entry.slots.some(slot=>![100001,100002,100003].includes(slot.image)))throw new Error('Invalid additional monster art asset');
    const count=validateNativeCardArt({schemaVersion:2,editorCommit:'103025f9095d8089e3f9bf097f4d0c5fe039d546',canvas:[144,64],assets:{cleave:{...entry,cardId:'cleave'}}});
    if(!Array.isArray(entry.sourceInputs)||entry.sourceInputs.length!==2)throw new Error('Missing additional monster provenance');
    for(const [index,record] of entry.sourceInputs.entries()) {
      const extension=index===0?'lua':'json';
      if(record.path!==`art/monster-benchmarks/${['pyro-abyss-mage','geovishap-hatchling','stonehide-lawachurl'].includes(id)?'genshin-v1':'genshin-v2'}/${id}/native-art.${extension}`||record.sha256!==entry[extension+'Sha256'])throw new Error('Additional monster provenance identity mismatch');
      if(!input&&createHash('sha256').update(readFileSync(record.path)).digest('hex')!==record.sha256)throw new Error('Additional monster source hash mismatch');
      inputPaths.push(record.path);
    }
    assets[id]=inventoryOnly?{capacity:count}:{...structuredClone(entry),cardId:id,capacity:count};
  }
  for(const [enemy,id] of Object.entries(bindings))if(!/^[a-z][a-z0-9_]+$/.test(enemy)||!Object.hasOwn(assets,id))throw new Error('Invalid monster binding');
  if(!Object.keys(assets).every(id=>Object.values(bindings).includes(id)))throw new Error('Unbound monster art asset');
  const poolCapacity=Math.max(...Object.values(assets).map(a=>a.capacity));
  for(const entry of Object.values(assets))entry.capacity=poolCapacity;
  if(inventoryOnly)return {inputPaths};
  return {...structuredClone(registry),inputPaths,assets,bindings,poolCapacity,asset:assets[asset.enemyId]};
}
export const monsterPowerTemplateName='AbyssMonsterPower';
export const monsterActorTemplateName='AbyssMonsterActor';
export const monsterActorBindingModule='abyss_monster_actor_binding';
export function monsterActorTemplate(art) {
  const actor=enemyUnitTemplate(monsterActorTemplateName);
  actor.visible=false;
  if(art) {
    const pool=nativeArtPool(art.poolCapacity??art.asset.capacity);
    pool.name='monsterSamples';pool.position=[0,0];pool.size=[...art.canvas];
    for(const group of pool.children)group.size=[...art.canvas];
    const host={name:'monsterArt',kind:'container',position:[0,0],size:[...art.canvas],visible:false,children:[pool]};
    actor.children.unshift(host);
  }
  return actor;
}
export function attachMonsterArt(tree,art) {
  let found=0;
  function visit(node) {
    const children=node.children??node.controls??[];
    const layer=children.find(c=>c.name==='actorLayer');
    if(layer) {
      if(layer.kind!=='container'||layer.mask||layer.children?.length||JSON.stringify(layer.position)!=='[0,0]')throw Error('Invalid empty monster actor layer');
      if(children.some(c=>/^enemy[0-9]+$/.test(c.name)))throw Error('Static enemies cannot coexist with dynamic actor surfaces');
      found++;
    }
    for(const child of children)visit(child);
  }
  visit(tree);
  if(found!==1)throw Error('Missing or ambiguous monster actor layer');
  if(art)art.hostOrigin=[0,0];
}
export function writeMonsterActorBinding(directory,{templateIndex=0,containerTemplateIndex=0,powerTemplateIndex=0,enabled=false}={}) {
  for(const index of [templateIndex,containerTemplateIndex,powerTemplateIndex])if(!Number.isSafeInteger(index)||index<0)throw Error('Invalid monster actor template index');
  if(enabled&&(!templateIndex||!containerTemplateIndex||!powerTemplateIndex||new Set([templateIndex,containerTemplateIndex,powerTemplateIndex]).size!==3))throw Error('Monster actor binding requires distinct positive template indices');
  writeFileSync(join(directory,monsterActorBindingModule+'.lua'),`-- Candidate-local bindings; zero is an unbound offline preview, not a playable candidate.\nreturn {templateIndex=${templateIndex},containerTemplateIndex=${containerTemplateIndex},powerTemplateIndex=${powerTemplateIndex},enabled=${enabled?'true':'false'}}\n`);
}
export function bindMonsterActorTemplates(directory,{actor,group,power}) {
  for(const result of [actor,group,power])if(!Number.isSafeInteger(result?.templateIndex)||result.templateIndex<=0)throw Error('Missing actual monster actor template index');
  writeMonsterActorBinding(directory,{templateIndex:actor.templateIndex,containerTemplateIndex:group.templateIndex,powerTemplateIndex:power.templateIndex,enabled:true});
}
export function monsterActorInventory(template) {
  const count=node=>1+(node.children??[]).reduce((total,child)=>total+count(child),0);
  const shapes=node=>(/^shape[0-9]+$/.test(node.name)?1:0)+(node.children??[]).reduce((total,child)=>total+shapes(child),0);
  return {templateName:monsterActorTemplateName,controlsPerActor:count(template),shapesPerActor:shapes(template),
    powerTemplateName:monsterPowerTemplateName,controlsPerPower:count(enemyPowerTemplate()),powerAllocation:'per-power-instance',
    allocation:'per-drawable-actor-instance',measurement:'offline-template-count-not-official-load',officialImport:'not_run',devices:'not_run'};
}
