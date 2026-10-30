import {readFileSync, writeFileSync, existsSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {toLua} from './build-lua-data.mjs';

export const backgroundModule = 'abyss_menu_background_asset';
export const backgroundTemplate = 'AbyssOfficialBackgroundImage';
const directory = 'art/characters/key-visual/traveler-geo/official-landscape-v1/runtime';
const frozenInputs = [`${directory}/background_adapter.lua`, `${directory}/background_data.lua`];
const budgetPath='art/performance/background-budget-v1.json';
const previewPath='art/characters/key-visual/traveler-geo/official-landscape-v1/preview-native.png';
export const backgroundInputs=[...frozenInputs,budgetPath,previewPath];
const hashes = ['5cbaca64eeac8c7765640f7116b953bd70a3175b18e2bf665fcf0b2e35ef9f5a',
  'c5f4429f6e664ba8f18d79f440a87167cd7ec6c1adad36fd41e2342414e72397'];
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export function backgroundSources(root = process.cwd()) {
  return frozenInputs.map((path, i) => {
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
export function writeBackgroundModule(directory, {root=process.cwd(), templateIndex=0,containerTemplateIndex=0,enabled=true} = {}) {
  if(!Number.isSafeInteger(templateIndex)||templateIndex<0)throw Error('Invalid official background templateIndex');
  if(!Number.isSafeInteger(containerTemplateIndex)||containerTemplateIndex<0)throw Error('Invalid official background containerTemplateIndex');
  if(!enabled){const source='-- Disabled optional drawing.\nreturn {enabled=false,imagePrefabId=0}\n';writeFileSync(join(directory,`${backgroundModule}.lua`),source);return source;}
  const [adapter,data]=backgroundSources(root);
  const compactPath=join(directory,'art-performance.json');
  if(existsSync(compactPath)){
    const asset=JSON.parse(readFileSync(compactPath,'utf8')).assets.background;
    const compact={width:480,height:270,count:asset.count,rows:asset.rows,renderProfile:'compact-v1',sourcePreviewSha256:asset.sha256};
    const source=`-- Compact display candidate; original frozen inputs remain validated.\nreturn {imagePrefabId=${templateIndex},containerPrefabId=${containerTemplateIndex},renderProfile='compact-v1',data=${toLua(compact)}}\n`;
    writeFileSync(join(directory,`${backgroundModule}.lua`),source,'utf8');return source;
  }
  const runtimeV2=existsSync(join(directory,'art-render-v2.json'));
  if(runtimeV2){
    const bytes=readFileSync(join(root,budgetPath));
    const budget=JSON.parse(bytes);
    if(hash(bytes)!=='47c696b1b9504c1b842fea20cdf3222c098ec8bd5886f0e8f68582a0430ba980'
      ||hash(readFileSync(join(root,previewPath)))!=='e23d1daac5e7046f9119edbd6179fd16fa31abd245c24d395adfd1af31a91a43'
      ||budget.width!==480||budget.height!==270||budget.count!==4500||budget.rows.length!==4500)
      throw Error('Background budget data changed');
    const native={...budget,runtimeV2:true,cache:true,rectanglesOnly:true};
    const source=`-- Full-resolution adaptive background experiment; original inputs stay frozen.\nreturn {imagePrefabId=${templateIndex},containerPrefabId=${containerTemplateIndex},renderProfile='background-budget-v1',data=${toLua(native)}}\n`;
    writeFileSync(join(directory,`${backgroundModule}.lua`),source,'utf8');return source;
  }
  const source=`-- Frozen official landscape; only binding/runtime ownership varies.\nlocal imagePrefabId = ${templateIndex}\nlocal adapter = (function()\n${adapter}\nend)()\nlocal data = (function()\n${data}\nend)()\n${runtimeV2?'data.runtimeV2=true;data.cache=true;data.rectanglesOnly=true;data.count=#data.rows\n':''}return {adapter=adapter,data=data,imagePrefabId=imagePrefabId${runtimeV2?",renderProfile='native-v2'":''}}\n`;
  writeFileSync(join(directory,`${backgroundModule}.lua`),source,'utf8');
  return source;
}
export function bindBackgroundTemplate(directory, result, options = {}) {
  const index=result?.templateIndex;
  if(!Number.isSafeInteger(index)||index<=0)throw Error('MCP did not return a valid official background templateIndex');
  if((existsSync(join(directory,'art-render-v2.json'))||existsSync(join(directory,'art-performance.json')))
    &&(!Number.isSafeInteger(options.containerTemplateIndex)||options.containerTemplateIndex<=0))throw Error('MCP did not return a valid official background containerTemplateIndex');
  return writeBackgroundModule(directory,{...options,templateIndex:index});
}
export function backgroundRuntimeInventory(directory) {
  if(!existsSync(join(directory,`${backgroundModule}.lua`))||readFileSync(join(directory,`${backgroundModule}.lua`),'utf8').includes('enabled=false'))return undefined;
  if(existsSync(join(directory,'art-performance.json'))){
    const a=JSON.parse(readFileSync(join(directory,'art-performance.json'),'utf8')).assets.background;
    const controls=a.count+Math.ceil(a.count/60)+Math.ceil(a.count/3600);
    return {asset:'traveler-geo/official-landscape-v1',renderProfile:'compact-v1',grid:a.grid,sourcePreviewSha256:a.sha256,
      host:'stage/officialBackground',instances:1,pages:['menu','character'],dynamicControlsPerInstance:controls,
      peakDynamicControls:controls,maxDirectDynamicChildren:60,batchSize:64,measurement:'offline-runtime-control-contract-not-official-capacity'};
  }
  if(existsSync(join(directory,'art-render-v2.json')))return {asset:'traveler-geo/official-landscape-v1',renderProfile:'background-budget-v1',host:'stage/officialBackground',instances:1,
    pages:['menu','character'],images:4500,dynamicControlsPerInstance:4577,peakDynamicControls:4577,maxDirectDynamicChildren:60,
    batchSize:256,timeBudgetMs:8,hiddenBuild:true,cache:true,revealGroupsPerFrame:4,budgetSha256:'47c696b1b9504c1b842fea20cdf3222c098ec8bd5886f0e8f68582a0430ba980',
    sourcePreviewSha256:'e23d1daac5e7046f9119edbd6179fd16fa31abd245c24d395adfd1af31a91a43',grid:[480,270],
    measurement:'offline-runtime-control-contract-not-official-capacity'};
  return {asset:'traveler-geo/official-landscape-v1',host:'stage/officialBackground',instances:1,
    pages:['menu','character'],dynamicControlsPerInstance:13201,peakDynamicControls:13201,maxDirectDynamicChildren:13201,batchSize:64,
    sourceSha256:'fc0e4c50c0ed03a7a790731df5f5e10076d1418db615c41784210e9677c24ce3',
    measurement:'offline-runtime-control-contract-not-official-capacity'};
}
