import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {toLua} from './build-lua-data.mjs';

export const portraitModule='abyss_traveler_portrait_assets';
const base='art/characters/traveler-geo/portraits';
const assets=[
 {kind:'avatar96',count:4822,width:96,display:32,runtime:'c30551e1fed1cd7f18c61b67fe0ad0cd6e52c61bfa6ae937ccd9e4c90e7f72bb',json:'93bcf4303d370f7faac2b8289146acfe655bae6dced0abf5257e407d69f748ef'},
 {kind:'battle133',count:4315,width:133,display:400/3,runtime:'ae2161957033d688b1bed1c7ab2ad2891d5f7bf5e34b291f9ecaef7cfa11f880',json:'f8a7af7b079aa5bbb7e16b502b222f1fd7dbfaa2c30f6eef1bf0d76af0a0a248'},
];
const licensePath=`${base}/avatar96/LICENSE-runtime-MIT.txt`;
const selectionBudgetPath='art/performance/selection-budget-v1.json';
export const portraitInputs=[...assets.flatMap(a=>['runtime-no-snapshot.lua','native-art.json'].map(f=>`${base}/${a.kind}/${f}`)),licensePath,selectionBudgetPath,
 `${base}/avatar96/preview-native-1x.png`,`${base}/battle133/preview-native-1x.png`];
