import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';

const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const load=name=>import(pathToFileURL(join(toolRoot,'src',name)));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export const nativeModels=Object.freeze([
  {model:1,name:'遗迹守卫',asset:30005001,idle:5001001,attack:5001002,attackSeconds:3.58,hit:5001011,hitSeconds:2.16},
  {model:2,name:'大型风史莱姆',asset:30005003,idle:5003001,attack:5003002,attackSeconds:2.28,hit:null},
  {model:3,name:'打手丘丘人',asset:30007001,idle:7001007,attack:7001012,attackSeconds:2.15,hit:null},
]);

// The installed tool rejects creature asset -> prefab. Reuse the actual official
// complex-creature template envelope instead, then replace all behavior through
// the tool's public operations. This is an experimental structural adaptation:
// changing the model of the envelope still needs official import validation.
export async function seedCreaturePrefabs({mapPath,outputPath,models=nativeModels}) {
  const {container,fields,field,one,replace,wrap,varint}=await load('scene/wire.mjs');
  const {inspectPrefabs}=await load('scene/prefabs.mjs');
  const sourcePath=join(toolRoot,'knowledge/samples/gil/mh6riq9wvxqq_复杂造物.gil');
  const sourceBytes=readFileSync(sourcePath),sourceRoot=container(sourceBytes);
  const seed=fields(one(sourceRoot,4)).filter(f=>f.id===1&&f.wire===2)
    .find(f=>Number(one(f.data,2,0))===30007001)?.data;
  if(!seed||Number(one(seed,9,0))!==4)throw Error('Official complex-creature seed missing');
  const bytes=readFileSync(mapPath);let root=container(bytes);
  const kind=b=>Number(one(b,1,0));
  const old=inspectPrefabs(root),prefabs=[];
  if(old.some(p=>p.name.startsWith('LAB3D_')))throw Error('LAB3D already exists: use the clean input copy');
  let next=Math.max(0x40800000,...old.map(p=>Number(p.gameId)).filter(id=>id>=0x40800000&&id<=0x408fffff))+1;
  for(const model of models){
    while(root.includes(varint(next)))next++;
    if(next>0x408fffff)throw Error('No free creature prefab ID');
    const name=`LAB3D_${model.model}`,id=next++;
    const entry=Buffer.concat(fields(seed).flatMap(f=>{
      if(f.id===1)return [field(1,0,id)];
      if(f.id===2)return [field(2,0,model.asset)];
      if(f.id===6&&f.wire===2){
        const type=kind(f.data);
        if(type===1)return [field(6,2,Buffer.concat([field(1,0,1),field(11,2,field(1,2,Buffer.from(name)))]))];
        // Remove source decision, skill, patrol and logic references. Public
        // scene_set_creature_logic installs new decision/skills/logic below.
        if([80,81,82].includes(type))return [];
        if(type===65)return [field(6,2,Buffer.concat([field(1,0,65),field(70,2,field(1,2,Buffer.alloc(0)))]))];
      }
      if(f.id===7&&f.wire===2){
        const type=kind(f.data);
        if(type===1){const v=Buffer.alloc(4);v.writeFloatLE(1);
          return [field(7,2,Buffer.concat([field(1,0,1),field(11,2,Buffer.concat([field(1,2,Buffer.alloc(0)),field(2,2,Buffer.alloc(0)),field(3,2,Buffer.concat([1,2,3].map(i=>field(i,5,v)))),field(501,0,4294967295)]))]))];}
        if(type===3)return [field(7,2,Buffer.concat([field(1,0,3),field(13,2,Buffer.alloc(0))]))];
      }
      // Source status-instance runtime record references an external sample
      // resource. It is deliberately omitted; own invincibility is added below.
      if(f.id===8&&f.wire===2&&kind(f.data)===42)return [];
      return [f.raw];
    }));
    root=replace(root,4,2,Buffer.concat([one(root,4),field(1,2,entry)]));
    const library=one(root,6),tabs=fields(library);
    const tab=tabs.find(t=>t.id===1&&t.wire===2&&kind(t.data)===18);
    const listed=field(5,2,Buffer.concat([field(1,0,2700),field(2,0,id)]));
    let changed;
    if(tab){
      const contents=fields(tab.data),existing=contents.find(t=>t.id===3&&t.wire===2);
      const tabBytes=existing?replace(tab.data,3,2,Buffer.concat([existing.data,listed])):Buffer.concat([tab.data,field(3,2,listed)]);
      changed=Buffer.concat(tabs.map(t=>t===tab?field(1,2,tabBytes):t.raw));
    }else{
      // Library-tab envelope copied from the actual official creature tab.
      const template=fields(one(sourceRoot,6)).find(t=>t.id===1&&t.wire===2&&kind(t.data)===18);
      if(!template)throw Error('Official creature library tab missing');
      const tabBytes=replace(template.data,3,2,listed);
      changed=Buffer.concat([library,field(1,2,tabBytes)]);
    }
    root=replace(root,6,2,changed);
    prefabs.push({...model,prefabId:id,prefabName:name});
  }
  const output=resolve(outputPath??join(dirname(mapPath),'lab3d-prefabs.gil'));
  if(output===resolve(mapPath))throw Error('Refuse to overwrite input save');
  mkdirSync(dirname(output),{recursive:true});writeFileSync(output,wrap(bytes,root),{flag:'wx'});
  const readback=inspectPrefabs(container(readFileSync(output)));
  for(const p of prefabs)if(!readback.some(r=>Number(r.gameId)===p.prefabId&&r.baseTemplateId===p.asset&&r.name===p.prefabName&&!r.duplicateIdentity))throw Error('Creature prefab readback failed');
  return {mapPath:output,prefabs,provenance:{sourcePath,sourceSha256:hash(sourceBytes),seedEntrySha256:hash(seed),method:'official_complex_template_model_adaptation',officialImport:'not_run',spawnability:'unverified'}};
}

