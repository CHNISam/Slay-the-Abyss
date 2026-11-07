// Original six-petal ceramic seal: follows art/monsters/hexaghost's reviewed
// silhouette, not the commercial game's original green ghost artwork.
export function hexaghostParts(){
 const parts=[],round=x=>Math.round(x*1000)/1000;
 for(let i=0;i<6;i++){
  const degrees=i*60,a=degrees*Math.PI/180,s=Math.sin(a),c=Math.cos(a);
  const at=(radius,z=0)=>[round(radius*s),round(2+radius*c),z];
  parts.push({name:`rim_${i+1}`,shape:'cube',position:at(.43),size:[.49,.17,.34],rotation:[0,0,-degrees],color:'#393337',solid:false});
  parts.push({name:`ceramic_${i+1}`,shape:'pentagonal pyramid',position:at(1.04),size:[.87,1.5,.46],rotation:[0,0,-degrees-12],color:i%2?'#A8978A':'#B6A599',solid:false});
  parts.push({name:`socket_${i+1}`,shape:'pentagonal prism',position:at(.72,.265),size:[.31,.08,.31],rotation:[90,0,-degrees],color:'#493126',solid:false});
  parts.push({name:`fire_${i+1}`,shape:'pentagonal pyramid',position:at(.77,.325),size:[.16,.27,.10],rotation:[0,0,-degrees],color:'#E58A35',solid:false});
 }
 return parts;
}
export const shapeSample={id:'hexaghost',name:'LAB3D_hexaghost_shapes',title:'六焰陶核 · 24块原生积木',parts:hexaghostParts(),solid:false};

export function shapeGraphSource({graphId,name,shapePrefabId,anchorPrefabId,anchor=[0,.4,0]}){
 const send=(message,seq)=>`for(const player of f.getListOfPlayerEntitiesOnTheField())f.sendSignal(ACK,player,${message},${seq});`;
 const link=`f.switchFollowMotionDeviceTargetByEntity(shape,mover,'',[0,0,0],[0,0,0],FollowCoordinateSystem.WorldCoordinateSystem,FollowLocationType.FollowLocation);f.activateDisableFollowMotionDevice(shape,true);`;
 return `/// <reference types="genshin-ts" />
import {g,defineSignal} from 'genshin-ts/runtime/core'
import {FollowCoordinateSystem,FollowLocationType} from 'genshin-ts/definitions/enum'
const COMMAND=defineSignal('SHAPE3D_COMMAND',[['command','str'],['seq','int']] as const)
const ACK=defineSignal('client:SHAPE3D_ACK',[['player','entity'],['message','str'],['seq','int']] as const)
g.server({id:${graphId},name:${JSON.stringify(name)}})
.onSignal(COMMAND,(evt,f)=>{
 const stage=f.getSelfEntity(),sequence=evt.params.seq;
 let command=evt.params.command;if(command==='move')command='idle';if(command==='turn')command='rotate';
 if(sequence<=f.getCustomVariable(stage,'SHAPE_seq').asType('int')){${send("'duplicate_or_stale'",'sequence')}return;}
 f.setCustomVariable(stage,'SHAPE_seq',sequence,true);
 if(command!=='show'&&command!=='hide'&&command!=='idle'&&command!=='attack'&&command!=='hit'&&command!=='death'&&command!=='rotate'){${send("'unsupported:shape_command'",'sequence')}return;}
 if(command==='show'||command==='hide'||command==='death'){
  f.stopTimer(stage,'SHAPE_DONE');f.setCustomVariable(stage,'SHAPE_busy',false,true);
  for(const unit of f.getEntitiesWithSpecifiedPrefabOnTheField(${shapePrefabId})){if(command==='death')f.destroyEntity(unit);else f.removeEntity(unit);}
  for(const unit of f.getEntitiesWithSpecifiedPrefabOnTheField(${anchorPrefabId}))f.removeEntity(unit);
  if(command==='hide'){${send("'hidden'",'sequence')}return;}
  if(command==='death'){${send("'completed:death_whole_object'",'sequence')}return;}
  const mover=f.createPrefab(${anchorPrefabId},[${anchor[0]+4},${anchor[1]},${anchor[2]+3}],[0,0,0],stage,false,1,[] as bigint[]);
  const shape=f.createPrefab(${shapePrefabId},[${anchor[0]+4},${anchor[1]},${anchor[2]+3}],[0,180,0],stage,false,1,[] as bigint[]);
  ${link}
  f.setCustomVariable(stage,'SHAPE_yaw',180n,true);${send("'ready:whole_object_not_rigged'",'sequence')}return;
 }
 const shapes=f.getEntitiesWithSpecifiedPrefabOnTheField(${shapePrefabId}),movers=f.getEntitiesWithSpecifiedPrefabOnTheField(${anchorPrefabId});
 if(shapes.length!==1||movers.length!==1){${send("'missing_shape:show_first'",'sequence')}return;}
 if(f.getCustomVariable(stage,'SHAPE_busy').asType('bool')){${send("'busy'",'sequence')}return;}
 const mover=movers[0];
 if(command==='rotate'){
  const yaw=f.getCustomVariable(stage,'SHAPE_yaw').asType('int')+90n;
  f.setCustomVariable(stage,'SHAPE_yaw',yaw,true);f.removeEntity(shapes[0]);
  const shape=f.createPrefab(${shapePrefabId},f.getEntityLocationAndRotation(mover).location,f.create3dVector(0,f.dataTypeConversion(yaw,'float'),0),stage,false,1,[] as bigint[]);
  ${link}
  ${send("'completed:rotation_by_recreation_not_rotation_motor'",'sequence')}return;
 }
 if(command==='idle'){f.recoverBasicMotionDevice(mover,'SHAPE_bob');${send("'completed:idle_native_bob'",'sequence')}return;}
 f.pauseBasicMotionDevice(mover,'SHAPE_bob');
 if(command==='attack')f.activateBasicMotionDevice(mover,'SHAPE_attack');
 else f.activateBasicMotionDevice(mover,'SHAPE_hit');
 f.setCustomVariable(stage,'SHAPE_busy',true,true);f.setCustomVariable(stage,'SHAPE_action',command,true);
 f.setCustomVariable(stage,'SHAPE_pendingseq',sequence,true);f.startTimer(stage,'SHAPE_DONE',false,[.6]);${send("'requested:whole_object_motion'",'sequence')}
})
.on('whenTimerIsTriggered',(evt,f)=>{
 if(evt.timerName!=='SHAPE_DONE')return;
 const stage=evt.eventSourceEntity,sequence=f.getCustomVariable(stage,'SHAPE_pendingseq').asType('int');
 for(const mover of f.getEntitiesWithSpecifiedPrefabOnTheField(${anchorPrefabId}))f.recoverBasicMotionDevice(mover,'SHAPE_bob');
 f.setCustomVariable(stage,'SHAPE_busy',false,true);
 ${send("'completed:timed_whole_motion_requires_visual_check'",'sequence')}
})
`;
}

