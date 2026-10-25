// Add native world geometry and synthetic parallax layers to the same all-stage save.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync,existsSync,readdirSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {connectMcp} from './mcp.mjs';
if(!process.argv[2]||!process.argv[3])throw Error('Usage: node extend-scenes.mjs <prepared-20-stage-directory> <new-output-directory>');
const here=dirname(fileURLToPath(import.meta.url)),repo=resolve(here,'../../..');
const previous=resolve(process.argv[2]),out=resolve(process.argv[3]);
if(existsSync(out)&&readdirSync(out).length)throw Error('Output directory must be empty: '+out);
mkdirSync(out,{recursive:true});
let mapPath=join(out,'source.gil');copyFileSync(join(previous,'art-pressure-all.gil'),mapPath);
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const client=await connectMcp('art-pressure-scenes',out);
let step=0;
async function call(name,args={}){
 const r=await client.callTool({name,arguments:{mapPath,...args}},undefined,{timeout:120000});
 const d=r.structuredContent??JSON.parse(r.content.find(c=>c.type==='text').text);
 writeFileSync(join(out,`${String(++step).padStart(2,'0')}-${name}.json`),JSON.stringify(d,null,2));
 if(r.isError||d.error)throw Error(JSON.stringify(d));if(d.mapPath)mapPath=d.mapPath;return d;
}
try{
 for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeFileSync(join(out,uri.split('//')[1]+'.json'),JSON.stringify(await client.readResource({uri}),null,2));
 const scene=JSON.parse(readFileSync(join(repo,'docs/art/scene-spike/geo-ruins.scene.json')));
 const prefabs=[];
 for(const item of scene.blocks){
  const d=await call('scene_add_prefab',{asset:item.template,name:'AP3D_'+item.name,scale:item.scale,outputName:'pressure-scene-prefab'});
  if(!Number.isSafeInteger(d.prefabId))throw Error('Missing prefab ID: '+JSON.stringify(d));
  await call('scene_add_components',{prefab:d.prefabId,solid:false,outputName:'pressure-scene-nonsolid'});
  prefabs.push({...item,prefabId:d.prefabId});
 }
 const production=JSON.parse(readFileSync(join(here,'production-3d.scene.json')));
 const productionPrefabs=[];const byModel=new Map();
 for(const item of production.blocks){
  const key=JSON.stringify([item.template,item.scale]);let prefabId=byModel.get(key);
  if(!prefabId){
   const p=await call('scene_add_prefab',{asset:item.template,name:'AP_PROD_'+productionPrefabs.length,scale:item.scale,outputName:'production-prefab'});
   prefabId=p.prefabId;if(!Number.isSafeInteger(prefabId))throw Error('Missing production prefab');
   await call('scene_add_components',{prefab:prefabId,solid:false,outputName:'production-nonsolid'});byModel.set(key,prefabId);
  }
  productionPrefabs.push({...item,prefabId});
 }
 const environment=await call('scene_add_environment',{name:'AP_GeoSealDusk',hour:18,stars:false,milkyWay:false,clouds:true,outputName:'production-dusk'});
 if(!Number.isSafeInteger(environment.environmentId))throw Error('Missing environment ID: '+JSON.stringify(environment));
 await call('scene_add_light',{name:'AP_SealDoorLight',environment:environment.environmentId,position:[5.6,3.4,8.2],radius:7,intensity:1.4,range:70,outputName:'production-key-light'});
 await call('scene_add_light',{name:'AP_SealFill',environment:environment.environmentId,position:[0,4,0],radius:10,intensity:1,range:70,outputName:'production-fill-light'});
 await call('scene_add_signal',{name:'AP_SCENE',parameters:[{name:'groups',type:'integer'},{name:'requestId',type:'integer'}],outputName:'pressure-scene-signal'});
 await call('scene_add_signal',{name:'AP_SCENE_READY',parameters:[{name:'groups',type:'integer'},{name:'count',type:'integer'},{name:'requestId',type:'integer'}],outputName:'pressure-scene-ack'});
 const graph=await call('scene_add_graph',{name:'AP_Scene_World',outputName:'pressure-scene-graph'});
 if(!Number.isSafeInteger(graph.graphId))throw Error('Missing graph ID');
 const creates=prefabs.map(p=>{
  const [x,y,z]=p.position,rot=p.rotation??[0,0,0];
  return `f.createPrefab(${p.prefabId},f.create3dVector(${x}+ox,${y},${z}+oz),[${rot}],evt.eventSourceEntity,false,1,[] as bigint[]);`;
 }).join('\n');
 const productionCreates=productionPrefabs.map(p=>`f.createPrefab(${p.prefabId},[${p.position}],[${p.rotation??[0,0,0]}],evt.eventSourceEntity,false,1,[] as bigint[]);`).join('\n');
 const code=`/// <reference types="genshin-ts" />
import { g, defineSignal } from 'genshin-ts/runtime/core'
const SWITCH=defineSignal('AP_SCENE',[['groups','int'],['requestId','int']] as const)
const ACK=defineSignal('client:AP_SCENE_READY',[['player','entity'],['groups','int'],['count','int'],['requestId','int']] as const)
g.server({id:${graph.graphId},name:'AP_Scene_World',variables:{requested:0n,requestId:0n}})
.onSignal(SWITCH,(evt,f)=>{
 f.set('requested',evt.params.groups);
 f.set('requestId',evt.params.requestId);
 f.stopTimer(evt.eventSourceEntity,'AP_WORLD_TICK');
 f.startTimer(evt.eventSourceEntity,'AP_WORLD_TICK',true,[0.25]);
})
.on('whenTimerIsTriggered',(evt,f)=>{
 if(evt.timerName!=='AP_WORLD_TICK')return;
 if(f.getListLength(f.getListOfEntitiesOwnedByTheEntity(evt.eventSourceEntity))>0n){
  for(let i=0n;i<16n;i++){
   const remaining=f.getListOfEntitiesOwnedByTheEntity(evt.eventSourceEntity);
   if(f.getListLength(remaining)>0n)f.removeEntity(remaining[0]);
  }
  return;
 }
 const requested=f.get('requested');
 const players=f.getListOfPlayerEntitiesOnTheField();
 f.modifyEnvironmentSettings(${environment.environmentId},players,false,0n);
 if(requested===100n){${productionCreates}}
 if(requested>0n && requested<=12n){
  for(let group=0n;group<requested;group++){
   const ox=requested===1n?0:Number(group%3n-1n)*7;
   const oz=Number(group/3n)*4;
   ${creates}
  }
 }
 const count=f.getListLength(f.getListOfEntitiesOwnedByTheEntity(evt.eventSourceEntity));
 f.stopTimer(evt.eventSourceEntity,'AP_WORLD_TICK');
 f.printString('ARTSCENE_WORLD_APPLIED');f.printString(f.dataTypeConversion(requested,'str'));f.printString(f.dataTypeConversion(count,'str'));
 for(const player of f.getListOfPlayerEntitiesOnTheField())f.sendSignal(ACK,player,requested,count,f.get('requestId'));
})`;
 writeFileSync(join(out,'AP_Scene_World.ts'),code);
 const built=await call('write_graphs',{graphs:[{graphId:graph.graphId,code}]});
 if(built.failed)throw Error(JSON.stringify(built));
 await call('scene_set_camera',{distance:22,fieldOfView:43,fixedView:{yaw:0,pitch:22,ignoreCollision:true},outputName:'pressure-scene-camera'});
 await call('scene_set_spawn',{position:[0,0,0],rotation:[0,0,0],outputName:'pressure-scene-spawn'});
 const control=readFileSync(join(previous,'AP_Control.lua'),'utf8');
 const host=Number(control.match(/local HOST_PREFAB_ID = (\d+)/)[1]);
 const image=Number(readFileSync(join(previous,'AP_A.lua'),'utf8').match(/local IMAGE_PREFAB_ID = (\d+)/)[1]);
 const extended=readFileSync(join(here,'controller.lua'),'utf8').replace('local HOST_PREFAB_ID = 0',`local HOST_PREFAB_ID = ${host}`).replace('local EXTENDED = false','local EXTENDED = true');
 const scenery=readFileSync(join(here,'scenes.lua'),'utf8').replace('local IMAGE_PREFAB_ID = 0',`local IMAGE_PREFAB_ID = ${image}`);
 writeFileSync(join(out,'AP_Control.lua'),extended);writeFileSync(join(out,'AP_Scenes.lua'),scenery);
 copyFileSync(join(here,'production-25d.lua'),join(out,'AP_Production25D.lua'));
 await call('scene_set_client_script',{name:'AP_Production25D',sourceFile:join(out,'AP_Production25D.lua'),outputName:'production-25d-script'});
 for(const name of ['AP_Scenes','AP_Control'])await call('scene_set_client_script',{name,sourceFile:join(out,name+'.lua'),outputName:'pressure-scene-script'});
 const checked=await call('scene_check_client');if(!checked.ok||checked.errors)throw Error(JSON.stringify(checked));
 const candidate=join(out,'art-pressure-all-scenes.gil');copyFileSync(mapPath,candidate);
 const manifest={state:'prepared',candidate,candidateHash:hash(candidate),sourceCandidateHash:hash(join(previous,'art-pressure-all.gil')),prefabs,productionPrefabs,environmentId:environment.environmentId,graphId:graph.graphId,checked,stages:41,performance:'UNVERIFIED',liveWrite:false};
 writeFileSync(join(out,'candidate.json'),JSON.stringify(manifest,null,2));console.log(JSON.stringify(manifest));
}finally{await client.close();}
