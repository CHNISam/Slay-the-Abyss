import {readFileSync, writeFileSync, existsSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';

export const backgroundModule = 'abyss_menu_background_asset';
export const backgroundTemplate = 'AbyssOfficialBackgroundImage';
const directory = 'art/characters/key-visual/traveler-geo/official-landscape-v1/runtime';
export const backgroundInputs = [`${directory}/background_adapter.lua`, `${directory}/background_data.lua`];
const hashes = ['5cbaca64eeac8c7765640f7116b953bd70a3175b18e2bf665fcf0b2e35ef9f5a',
  'c5f4429f6e664ba8f18d79f440a87167cd7ec6c1adad36fd41e2342414e72397'];
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export function backgroundSources(root = process.cwd()) {
  return backgroundInputs.map((path, i) => {
    const bytes = readFileSync(join(root,path));
    if(hash(bytes)!==hashes[i])throw Error(`Frozen official background input changed: ${path}`);
    return bytes.toString('utf8');
  });
}
export function attachOfficialBackground(layout, templates) {
  const stage=layout.controls.find(c=>c.name==='stage');
  if(!stage || stage.children.some(c=>c.name==='officialBackground'))throw Error('Expected one fresh stage background host');
  stage.children.unshift({name:'officialBackground',kind:'container',size:[480,270],visible:false,children:[]});
  templates.push({name:backgroundTemplate,kind:'image',size:[20,20],image:100001});
}
export function writeBackgroundModule(directory, {root=process.cwd(), templateIndex=0,enabled=true} = {}) {
  if(!Number.isSafeInteger(templateIndex)||templateIndex<0)throw Error('Invalid official background templateIndex');
  if(!enabled){const source='-- Disabled optional drawing.\nreturn {enabled=false,imagePrefabId=0}\n';writeFileSync(join(directory,`${backgroundModule}.lua`),source);return source;}
  const [adapter,data]=backgroundSources(root);
  const source=`-- Frozen official landscape; only the candidate-local template binding varies.\nlocal imagePrefabId = ${templateIndex}\nlocal adapter = (function()\n${adapter}\nend)()\nlocal data = (function()\n${data}\nend)()\nreturn {adapter=adapter,data=data,imagePrefabId=imagePrefabId}\n`;
  writeFileSync(join(directory,`${backgroundModule}.lua`),source,'utf8');
  return source;
}
export function bindBackgroundTemplate(directory, result, options = {}) {
  const index=result?.templateIndex;
  if(!Number.isSafeInteger(index)||index<=0)throw Error('MCP did not return a valid official background templateIndex');
  return writeBackgroundModule(directory,{...options,templateIndex:index});
}
export function backgroundRuntimeInventory(directory) {
  if(!existsSync(join(directory,`${backgroundModule}.lua`))||readFileSync(join(directory,`${backgroundModule}.lua`),'utf8').includes('enabled=false'))return undefined;
  return {asset:'traveler-geo/official-landscape-v1',host:'stage/officialBackground',instances:1,
    pages:['menu','character'],dynamicControlsPerInstance:13201,peakDynamicControls:13201,maxDirectDynamicChildren:13201,batchSize:64,
    sourceSha256:'fc0e4c50c0ed03a7a790731df5f5e10076d1418db615c41784210e9677c24ce3',
    measurement:'offline-runtime-control-contract-not-official-capacity'};
}
