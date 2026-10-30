import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';

export const portraitModule='abyss_traveler_portrait_assets';
const base='art/characters/traveler-geo/portraits';
const assets=[
 {kind:'avatar96',count:4822,width:96,display:32,runtime:'c30551e1fed1cd7f18c61b67fe0ad0cd6e52c61bfa6ae937ccd9e4c90e7f72bb',json:'93bcf4303d370f7faac2b8289146acfe655bae6dced0abf5257e407d69f748ef'},
 {kind:'battle133',count:4315,width:133,display:400/3,runtime:'ae2161957033d688b1bed1c7ab2ad2891d5f7bf5e34b291f9ecaef7cfa11f880',json:'f8a7af7b079aa5bbb7e16b502b222f1fd7dbfaa2c30f6eef1bf0d76af0a0a248'},
];
const licensePath=`${base}/avatar96/LICENSE-runtime-MIT.txt`;
export const portraitInputs=[...assets.flatMap(a=>['runtime-no-snapshot.lua','native-art.json'].map(f=>`${base}/${a.kind}/${f}`)),licensePath];
const hash=b=>createHash('sha256').update(b).digest('hex');
function license(root) {
 const bytes=readFileSync(join(root,licensePath));
 if(hash(bytes)!=='b5f34362abd2e8c31b7a7bc62c2977f158faa4cd78b17ef7c197fb464e56a6ef')throw Error('Frozen portrait runtime license changed');
 return bytes.toString('utf8');
}
export function portraitSources(root=process.cwd()) {
 license(root);
 return assets.map(a=>{
  const path=`${base}/${a.kind}/runtime-no-snapshot.lua`,bytes=readFileSync(join(root,path));
  if(hash(bytes)!==a.runtime||hash(readFileSync(join(root,`${base}/${a.kind}/native-art.json`)))!==a.json)
   throw Error(`Frozen portrait input changed: ${a.kind}`);
  const source=bytes.toString('utf8'),start=source.indexOf('local ROOT = '),end=source.indexOf('\nlocal created = {}');
  if(start<0||end<=start)throw Error(`Missing frozen portrait literal block: ${a.kind}`);
  const literals=source.slice(start,end);
  return {...a,literals};
 });
}
export function attachOfficialPortraits(layout) {
 const stage=layout.controls.find(c=>c.name==='stage');
 const child=(p,n)=>{const c=p?.children?.find(c=>c.name===n);if(!c)throw Error(`Missing portrait parent ${n}`);return c;};
 const traveler=child(child(stage,'characterPanel'),'traveler'),hero=child(child(stage,'battlePanel'),'hero');
 if(traveler.children.some(c=>c.name==='officialAvatar')||hero.children.some(c=>c.name==='officialFigure'))throw Error('Portrait hosts already attached');
 const bust=child(child(child(traveler,'hit'),'normal'),'bust');
 traveler.children.push({name:'officialAvatar',kind:'container',position:[...bust.position],size:[96,96],scale:[1/3,1/3],visible:false,children:[]});
 const index=hero.children.findIndex(c=>c.name==='portrait');
 hero.children.splice(index+1,0,{name:'officialFigure',kind:'container',position:[0,0],size:[133,133],scale:[(400/3)/133,(400/3)/133],visible:false,children:[]});
}
function validIndex(index,allowUnbound=false) {
 return Number.isSafeInteger(index)&&index>=(allowUnbound?0:1)&&index!==100001;
}
export function writePortraitModule(directory,{root=process.cwd(),imageTemplateIndex=0,containerTemplateIndex=0}={}) {
 if(!validIndex(imageTemplateIndex,true)||!validIndex(containerTemplateIndex,true))throw Error('Invalid portrait templateIndex');
 const data=portraitSources(root).map(a=>`${a.kind}=(function()\n${a.literals}\nreturn {root=ROOT,rows=ELEMENTS,width=${a.width},count=${a.count},display=${a.display},sourceSha256='${a.runtime}',jsonSha256='${a.json}'}\nend)()`);
 const source=`--[=[
${license(root)}]=]
-- Frozen portrait literal bytes; no original synchronous OnStart/exporter included.\n-- Native property sequence is derived from Primitive's MIT runtime (2026 LiuL).\nreturn {imagePrefabId=${imageTemplateIndex},containerPrefabId=${containerTemplateIndex},\n${data.join(',\n')}\n}\n`;
 writeFileSync(join(directory,`${portraitModule}.lua`),source,'utf8');return source;
}
export function bindPortraitTemplates(directory,result,options={}) {
 const imageTemplateIndex=result?.image?.templateIndex,containerTemplateIndex=result?.container?.templateIndex;
 if(!validIndex(imageTemplateIndex)||!validIndex(containerTemplateIndex))throw Error('MCP did not return valid portrait image/container templateIndex');
 return writePortraitModule(directory,{...options,imageTemplateIndex,containerTemplateIndex});
}
export function portraitRuntimeInventory(directory) {
 if(!existsSync(join(directory,`${portraitModule}.lua`)))return undefined;
 return {assets:assets.map(a=>({asset:`traveler-geo/portraits/${a.kind}`,images:a.count,groups:Math.ceil(a.count/60),pages:Math.ceil(a.count/3600),sourceSha256:a.runtime})),
  instances:2,batchSize:64,peakDynamicControls:9294,maxDirectDynamicChildren:60,officialCapacity:'not_measured',
  measurement:'offline-runtime-control-contract-not-official-capacity',devicePerformance:'not_run'};
}