const hash=b=>createHash('sha256').update(b).digest('hex');
export function selectionBudget(root=process.cwd()) {
 const bytes=readFileSync(join(root,selectionBudgetPath));
 if(hash(bytes)!=='df3b34983dafd051842c820e6c7bf0931926fccba00fce0cc8873cab0f803b82')throw Error('Selection budget data changed');
 const pack=JSON.parse(bytes);
 for(const [id,width,count]of [['avatar96',96,457],['selection133',133,1940]]) {
  const a=pack.assets[id];
  if(a.width!==width||a.count!==count||a.rows.length!==count||hash(readFileSync(join(root,a.source)))!==a.sourceSha256
   ||a.rows.some(r=>r.length!==18||r.some(n=>!Number.isFinite(n))||r[0]!==100001||r[3]<=0||r[4]<=0||r[13]!==0
    ||r.slice(14).some(n=>n<0||n>255)||Math.abs(r[1])+r[3]/2>width/2||Math.abs(r[2])+r[4]/2>width/2))throw Error('Invalid selection budget '+id);
 }
 return pack;
}
function license(root) {
 const bytes=readFileSync(join(root,licensePath));
 if(hash(bytes)!=='b5f34362abd2e8c31b7a7bc62c2977f158faa4cd78b17ef7c197fb464e56a6ef')throw Error('Frozen portrait runtime license changed');
 return bytes.toString('utf8');
}
const selectedAssets=({selectionAvatar=true,battlePortrait=true}={})=>assets.filter(a=>a.kind==='avatar96'?selectionAvatar:battlePortrait);
export function portraitSourceInputs(options={}) {
 const selected=selectedAssets(options);if(!selected.length)return [];
 return [...selected.flatMap(a=>['runtime-no-snapshot.lua','native-art.json'].map(f=>`${base}/${a.kind}/${f}`)),licensePath,
  ...(selected.some(a=>a.kind==='avatar96')?[selectionBudgetPath,`${base}/avatar96/preview-native-1x.png`,`${base}/battle133/preview-native-1x.png`]:[])];
}
export function portraitSources(root=process.cwd(),options) {
 const selected=selectedAssets(options);if(selected.length)license(root);
 return selected.map(a=>{
  const path=`${base}/${a.kind}/runtime-no-snapshot.lua`,bytes=readFileSync(join(root,path));
  if(hash(bytes)!==a.runtime||hash(readFileSync(join(root,`${base}/${a.kind}/native-art.json`)))!==a.json)
   throw Error(`Frozen portrait input changed: ${a.kind}`);
  const source=bytes.toString('utf8'),start=source.indexOf('local ROOT = '),end=source.indexOf('\nlocal created = {}');
  if(start<0||end<=start)throw Error(`Missing frozen portrait literal block: ${a.kind}`);
  const literals=source.slice(start,end);
  return {...a,literals};
 });
}
export function attachOfficialPortraits(layout,{selectionAvatar=true,battlePortrait=true}={}) {
 if(!selectionAvatar&&!battlePortrait)return;
 const stage=layout.controls.find(c=>c.name==='stage');
 const child=(p,n)=>{const c=p?.children?.find(c=>c.name===n);if(!c)throw Error(`Missing portrait parent ${n}`);return c;};
 if(selectionAvatar){
  const selection=child(stage,'characterPanel'),traveler=child(selection,'traveler');
  if(traveler.children.some(c=>c.name==='officialAvatar'))throw Error('Portrait hosts already attached');
  const bust=child(child(child(traveler,'hit'),'normal'),'bust');
  traveler.children.push({name:'officialAvatar',kind:'container',position:[...bust.position],size:[96,96],scale:[bust.size[0]/96,bust.size[0]/96],visible:false,children:[]});
  const details=child(selection,'details'),frame=child(details,'portraitFrame');
  const position=[frame.position[0],frame.position[1]-(frame.size[1]-frame.size[0])/2];
  details.children.splice(details.children.findIndex(c=>c.name==='portraits')+1,0,
   {name:'officialSelectionFigure',kind:'container',position,size:[133,133],scale:[frame.size[0]/133,frame.size[0]/133],visible:false,children:[]});
 }
 if(battlePortrait){
  const hero=child(child(stage,'battlePanel'),'hero');
  if(hero.children.some(c=>c.name==='officialFigure'))throw Error('Portrait hosts already attached');
  const index=hero.children.findIndex(c=>c.name==='portrait');
  hero.children.splice(index+1,0,{name:'officialFigure',kind:'container',position:[0,0],size:[133,133],scale:[(400/3)/133,(400/3)/133],visible:false,children:[]});
 }
}
function validIndex(index,allowUnbound=false) {
 return Number.isSafeInteger(index)&&index>=(allowUnbound?0:1)&&index!==100001;
}
// Breakthrough low-poly select look (art/lowpoly-select). Emitted only for the flag that owns it:
// selectionAvatar -> lowpolyHero, cards -> lowpolyCardFan (premium frames + illustrations).
export const lowpolySelectPath='art/lowpoly-select/select-lowpoly.json';
export function lowpolySelectLiterals(root=process.cwd(),{selectionAvatar=false,cards=false}={}) {
 if(!selectionAvatar&&!cards)return [];
 const bytes=readFileSync(join(root,lowpolySelectPath)),data=JSON.parse(bytes),sha=createHash('sha256').update(bytes).digest('hex');
 const asset=(name,a)=>`${name}=${toLua({rows:a.rows.map(r=>[r[0],r[1],r[2],r[3],r[4],.5,.5,.5,.5,.5,.5,1,1,r[7],r[8],r[9],r[10],r[11],r[5],r[6]]),
  width:a.width,height:a.height,count:a.rows.length,renderProfile:'lowpoly-v1',cache:true,jsonSha256:sha,sourceSha256:data.sourceSha256,
  root:[0,0,a.width,a.width,.5,.5,.5,.5,.5,.5,1,1,0]})}`;
 return [...(selectionAvatar?[asset('lowpolyHero',data.hero)]:[]),...(cards?[asset('lowpolyCardFan',data.cardFan)]:[])];
}
export function writePortraitModule(directory,{root=process.cwd(),imageTemplateIndex=0,containerTemplateIndex=0,selectionAvatar=true,battlePortrait=true,cards=false}={}) {
 if(!validIndex(imageTemplateIndex,true)||!validIndex(containerTemplateIndex,true))throw Error('Invalid portrait templateIndex');
 const lowpoly=lowpolySelectLiterals(root,{selectionAvatar,cards});
 if(!selectionAvatar&&!battlePortrait){const source=lowpoly.length?`-- Disabled portraits; cards flag low-poly select fan only.\nreturn {imagePrefabId=0,containerPrefabId=0,\n${lowpoly.join(',\n')}\n}\n`:'-- Disabled optional drawings.\nreturn {imagePrefabId=0,containerPrefabId=0}\n';writeFileSync(join(directory,`${portraitModule}.lua`),source);return source;}
 const compactPath=join(directory,'art-performance.json');
 const compact=existsSync(compactPath)?JSON.parse(readFileSync(compactPath,'utf8')):null;
 const runtimeV2=existsSync(join(directory,'art-render-v2.json'));
 const budget=selectionAvatar&&(runtimeV2||!battlePortrait)&&!compact?selectionBudget(root):null;
 const budgetLiteral=(a,asset)=>toLua({root:[0,0,a.width,a.width,.5,.5,.5,.5,.5,.5,1,1,0],rows:asset.rows,width:a.width,count:asset.count,
  display:a.display,sourceSha256:a.runtime,jsonSha256:a.json,renderProfile:'selection-budget-v1',runtimeV2:true,cache:true,rectanglesOnly:true});
 const data=portraitSources(root,{selectionAvatar,battlePortrait}).map(a=>{
  if(budget&&a.kind==='avatar96')return `${a.kind}=${budgetLiteral(a,budget.assets.avatar96)}`;
  if(compact){const asset=compact.assets[a.kind];return `${a.kind}=${toLua({root:[0,0,a.width,a.width,.5,.5,.5,.5,.5,.5,1,1,0],rows:asset.rows,width:a.width,count:asset.count,display:a.display,sourceSha256:a.runtime,jsonSha256:a.json,renderProfile:'compact-v1',sourcePreviewSha256:asset.sha256})}`;}
  return `${a.kind}=(function()\n${a.literals}\nreturn {root=ROOT,rows=ELEMENTS,width=${a.width},count=${a.count},display=${a.display},sourceSha256='${a.runtime}',jsonSha256='${a.json}'${runtimeV2?',runtimeV2=true,cache=true,rectanglesOnly=true':''}}\nend)()`;
 });
 if(budget)data.push(`selection133=${budgetLiteral(assets[1],budget.assets.selection133)}`);
 data.push(...lowpoly);
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
function inventoryRows(selectionAvatar,battlePortrait,budget) {
 const rows=[];
 if(selectionAvatar)rows.push({asset:'traveler-geo/portraits/avatar96',images:budget?457:4822,sourceSha256:assets[0].runtime});
 if(selectionAvatar&&budget)rows.push({asset:'traveler-geo/portraits/selection133',images:1940,sourceSha256:assets[1].runtime});
 if(battlePortrait)rows.push({asset:'traveler-geo/portraits/battle133',images:4315,sourceSha256:assets[1].runtime});
 return rows.map(row=>({...row,groups:Math.ceil(row.images/60),pages:Math.ceil(row.images/3600)}));
}
export function portraitInventory({selectionAvatar=true,battlePortrait=true}={}, {budget=true}={}) {
 const rows=inventoryRows(selectionAvatar,battlePortrait,budget);if(!rows.length)return undefined;
 return {...(budget?{renderProfile:'selection-budget-v1',hiddenBuild:true,cache:true,revealGroupsPerFrame:4,
  ...(selectionAvatar?{selectionUses:'selection133'}:{})}:{}),assets:rows,instances:rows.length,batchSize:64,
  peakDynamicControls:rows.reduce((sum,a)=>sum+a.images+a.groups+a.pages,0),maxDirectDynamicChildren:60,officialCapacity:'not_measured',
  measurement:'offline-runtime-control-contract-not-official-capacity',devicePerformance:'not_run'};
}
export function portraitRuntimeInventory(directory) {
 if(!existsSync(join(directory,`${portraitModule}.lua`)))return undefined;
 const source=readFileSync(join(directory,`${portraitModule}.lua`),'utf8');
 const flags={selectionAvatar:/\bavatar96=/.test(source),battlePortrait:/\bbattle133=/.test(source)};
 if(existsSync(join(directory,'art-performance.json'))){
  const pack=JSON.parse(readFileSync(join(directory,'art-performance.json'),'utf8'));
  const rows=selectedAssets(flags).map(a=>{const row=pack.assets[a.kind];return {asset:`traveler-geo/portraits/${a.kind}`,images:row.count,
   groups:Math.ceil(row.count/60),pages:Math.ceil(row.count/3600),sourcePreviewSha256:row.sha256,grid:row.grid};});
  if(!rows.length)return undefined;
  return {renderProfile:'compact-v1',assets:rows,instances:rows.length,batchSize:64,peakDynamicControls:rows.reduce((n,a)=>n+a.images+a.groups+a.pages,0),maxDirectDynamicChildren:60,officialCapacity:'not_measured',devicePerformance:'not_run'};
 }
 return portraitInventory(flags,{budget:existsSync(join(directory,'art-render-v2.json'))||source.includes('selection133=')});
}
