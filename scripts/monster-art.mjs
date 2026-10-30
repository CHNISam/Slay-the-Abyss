// One bounded native drawing, not a monster renderer or an image importer.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {nativeArtPool,validateNativeCardArt} from './card-art-samples.mjs';
export function prepareMonsterArt(input) {
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
  if(registry.schemaVersion!==1||typeof registry.enabled!=='boolean')throw new Error('Invalid monster art registry');
  if(!registry.enabled)return null;
  const asset=registry.asset;
  if(asset?.enemyId!=='acid_slime_m'||!Array.isArray(registry.canvas)||registry.canvas.length!==2||registry.canvas.some(n=>!Number.isFinite(n)||n<=0)
    ||!Array.isArray(asset.slots)||asset.slots.length>600||asset.slots.some(slot=>![100001,100002,100003].includes(slot.image)))throw new Error('Invalid bounded monster art asset');
  // Keep the mature native slot/type validation, without loosening its contract.
  const capacity=validateNativeCardArt({schemaVersion:2,editorCommit:'103025f9095d8089e3f9bf097f4d0c5fe039d546',canvas:[144,64],
    assets:{cleave:{...asset,cardId:'cleave'}}});
  return {...structuredClone(registry),inputPaths,asset:{...structuredClone(asset),cardId:asset.enemyId,capacity}};
}
export function attachMonsterArt(tree,art) {
  if(!art)return;
  let found=0;
  function visit(node) {
    const children=node.children??node.controls??[];
    const index=children.findIndex(c=>c.name==='enemy1');
    if(index>=0) {
      const pool=nativeArtPool(art.asset.capacity);
      pool.name='monsterSamples';pool.position=[0,0];pool.size=[...art.canvas];
      for(const group of pool.children)group.size=[...art.canvas];
      const overlay=children.find(c=>c.name==='topBar');
      if(!overlay?.children||overlay.kind!=='container'||overlay.mask)throw new Error('Missing unmasked behind-unit container');
      const origin=overlay.position??[0,0];
      if(art.hostOrigin&&JSON.stringify(art.hostOrigin)!==JSON.stringify(origin))throw new Error('Inconsistent monster art host origin');
      art.hostOrigin=[...origin];
      overlay.children.unshift({name:'monsterArt',kind:'container',position:[0,0],size:[...art.canvas],visible:false,children:[pool]});found++;
    }
    for(const child of children)if(child.name!=='monsterArt')visit(child);
  }
  visit(tree);
  if(found!==1)throw new Error('Missing or ambiguous monster portrait stage');
}