const head="/// <reference types=\"genshin-ts\" />\nimport {g,defineSignal} from 'genshin-ts/runtime/core'\n";
const clientHead=head+"import {TargetEntity} from 'genshin-ts/definitions/client_enums'\n";
const signals=`const COMMAND=defineSignal('LAB3D_COMMAND',[['command','str'],['model','int'],['actor','int'],['seq','int']] as const)\nconst ACK=defineSignal('client:LAB3D_ACK',[['player','entity'],['message','str'],['seq','int']] as const)\n`;
const ack=(message,seq)=>`for(const player of f.getListOfPlayerEntitiesOnTheField())f.sendSignal(ACK,player,${message},${seq});`;

export function nativeGraphSources({graphs,prefabs,statusId,playerStatusId=statusId,floorId,anchor}){
  const createUnit=p=>`if(evt.params.model===${p.model}n){
  let slotX=${anchor[0]+3.5};if(slot===2n)slotX+=3;else if(slot===3n)slotX+=6;
  const unit=f.createPrefab(${p.prefabId},f.create3dVector(slotX,${anchor[1]},${anchor[2]+3}),[0,-90,0],stage,false,1,[] as bigint[]);
  const players=f.getListOfPlayerEntitiesOnTheField();
  if(players.length>0){const characters=f.getAllCharacterEntitiesOfSpecifiedPlayer(players[0]);if(characters.length>0){const character=characters[0];f.modifyEntityFaction(unit,f.queryEntityFaction(character));
   f.addUnitStatus(character,unit,${statusId},1n,f.createDictionary([] as string[],[] as number[]));
   f.addUnitStatus(character,character,${playerStatusId},1n,f.createDictionary([] as string[],[] as number[]));}}
  f.setCustomVariable(unit,'LAB_actor',slot,true);f.setCustomVariable(unit,'LAB_seq',sequence,true);
  f.setCustomVariable(unit,'LAB_command',0n,true);f.setCustomVariable(unit,'LAB_busy',1n,true);
  f.startTimer(unit,'LAB_READY',false,[4.5]);
  ${ack("'created:initializing_4.5s'","sequence")}return;
  }`;
  const server=head+signals+`g.server({id:${graphs.server.graphId},name:'${graphs.server.name}'})
.on('whenEntityIsCreated',(evt,f)=>{
 ${floorId?`f.createPrefab(${floorId},[${anchor[0]+4},${anchor[1]-0.35},${anchor[2]+2}],[0,0,0],evt.eventSourceEntity,false,1,[] as bigint[]);`:''}
 f.startTimer(evt.eventSourceEntity,'LAB_BOOT',true,[1]);
})
.on('whenTimerIsTriggered',(evt,f)=>{
 if(evt.timerName!=='LAB_BOOT')return;
 for(const player of f.getListOfPlayerEntitiesOnTheField()){
  const characters=f.getAllCharacterEntitiesOfSpecifiedPlayer(player);
  for(const character of characters){f.addUnitStatus(character,character,${playerStatusId},1n,f.createDictionary([] as string[],[] as number[]));f.stopTimer(evt.eventSourceEntity,'LAB_BOOT');}
 }
})
.onSignal(COMMAND,(evt,f)=>{
 const stage=f.getSelfEntity(),sequence=evt.params.seq,command=evt.params.command,slot=evt.params.actor;
 if(sequence<=f.getCustomVariable(stage,'LAB_lastseq').asType('int')){${ack("'duplicate_or_stale'","sequence")}return;}
 f.setCustomVariable(stage,'LAB_lastseq',sequence,true);
 if(command!=='show'&&command!=='reset'&&command!=='hide'&&command!=='idle'&&command!=='attack'&&command!=='hit'&&command!=='death'){${ack("'unsupported:command'","sequence")}return;}
 if(slot<0n||slot>3n){${ack("'unsupported:actor'","sequence")}return;}
 if(slot===0n&&command!=='hide'){${ack("'unsupported:player_animation'","sequence")}return;}
 if(command==='show'||command==='reset'||command==='hide'){
  ${prefabs.map(p=>`for(const unit of f.getEntitiesWithSpecifiedPrefabOnTheField(${p.prefabId})){if(slot===0n||f.getCustomVariable(unit,'LAB_actor').asType('int')===slot)f.removeEntity(unit);}`).join('\n')}
  if(command==='hide'){${ack("'hidden'","sequence")}return;}
  ${prefabs.map(createUnit).join('\n')}
  ${ack("'unsupported:model'","sequence")}return;
 }
 let found=false;
 ${prefabs.map(p=>`for(const unit of f.getEntitiesWithSpecifiedPrefabOnTheField(${p.prefabId})){
 if(f.getCustomVariable(unit,'LAB_actor').asType('int')===slot){
  found=true;
  if(command==='death'){f.destroyEntity(unit);${ack("'completed:death'","sequence")}}
  else if(command==='idle'){f.setCustomVariable(unit,'LAB_command',0n,true);f.setCustomVariable(unit,'LAB_busy',0n,true);${ack("'completed:idle'","sequence")}}
  else if(f.getCustomVariable(unit,'LAB_busy').asType('int')!==0n){${ack("'busy:wait_ready_or_animation'","sequence")}}
  else if(command==='hit'&&${p.hit===null?'true':'false'}){${ack("'unsupported:hit'","sequence")}}
  else{f.setCustomVariable(unit,'LAB_seq',sequence,true);f.setCustomVariable(unit,'LAB_busy',1n,true);f.setCustomVariable(unit,'LAB_command',command==='attack'?1n:2n,true);f.startTimer(unit,'LAB_TIMEOUT',false,[8]);${ack("'requested:await_skill_event'","sequence")}}
 }
 }`).join('\n')}
 if(!found){${ack("'missing_actor:show_first'","sequence")}}
})`;
  const unit=head+signals+`g.server({id:${graphs.unit.graphId},name:'${graphs.unit.name}'})
.on('whenTimerIsTriggered',(evt,f)=>{
 const unit=evt.eventSourceEntity,seq=f.getCustomVariable(unit,'LAB_seq').asType('int');
 if(evt.timerName==='LAB_READY'){f.setCustomVariable(unit,'LAB_busy',0n,true);${ack("'ready'","seq")}}
 if(evt.timerName==='LAB_TIMEOUT'&&f.getCustomVariable(unit,'LAB_busy').asType('int')===1n){f.setCustomVariable(unit,'LAB_command',0n,true);f.setCustomVariable(unit,'LAB_busy',0n,true);${ack("'error:animation_timeout'","seq")}}
})
.on('whenSkillNodeIsCalled',(evt,f)=>{
 const unit=evt.callerEntity,seq=f.getCustomVariable(unit,'LAB_seq').asType('int');
 f.stopTimer(unit,'LAB_TIMEOUT');f.setCustomVariable(unit,'LAB_command',0n,true);f.setCustomVariable(unit,'LAB_busy',0n,true);
 if(evt.parameter1==='LAB_attack'){${ack("'completed:attack'","seq")}}
 if(evt.parameter1==='LAB_hit'){${ack("'completed:hit'","seq")}}
})`;
  const decision=clientHead+`g.creationStatusDecision({id:${graphs.decision.graphId},name:'${graphs.decision.name}',prefix:false}).on('start1',(_evt,f)=>{
 const command=f.getCustomVariable(TargetEntity.Self,'LAB_command').asType('int');
 if(command===1n)f.switchToSelfExecutionStatus(true,${graphs.attack.graphId},1n);
 else if(command===2n)f.switchToSelfExecutionStatus(true,${graphs.hit.graphId},1n);
 else f.switchToSelfExecutionStatus(true,${graphs.idle.graphId},1n);
})`;
  const records=[{...graphs.server,code:server},{...graphs.unit,code:unit},{...graphs.decision,code:decision}];
  for(const [key,number] of [['attack',1],['hit',2],['idle',0]])records.push({...graphs[key],code:clientHead+`g.creationStatus({id:${graphs[key].graphId},name:'${graphs[key].name}',prefix:false}).on('start1',(_evt,f)=>{${number?`f.executeSkill(true,${number}n);`:''}f.tacticStandStill(true,'stand',false);})`});
  for(const action of ['attack','hit'])records.push({...graphs[`skill_${action}`],code:clientHead+`g.creationSkill({id:${graphs[`skill_${action}`].graphId},name:'${graphs[`skill_${action}`].name}',prefix:false}).on('start',(_evt,f)=>{f.notifyServerNodeGraph('LAB_${action}','','');})`});
  return records.map(({graphId,code})=>({graphId,code}));
}

