import {loadConvertedCardPack,convertedArtInputs} from './converted-card-data.mjs';
import {toLua} from '../build-lua-data.mjs';
import {createHash} from 'node:crypto';
// Register empty holders, not thousands of static children per card/template.
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {buildReadyCardRegistry} from './ready-card-registry.mjs';
import {bindNativeArtPresentation} from '../card-art-samples.mjs';
export const readyArtImageTemplate='AbyssReadyCardImage';
export const readyArtGroupTemplate='AbyssReadyCardGroup';
export function readyArtTemplates(){return [
 {name:readyArtImageTemplate,kind:'image',size:[1,1],image:100001,colour:'#FFFFFF',visible:false},
 {name:readyArtGroupTemplate,kind:'container',size:[144,64],visible:false,children:[]},
];}
function holder(children) {
 if(children.some(c=>c.name==='artSamples'))throw Error('Cannot combine static and dynamic card art pools');
 const plate=children.find(c=>c.name==='artPlate');
 if(JSON.stringify(plate.size)!=='[144,64]'||JSON.stringify(plate.position)!=='[0,40]')throw Error('Card aperture changed');
 const index=children.findLastIndex(c=>c.name==='art'||c.name.startsWith('art_'))+1;
 if(index===0)throw Error('Missing fallback card image');
 children.splice(index,0,{name:'artSamples',kind:'container',position:[0,40],size:[144,64],visible:false,children:[]});
}
export function attachReadyCardHosts(tree) {
 const hosts=[];
 function visit(node,path) {
  const current=[...path,node.name??''],children=node.children??node.controls??[];
  if(children.some(c=>c.name==='artPlate')){holder(children);hosts.push(current.join('/'));}
  for(const child of children)if(child.name!=='artSamples')visit(child,current);
 }
 visit(tree,[]);return hosts;
}
export function bindReadyCardPresentation(cards,{root=process.cwd()}={}) {
 const registry=buildReadyCardRegistry({root});
 bindNativeArtPresentation(cards,{registry,capacity:2657});
 for(const id of Object.keys(registry.assets))cards[id].nativeArt.runtime=true;
 return registry;
}
export const readyArtModule='abyss_ready_card_binding.lua';
export const readyArtInputs=['armaments','cleave','heavy_blade'].flatMap(id=>['asset.json','native-art.lua','native-art.json'].map(file=>`art/cards/traveler-geo/${id}/${file}`));
export function writeReadyArtBinding(directory,{imageTemplateIndex=0,containerTemplateIndex=0,enabled=false}={}) {
 for(const index of [imageTemplateIndex,containerTemplateIndex])if(!Number.isSafeInteger(index)||index<0)throw Error('Invalid card art template index');
 writeFileSync(join(directory,readyArtModule),`-- Candidate-local native template binding; zero is an offline unbound preview.\nreturn {imageTemplateIndex=${imageTemplateIndex},containerTemplateIndex=${containerTemplateIndex},enabled=${enabled?'true':'false'}}\n`);
}
export function bindReadyArtTemplates(directory,{image,group},{enabled=true}={}) {
 for(const result of [image,group])if(!Number.isSafeInteger(result?.templateIndex)||result.templateIndex<=0)throw Error('Missing actual card art template index');
 if(image.templateIndex===group.templateIndex)throw Error('Card image and group template indices must differ');
 writeReadyArtBinding(directory,{imageTemplateIndex:image.templateIndex,containerTemplateIndex:group.templateIndex,enabled});
}
export function readyArtRuntimeInventory(directory){
 if(directory&&(!existsSync(join(directory,readyArtAssetModule+'.lua'))||!readFileSync(join(directory,readyArtAssetModule+'.lua'),'utf8').includes('["runtime"]=true')))return undefined;
 return {
 assetCount:75,preciseAssets:3,compactAssets:72,maxLivePools:10,maxShapesPerPool:2657,maxGroupsPerPool:45,
 peakDynamicControls:27020,maxCreatesPerUpdate:64,measurement:'offline-allocation-bound-not-official-load',
 officialImport:'not_run',devices:'not_run',
};}

export const readyArtAssetModule='abyss_ready_card_assets';
export function readyArtSourceInputs(root=process.cwd()){return [...readyArtInputs,...convertedArtInputs(root)];}
export function prepareReadyCardAssets({root=process.cwd()}={}) {
 const cards={armaments:{},cleave:{},heavy_blade:{}};
 bindReadyCardPresentation(cards,{root});
 const assets=Object.fromEntries(Object.entries(cards).map(([id,row])=>[id,row.nativeArt]));
 const pack=loadConvertedCardPack(root);
 for(const [id,row]of Object.entries(pack.cards))assets[id]={cardId:id,runtime:true,rectangles:row.rectangles,
  rectangleCount:row.rectangleCount,rectangleEncoding:pack.encoding,sourcePreviewSha256:row.sourcePreviewSha256,
  rectangleSha256:createHash('sha256').update(row.rectangles).digest('hex')};
 return assets;
}
export function writeReadyCardAssets(directory,{root=process.cwd(),prepared}={}) {
 const assets=prepared??prepareReadyCardAssets({root});
 writeFileSync(join(directory,readyArtAssetModule+'.lua'),'-- Frozen reviewed artwork, loaded only after native template binding.\nreturn '+toLua(assets)+'\n');
 return assets;
}