// call must use an isolated checkout of upstream f32c8b0 or newer. No global
// installation changes, editor import, UI input or existing graph rewrites.
export async function prepareShapeSample({call,mapPath,anchor=[0,.4,0]}={}){
 if(!call||!mapPath)throw Error('Shape sample requires call and mapPath');
 if(anchor.length!==3||!anchor.every(Number.isFinite)||Math.abs(anchor[1])>20)throw Error('Use playable ground coordinates');
 async function invoke(name,args={}){const value=await call(name,{...args,mapPath});if(value.error||value.isError)throw Error(`${name}: ${JSON.stringify(value)}`);if(value.mapPath)mapPath=value.mapPath;return value;}
 const shape=await invoke('scene_add_shape_prefab',{name:shapeSample.name,parts:shapeSample.parts,solid:shapeSample.solid});
 if(shape.parts!==24)throw Error('Shape part count differs');
 await invoke('scene_add_components',{prefab:shape.prefabId,follow:'attach'});
 const mover=await invoke('scene_add_prefab',{asset:10005018,name:'LAB3D_shape_motion_anchor'});
 await invoke('scene_add_components',{prefab:mover.prefabId,motions:[
  {name:'SHAPE_bob',path:[{position:[0,.20,0],seconds:2}],loop:'backAndForth',active:true},
  {name:'SHAPE_attack',path:[{position:[-.65,0,-.45],seconds:.15},{position:[0,0,0],seconds:.30}],loop:'once'},
  {name:'SHAPE_hit',path:[{position:[.28,0,.18],seconds:.10},{position:[0,0,0],seconds:.20}],loop:'once'},
 ]});
 await invoke('scene_add_components',{entity:'关卡实体',variables:[{name:'SHAPE_seq',type:'integer',value:0},{name:'SHAPE_pendingseq',type:'integer',value:0},{name:'SHAPE_yaw',type:'integer',value:180},{name:'SHAPE_busy',type:'boolean',value:false},{name:'SHAPE_action',type:'string',value:''}]});
 await invoke('scene_add_signal',{name:'SHAPE3D_COMMAND',parameters:[{name:'command',type:'string'},{name:'seq',type:'integer'}]});
 await invoke('scene_add_signal',{name:'SHAPE3D_ACK',parameters:[{name:'message',type:'string'},{name:'seq',type:'integer'}]});
 const graph=await invoke('scene_add_graph',{name:'LAB3D_SHAPE_SAMPLE',kind:'server'});
 const code=shapeGraphSource({graphId:graph.graphId,name:graph.name,shapePrefabId:shape.prefabId,anchorPrefabId:mover.prefabId,anchor});
 const compiled=await invoke('write_graphs',{graphs:[{graphId:graph.graphId,code}]});
 if(compiled.failed||compiled.errors?.length||compiled.written?.length!==1)throw Error('Shape graph compilation incomplete: '+JSON.stringify(compiled));
 const readback=await invoke('scene_list_prefabs');
 if(!readback.prefabs.some(p=>p.prefabId===shape.prefabId)||!readback.prefabs.some(p=>p.prefabId===mover.prefabId))throw Error('Shape prefab readback incomplete');
 return {mapPath,prefabId:shape.prefabId,anchorPrefabId:mover.prefabId,graphId:graph.graphId,graphName:graph.name,source:code,
  inventory:{shapeParts:24,visibleEntities:1,hiddenMotionAnchors:1,prefabs:2,graphs:1,partCollisions:0,damageNodes:0,skeletons:0,customTextures:0},
  capabilities:{show:true,hide:true,idle:'whole_object_native_motion_via_anchor',attack:'whole_object_lunge_not_official_attack_clip',hit:'whole_object_recoil_not_official_hit_clip',death:'whole_object_destroy_not_death_clip',rotate:'recreate_with_rotation_not_runtime_rotation_motor',officialImport:'not_run',visualMotion:'not_run',nativeLoad:'unverified',mobile:'not_run'},
  bridge:{commandSignal:'SHAPE3D_COMMAND',parameters:['command:string','seq:integer'],ackSignal:'SHAPE3D_ACK',ackParameters:['message:string','seq:integer'],commands:['show','move','attack','hit','turn','death','hide']}};
}