export async function prepareNativeScene({call,mapPath,anchor=[0,2000.4,0],outputPath,addFloor=true}={}){
  if(typeof call!=='function'||!mapPath)throw Error('prepareNativeScene needs call and mapPath');
  if(!Array.isArray(anchor)||anchor.length!==3||!anchor.every(Number.isFinite))throw Error('anchor needs three finite coordinates');
  const seeded=await seedCreaturePrefabs({mapPath,outputPath});mapPath=seeded.mapPath;
  async function invoke(name,args={}){const result=await call(name,{...args,mapPath});if(result.error||result.isError)throw Error(`${name}: ${JSON.stringify(result)}`);if(result.mapPath)mapPath=result.mapPath;return result;}
  const listed=await invoke('scene_list_prefabs');
  for(const p of seeded.prefabs)if(!listed.prefabs.some(r=>r.prefabId===p.prefabId&&r.assetId===p.asset))throw Error('Tool prefab readback failed');
  await invoke('scene_set_faction_hostility',{hostilePairs:[]});
  await invoke('scene_set_level_settings',{aggroMode:'custom'});
  await invoke('scene_set_player_count',{min:1,max:1});
  await invoke('scene_set_spawn',{position:anchor,rotation:[0,0,0]});
  let floor;
  if(addFloor){
    floor=await invoke('scene_add_prefab',{asset:20002055,name:'LAB3D_floor',scale:[5,1,5]});
    await invoke('scene_add_components',{prefab:floor.prefabId,extraCollision:{areas:[{size:[5,0.5,5]}]}});
  }
  const cameras=await invoke('scene_list_cameras');
  if(cameras.cameras?.length)await invoke('scene_set_camera',{distance:18,fieldOfView:55,fixedView:{yaw:0,pitch:22}});
  for(const [name,parameters] of [['LAB3D_COMMAND',[{name:'command',type:'string'},{name:'model',type:'integer'},{name:'actor',type:'integer'},{name:'seq',type:'integer'}]],['LAB3D_ACK',[{name:'message',type:'string'},{name:'seq',type:'integer'}]]])await invoke('scene_add_signal',{name,parameters});
  const safe=await invoke('scene_add_unit_status',{name:'LAB3D_invincible',invincible:true});
  const playerSafe=await invoke('scene_add_unit_status',{name:'LAB3D_player_rooted',invincible:true,rooted:true});
  await invoke('scene_add_components',{entity:'关卡实体',variables:[{name:'LAB_lastseq',type:'integer',value:0}]});
  const graphs={};
  for(const [key,kind] of [['server','server'],['unit','server'],['decision','creatureDecision'],['idle','creatureStatus'],['attack','creatureStatus'],['hit','creatureStatus'],['skill_attack','creatureSkill'],['skill_hit','creatureSkill']]){
    graphs[key]=await invoke('scene_add_graph',{name:`LAB3D_${key}`,kind,...(key==='unit'?{attachToPrefab:seeded.prefabs.map(p=>p.prefabId)}:{})});
  }
  for(const p of seeded.prefabs){
    await invoke('scene_add_components',{prefab:p.prefabId,variables:[{name:'LAB_actor',type:'integer',value:0},{name:'LAB_seq',type:'integer',value:0},{name:'LAB_command',type:'integer',value:0},{name:'LAB_busy',type:'integer',value:0}]});
    const skills=[];
    for(const action of ['attack',...(p.hit?['hit']:[])]){
      const skill=await invoke('scene_add_creature_skill',{name:`LAB3D_${p.model}_${action}`,creature:p.asset,animation:p[action],graphId:graphs[`skill_${action}`].graphId,graphAtMs:Math.floor(p[`${action}Seconds`]*1000)-1,faceTarget:false,interrupts:true});
      skills.push({skill:skill.skillId,firstCooldownSeconds:0,cooldownSeconds:0.5});
    }
    await invoke('scene_set_creature_logic',{prefab:p.prefabId,decisionGraphId:graphs.decision.graphId,skills,sharedCooldownSeconds:0,logic:{sightDistance:0.01,chainRadius:0.01,territoryRadius:20}});
  }
  const sources=nativeGraphSources({graphs,prefabs:seeded.prefabs,statusId:safe.statusId,playerStatusId:playerSafe.statusId,floorId:floor?.prefabId,anchor});
  const compiled=await invoke('write_graphs',{graphs:sources});
  if(compiled.failed||compiled.errors?.length||compiled.written?.length!==sources.length)throw Error(`Native graph compilation incomplete: ${JSON.stringify(compiled)}`);
  const inspected=await invoke('inspect_map');
  for(const graph of Object.values(graphs))if(!inspected.graphs.some(r=>r.id===graph.graphId&&r.nodeCount>0))throw Error('Native graph readback incomplete');
  return {mapPath,anchor,prefabs:seeded.prefabs,graphs,sources,statusId:safe.statusId,playerStatusId:playerSafe.statusId,floor,provenance:seeded.provenance,
    capabilities:{models:seeded.prefabs.map(p=>({model:p.model,name:p.name,idle:'native_standing',attack:true,hit:Boolean(p.hit),death:'destroyEntity_effect_not_clip'})),playerAnimation:false,actors:3,initializationSeconds:4.5,commands:['show','hide','reset','idle','attack','hit','death'],damageAuthority:'existing_lua_only',animationReceipt:'skill_endpoint_not_visual_confirmation',officialImport:'not_run',phone:'not_run'}};
}
